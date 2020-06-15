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

  capacity_provider_strategy {
    base              = 1
    capacity_provider = aws_ecs_capacity_provider.stack.name
    weight            = 1
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_streaming.id
    container_name   = "streaming"
    container_port   = "80"
  }

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  depends_on = [
    aws_iam_role_policy.ecs_service,
  ]
}

resource "aws_cloudwatch_log_group" "streaming" {
  name = "${local.namespace}/streaming"
}

resource "aws_appautoscaling_target" "ecs_streaming" {
  max_capacity       = 8
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.streaming_service.name}"
  # role_arn           = aws_iam_role.ecs_service.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_streaming" {
  name               = "${local.namespace}-scale-streaming"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_streaming.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_streaming.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_streaming.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 40
  }
}
