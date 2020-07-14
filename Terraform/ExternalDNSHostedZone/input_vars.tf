# INPUT variables

variable "dns_domain_ID" {
  description = "Zone ID for the route 53 DNS domain that will be used as base"
  type = string
}

variable "subdomain_name" {
  description = "Subdomain name to add to the base domain, to build the complete domain name for the cluster"
  type = string
  default = "caramel"
}
