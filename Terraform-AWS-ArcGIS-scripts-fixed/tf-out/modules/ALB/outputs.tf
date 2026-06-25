output "alb_dns_name" {
  description = "ALB DNS name — point your domain CNAME here"
  value       = aws_lb.arcgis_alb.dns_name
}

output "alb_arn" {
  value = aws_lb.arcgis_alb.arn
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB — used for Route53 alias records"
  value       = aws_lb.arcgis_alb.zone_id
}

output "domain_name" {
  description = "Domain name yang dipetakan ke ALB lewat Route53 alias record"
  value       = aws_route53_record.alb_alias.name
}
