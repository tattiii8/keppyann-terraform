locals {
  bucket_name = "${var.project_name}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Service   = "Podcast"
  }
}
