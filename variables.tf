variable "aws_region" {
  description = "AWS region for the S3 bucket and CloudFront origin."
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name used in resource names."
  type        = string
  default     = "keppyann"
}

variable "domain_name" {
  description = "Existing public hostname used by Apple Podcasts."
  type        = string
  default     = "verlaine.lesure.net"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID. Used only for outputs/documentation unless DNS is managed separately."
  type        = string
  default     = ""
}

variable "enable_ipv6" {
  type    = bool
  default = true
}

variable "acm_validation_wait" {
  description = "Wait for ACM certificate validation during apply. Set false for the first apply if DNS validation records are created outside Terraform."
  type        = bool
  default     = false
}

variable "price_class" {
  type    = string
  default = "PriceClass_200"
}
