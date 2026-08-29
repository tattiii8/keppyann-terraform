
data "aws_iam_policy_document" "podcast_bucket" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.podcast.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values = [
        aws_cloudfront_distribution.podcast.arn
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "podcast" {
  bucket = aws_s3_bucket.podcast.id
  policy = data.aws_iam_policy_document.podcast_bucket.json

  depends_on = [
    aws_cloudfront_distribution.podcast
  ]
}
