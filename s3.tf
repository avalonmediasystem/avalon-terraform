resource "aws_s3_bucket" "this_masterfiles" {
  bucket = "${local.namespace}-masterfiles"
  acl    = "private"
  tags   = "${local.common_tags}"

  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
  }
}

resource "aws_s3_bucket" "this_derivatives" {
  #  bucket = "${local.namespace}-derivatives"
  acl  = "private"
  tags = "${local.common_tags}"

  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET"]
    max_age_seconds = "3000"
    allowed_headers = ["Authorization", "Access-Control-Allow-Origin"]
  }
}

resource "aws_s3_bucket" "this_preservation" {
  #  bucket = "${local.namespace}-avr-preservation"
  acl  = "private"
  tags = "${local.common_tags}"
}

data "aws_iam_policy_document" "this_bucket_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["arn:aws:s3:::*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [
      "${aws_s3_bucket.this_masterfiles.arn}",
      "${aws_s3_bucket.this_derivatives.arn}",
      "${aws_s3_bucket.this_preservation.arn}",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = [
      "${aws_s3_bucket.this_masterfiles.arn}/*",
      "${aws_s3_bucket.this_derivatives.arn}/*",
      "${aws_s3_bucket.this_preservation.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "sqs:ListQueues",
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
    ]

    resources = ["*"]
  }
}

