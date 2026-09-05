# -------------------------------------------------------------------
# CloudFront Log Bucket (S3)
# -------------------------------------------------------------------
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket        = "${var.project_name}-cloudfront-logs"
  force_destroy = true
}

# CloudFront Standard Logging には ACL 有効化が必要
resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]

  bucket = aws_s3_bucket.cloudfront_logs.id
  acl    = "private"
}

# -------------------------------------------------------------------
# Resource: Origin Access Control
# -------------------------------------------------------------------
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
# Origin Request Policy (国識別ヘッダー転送用) ★追加
# -------------------------------------------------------------------
resource "aws_cloudfront_origin_request_policy" "viewer_country" {
  name    = "${var.project_name}-viewer-country-policy"
  comment = "Pass CloudFront-Viewer-Country and User-Agent headers to CloudFront Function and Origin"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "CloudFront-Viewer-Country",
        "User-Agent"
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "none"
  }
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

  # ★ アクセスログ設定
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix          = "cf-logs/"
  }

  origin {
    domain_name              = aws_s3_bucket.podcast.bucket_regional_domain_name
    origin_id                = "s3-podcast"
    origin_access_control_id = aws_cloudfront_origin_access_control.podcast.id
  }

  # -------------------------------------------------------------------
  # 優先度 1: RSS フィード（認証あり / キャッシュなし）
  # -------------------------------------------------------------------
  ordered_cache_behavior {
    path_pattern           = "/arch/keppyann.rss"
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.viewer_country.id # ★追加

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

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.viewer_country.id # ★追加

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.basic_auth.arn
    }
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
    path_pattern           = "*.png"
    target_origin_id       = "s3-podcast"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
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

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.viewer_country.id # ★追加

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.basic_auth.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.podcast.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [
    aws_acm_certificate.podcast,
    aws_s3_bucket_acl.cloudfront_logs # ★ ACL 設定の完了を保証
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

# -------------------------------------------------------------------
# Athena Setup for Log Analytics
# -------------------------------------------------------------------
resource "aws_athena_database" "cloudfront_logs" {
  name   = replace("${var.project_name}_cloudfront_logs_db", "-", "_")
  bucket = aws_s3_bucket.cloudfront_logs.bucket
}

resource "aws_athena_named_query" "create_cloudfront_logs_table" {
  name     = "create-cloudfront-logs-table"
  database = aws_athena_database.cloudfront_logs.name
  query    = <<-SQL
    CREATE EXTERNAL TABLE IF NOT EXISTS ${aws_athena_database.cloudfront_logs.name}.cloudfront_logs (
      `date` DATE,
      `time` STRING,
      `location` STRING,
      `bytes` BIGINT,
      `c_ip` STRING,
      `method` STRING,
      `host` STRING,
      `uri_stem` STRING,
      `status` INT,
      `referrer` STRING,
      `user_agent` STRING,
      `uri_query` STRING,
      `cookie` STRING,
      `edge_result_type` STRING,
      `request_id` STRING,
      `host_header` STRING,
      `cs_protocol` STRING,
      `cs_bytes` BIGINT,
      `time_taken` FLOAT,
      `xforwarded_for` STRING,
      `ssl_protocol` STRING,
      `ssl_cipher` STRING,
      `edge_response_result_type` STRING,
      `cs_protocol_version` STRING,
      `fle_status` STRING,
      `fle_encrypted_fields` INT,
      `c_port` INT,
      `time_to_first_byte` FLOAT,
      `x_edge_detailed_result_type` STRING,
      `sc_content_type` STRING,
      `sc_content_len` BIGINT,
      `sc_range_start` BIGINT,
      `sc_range_end` BIGINT
    )
    ROW FORMAT DELIMITED 
    FIELDS TERMINATED BY '\t'
    LOCATION 's3://${aws_s3_bucket.cloudfront_logs.bucket}/cf-logs/'
    TBLPROPERTIES (
      'skip.header.line.count'='2'
    );
  SQL
}