output "s3_bucket_name" {
  value = aws_s3_bucket.podcast.bucket
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.podcast.arn
}
/*
output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.podcast.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.podcast.domain_name
}
*/
output "podcast_url" {
  value = "https://${var.domain_name}/"
}

output "feed_url" {
  value = "https://${var.domain_name}/feed.xml"
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.podcast.arn
}

output "acm_validation_records" {
  description = "Create these DNS CNAME records in Cloudflare before enabling acm_validation_wait."
  value = {
    for option in aws_acm_certificate.podcast.domain_validation_options :
    option.domain_name => {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  }
}
