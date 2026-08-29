resource "aws_s3_bucket" "podcast" {
  bucket = local.bucket_name

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "podcast" {
  bucket = aws_s3_bucket.podcast.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "podcast" {
  bucket = aws_s3_bucket.podcast.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "podcast" {
  bucket = aws_s3_bucket.podcast.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "podcast" {
  bucket = aws_s3_bucket.podcast.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_object" "healthcheck" {
  bucket       = aws_s3_bucket.podcast.id
  key          = "healthcheck.txt"
  content      = "podcast-s3-ok\n"
  content_type = "text/plain"
}
