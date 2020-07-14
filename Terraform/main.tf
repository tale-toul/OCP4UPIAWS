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
        "kubernetes.io/cluster/${var.infra_name}" = "shared"
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
      "kubernetes.io/cluster/${var.infra_name}" = "shared"
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
  name = "nlb-${var.infra_name}-ext"
  internal = false
  load_balancer_type = "network"
  subnets = aws_subnet.subnet_pub.*.id
  ip_address_type = "ipv4"

  tags = {
    Clusterid = var.cluster_name
  }
}

#Target group for the external API NLB
#Attachment to the target groups is defined next to the EC2 instances definition
resource "aws_lb_target_group" "external_tg" {
  name = "${var.infra_name}-ext-lb"
  port = 6443
  protocol = "TCP"
  target_type = "ip"
  vpc_id = aws_vpc.vpc.id
  deregistration_delay = 60

  tags = {
    Clusterid = var.cluster_name
  }
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
  name = "nlb-${var.infra_name}-int"
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
  name = "${var.infra_name}-int-lb"
  port = 6443
  protocol = "TCP"
  target_type = "ip"
  vpc_id = aws_vpc.vpc.id
  deregistration_delay = 60

  tags = {
    Clusterid = var.cluster_name
  }
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
  name = "${var.infra_name}-intsvc-lb"
  port = 22623
  protocol = "TCP"
  target_type = "ip"
  vpc_id = aws_vpc.vpc.id
  deregistration_delay = 60

  tags = {
    Clusterid = var.cluster_name
  }
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
#IAM role for master EC2 instances
resource "aws_iam_role" "master-role" {
  name = "${var.infra_name}-master-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags = {
    Clusterid = var.cluster_name
  }
}

#Policies for the master role
resource "aws_iam_role_policy" "master-policy" {
  name = "${var.infra_name}-master-policy"
  role = aws_iam_role.master-role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "ec2:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
          "elasticloadbalancing:*"
        ],
      "Resource":  "*" 
    },
    {
      "Effect": "Allow",
      "Action": [
          "iam:PassRole"
        ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
          "s3:GetObject"
        ],
      "Resource": "*"
    }
  ]
}
EOF
}

#Instance profile for the master role
resource "aws_iam_instance_profile" "master-profile" {
  name = "${var.infra_name}-master-profile"
  role = aws_iam_role.master-role.name
}

#IAM role for worker EC2 instances
resource "aws_iam_role" "worker-role" {
  name = "${var.infra_name}-worker-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags = {
    Clusterid = var.cluster_name
  }
}

#Policies for the worker role
resource "aws_iam_role_policy" "worker-policy" {
  name = "${var.infra_name}-worker-policy"
  role = aws_iam_role.worker-role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "ec2:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

#Instance profile for the worker role
resource "aws_iam_instance_profile" "worker-profile" {
  name = "${var.infra_name}-worker-profile"
  role = aws_iam_role.worker-role.name
}

#IAM role for bootstrap EC2 instance
resource "aws_iam_role" "bootstrap-role" {
  name = "${var.infra_name}-bootstrap-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags = {
    Clusterid = var.cluster_name
  }
}

#Policies for the bootstrap role
resource "aws_iam_role_policy" "bootstrap-policy" {
  name = "${var.infra_name}-bootstrap-policy"
  role = aws_iam_role.bootstrap-role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "ec2:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
          "ec2:AttachVolume"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
          "ec2:DetachVolume"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
          "s3:GetObject"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

#Instance profile for the bootstrap role
resource "aws_iam_instance_profile" "bootstrap-profile" {
  name = "${var.infra_name}-bootstrap-profile"
  role = aws_iam_role.bootstrap-role.name
  path = "/"
}

#SECURITY GROUPS
#Master security group
resource "aws_security_group" "master-sg" {
    name = "${var.infra_name}-master-sg"
    description = "Security group for master nodes"
    vpc_id = aws_vpc.vpc.id

    tags = {
        Name = "${var.infra_name}-master-sg"
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
  description = "ignition config files"
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
    name = "${var.infra_name}-worker-sg"
    description = "Security group for worker nodes"
    vpc_id = aws_vpc.vpc.id

    tags = {
        Name = "${var.infra_name}-worker-sg"
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

#Bootstrap security group
resource "aws_security_group" "bootstrap-sg" {
    name = "${var.infra_name}-bootstrap-sg"
    description = "Security group for bootstrap node"
    vpc_id = aws_vpc.vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 19531
        to_port = 19531
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.infra_name}-bootstrap-sg"
        Clusterid = var.cluster_name
    }
}

resource "aws_security_group_rule" "outbound-all-master-sgr" {
  type = "egress"
  description = "Allow all outbound connections from master EC2s"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.master-sg.id
}

resource "aws_security_group_rule" "outbound-all-worker-sgr" {
  type = "egress"
  description = "Allow all outbound connections from workers EC2s"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.worker-sg.id
}

resource "aws_security_group_rule" "outbound-all-bootstrap-sgr" {
  type = "egress"
  description = "Allow all outbound connections from bootstrap EC2s"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bootstrap-sg.id
}

###EC2s
#Bootstrap 
resource "aws_instance" "bootstrap-ec2" {
  ami = var.rhcos-ami[var.region_name]
  iam_instance_profile = aws_iam_instance_profile.bootstrap-profile.name
  instance_type = "m5.large"
  depends_on = [aws_s3_bucket.ignition-bucket]
  
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.bootstrap-nic.id
  }

  user_data = <<-EOF
    {"ignition":{"config":{"replace":{"source":"s3://${aws_s3_bucket.ignition-bucket.id}/bootstrap.ign","verification":{}}},"timeouts":{},"version":"2.1.0"},"networkd":{},"passwd":{},"storage":{},"systemd":{}}
  EOF

  tags = {
        Name = "boostrap-${var.infra_name}"
        Clusterid = var.cluster_name
        "kubernetes.io/cluster/${var.infra_name}" = "shared"
  }
}

#Network interface for bootstrap instance
resource "aws_network_interface" "bootstrap-nic" {
  security_groups = [aws_security_group.master-sg.id, aws_security_group.bootstrap-sg.id]
  #Linkded to the subnet 0 for no particular reason
  subnet_id = aws_subnet.subnet_pub[0].id 

  tags = {
        Clusterid = var.cluster_name
  }
}

#Attachment to the external API target group for bootstrap instance
resource "aws_lb_target_group_attachment" "bootstrap-external-api-attach" {
  target_group_arn = aws_lb_target_group.external_tg.arn
  target_id = aws_instance.bootstrap-ec2.private_ip
}

#Attachment to the internal API target group for bootstrap instance
resource "aws_lb_target_group_attachment" "bootstrap-internal-api-attach" {
  target_group_arn = aws_lb_target_group.internal_tg.arn
  target_id = aws_instance.bootstrap-ec2.private_ip
}

#Attachment to the internal service target group for bootstrap instance
resource "aws_lb_target_group_attachment" "bootstrap-external-service-attach" {
  target_group_arn = aws_lb_target_group.internal_service_tg.arn
  target_id = aws_instance.bootstrap-ec2.private_ip
}

#Masters EC2 instances
resource "aws_instance" "master-ec2" {
  count = local.private_subnet_count
  depends_on = [aws_route53_record.api-internal-internal]
  ami = var.rhcos-ami[var.region_name]
  iam_instance_profile = aws_iam_instance_profile.master-profile.name
  instance_type = "m5.xlarge"

  root_block_device {
      volume_size = 120
      volume_type = "gp2"
      delete_on_termination = true
  }

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.master-nic[count.index].id
  }

  user_data = <<-EOF
    {"ignition":{"config":{"append":[{"source":"https://api-int.${var.cluster_name}.${local.dotless_domain}:22623/config/master","verification":{}}]},"security":{"tls":{"certificateAuthorities":[{"source":"${var.master_ign_CA}","verification":{}}]}},"timeouts":{},"version":"2.2.0"},"networkd":{},"passwd":{},"storage":{},"systemd":{}}
  EOF

  tags = {
        Name = "master-${var.infra_name}.${count.index}"
        Clusterid = var.cluster_name
        "kubernetes.io/cluster/${var.infra_name}" = "shared"
  }
}

#Network interface for the master EC2 instances
resource "aws_network_interface" "master-nic" {
  count = local.private_subnet_count
  security_groups = [aws_security_group.master-sg.id]
  subnet_id = aws_subnet.subnet_priv[count.index].id

  tags = {
        Clusterid = var.cluster_name
  }
}

#Attachment to the external API target group for master instances
resource "aws_lb_target_group_attachment" "master-external-api-attach" {
  count = local.private_subnet_count
  target_group_arn = aws_lb_target_group.external_tg.arn
  target_id = aws_instance.master-ec2[count.index].private_ip
}

#Attachment to the internal API target group for master instances
resource "aws_lb_target_group_attachment" "master-internal-api-attach" {
  count = local.private_subnet_count
  target_group_arn = aws_lb_target_group.internal_tg.arn
  target_id = aws_instance.master-ec2[count.index].private_ip
}

#Attachment to the internal service target group for master instances
resource "aws_lb_target_group_attachment" "master-external-service-attach" {
  count = local.private_subnet_count
  target_group_arn = aws_lb_target_group.internal_service_tg.arn
  target_id = aws_instance.master-ec2[count.index].private_ip
}


#ROUTE53 CONFIG
#Datasource for rhcee.support. route53 zone
data "aws_route53_zone" "domain" {
  zone_id = var.dns_domain_ID
}

#External API DNS record
resource "aws_route53_record" "api-external" {
    zone_id = var.dns_domain_ID
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
  name = "${var.cluster_name}.${data.aws_route53_zone.domain.name}"

  vpc {
    vpc_id = aws_vpc.vpc.id
  }

  tags = {
    Name = "${var.infra_name}-int"
    Clusterid = var.cluster_name
    "kubernetes.io/cluster/${var.infra_name}" = "owned"
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

#S3
#S3 disk to store ignition config files
resource "aws_s3_bucket" "ignition-bucket" {
  bucket = "${var.infra_name }-ignition"
  region = var.region_name
  force_destroy = true

  acl    = "private"

  tags = {
    Name  = "${var.infra_name }-ignition"
    Clusterid = var.cluster_name
  }
}

#Copy bootstrap ignition file to the above bucket
resource "aws_s3_bucket_object" "bootstrap-ignition-file" {
  bucket = aws_s3_bucket.ignition-bucket.id
  key = "bootstrap.ign"
  source = "${path.module}/../${var.cluster_name}/bootstrap.ign"
  etag   = filemd5("${path.module}/../${var.cluster_name}/bootstrap.ign")
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

output "ignition-s3-bucket" {
  value = aws_s3_bucket.ignition-bucket.id
  description ="S3 bucket used to store the bootstrap ignition config file"
}
