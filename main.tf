provider "aws" {
  profile = var.aws_profile
  region = var.aws_region
}

terraform {
  backend "s3" {
  }
}

