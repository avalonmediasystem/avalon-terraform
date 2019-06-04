resource "aws_security_group" "db_client" {
  name        = "${local.namespace}-db-client"
  description = "RDS Client Security Group"
  vpc_id      = "${module.vpc.vpc_id}"
  tags        = "${local.common_tags}"
}

resource "aws_security_group" "db" {
  name        = "${local.namespace}-db"
  description = "RDS Security Group"
  vpc_id      = "${module.vpc.vpc_id}"
  tags        = "${local.common_tags}"
}

resource "aws_security_group_rule" "db_client_access" {
  security_group_id        = "${aws_security_group.db.id}"
  type                     = "ingress"
  from_port                = "5432"
  to_port                  = "5432"
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.db_client.id}"
}
