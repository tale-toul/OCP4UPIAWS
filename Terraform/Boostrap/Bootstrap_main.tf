#Bootstrap resources

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
    "kubernetes.io/cluster/${var.infra_name}" = "shared"
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

#Bootstrap security group
resource "aws_security_group" "bootstrap-sg" {
    name = "${var.infra_name}-bootstrap-sg"
    description = "Security group for bootstrap node"
    vpc_id = var.vpc_id

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

    egress {
        from_port = 0 
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.infra_name}-bootstrap-sg"
        Clusterid = var.cluster_name
        "kubernetes.io/cluster/${var.infra_name}" = "shared"
    }
}

#Bootstrap 
resource "aws_instance" "bootstrap-ec2" {
  ami = var.rhcos-ami
  iam_instance_profile = aws_iam_instance_profile.bootstrap-profile.name
  instance_type = var.bootstrap_inst_type
  depends_on = [aws_s3_bucket.ignition-bucket]
  
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.bootstrap-nic.id
  }

  user_data = <<-EOF
    {"ignition":{"config":{"replace":{"source":"s3://${aws_s3_bucket.ignition-bucket.id}/bootstrap.ign"}},"version":"3.1.0"}}
  EOF

  tags = {
        Name = "boostrap-${var.infra_name}"
        Clusterid = var.cluster_name
        "kubernetes.io/cluster/${var.infra_name}" = "shared"
  }
}

#Network interface for bootstrap instance
resource "aws_network_interface" "bootstrap-nic" {
  security_groups = [var.master_sg_id, aws_security_group.bootstrap-sg.id]
  #Linkded to the subnet 0 for no particular reason
  subnet_id = var.pub_subnet_id  

  tags = {
        Clusterid = var.cluster_name
        "kubernetes.io/cluster/${var.infra_name}" = "shared"
  }
}

#Attachment to the external API target group for bootstrap instance
resource "aws_lb_target_group_attachment" "bootstrap-external-api-attach" {
  target_group_arn = var.external_api_tg_arn 
  target_id = aws_instance.bootstrap-ec2.private_ip
}

#Attachment to the internal API target group for bootstrap instance
resource "aws_lb_target_group_attachment" "bootstrap-internal-api-attach" {
  target_group_arn = var.internal_api_tg_arn 
  target_id = aws_instance.bootstrap-ec2.private_ip
}

#Attachment to the internal service target group for bootstrap instance
resource "aws_lb_target_group_attachment" "bootstrap-external-service-attach" {
  target_group_arn = var.external_service_tg_arn 
  target_id = aws_instance.bootstrap-ec2.private_ip
}

#S3
#S3 disk to store the bootstrap ignition config file
resource "aws_s3_bucket" "ignition-bucket" {
  bucket = "${var.infra_name }-ignition"
  region = var.region_name
  force_destroy = true

  acl    = "private"

  tags = {
    Name  = "${var.infra_name }-ignition"
    Clusterid = var.cluster_name
    "kubernetes.io/cluster/${var.infra_name}" = "shared"
  }
}

#Copy bootstrap ignition file to the above bucket
resource "aws_s3_bucket_object" "bootstrap-ignition-file" {
  bucket = aws_s3_bucket.ignition-bucket.id
  key = "bootstrap.ign"
  source = "${path.root}/../${var.cluster_name}/bootstrap.ign"
  etag   = filemd5("${path.root}/../${var.cluster_name}/bootstrap.ign")
}

#OUTPUTS
output "ignition-s3-bucket" {
  value = aws_s3_bucket.ignition-bucket.id
  description ="S3 bucket used to store the bootstrap ignition config file"
}
