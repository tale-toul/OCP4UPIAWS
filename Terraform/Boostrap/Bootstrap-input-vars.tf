#Variables definition

#infra_name 
variable "infra_name" {
  type = string
  description = "Unique string based on the cluster_name used to create the names of other some components" 
}

variable "cluster_name" {
  description = "Cluster name, used to define Clusterid tag and as part of other component names"
  type = string
}

variable "region_name" {
  description = "AWS Region where the cluster is deployed"
  type = string
}

variable "rhcos-ami" {
  description = "RHCOS AMI on which the EC2 instances are based on, depends on the region"
  type = string
}

variable "vpc_id" {
  description = "ID of the VPC where the resources will be created"
  type = string
}

variable "master_sg_id" {
  description = "ID of the master security group"
  type = string
}

variable "pub_subnet_id" {
  description = "ID of the public subnet to deploy the bootstrap EC2 instance"
  type = string
}

variable "external_api_tg_arn" {
  description = "ARN of the target group for the external load balancer API listener"
  type = string
}

variable "internal_api_tg_arn" {
  description = "ARN of the target group for the internal load balancer API listener"
  type = string
}

variable "external_service_tg_arn" {
  description = "ARN of the target group for the external load balancer service listener"
  type = string
}
