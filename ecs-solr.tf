# Don't group unrelated containers into 1 task definition 
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/application_architecture.html
resource "aws_ecs_task_definition" "solr_task_def" {
  family                = "${local.namespace}_solr_task_def"
  container_definitions = <<TASK_DEFINITION
[
  {
    "cpu": 512,
    "entryPoint": ["docker-entrypoint.sh", "solr-precreate", "avalon", "/opt/solr/avalon_conf"],
    "essential": true,
    "image": "avalonmediasystem/solr:latest",
    "memory": 1024,
    "name": "solr",
    "portMappings": [
      {
        "containerPort": 8983,
        "hostPort": 0
      }
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.solr.name}",
            "awslogs-region": "${var.aws_region}"
        }
    },
    "mountPoints": [
      {
        "sourceVolume": "solr-data",
        "containerPath": "/opt/solr/server/solr/mycores"
      }
    ]
  }
]
TASK_DEFINITION

  volume {
    name      = "solr-data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.solr_backups.id
    }
  }
}

resource "aws_ecs_service" "solr_service" {
  name            = "${local.namespace}-ecs-solr"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.solr_task_def.arn
  desired_count   = 1
  # iam_role        = aws_iam_role.ecs_service.name

  # load_balancer {
  #   target_group_arn = aws_alb_target_group.test.id
  #   container_name   = "solr"
  #   container_port   = "8983"
  # }

  service_registries {
    registry_arn = aws_service_discovery_service.solr.arn
    container_port = 8983
    container_name = "solr"
  }

  depends_on = [
    aws_iam_role_policy.ecs_service,
  ]
}

resource "aws_service_discovery_service" "solr" {
  name = "${local.namespace}-solr"

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

resource "aws_cloudwatch_log_group" "solr" {
  name = "${local.namespace}/solr"
}
