# Don't group unrelated containers into 1 task definition 
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/application_architecture.html
resource "aws_ecs_task_definition" "fcrepo_task_def" {
  family                = "${local.namespace}_fcrepo_task_def"
  container_definitions = <<TASK_DEFINITION
[
  {
    "cpu": 512,
    "essential": true,
    "image": "nulib/fcrepo4:4.7.5-s3fix",
    "memory": 1024,
    "name": "fcrepo",
    "environment": [
      { "name": "MODESHAPE_CONFIG", "value": "classpath:/config/jdbc-postgresql-s3/repository.json" },
      { "name": "JAVA_OPTIONS", "value": "-Dfcrepo.postgresql.host=${module.db_fcrepo.this_db_instance_address} -Dfcrepo.postgresql.username=${module.db_fcrepo.this_db_instance_username} -Dfcrepo.postgresql.password=${module.db_fcrepo.this_db_instance_password} -Dfcrepo.postgresql.port=${module.db_fcrepo.this_db_instance_port} -Daws.accessKeyId=${var.fcrepo_binary_bucket_access_key} -Daws.secretKey=${var.fcrepo_binary_bucket_secret_key} -Daws.bucket=${aws_s3_bucket.fcrepo_binary_bucket.id}" }
    ],
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 0
      }
    ],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.fcrepo.name}",
            "awslogs-region": "${var.aws_region}"
        }
    },
    "mountPoints": [
      {
        "sourceVolume": "fcrepo-data",
        "containerPath": "/data"
      }
    ]
  }
]
TASK_DEFINITION

  volume {
    name      = "fcrepo-data"
    docker_volume_configuration {
      scope         = "task"
      driver        = "local"
    }
  }
}

resource "aws_ecs_service" "fcrepo_service" {
  name            = "${local.namespace}-ecs-fcrepo"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.fcrepo_task_def.arn
  desired_count   = 1

  service_registries {
    registry_arn = aws_service_discovery_service.fcrepo.arn
    container_port = 8080
    container_name = "fcrepo"
  }

  depends_on = [
    aws_iam_role_policy.ecs_service,
  ]
}

resource "aws_service_discovery_service" "fcrepo" {
  name = "fcrepo"

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

resource "aws_cloudwatch_log_group" "fcrepo" {
  name = "${local.namespace}/fcrepo"
}
