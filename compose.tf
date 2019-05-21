module "this_db" {
  source          = "modules/database"
  schema          = "${local.app_name}"
  host            = "${data.terraform_remote_state.stack.db_address}"
  port            = "${data.terraform_remote_state.stack.db_port}"
  master_username = "${data.terraform_remote_state.stack.db_master_username}"
  master_password = "${data.terraform_remote_state.stack.db_master_password}"

  connection = {
    user        = "ec2-user"
    host        = "${data.terraform_remote_state.stack.compose_address}"
    private_key = "${file(var.ec2_private_keyfile)}"
  }
}

data "aws_ami" "amzn" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["137112412989"] # Amazon
}

data "aws_iam_policy_document" "compose" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_policy" "this_bucket_policy" {
  name   = "${data.terraform_remote_state.stack.stack_name}-${local.app_name}-bucket-access"
  policy = "${data.aws_iam_policy_document.this_bucket_access.json}"
  role = "${aws_iam_role.compose.id}"
}

resource "aws_iam_instance_profile" "compose" {
  name = "${local.namespace}-compose-profile"
  role = "${aws_iam_role.compose.name}"
}

resource "aws_iam_role" "compose" {
  name               = "${local.namespace}-compose-role"
  assume_role_policy = "${data.aws_iam_policy_document.compose.json}"
}

data "aws_iam_policy_document" "compose_api_access" {
  statement {
    effect    = "Allow"
    actions   = [
                  "ec2:DescribeInstances",
                  "elasticfilesystem:*",
                  "s3:*",
                  "cloudwatch:PutMetricData",
                  "ssm:Get*"
                ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "compose_api_access" {
  name   = "${local.namespace}-compose-api-access"
  policy = "${data.aws_iam_policy_document.compose_api_access.json}"
}

resource "aws_iam_role_policy_attachment" "compose_api_access" {
  role       = "${aws_iam_role.compose.name}"
  policy_arn = "${aws_iam_policy.compose_api_access.arn}"
}

resource "aws_security_group" "compose" {
  name        = "${local.namespace}-compose"
  description = "Compose Host Security Group"
  vpc_id      = "${module.vpc.vpc_id}"
  tags        = "${local.common_tags}"
}

resource "aws_security_group_rule" "compose_ingress" {
  security_group_id = "${aws_security_group.compose.id}"
  type              = "ingress"
  from_port         = "22"
  to_port           = "22"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "compose_egress" {
  security_group_id = "${aws_security_group.compose.id}"
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_instance" "compose" {
  ami                         = "${data.aws_ami.amzn.id}"
  instance_type               = "${var.compose_instance_type}"
  key_name                    = "${var.ec2_keyname}"
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.compose.name}"
  tags                        = "${merge(local.common_tags, map("Name", "${local.namespace}-compose"))}"

  vpc_security_group_ids = [
    "${aws_security_group.compose.id}",
    "${aws_security_group.db_client.id}",
  ]

  lifecycle {
    ignore_changes = ["ami"]
  }
}

resource "null_resource" "install_docker_on_compose" {
  triggers {
    host = "${aws_instance.compose.id}"
  }

  provisioner "remote-exec" {
    connection {
      host        = "${aws_instance.compose.public_dns}"
      user        = "ec2-user"
      agent       = true
      timeout     = "10m"
      private_key = "${file(var.ec2_private_keyfile)}"
    }

    inline = [
      "sudo curl -L 'https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)' -o /usr/local/bin/docker-compose"
    ]
  }
}

resource "aws_route53_record" "compose" {
  zone_id = "${module.dns.public_zone_id}"
  name    = "compose.${local.public_zone_name}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.compose.public_ip}"]
}
