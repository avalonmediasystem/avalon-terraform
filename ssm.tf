resource "aws_iam_role_policy_attachment" "compose_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.compose.name
}

resource "aws_iam_role_policy" "build_ssm" {
  role = aws_iam_role.build.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand"
      ],
      "Resource": [
        "${aws_instance.compose.arn}",
        "arn:aws:ssm:${data.aws_region.current.name}::document/AWS-RunShellScript"
      ]
    }
  ]
}
POLICY
}