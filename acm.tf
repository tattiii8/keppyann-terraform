resource "aws_acm_certificate" "podcast" {
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_acm_certificate_validation" "podcast" {
  provider = aws.us_east_1

  count = var.acm_validation_wait ? 1 : 0

  certificate_arn = aws_acm_certificate.podcast.arn

  validation_record_fqdns = [
    for option in aws_acm_certificate.podcast.domain_validation_options :
    option.resource_record_name
  ]

  depends_on = [
    aws_acm_certificate.podcast
  ]
}
