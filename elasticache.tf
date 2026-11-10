resource "aws_security_group" "elasticache" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "elasticache_egress" {
  security_group_id = aws_security_group.elasticache.id
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_elasticache_subnet_group" "elasticache" {
  name = "${local.namespace}-elasticache"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_replication_group" "elasticache" {
#module "elasticache" {
#  source = "terraform-aws-modules/elasticache/aws"

  replication_group_id = "${local.namespace}-valkey"
  description          = "Valkey cache for rails cache and sidekiq"
  engine               = "valkey"
  node_type            = "cache.t4g.micro"
  num_cache_clusters      = 1
  engine_version       = "9.1"
  security_group_ids   = [aws_security_group.elasticache.id]
  subnet_group_name    = aws_elasticache_subnet_group.elasticache.name
  port                 = "6379"
}

resource "aws_route53_record" "elasticache" {
  zone_id = module.dns.private_zone_id
  name    = "redis.${local.private_zone_name}"
  type    = "CNAME"
  ttl     = 900
  records = [aws_elasticache_replication_group.elasticache.primary_endpoint_address]
}

