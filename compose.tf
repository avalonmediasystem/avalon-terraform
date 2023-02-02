data "aws_ami" "amzn" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
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
  name   = "${local.namespace}-compose-bucket-access"
  policy = data.aws_iam_policy_document.this_bucket_access.json
}

resource "aws_iam_instance_profile" "compose" {
  name = "${local.namespace}-compose-profile"
  role = aws_iam_role.compose.name
}

resource "aws_iam_role" "compose" {
  name               = "${local.namespace}-compose-role"
  assume_role_policy = data.aws_iam_policy_document.compose.json
}

data "aws_iam_policy_document" "compose_api_access" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "elasticfilesystem:*",
      "elastictranscoder:List*",
      "elastictranscoder:Read*",
      "elastictranscoder:CreatePreset",
      "elastictranscoder:ListPresets",
      "elastictranscoder:ReadPreset",
      "elastictranscoder:ListJobs",
      "elastictranscoder:CreateJob",
      "elastictranscoder:ReadJob",
      "elastictranscoder:CancelJob",
      "s3:*",
      "ses:SendEmail",
      "ses:SendRawEmail",
      "cloudwatch:PutMetricData",
      "ssm:Get*",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "compose_api_access" {
  name   = "${local.namespace}-compose-api-access"
  policy = data.aws_iam_policy_document.compose_api_access.json
}

resource "aws_iam_role_policy_attachment" "compose_api_access" {
  role       = aws_iam_role.compose.name
  policy_arn = aws_iam_policy.compose_api_access.arn
}

resource "aws_iam_role_policy_attachment" "compose_ecr" {
  role       = aws_iam_role.compose.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_security_group" "compose" {
  name        = "${local.namespace}-compose"
  description = "Compose Host Security Group"
  vpc_id      = module.vpc.vpc_id
  tags        = local.common_tags
}

resource "aws_security_group_rule" "compose_web" {
  security_group_id = aws_security_group.compose.id
  type              = "ingress"
  from_port         = "80"
  to_port           = "80"
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
}

resource "aws_security_group_rule" "compose_streaming" {
  security_group_id = aws_security_group.compose.id
  type              = "ingress"
  from_port         = "8880"
  to_port           = "8880"
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
}

resource "aws_security_group_rule" "compose_ssh" {
  security_group_id = aws_security_group.compose.id
  type              = "ingress"
  from_port         = "22"
  to_port           = "22"
  protocol          = "tcp"
  cidr_blocks       = setunion([var.vpc_cidr_block], var.ssh_cidr_blocks)
}

resource "aws_security_group_rule" "compose_egress" {
  security_group_id = aws_security_group.compose.id
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_this_redis_access" {
  security_group_id        = aws_security_group.redis.id
  type                     = "ingress"
  from_port                = aws_elasticache_cluster.redis.cache_nodes[0].port
  to_port                  = aws_elasticache_cluster.redis.cache_nodes[0].port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.compose.id
}

resource "aws_security_group" "public_ip" {
  name        = "${local.namespace}-ssh-public-ip"
  description = "SSH Public IP Security Group"
  tags        = local.common_tags
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "ssh_public_ip" {
  type = "ingress"
  description = "Allow SSH direct to public IP"
  cidr_blocks = var.ssh_cidr_blocks
  ipv6_cidr_blocks = []
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  security_group_id = aws_security_group.public_ip.id
}

resource "aws_instance" "compose" {
  ami                         = data.aws_ami.amzn.id
  instance_type               = var.compose_instance_type
  key_name                    = var.ec2_keyname == "" ? null : var.ec2_keyname
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  availability_zone           = var.availability_zone
  iam_instance_profile        = aws_iam_instance_profile.compose.name
  tags = merge(
    local.common_tags,
    {
      "Name" = "${local.namespace}-compose"
    },
  )

  root_block_device {
    volume_size = var.compose_volume_size
    volume_type = "standard"
  }

  user_data = base64encode(templatefile("scripts/compose-init.sh", {
    ec2_public_key = "${var.ec2_public_key}"
    solr_backups_efs_id = "${aws_efs_file_system.solr_backups.id}"
    solr_backups_efs_dns_name = "${aws_efs_file_system.solr_backups.dns_name}"
    db_fcrepo_address = "${module.db_fcrepo.db_instance_address}"
    db_fcrepo_username = "${module.db_fcrepo.db_instance_username}"
    db_fcrepo_password = "${module.db_fcrepo.db_instance_password}"
    db_fcrepo_port = "${module.db_fcrepo.db_instance_port}"
    db_avalon_address = "${module.db_avalon.db_instance_address}"
    db_avalon_username = "${module.db_avalon.db_instance_username}"
    db_avalon_password = "${module.db_avalon.db_instance_password}"
    fcrepo_binary_bucket_access_key = "${var.fcrepo_binary_bucket_access_key}"
    fcrepo_binary_bucket_secret_key = "${var.fcrepo_binary_bucket_secret_key}"
    fcrepo_binary_bucket_id = "${aws_s3_bucket.fcrepo_binary_bucket.id}"
    compose_log_group_name = "${aws_cloudwatch_log_group.compose_log_group.name}"
    fcrepo_db_ssl = "${var.fcrepo_db_ssl}"
    derivatives_bucket_id = "${aws_s3_bucket.this_derivatives.id}"
    masterfiles_bucket_id = "${aws_s3_bucket.this_masterfiles.id}"
    preservation_bucket_id = "${aws_s3_bucket.this_preservation.id}"
    supplemental_files_bucket_id = "${aws_s3_bucket.this_supplemental_files.id}"
    avalon_ecr_repository_url = "${aws_ecr_repository.avalon.repository_url}"
    avalon_repo = "${var.avalon_repo}"
    redis_host_name = "${aws_route53_record.redis.name}"
    aws_region = "${var.aws_region}"
    avalon_fqdn = "${length(var.alt_hostname) > 0 ? values(var.alt_hostname)[0].hostname : aws_route53_record.alb.fqdn}"
    streaming_fqdn = "${aws_route53_record.alb_streaming.fqdn}"
    elastictranscoder_pipeline_id = "${aws_elastictranscoder_pipeline.this_pipeline.id}"
    email_comments = "${var.email_comments}"
    email_notification = "${var.email_notification}"
    email_support = "${var.email_support}"
    avalon_admin = "${var.avalon_admin}"
    bib_retriever_protocol = "${var.bib_retriever_protocol}"
    bib_retriever_url = "${var.bib_retriever_url}"
    bib_retriever_query = "${var.bib_retriever_query}"
    bib_retriever_host = "${var.bib_retriever_host}"
    bib_retriever_port = "${var.bib_retriever_port}"
    bib_retriever_database = "${var.bib_retriever_database}"
    bib_retriever_attribute = "${var.bib_retriever_attribute}"
    bib_retriever_class = "${var.bib_retriever_class}"
    bib_retriever_class_require = "${var.bib_retriever_class_require}"
  }))

  vpc_security_group_ids = [
    aws_security_group.compose.id,
    aws_security_group.db_client.id,
    aws_security_group.public_ip.id,
  ]

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

resource "null_resource" "install_docker_on_compose" {
  triggers = {
    host = aws_instance.compose.id
  }

  provisioner "local-exec" {
    command = "aws codebuild start-build --project-name ${aws_codebuild_project.docker.name} --region ${var.aws_region}"
  }
}

resource "aws_s3_bucket_policy" "compose-s3" {
  bucket = aws_s3_bucket.this_derivatives.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "IPAllow",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.this_derivatives.id}/*",
      "Condition": {
         "IpAddress": {"aws:SourceIp": "${aws_instance.compose.public_ip}"}
      }
    }
  ]
}
POLICY

}

resource "aws_cloudwatch_log_group" "compose_log_group" {
  name = local.namespace
}

resource "aws_volume_attachment" "compose_solr" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.solr_data.id
  instance_id = aws_instance.compose.id
}

resource "aws_ebs_volume" "solr_data" {
  availability_zone = var.availability_zone
  size              = 20
}

