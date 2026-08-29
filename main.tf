terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# メインプロバイダー（東京リージョン）
provider "aws" {
  region = var.aws_region # "ap-northeast-1"
}

# エイリアスプロバイダー（バージニア北部：CloudFront用ACM証明書などに使用）
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}