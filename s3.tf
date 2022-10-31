resource "aws_s3_bucket" "this_masterfiles" {
  bucket        = "${local.namespace}-masterfiles"
  tags          = local.common_tags
  force_destroy = "false"
}

resource "aws_s3_bucket_acl" "this_masterfiles_bucket_acl" {
  bucket = aws_s3_bucket.this_masterfiles.id
  acl    = "private"
}

resource "aws_s3_bucket_cors_configuration" "this_masterfiles" {
  bucket = aws_s3_bucket.this_masterfiles.id

  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_headers = ["x-csrf-token"]
  }
}

resource "aws_s3_bucket" "this_derivatives" {
  bucket        = "${local.namespace}-derivatives"
  tags          = local.common_tags
  force_destroy = "false"
}

resource "aws_s3_bucket_acl" "this_derivatives_bucket_acl" {
  bucket = aws_s3_bucket.this_derivatives.id
  acl    = "private"
}

resource "aws_s3_bucket_cors_configuration" "this_derivatives" {
  bucket = aws_s3_bucket.this_derivatives.id

  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET"]
    max_age_seconds = "3000"
    allowed_headers = ["Authorization", "Access-Control-Allow-Origin"]
  }
}

resource "aws_s3_bucket" "this_preservation" {
  bucket        = "${local.namespace}-preservation"
  tags          = local.common_tags
  force_destroy = "false"
}

resource "aws_s3_bucket_acl" "this_preservation_bucket_acl" {
  bucket = aws_s3_bucket.this_preservation.id
  acl    = "private"
}

resource "aws_s3_bucket" "this_supplemental_files" {
  bucket        = "${local.namespace}-supplemental-files"
  tags          = local.common_tags
  force_destroy = "false"
}

resource "aws_s3_bucket_acl" "this_supplemental_files_bucket_acl" {
  bucket = aws_s3_bucket.this_supplemental_files.id
  acl    = "private"
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
      aws_s3_bucket.this_masterfiles.arn,
      aws_s3_bucket.this_derivatives.arn,
      aws_s3_bucket.this_preservation.arn,
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
      "${aws_s3_bucket.this_supplemental_files.arn}/*",
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

resource "aws_s3_bucket" "fcrepo_binary_bucket" {
  bucket        = "${local.namespace}-fedora-binaries"
  tags          = local.common_tags
  force_destroy = "true"
}

resource "aws_s3_bucket_acl" "fcrepo_binary_bucket_acl" {
  bucket = aws_s3_bucket.fcrepo_binary_bucket.id
  acl    = "private"
}

data "aws_iam_policy_document" "fcrepo_binary_bucket_access" {
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

    resources = [aws_s3_bucket.fcrepo_binary_bucket.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.fcrepo_binary_bucket.arn}/*"]
  }
}

resource "aws_iam_user_policy" "fcrepo_binary_bucket_policy" {
  name   = "${local.namespace}-fcrepo-s3-bucket-access"
  user   = var.fcrepo_binary_bucket_username
  policy = data.aws_iam_policy_document.fcrepo_binary_bucket_access.json
}

