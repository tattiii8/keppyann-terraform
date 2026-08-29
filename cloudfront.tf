
resource "aws_cloudfront_origin_access_control" "podcast" {
  name                              = "${var.project_name}-s3-oac"
  description                       = "OAC for ${var.project_name} S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "podcast" {
  enabled         = true
  is_ipv6_enabled = var.enable_ipv6
  price_class     = var.price_class
  comment         = "Podcast delivery for ${var.domain_name}"

  aliases = [var.domain_name]

  origin {
    domain_name              = aws_s3_bucket.podcast.bucket_regional_domain_name
    origin_id                = "s3-podcast"
    origin_access_control_id = aws_cloudfront_origin_access_control.podcast.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  ordered_cache_behavior {
    path_pattern           = "keppyann.rss"
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id
  }

  ordered_cache_behavior {
    path_pattern           = "healthcheck.txt"
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id
  }

  ordered_cache_behavior {
    path_pattern           = "arch/*"
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    compress = false

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.podcast.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [
    aws_acm_certificate.podcast
  ]

  tags = local.common_tags
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}
