#VARIABLES
variable "region_name" {
  description = "AWS Region where the cluster is deployed"
  type = string
  default = "eu-west-1"
}

#infra_name has no default value, see README.md to know how to get its value
variable "infra_name" {
  type = string
  description = "Unique string based on the cluster_name used to create the names of other components" 
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
    af-south-1     = "ami-0067394b051d857f9"
    ap-east-1      = "ami-057f593cc29fd3e08"
    ap-northeast-1 = "ami-0f5bfc3e39711a7d8"
    ap-northeast-2 = "ami-07b8f6b801b49a0b7"
    ap-northeast-3 = "ami-0677b0ba9d47e5e3a"
    ap-south-1     = "ami-0755c7732de0421e7"
    ap-southeast-1 = "ami-07b2f18a01b8ddce4"
    ap-southeast-2 = "ami-075b1af2bc583944b"
    ap-southeast-3 = "ami-0b5a81f57762da2f4"
    ca-central-1   = "ami-0fda98e014e64d6c4"
    eu-central-1   = "ami-0ba6fa5b3d81c5d56"
    eu-north-1     = "ami-08aed4be0d4d11b0c"
    eu-south-1     = "ami-0349bc626dd021c7c"
    eu-west-1      = "ami-0706a49df2a8357b6"
    eu-west-2      = "ami-0681b7397b0ec9691"
    eu-west-3      = "ami-0919c4668782f35da"
    me-south-1     = "ami-07ef03ebf19799060"
    sa-east-1      = "ami-046a4e6f57aea3234"
    us-east-1      = "ami-0722eb0819717090f"
    us-east-2      = "ami-026e5701f495c94a2"
    us-west-1      = "ami-021ef831672014a17"
    us-west-2      = "ami-0bba4636ff1b1dc1c"
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
dotless_domain = replace("${data.aws_route53_zone.domain.name}","/\\.$/","")

#Cluster name derived from infra_name
#The regular expression contains two parantheses groups, so it will return a list with two values.  The first value contains the cluster name, that is why the index [0] is assigned to the variable.
#The first parentheses group (^[-0-9A-Za-z]+) selects the longest string possible containing dashes (-), numbers and lower case letters. Uppercase letters are not allowed for the cluster name, but dashes are.
#The second parentheses group will match a string starting with a dash and any letter or number, this second part is never used.
cluster_name = regex("(^[-0-9a-z]+)(-\\w+)", var.infra_name)[0]
}

