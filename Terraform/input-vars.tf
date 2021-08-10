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
    af-south-1     = "ami-09921c9c1c36e695c"
    ap-east-1      = "ami-01ee8446e9af6b197"
    ap-northeast-1 = "ami-04e5b5722a55846ea"
    ap-northeast-2 = "ami-0fdc25c8a0273a742"
    ap-south-1     = "ami-09e3deb397cc526a8"
    ap-southeast-1 = "ami-0630e03f75e02eec4"
    ap-southeast-2 = "ami-069450613262ba03c"
    ca-central-1   = "ami-012518cdbd3057dfd"
    eu-central-1   = "ami-0bd7175ff5b1aef0c"
    eu-north-1     = "ami-06c9ec42d0a839ad2"
    eu-south-1     = "ami-0614d7440a0363d71"
    eu-west-1      = "ami-01b89df58b5d4d5fa"
    eu-west-2      = "ami-06f6e31ddd554f89d"
    eu-west-3      = "ami-0dc82e2517ded15a1"
    me-south-1     = "ami-07d181e3aa0f76067"
    sa-east-1      = "ami-0cd44e6dd20e6c7fa"
    us-east-1      = "ami-04a16d506e5b0e246"
    us-east-2      = "ami-0a1f868ad58ea59a7"
    us-west-1      = "ami-0a65d76e3a6f6622f"
    us-west-2      = "ami-0dd9008abadc519f1"
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

