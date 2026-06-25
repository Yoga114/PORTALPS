variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB (min 2)"
  type        = list(string)
}

variable "target_instance_id" {
  description = "EC2 instance ID to forward traffic to"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "domain" {
  description = "Domain name e.g. domain.com"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID tempat alias record akan dibuat (zone yang menaungi var.domain)"
  type        = string
}
