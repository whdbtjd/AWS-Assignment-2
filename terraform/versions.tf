terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "acme"
      ManagedBy   = "Terraform"
      Repository  = "ACME/Assignment_2"
    }
  }
}

# CloudFront ACM 인증서는 반드시 us-east-1 이어야 함
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "acme"
      ManagedBy   = "Terraform"
      Repository  = "ACME/Assignment_2"
    }
  }
}
