provider "aws" {
    region = "us-east-1"
}

data "terraform_remote_state" "stack" {
  backend = "s3"

  config {
    bucket = "${var.stack_bucket}"
    key    = "env:/${terraform.workspace}/${var.stack_key}"
    region = "${var.stack_region}"
  }
}
