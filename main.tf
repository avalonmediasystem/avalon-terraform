provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
  }
  required_providers {
    aws = "~> 2.46"
  }
}
