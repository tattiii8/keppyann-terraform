resource "aws_cloudfront_origin_access_control" "podcast" {
  name                              = "${var.project_name}-s3-oac"
  description                       = "OAC for ${var.project_name} S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# -------------------------------------------------------------------
# Basic Auth CloudFront Function
# -------------------------------------------------------------------
resource "aws_cloudfront_function" "basic_auth" {
  name    = "podcast-basic-auth"
  runtime = "cloudfront-js-2.0"
  comment = "Basic authentication for private podcast"
  publish = true

  code = templatefile("${path.module}/basic-auth.js.tftpl", {
    auth_string = base64encode("${var.basic_auth_username}:${var.basic_auth_password}")
  })
}

# -------------------------------------------------------------------
# CloudFront Distribution
# -------------------------------------------------------------------
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

  # -------------------------------------------------------------------
  # 優先度 1: RSS フィード（認証あり / キャッシュなし）
  # -------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "keppyann.rss"
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.basic_auth.arn
    }
  }

  # -------------------------------------------------------------------
  # 優先度 2: 音声ファイル（認証あり / キャッシュあり）
  # -------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "arch/*"
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    compress = false

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id

    #function_association {
    #  event_type   = "viewer-request"
    #  function_arn = aws_cloudfront_function.basic_auth.arn
    #}
  }

  # -------------------------------------------------------------------
  # 優先度 3: ヘルスチェック（認証除外 / 監視用）
  # -------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "healthcheck.txt"
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id
  }

  # -------------------------------------------------------------------
  # 画像ファイル専用設定（認証なし / キャッシュあり）
  # -------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "*.png" # または "images/*" など配置パスに合わせる
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    # 画像はキャッシュを効かせる
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id

    # ★ function_association をつけないことで認証を除外
  }

  # -------------------------------------------------------------------
  # デフォルト: その他全般（認証あり）
  # -------------------------------------------------------------------
  default_cache_behavior {
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.basic_auth.arn
    }
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

# -------------------------------------------------------------------
# Cache Policies
# -------------------------------------------------------------------
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}