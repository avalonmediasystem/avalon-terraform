module "db_fcrepo_password" {
  source = "modules/password"
}

module "db_fcrepo" {
  source  = "terraform-aws-modules/rds/aws"
  version = "1.28.0"

  identifier = "${local.namespace}-fcrepo-db"

  engine         = "postgres"
  engine_version = "${var.postgres_version}"

  instance_class    = "db.t2.small"
  allocated_storage = 40

  name     = "fcrepo"
  username = "${var.db_fcrepo_username}"
  password = "${module.db_fcrepo_password.result}"
  port     = 5432

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 35
  copy_tags_to_snapshot   = true

  vpc_security_group_ids = ["${aws_security_group.db.id}"]

  tags = "${local.common_tags}"

  subnet_ids = ["${module.vpc.private_subnets}"]

  availability_zone = "${aws_instance.compose.availability_zone}"

  family = "postgres10"

  parameters = [
    {
      name  = "client_encoding"
      value = "UTF8"
    },
  ]
}

resource "aws_ssm_parameter" "db_fcrepo_host" {
  name        = "/${var.stack_name}-fcrepo-db/host"
  value       = "${module.db_fcrepo.this_db_instance_address}"
  type        = "String"
  overwrite   = true
}

resource "aws_ssm_parameter" "db_fcrepo_port" {
  name        = "/${var.stack_name}-fcrepo-db/port"
  value       = "${module.db_fcrepo.this_db_instance_port}"
  type        = "String"
  overwrite   = true
}

resource "aws_ssm_parameter" "db_fcrepo_admin_user" {
  name        = "/${var.stack_name}-fcrepo-db/admin_user"
  value       = "${module.db_fcrepo.this_db_instance_username}"
  type        = "SecureString"
  overwrite   = true
}

resource "aws_ssm_parameter" "db_fcrepo_admin_password" {
  name        = "/${var.stack_name}-fcrepo-db/admin_password"
  value       = "${module.db_fcrepo.this_db_instance_password}"
  type        = "SecureString"
  overwrite   = true
}
