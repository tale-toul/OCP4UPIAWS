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
    af-south-1     = "ami-0ce5aa99b7d576c79"
    ap-east-1      = "ami-0f6debc614042ce76"
    ap-northeast-1 = "ami-0423a1bf292f34dc3"
    ap-northeast-2 = "ami-0889161041cb9d77f"
    ap-northeast-3 = "ami-00564b0d6cbb676b1"
    ap-south-1     = "ami-0650f4166d12ccead"
    ap-southeast-1 = "ami-0b09ad848356811c7"
    ap-southeast-2 = "ami-013484d0474ab5860"
    ca-central-1   = "ami-03291c3e2b74c32b9"
    eu-central-1   = "ami-0510f6f15c25b29d4"
    eu-north-1     = "ami-03a3119ba25eb55b1"
    eu-south-1     = "ami-04f719435625c1313"
    eu-west-1      = "ami-08e20744bd1c89c8e"
    eu-west-2      = "ami-0c190f5d05b071c7a"
    eu-west-3      = "ami-0eb0bf894fdf1d416"
    me-south-1     = "ami-073928aa740f738bd"
    sa-east-1      = "ami-01242f1bac18cc0fd"
    us-east-1      = "ami-05ed2cc6e70392ff9"
    us-east-2      = "ami-00b3a5054da356288"
    us-west-1      = "ami-021f626622b5238f3"
    us-west-2      = "ami-0c9fd8b47bfd717e8"
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

