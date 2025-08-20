resource "aws_iam_role" "this_mediaconvert_role" {
  name               = "${local.namespace}-mediaconvert-role"
  assume_role_policy = jsonencode({
    Version   = "2008-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "this_mediaconvert_policy" {
  name   = "${local.namespace}-${var.app_name}-mediaconvert-policy"
  policy = data.aws_iam_policy_document.mediaconvert.json
}

resource "aws_iam_role_policy_attachment" "this_mediaconvert" {
  role       = aws_iam_role.this_mediaconvert_role.name
  policy_arn = aws_iam_policy.this_mediaconvert_policy.arn
}

data "aws_iam_policy_document" "mediaconvert" {
  statement {
    effect = "Allow"

    actions = [
      "s3:List*",
      "s3:Get*",
    ]

    resources = [
      aws_s3_bucket.this_masterfiles.arn,
      "${aws_s3_bucket.this_masterfiles.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:Put*",
    ]

    resources = [
      aws_s3_bucket.this_derivatives.arn,
      "${aws_s3_bucket.this_derivatives.arn}/*",
    ]
  }
}
