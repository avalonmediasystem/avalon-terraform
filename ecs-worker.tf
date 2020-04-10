resource "aws_ecs_task_definition" "worker_task_def" {
  family                = "${local.namespace}_worker_task_def"
  container_definitions = <<TASK_DEFINITION
[
  {
    "cpu": 512,
    "command": ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"],
    "essential": true,
    "image": "avalonmediasystem/avalon:7.1-ecs",
    "memory": 1024,
    "name": "worker",
    "environment": [
      {"name": "AWS_REGION", "value": "us-east-1"},
      {"name": "DATABASE_URL", "value": "postgres://${module.db_avalon.this_db_instance_username}:${module.db_avalon.this_db_instance_password}@${module.db_avalon.this_db_instance_address}/avalon"},
      {"name": "SECRET_KEY_BASE", "value": "112f7d33c8864e0ef22910b45014a1d7925693ef549850974631021864e2e67b16f44aa54a98008d62f6874360284d00bb29dc08c166197d043406b42190188a"},
      {"name": "FEDORA_NAMESPACE", "value": "avalon"},
      {"name": "FEDORA_URL", "value": "http://fedoraAdmin:fedoraAdmin@fcrepo.avalon-dev-local/rest"},
      {"name": "SOLR_URL", "value": "http://avalon-dev-solr.avalon-dev-local/solr/avalon"},
      {"name": "SETTINGS__REDIS__HOST", "value": "${aws_route53_record.redis.name}"},
      {"name": "RAILS_LOG_TO_STDOUT", "value": "true"},
      {"name": "SETTINGS__DOMAIN", "value": "https://${aws_route53_record.alb.fqdn}"},
      {"name": "SETTINGS__DROPBOX__PATH", "value": "s3://${aws_s3_bucket.this_masterfiles.id}/dropbox/"},
      {"name": "SETTINGS__DROPBOX__UPLOAD_URI", "value": "s3://${aws_s3_bucket.this_masterfiles.id}/dropbox/"},
      {"name": "SETTINGS__MASTER_FILE_MANAGEMENT__PATH", "value": "s3://${aws_s3_bucket.this_preservation.id}/"},
      {"name": "SETTINGS__MASTER_FILE_MANAGEMENT__STRATEGY", "value": "MOVE"},
      {"name": "SETTINGS__FFMPEG__PATH", "value": "/usr/bin/ffmpeg"},
      {"name": "SETTINGS__ENCODING__ENGINE_ADAPTER", "value": "elastic_transcoder"},
      {"name": "SETTINGS__ENCODING__PIPELINE", "value": "${aws_elastictranscoder_pipeline.this_pipeline.id}"},
      {"name": "SETTINGS__EMAIL__COMMENTS", "value": "${var.email_comments}"},
      {"name": "SETTINGS__EMAIL__NOTIFICATION", "value": "${var.email_notification}"},
      {"name": "SETTINGS__EMAIL__SUPPORT", "value": "${var.email_support}"},
      {"name": "STREAMING_HOST", "value": "${aws_route53_record.alb_streaming.fqdn}"},
      {"name": "SETTINGS__STREAMING__HTTP_BASE", "value": "https://${aws_route53_record.alb_streaming.fqdn}/avalon"}
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.worker.name}",
            "awslogs-region": "${var.aws_region}"
        }
    }
  }
]
TASK_DEFINITION
}

resource "aws_ecs_service" "worker_service" {
  name            = "${local.namespace}-ecs-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker_task_def.arn
  desired_count   = 2

  depends_on = [
    aws_iam_role_policy.ecs_service,
  ]
}

resource "aws_cloudwatch_log_group" "worker" {
  name = "${local.namespace}/worker"
}
