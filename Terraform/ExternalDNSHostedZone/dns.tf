#PROVIDERS
provider "aws" {
#The region is unimportant since ROUTE53 records are not region dependent
  region = "eu-west-3"
  version = "~> 2.69.0"
  shared_credentials_file = "aws-credentials.ini"
}

#ROUTE53 CONFIG
#Datasource for the base domain zone.
data "aws_route53_zone" "base_domain" {
  zone_id = var.dns_domain_ID
}

#External hosted zone, this is a public zone because it is not associated with a VPC
resource "aws_route53_zone" "external" {
  name = "${var.subdomain_name}.${data.aws_route53_zone.base_domain.name}"
}

#Name server records to link the subdomain to the base domain
resource "aws_route53_record" "external-ns" {
  zone_id = data.aws_route53_zone.base_domain.zone_id
  name    = "${var.subdomain_name}.${data.aws_route53_zone.base_domain.name}"
  type    = "NS"
  ttl     = "30"

  records = [
    "${aws_route53_zone.external.name_servers.0}",
    "${aws_route53_zone.external.name_servers.1}",
    "${aws_route53_zone.external.name_servers.2}",
    "${aws_route53_zone.external.name_servers.3}",
  ]
}
