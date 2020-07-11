#PROVIDERS
provider "aws" {
  region = var.region_name
  version = "~> 2.69.0"
  shared_credentials_file = "aws-credentials.ini"
}

#This is only used to generate random values
provider "random" {
  version = "~> 2.3.0"
}

#Provides a source to create a short random string 
resource "random_string" "sufix_name" {
  length = 5
  upper = false
  special = false
}

#VPC
resource "aws_vpc" "vpc" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
        Name = var.vpc_name
        Clusterid = var.cluster_name
    }
}

resource "aws_vpc_dhcp_options" "vpc-options" {
  domain_name = var.region_name == "us-east-1" ? "ec2.internal" : "${var.region_name}.compute.internal" 
  domain_name_servers  = ["AmazonProvidedDNS"] 

  tags = {
        Clusterid = var.cluster_name
  }
}

resource "aws_vpc_dhcp_options_association" "vpc-association" {
  vpc_id          = aws_vpc.vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.vpc-options.id
}

#SUBNETS
data "aws_availability_zones" "avb-zones" {
  state = "available"
}

#Public subnets
resource "aws_subnet" "subnet_pub" {
    count = local.public_subnet_count
    vpc_id = aws_vpc.vpc.id
    availability_zone = data.aws_availability_zones.avb-zones.names[count.index]
    #CIDR: 172.20.0.0/20; 172.20.16.0/20; 172.20.32.0/20; 
    cidr_block = "172.20.${count.index * 16}.0/20"
    map_public_ip_on_launch = true

    tags = {
        Name = "subnet_pub.${count.index}"
        Clusterid = var.cluster_name
        "kubernetes.io/cluster/${var.cluster_name}-${local.ran_string_tag}" = "shared"
    }
}

#Private subnets
resource "aws_subnet" "subnet_priv" {
  count = local.private_subnet_count 
  vpc_id = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.avb-zones.names[count.index]
  #CIDR: 172.20.128.0/20; 172.20.144.0/20; 172.20.160.0/20; 
  cidr_block = "172.20.${(count.index + 8) * 16}.0/20"
  map_public_ip_on_launch = false

  tags = {
      Name = "subnet_priv.${count.index}"
      Clusterid = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}-${local.ran_string_tag}" = "shared"
  }
}

#ENDPOINTS
#S3 endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.region_name}.s3"
  route_table_ids = concat(aws_route_table.rtable_priv[*].id, [aws_route_table.rtable_igw.id]) 
  vpc_endpoint_type = "Gateway"

  tags = {
      Clusterid = var.cluster_name
  }
}

##EC2 endpoint
#resource "aws_vpc_endpoint" "ec2" {
#  vpc_id = aws_vpc.vpc.id
#  service_name = "com.amazonaws.${var.region_name}.ec2"
#  vpc_endpoint_type = "Interface"
#  private_dns_enabled = true
#
#  subnet_ids = aws_subnet.subnet_priv[*].id
#
#  security_group_ids = [aws_security_group.sg-all-out.id, 
#                        aws_security_group.sg-web-in.id]
#
#  tags = {
#      Clusterid = var.cluster_name
#  }
#}

##Elastic Load Balancing endpoint
#resource "aws_vpc_endpoint" "elb" {
#  vpc_id = aws_vpc.vpc.id
#  service_name = "com.amazonaws.${var.region_name}.elasticloadbalancing"
#  vpc_endpoint_type = "Interface"
#  private_dns_enabled = true
#
#  subnet_ids = aws_subnet.subnet_priv[*].id
#
#  security_group_ids = [aws_security_group.sg-all-out.id, 
#                        aws_security_group.sg-web-in.id]
#
#  tags = {
#      Clusterid = var.cluster_name
#  }
#}

#INTERNET GATEWAY
resource "aws_internet_gateway" "intergw" {
    vpc_id = aws_vpc.vpc.id

    tags = {
        Name = "intergw"
        Clusterid = var.cluster_name
    }
}

#EIPS
resource "aws_eip" "nateip" {
  count = var.enable_proxy ? 0 : local.public_subnet_count
  vpc = true
  tags = {
      Name = "nateip.${count.index}"
      Clusterid = var.cluster_name
  }
}

#resource "aws_eip" "bastion_eip" {
#    vpc = true
#    instance = aws_instance.tale_bastion.id
#
#    tags = {
#        Name = "bastion_eip"
#        Clusterid = var.cluster_name
#    }
#}

#NAT GATEWAYs
resource "aws_nat_gateway" "natgw" {
    count = var.enable_proxy ? 0 : local.public_subnet_count
    allocation_id = aws_eip.nateip[count.index].id
    subnet_id = aws_subnet.subnet_pub[count.index].id
    depends_on = [aws_internet_gateway.intergw]

    tags = {
        Name = "natgw.${count.index}"
        Clusterid = var.cluster_name
    }
}

##ROUTE TABLES
#Route table: Internet Gateway access for public subnets
resource "aws_route_table" "rtable_igw" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.intergw.id
    }
    tags = {
        Name = "rtable_igw"
        Clusterid = var.cluster_name
    }
}

#Route table associations to the public subnets
resource "aws_route_table_association" "rtabasso_subnet_pub" {
    count = local.public_subnet_count
    subnet_id = aws_subnet.subnet_pub[count.index].id
    route_table_id = aws_route_table.rtable_igw.id
}

#Route tables for private subnets
resource "aws_route_table" "rtable_priv" {
    count =  local.private_subnet_count
    vpc_id = aws_vpc.vpc.id

    tags = {
        Name = "rtable_priv.${count.index}"
        Clusterid = var.cluster_name
    }
}

resource "aws_route" "internet_access" {
  count = var.enable_proxy ? 0 : local.private_subnet_count
  route_table_id = aws_route_table.rtable_priv[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.natgw[count.index].id
}

#Route table associations  to private subnets
resource "aws_route_table_association" "rtabasso_nat_priv" {
    count = local.private_subnet_count
    subnet_id = aws_subnet.subnet_priv[count.index].id
    route_table_id = aws_route_table.rtable_priv[count.index].id
}

#LOAD BALANCERS

#External API loadbalancer
resource "aws_lb" "ext_api_lb" {
  name = "nlb-${var.cluster_name}-ext"
  internal = false
  load_balancer_type = "network"
  subnets = aws_subnet.subnet_pub.*.id
  ip_address_type = "ipv4"

  tags = {
    Clusterid = var.cluster_name
  }
}

#Target group for the external API NLB
resource "aws_lb_target_group" "external_tg" {
  name = "tg-external-lb"
  port = 6443
  protocol = "TCP"
  target_type = "ip"
  vpc_id = aws_vpc.vpc.id
  deregistration_delay = 60
}

#Listener for the external API NLB
resource "aws_lb_listener" "external_listener" {
  load_balancer_arn = aws_lb.ext_api_lb.arn
  port = "6443"
  protocol = "TCP"
  
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.external_tg.arn
  }
}

#Internal API loadbalancer
resource "aws_lb" "int_api_lb" {
  name = "nlb-${var.cluster_name}-int"
  internal = true
  load_balancer_type = "network"
  subnets = aws_subnet.subnet_priv.*.id
  ip_address_type = "ipv4"

  tags = {
    Clusterid = var.cluster_name
  }
}

#Target group for the internal API NLB
resource "aws_lb_target_group" "internal_tg" {
  name = "tg-internal-lb"
  port = 6443
  protocol = "TCP"
  target_type = "ip"
  vpc_id = aws_vpc.vpc.id
  deregistration_delay = 60
}

#Listener for the internal API NLB
resource "aws_lb_listener" "internal_listener" {
  load_balancer_arn = aws_lb.int_api_lb.arn
  port = "6443"
  protocol = "TCP"
  
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.internal_tg.arn
  }
}

#Target group for the internal service API NLB
resource "aws_lb_target_group" "internal_service_tg" {
  name = "tg-internal-service-lb"
  port = 22623
  protocol = "TCP"
  target_type = "ip"
  vpc_id = aws_vpc.vpc.id
  deregistration_delay = 60
}

#Listener for the internal service API NLB
resource "aws_lb_listener" "internal_service_listener" {
  load_balancer_arn = aws_lb.int_api_lb.arn
  port = "22623"
  protocol = "TCP"
  
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.internal_service_tg.arn
  }
}

#IAM
#At the moment I'm dropping the IAM section about updating target groups and automatic tagging, which should not be required for installation.
##IAM role to (de)register targets in the NLBs
#resource "aws_iam_role" "reg-target-lambda-role" {
#  name = "${var.cluster_name}-nlb-lambda-role"
#  path = "/"
#  
#  assume_role_policy = <<EOF
#{
#  "Version": "2012-10-17",
#  "Statement": [
#    {
#      "Effect": "Allow",
#      "Principal": {
#        "Service": "lambda.amazonaws.com"
#      },
#      "Action": "sts:AssumeRole"
#    }
#  ]
#}
#EOF
#  tags = {
#    Clusterid = var.cluster_name
#  }
#}
#
##Policies for (de)register target roles
#resource "aws_iam_role_policy" "reg-target-policy" {
#  name = "${var.cluster_name}-reg-taget-policy"
#  role = aws_iam_role.reg-target-lambda-role.id
#
#  policy = <<EOF
#{
#  "Version": "2012-10-17",
#  "Statement": [
#    {
#      "Effect": "Allow",
#      "Action": [
#          "elasticloadbalancing:RegisterTargets",
#          "elasticloadbalancing:DeregisterTargets"
#      ],
#      "Resource": "${aws_lb_target_group.internal_tg.arn}"
#    },
#    {
#      "Effect": "Allow",
#      "Action": [
#          "elasticloadbalancing:RegisterTargets",
#          "elasticloadbalancing:DeregisterTargets"
#        ],
#      "Resource":  "${aws_lb_target_group.internal_service_tg.arn}" 
#    },
#    {
#      "Effect": "Allow",
#      "Action": [
#          "elasticloadbalancing:RegisterTargets",
#          "elasticloadbalancing:DeregisterTargets"
#        ],
#      "Resource": "${aws_lb_target_group.external_tg.arn}"
#    }
#  ]
#}
#EOF
#}

#SECURITY GROUPS
#Master security group
resource "aws_security_group" "master-sg" {
    name = "master-sg"
    description = "Security group for master nodes"
    vpc_id = aws_vpc.vpc.id

    tags = {
        Clusterid = var.cluster_name
    }
}

resource "aws_security_group_rule" "icmp-master" {
  type = "ingress"
  from_port = 0
  to_port = 0
  protocol = "icmp"
  cidr_blocks = [var.vpc_cidr]
  security_group_id = aws_security_group.master-sg.id
}

resource "aws_security_group_rule" "ssh-master" {
  type = "ingress" 
  description = "ssh"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = [var.vpc_cidr]
  security_group_id = aws_security_group.master-sg.id
}

resource "aws_security_group_rule" "api-master" {
  type = "ingress" 
  description = "api"
  from_port = 6443
  to_port = 6443
  protocol = "tcp"
  cidr_blocks = [var.vpc_cidr]
  security_group_id = aws_security_group.master-sg.id
}

resource "aws_security_group_rule" "ignition-master" {
  type = "ingress"
  description = "ignition config"
  from_port = 22623
  to_port = 22623
  protocol = "tcp"
  cidr_blocks = [var.vpc_cidr]
  security_group_id = aws_security_group.master-sg.id
}

resource "aws_security_group_rule" "etcd-master" {
  type = "ingress"
  description = "etcd"
  from_port = 2379
  to_port = 2380
  protocol = "tcp"
  security_group_id = aws_security_group.master-sg.id
  self = true
}

resource "aws_security_group_rule" "vxlan-master" {
  type = "ingress"
  description = "Vxlan packets"
  from_port = 4789
  to_port = 4789
  protocol = "udp"
  security_group_id = aws_security_group.master-sg.id
  source_security_group_id = aws_security_group.worker-sg.id
}

resource "aws_security_group_rule" "vxlan-master-self" {
  type = "ingress"
  description = "Vxlan packets"
  from_port = 4789
  to_port = 4789
  protocol = "udp"
  security_group_id = aws_security_group.master-sg.id
  self = true
}

resource "aws_security_group_rule" "internal-master" {
  type = "ingress"
  description = "Internal cluster communication"
  from_port = 9000
  to_port = 9999
  protocol = "tcp"
  security_group_id = aws_security_group.master-sg.id
  source_security_group_id = aws_security_group.worker-sg.id
}

resource "aws_security_group_rule" "internal-master-self" {
  type = "ingress"
  description = "Internal cluster communication"
  from_port = 9000
  to_port = 9999
  protocol = "tcp"
  security_group_id = aws_security_group.master-sg.id
  self = true
}

resource "aws_security_group_rule" "kubelet-master" {
  type = "ingress"
  description = "Kubernetes kubelet, scheduler and controller manager"
  from_port = 10250
  to_port = 10259
  protocol = "tcp"
  security_group_id = aws_security_group.master-sg.id
  source_security_group_id = aws_security_group.worker-sg.id
}

resource "aws_security_group_rule" "kubelet-master-self" {
  type = "ingress"
  description = "Kubernetes kubelet, scheduler and controller manager"
  from_port = 10250
  to_port = 10259
  protocol = "tcp"
  security_group_id = aws_security_group.master-sg.id
  self = true
}

resource "aws_security_group_rule" "services-master" {
  type = "ingress"
  description = "Kubernetes ingress services"
  from_port = 30000
  to_port = 32767
  protocol = "tcp"
  security_group_id = aws_security_group.master-sg.id
  source_security_group_id = aws_security_group.worker-sg.id
}

resource "aws_security_group_rule" "services-master-self" {
  type = "ingress"
  description = "Kubernetes ingress services"
  from_port = 30000
  to_port = 32767
  protocol = "tcp"
  security_group_id = aws_security_group.master-sg.id
  self = true
}

#Worker security group
resource "aws_security_group" "worker-sg" {
    name = "worker-sg"
    description = "Security group for worker nodes"
    vpc_id = aws_vpc.vpc.id

    tags = {
        Clusterid = var.cluster_name
    }
}

resource "aws_security_group_rule" "icmp-worker" {
  type = "ingress"
  from_port = 0
  to_port = 0
  protocol = "icmp"
  cidr_blocks = [var.vpc_cidr]
  security_group_id = aws_security_group.worker-sg.id
}

resource "aws_security_group_rule" "ssh-worker" {
  type = "ingress" 
  description = "ssh"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = [var.vpc_cidr]
  security_group_id = aws_security_group.worker-sg.id
}

resource "aws_security_group_rule" "vxlan-worker" {
  type = "ingress"
  description = "Vxlan packets"
  from_port = 4789
  to_port = 4789
  protocol = "udp"
  security_group_id = aws_security_group.worker-sg.id
  source_security_group_id = aws_security_group.master-sg.id
}

resource "aws_security_group_rule" "vxlan-worker-self" {
  type = "ingress"
  description = "Vxlan packets"
  from_port = 4789
  to_port = 4789
  protocol = "udp"
  security_group_id = aws_security_group.worker-sg.id
  self = true
}

resource "aws_security_group_rule" "internal-worker" {
  type = "ingress"
  description = "Internal cluster communication"
  from_port = 9000
  to_port = 9999
  protocol = "tcp"
  security_group_id = aws_security_group.worker-sg.id
  source_security_group_id = aws_security_group.master-sg.id
}

resource "aws_security_group_rule" "internal-worker-self" {
  type = "ingress"
  description = "Internal cluster communication"
  from_port = 9000
  to_port = 9999
  protocol = "tcp"
  security_group_id = aws_security_group.worker-sg.id
  self = true
}

resource "aws_security_group_rule" "kubelet-worker" {
  type = "ingress"
  description = "Kubernetes secure kubelet port"
  from_port = 10250
  to_port = 10250
  protocol = "tcp"
  security_group_id = aws_security_group.worker-sg.id
  source_security_group_id = aws_security_group.master-sg.id
}

resource "aws_security_group_rule" "kubelet-worker-self" {
  type = "ingress"
  description = "Kubernetes secure kubelet port"
  from_port = 10250
  to_port = 10250
  protocol = "tcp"
  security_group_id = aws_security_group.worker-sg.id
  self = true
}

resource "aws_security_group_rule" "services-worker" {
  type = "ingress"
  description = "Kubernetes ingress services"
  from_port = 30000
  to_port = 32767
  protocol = "tcp"
  security_group_id = aws_security_group.worker-sg.id
  source_security_group_id = aws_security_group.master-sg.id
}

resource "aws_security_group_rule" "services-worker-self" {
  type = "ingress"
  description = "Kubernetes ingress services"
  from_port = 30000
  to_port = 32767
  protocol = "tcp"
  security_group_id = aws_security_group.worker-sg.id
  self = true
}

#resource "aws_security_group" "sg-squid" {
#    count = var.enable_proxy ? 1 : 0
#    name = "squid"
#    description = "Allow squid proxy access"
#    vpc_id = aws_vpc.vpc.id
#
#  ingress {
#    from_port = 3128
#    to_port = 3128
#    protocol = "tcp"
#    cidr_blocks = [var.vpc_cidr]
#    }
#
#    tags = {
#        Name = "sg-ssh"
#        Clusterid = var.cluster_name
#    }
#}
#
#resource "aws_security_group" "sg-web-in" {
#    name = "web-in"
#    description = "Allow http and https inbound connections from anywhere"
#    vpc_id = aws_vpc.vpc.id
#
#    ingress {
#        from_port = 80
#        to_port = 80
#        protocol = "tcp"
#        cidr_blocks = [var.vpc_cidr]
#    }
#
#    ingress {
#        from_port = 443
#        to_port = 443
#        protocol = "tcp"
#        cidr_blocks = [var.vpc_cidr]
#    }
#
#    tags = {
#        Name = "sg-web-in"
#        Clusterid = var.cluster_name
#    }
#}
#resource "aws_security_group" "sg-all-out" {
#    name = "all-out"
#    description = "Allow all outgoing traffic"
#    vpc_id = aws_vpc.vpc.id
#
#  egress {
#    from_port = 0
#    to_port = 0
#    protocol = "-1"
#    cidr_blocks = ["0.0.0.0/0"]
#    }
#
#    tags = {
#        Name = "all-out"
#        Clusterid = var.cluster_name
#    }
#}
#
#
###EC2s
###SSH key
#resource "aws_key_pair" "ssh-key" {
#  key_name = "ssh-key-${random_string.sufix_name.result}"
#  public_key = file("${path.module}/${var.ssh-keyfile}")
#}
#
##Bastion host
#resource "aws_instance" "tale_bastion" {
#  ami = var.rhel7-ami[var.region_name]
#  instance_type = "m4.large"
#  subnet_id = aws_subnet.subnet_pub.0.id
#  vpc_security_group_ids = local.bastion_security_groups
#  key_name= aws_key_pair.ssh-key.key_name
#
#  root_block_device {
#      volume_size = 25
#      delete_on_termination = true
#  }
#
#  tags = {
#        Name = "bastion"
#        Clusterid = var.cluster_name
#  }
#}
#
#ROUTE53 CONFIG
#Datasource for rhcee.support. route53 zone
data "aws_route53_zone" "domain" {
  zone_id = var.dns_domain_ID
}

##External hosted zone, this is a public zone because it is not associated with a VPC. 
resource "aws_route53_zone" "external" {
  name = "${var.domain_name}.${data.aws_route53_zone.domain.name}"

  tags = {
    Name = "external"
    Clusterid = var.cluster_name
  }
}

resource "aws_route53_record" "external-ns" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "${var.domain_name}.${data.aws_route53_zone.domain.name}"
  type    = "NS"
  ttl     = "30"

  records = [
    "${aws_route53_zone.external.name_servers.0}",
    "${aws_route53_zone.external.name_servers.1}",
    "${aws_route53_zone.external.name_servers.2}",
    "${aws_route53_zone.external.name_servers.3}",
  ]
}

#External API DNS record
resource "aws_route53_record" "api-external" {
    zone_id = aws_route53_zone.external.zone_id
    name = "api.${var.cluster_name}"
    type = "A"

    alias {
      name = aws_lb.ext_api_lb.dns_name
      zone_id = aws_lb.ext_api_lb.zone_id
      evaluate_target_health = false
    }
}

#Internal hosted zone, this is private because it is associated with a VPC.
resource "aws_route53_zone" "internal" {
  name = "${var.cluster_name}.${var.domain_name}.${data.aws_route53_zone.domain.name}"

  vpc {
    vpc_id = aws_vpc.vpc.id
  }

  tags = {
    Name = "internal"
    Clusterid = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

#Internal API DNS record, for external name
resource "aws_route53_record" "api-internal-external" {
    zone_id = aws_route53_zone.internal.zone_id
    name = "api"
    type = "A"

    alias {
      name = aws_lb.int_api_lb.dns_name
      zone_id = aws_lb.int_api_lb.zone_id
      evaluate_target_health = false
    }
}

#Internal API DNS record, for internal name
resource "aws_route53_record" "api-internal-internal" {
    zone_id = aws_route53_zone.internal.zone_id
    name = "api-int"
    type = "A"

    alias {
      name = aws_lb.int_api_lb.dns_name
      zone_id = aws_lb.int_api_lb.zone_id
      evaluate_target_health = false
    }
}
##OUTPUT
output "api_extenal_name" {
  value     = aws_route53_record.api-external.fqdn
  description = "DNS name for the API entry point"
}
output "cluster_name" {
 value = var.cluster_name
 description = "Cluser name, used for prefixing some component names like the DNS domain"
}
output "region_name" {
 value = var.region_name
 description = "AWS region where the cluster and its components will be deployed"
}
output "availability_zones" {
  value = aws_subnet.subnet_priv[*].availability_zone
  description = "Names of the availbility zones used to created the subnets"
}
output "private_subnets" {
  value = aws_subnet.subnet_priv[*].id
  description = "Names of the private subnets"
}
output "vpc_cidr" {
  value = var.vpc_cidr
  description = "Network segment for the VPC"
}
output "public_subnet_cidr_block" {
  value = aws_subnet.subnet_pub[*].cidr_block
  description = "Network segments for the public subnets"
}
output "private_subnet_cidr_block" {
  value = aws_subnet.subnet_priv[*].cidr_block
  description = "Network segments for the private subnets"
}
output "enable_proxy" {
  value = var.enable_proxy
  description = "Is the proxy enabled or not?"
}
