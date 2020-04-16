# Don't group unrelated containers into 1 task definition 
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/application_architecture.html
resource "aws_ecs_task_definition" "streaming_task_def" {
  family                = "${local.namespace}_streaming_task_def"
  network_mode          = "bridge"
  container_definitions = <<TASK_DEFINITION
[
  {
    "cpu": 256,
    "essential": true,
    "image": "avalonmediasystem/nginx:ecs",
    "memory": 256,
    "name": "streaming",      
    "links": [
      "s3helper"
    ],
    "environment": [
      {"name": "AUTH_URL", "value": "https://${aws_route53_record.alb.fqdn}"},
      {"name": "PROXY_PASS_URL", "value": "http://s3helper:8080/"}
    ],
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 0
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.streaming.name}",
          "awslogs-region": "${var.aws_region}"
      }
    }
  },
  {
    "cpu": 256,
    "essential": true,
    "image": "avalonmediasystem/evs-s3helper",
    "memory": 256,
    "name": "s3helper",
    "environment": [
      {"name": "S3_REGION", "value": "${var.aws_region}"},
      {"name": "S3_BUCKET", "value": "${aws_s3_bucket.this_derivatives.id}"}
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.streaming.name}",
            "awslogs-region": "${var.aws_region}"
        }
    }
  }
]
TASK_DEFINITION
}

resource "aws_ecs_service" "streaming_service" {
  name            = "${local.namespace}-ecs-streaming"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.streaming_task_def.arn
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_streaming.id
    container_name   = "streaming"
    container_port   = "80"
  }

  depends_on = [
    aws_iam_role_policy.ecs_service,
  ]
}

resource "aws_cloudwatch_log_group" "streaming" {
  name = "${local.namespace}/streaming"
}
