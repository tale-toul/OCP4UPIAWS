#OUTPUT vars
output "external_zone_ID" {
  value = aws_route53_zone.external.id
  description = "ID of the External hosted zone created from subdomain_name + base domain"
}

output "full_domain" {
  value = aws_route53_zone.external.name
  description = "Full domain constructed form the subdomain + the base domain"
}
