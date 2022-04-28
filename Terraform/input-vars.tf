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
    af-south-1     = "ami-0f3804f5a2f913dcc"
    ap-east-1      = "ami-0de1febb30a83da66"
    ap-northeast-1 = "ami-0183df96a3e002687"
    ap-northeast-2 = "ami-06b8798cd60242798"
    ap-northeast-3 = "ami-00b16b33aa0951016"
    ap-south-1     = "ami-007243f8ff78e8294"
    ap-southeast-1 = "ami-079dfdacb5ab5a0d1"
    ap-southeast-2 = "ami-03882e39cb7785c32"
    ca-central-1   = "ami-05cba1f80cc8b1dbe"
    eu-central-1   = "ami-073c775bbe9cd434e"
    eu-north-1     = "ami-0763e6e75b681acc5"
    eu-south-1     = "ami-00d023f19775fb64b"
    eu-west-1      = "ami-0033e3f2331a530c4"
    eu-west-2      = "ami-00d8a741ebe74f0c4"
    eu-west-3      = "ami-09b04e7f60e3374a7"
    me-south-1     = "ami-0f8039330b6e54010"
    sa-east-1      = "ami-01af22f821b470ad1"
    us-east-1      = "ami-0c72f473496a7b1c2"
    us-east-2      = "ami-09e637fc5885c13cc"
    us-west-1      = "ami-0fa0f6fce7e63dd26"
    us-west-2      = "ami-084fb1316cd1ed4cc"
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

