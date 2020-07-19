#VARIABLES
variable "region_name" {
  description = "AWS Region where the cluster is deployed"
  type = string
  default = "eu-west-1"
}

#infra_name has no default value, see README.md to know how to get its value
variable "infra_name" {
  type = string
  description = "Unique string based on the cluster_name used to create the names of other some components" 
}

variable "subnet_count" {
  description = "Number of private and public subnets to a maximum of 3, there will be the same number of private and public subnets"
  type = number
  default = 3
}

variable "dns_domain_ID" {
  description = "Zone ID for the route 53 DNS domain that will be used for this cluster"
  type = string
  default = "Z00639431CO8O47BE0285"
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
  default = "10.0.0.0/16"
}

variable "enable_proxy" {
  description = "If set to true, disables nat gateways and adds sg-squid security group to bastion in preparation for the use of a proxy"
  type  = bool
  default = false
}

variable "master_ign_CA" {
  description = "The Certificate Authority (CA) to be used by the master instances"
  type = string
}

variable "master_inst_type" {
  description = "EC2 instance type for masters"
  type = string
  default = "m5.xlarge"
}

variable "worker_inst_type" {
  description = "EC2 instance type for workers"
  type = string
  default = "m5.large"
}

variable "bootstrap_inst_type" {
  description = "EC2 instance type for bootstrap"
  type = string
  default = "m5.large"
}

#LOCALS
locals {
#The number of private subnets must be between 1 and 3, default is 1
private_subnet_count = var.subnet_count > 0 && var.subnet_count <= 3 ? var.subnet_count : 1

#If the proxy is enable, only 1 public subnet is created for the bastion, otherwise the same number as for the private subnets
public_subnet_count = var.enable_proxy ? 1 : local.private_subnet_count

#Domain name without the dot at the end
dotless_domain = replace("${data.aws_route53_zone.domain.name}","/.$/","")

#Cluster name derived from infra_name
#The regular expression contains two parantheses groups, so it will return a list with two values.  The first value contains the cluster name, that is why the index [0] is assigned to the variable.
#The first parentheses group (^[-0-9A-Za-z]+) selects the longest string possible containing dashes (-), numbers and lower case letters. Uppercase letters are not allowed for the cluster name, but dashes are.
#The second parentheses group will match a string starting with a dash and any letter or number, this second part is never used.
cluster_name = regex("(^[-0-9a-z]+)(-\\w+)", var.infra_name)[0]
}

