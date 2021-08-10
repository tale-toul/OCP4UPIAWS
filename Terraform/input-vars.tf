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
    eu-central-1   = "ami-02e08df1201f1c2f8"
    eu-west-1      = "ami-0bdd69d8e7cd18188"
    eu-west-2      = "ami-0e610e967a62dbdfa"
    eu-west-3      = "ami-0e817e26f638a71ac"
    eu-north-1     = "ami-0309c9d2fadcb2d5a"
    us-east-1      = "ami-077ede5bed2e431ea"
    us-east-2      = "ami-0f4ecf819275850dd"
    us-west-1      = "ami-0c4990e435bc6c5fe"
    us-west-2      = "ami-000d6e92357ac605c"
    sa-east-1      = "ami-08e62f746b94950c1"
    ap-south-1     = "ami-0754b15d212830477"
    ap-northeast-1 = "ami-0530d04240177f118"
    ap-northeast-2 = "ami-09e4cd700276785d2"
    ap-southeast-1 = "ami-03b46cc4b1518c5a8"
    ap-southeast-2 = "ami-0a5b99ab2234a4e6a"
    ca-central-1   = "ami-012bc4ee3b6c673bc"
    me-south-1     = "ami-024117d7c87b7ff08"
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

