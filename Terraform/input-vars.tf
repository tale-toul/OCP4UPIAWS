#VARIABLES
variable "region_name" {
  description = "AWS Region where the cluster is deployed"
  type = string
  default = "eu-west-1"
}

variable "domain_name" {
  description = "Public DNS domain name" 
  type = string
  default = "tale"
}

variable "cluster_name" {
  description = "Cluster name, used to define Clusterid tag and as part of other component names"
  type = string
  default = "ocp"
}

variable "vpc_name" {
  description = "Name assigned to the VPC"
  type = string
  default = "volatil"
}

variable "subnet_count" {
  description = "Number of private and public subnets to a maximum of 3, there will be the same number of private and public subnets"
  type = number
  default = 3
}

variable "ssh-keyfile" {
  description = "Name of the file with public part of the SSH key to transfer to the EC2 instances"
  type = string
  default = "ocp-ssh.pub"
}

variable "dns_domain_ID" {
  description = "Zone ID for the route 53 DNS domain that will be used for this cluster"
  type = string
  default = "Z1UPG9G4YY4YK6"
}

variable "rhcos-ami" {
  description = "RHCOS AMI on which the EC2 instances are based on, depends on the region"
  type = map
  default = {
    eu-central-1   = "ami-0a8b58b4be8846e83"
    eu-west-1      = "ami-0d2e5d86e80ef2bd4"
    eu-west-2      = "ami-0a27424b3eb592b4d"
    eu-west-3      = "ami-0a8cb038a6e583bfa"
    eu-north-1     = "ami-04e659bd9575cea3d"
    us-east-1      = "ami-0543fbfb4749f3c3b"
    us-east-2      = "ami-070c6257b10036038"
    us-west-1      = "ami-02b6556210798d665"
    us-west-2      = "ami-0409b2cebfc3ac3d0"
    sa-east-1      = "ami-0d020f4ea19dbc7fa"
    ap-south-1     = "ami-0247a9f45f1917aaa"
    ap-northeast-1 = "ami-05f59cf6db1d591fe"
    ap-northeast-2 = "ami-06a06d31eefbb25c4"
    ap-southeast-1 = "ami-0b628e07d986a6c36"
    ap-southeast-2 = "ami-0bdd5c426d91caf8e"
    ca-central-1   = "ami-0c6c7ce738fe5112b"
    me-south-1     = "ami-0c9d86eb9d0acee5d"
  }
}

variable "vpc_cidr" {
  description = "Network segment for the VPC"
  type = string
  default = "172.20.0.0/16"
}

variable "enable_proxy" {
  description = "If set to true, disables nat gateways and adds sg-squid security group to bastion in preparation for the use of a proxy"
  type  = bool
  default = false
}

#variable "user-data-bootstrap" {
#  description = "User data for bootstrap EC2 instance"
#  type = string
#  default = <<-EOF
#    - '{"ignition":{"config":{"replace":{"source":"${S3Loc}","verification":{}}},"timeouts":{},"version":"2.1.0"},"networkd":{},"passwd":{},"storage":{},"systemd":{}}'
#    - {
#      S3Loc: !Ref BootstrapIgnitionLocation
#  EOF
#}

#LOCALS
locals {
##If enable_proxy is true, the security group sg-squid is added to the list, and later applied to bastion
#bastion_security_groups = var.enable_proxy ? concat([aws_security_group.sg-ssh-in.id, aws_security_group.sg-all-out.id], aws_security_group.sg-squid[*].id) : [aws_security_group.sg-ssh-in.id, aws_security_group.sg-all-out.id]

#The number of private subnets must be between 1 and 3, default is 1
private_subnet_count = var.subnet_count > 0 && var.subnet_count <= 3 ? var.subnet_count : 1

#If the proxy is enable, only 1 public subnet is created for the bastion, otherwise the same number as for the private subnets
public_subnet_count = var.enable_proxy ? 1 : local.private_subnet_count

#Random constant string to add to the kubernetio.io/cluster tags
ran_string_tag = random_string.sufix_name.result
}
