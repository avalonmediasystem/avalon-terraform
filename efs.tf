resource "aws_efs_file_system" "compose_efs" {
  creation_token   = "${local.namespace}-efs"
  performance_mode = "generalPurpose"
  encrypted        = "false"

  tags = "${local.common_tags}"
}

resource "aws_efs_mount_target" "compose_efs_mount" {
#   count           = "${length(var.subnets)}"
  file_system_id  = "${aws_efs_file_system.compose_efs.id}"
  subnet_id       = "${module.vpc.public_subnets[0]}"
  security_groups = ["${aws_security_group.efs_sgroup.id}"]
}

resource "aws_security_group" "efs_sgroup" {
  name        = "${local.namespace}-efs_sgroup"
  description = "Allow NFS traffic."
  vpc_id      = "${module.vpc.vpc_id}"
  tags        = "${local.common_tags}"

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port   = "2049"
    to_port     = "2049"
    protocol    = "tcp"
    cidr_blocks = ["${module.vpc.vpc_cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
