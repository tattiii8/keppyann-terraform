locals {
  bucket_name = "${var.project_name}"

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Service   = "Podcast"
  }
}
