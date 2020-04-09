resource "aws_ecs_task_definition" "avalon_task_def" {
  family                = "${local.namespace}_avalon_task_def"
  container_definitions = <<TASK_DEFINITION
[
  {
    "cpu": 512,
    "command": ["bash", "-c", "rake db:migrate; rails server -b 0.0.0.0"],
    "essential": true,
    "image": "avalonmediasystem/avalon:7.1-ecs",
    "memory": 1024,
    "name": "avalon",
    "environment": [
      {"name": "DATABASE_URL", "value": "postgres://${module.db_avalon.this_db_instance_username}:${module.db_avalon.this_db_instance_password}@${module.db_avalon.this_db_instance_address}/avalon"},
      {"name": "ELASTICACHE_HOST", "value": "${aws_route53_record.redis.name}"},
      {"name": "SECRET_KEY_BASE", "value": "112f7d33c8864e0ef22910b45014a1d7925693ef549850974631021864e2e67b16f44aa54a98008d62f6874360284d00bb29dc08c166197d043406b42190188a"},
      {"name": "FEDORA_NAMESPACE", "value": "avalon"},
      {"name": "FEDORA_URL", "value": "http://fedoraAdmin:fedoraAdmin@fcrepo.avalon-dev-local/rest"},
      {"name": "SOLR_URL", "value": "http://avalon-dev-solr.avalon-dev-local/solr/avalon"},
      {"name": "AWS_REGION", "value": "us-east-1"},
      {"name": "RAILS_LOG_TO_STDOUT", "value": "true"},
      {"name": "SETTINGS__DOMAIN", "value": "https://${aws_route53_record.alb.fqdn}"},
      {"name": "SETTINGS__DROPBOX__PATH", "value": "s3://${aws_s3_bucket.this_masterfiles.id}/dropbox/"},
      {"name": "SETTINGS__DROPBOX__UPLOAD_URI", "value": "s3://${aws_s3_bucket.this_masterfiles.id}/dropbox/"},
      {"name": "SETTINGS__MASTER_FILE_MANAGEMENT__PATH", "value": "s3://${aws_s3_bucket.this_preservation.id}/"},
      {"name": "SETTINGS__MASTER_FILE_MANAGEMENT__STRATEGY", "value": "MOVE"},
      {"name": "SETTINGS__ENCODING__ENGINE_ADAPTER", "value": "elastic_transcoder"},
      {"name": "SETTINGS__ENCODING__PIPELINE", "value": "${aws_elastictranscoder_pipeline.this_pipeline.id}"},
      {"name": "SETTINGS__EMAIL__COMMENTS", "value": "${var.email_comments}"},
      {"name": "SETTINGS__EMAIL__NOTIFICATION", "value": "${var.email_notification}"},
      {"name": "SETTINGS__EMAIL__SUPPORT", "value": "${var.email_support}"},
      {"name": "STREAMING_HOST", "value": "${aws_route53_record.alb_streaming.fqdn}"},
      {"name": "SETTINGS__STREAMING__HTTP_BASE", "value": "https://${aws_route53_record.alb_streaming.fqdn}/avalon"}
    ],
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 0
      }
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.avalon.name}",
            "awslogs-region": "${var.aws_region}"
        }
    }
  }
]
TASK_DEFINITION
}

data "aws_iam_policy_document" "avalon_api_access" {
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

resource "aws_iam_policy" "avalon_api_access" {
  name   = "${local.namespace}-avalon-api-access"
  policy = data.aws_iam_policy_document.avalon_api_access.json
}

resource "aws_iam_role_policy_attachment" "avalon_api_access" {
  role       = aws_iam_role.app_instance.name
  policy_arn = aws_iam_policy.avalon_api_access.arn
}

resource "aws_ecs_service" "avalon_service" {
  name            = "${local.namespace}-ecs-avalon"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.avalon_task_def.arn
  desired_count   = 1
  # iam_role        = aws_iam_role.ecs_service.name

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_web.id
    container_name   = "avalon"
    container_port   = "3000"
  }

  service_registries {
    registry_arn = aws_service_discovery_service.avalon.arn
    container_port = 3000
    container_name = "avalon"
  }

  depends_on = [
    aws_iam_role_policy.ecs_service,
  ]
}

resource "aws_service_discovery_service" "avalon" {
  name = "${local.namespace}-avalon"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.local.id

    dns_records {
      ttl  = 10
      type = "SRV"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

## ALB

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.web_cert.certificate_arn

  default_action {
    target_group_arn = aws_alb_target_group.alb_web.arn
    type             = "forward"
  }
}

# Web listener rule and target group
resource "aws_lb_listener_rule" "alb_web_listener_rule" {
  listener_arn = aws_alb_listener.alb_listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.alb_web.arn
  }

  condition {
    field  = "host-header"
    values = [aws_route53_record.alb.fqdn]
  }
}

# resource "aws_alb_target_group" "alb_web" {
#   name     = "${local.namespace}-alb-web"
#   port     = "80"
#   protocol = "HTTP"
#   vpc_id   = module.vpc.vpc_id

#   stickiness {
#     type            = "lb_cookie"
#     cookie_duration = 1800
#     enabled         = "true"
#   }
#   health_check {
#     healthy_threshold   = 3
#     unhealthy_threshold = 10
#     timeout             = 5
#     interval            = 30
#     path                = "/"
#     port                = "80"
#   }
# }

resource "aws_alb_target_group" "alb_web" {
  name     = "${local.namespace}-ecs-avalon"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

# resource "aws_alb_listener" "front_end" {
#   load_balancer_arn = aws_alb.alb.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     target_group_arn = aws_alb_target_group.avalon.id
#     type             = "forward"
#   }
# }

resource "aws_cloudwatch_log_group" "avalon" {
  name = "${local.namespace}/avalon"
}
