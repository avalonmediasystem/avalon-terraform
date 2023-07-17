module "db_avalon_password" {
  source = "./modules/password"
}

module "db_avalon" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 5.0"

  identifier = "${local.namespace}-avalon-db"

  engine         = "postgres"
  engine_version = var.postgres_version
  family = "postgres14"
  major_engine_version = "14"

  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "avalon"
  username = var.db_avalon_username
  password = module.db_avalon_password.result
  port     = 5432

  option_group_name       = "default:postgres-14"
  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:00-06:00"
  backup_retention_period = 35
  copy_tags_to_snapshot   = true

  vpc_security_group_ids = [aws_security_group.db.id]
  create_db_subnet_group = true
  subnet_ids = module.vpc.private_subnets
  availability_zone = var.availability_zone

  tags = local.common_tags

  apply_immediately = true
}

resource "aws_ssm_parameter" "db_avalon_host" {
  name      = "/${local.namespace}-avalon-db/host"
  value     = module.db_avalon.db_instance_address
  type      = "String"
  overwrite = true
}

resource "aws_ssm_parameter" "db_avalon_port" {
  name      = "/${local.namespace}-avalon-db/port"
  value     = module.db_avalon.db_instance_port
  type      = "String"
  overwrite = true
}

resource "aws_ssm_parameter" "db_avalon_admin_user" {
  name      = "/${local.namespace}-avalon-db/admin_user"
  value     = module.db_avalon.db_instance_username
  type      = "SecureString"
  overwrite = true
}

resource "aws_ssm_parameter" "db_avalon_admin_password" {
  name      = "/${local.namespace}-avalon-db/admin_password"
  value     = module.db_avalon.db_instance_password
  type      = "SecureString"
  overwrite = true
}

