data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

resource "aws_iam_role" "build" {
  name = "${local.namespace}-build-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "build_ecr" {
  role       = aws_iam_role.build.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy" "build" {
  role = aws_iam_role.build.name

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": [
        "arn:aws:ec2:${local.region}:${local.account_id}:network-interface/*"
      ],
      "Condition": {
        "StringEquals": {
          "ec2:Subnet": [
            "${module.vpc.private_subnet_arns[0]}",
            "${module.vpc.private_subnet_arns[1]}",
            "${module.vpc.private_subnet_arns[2]}"
          ],
          "ec2:AuthorizedService": "codebuild.amazonaws.com"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_ecr_repository" "avalon" {
  name                 = "avalon"
  image_tag_mutability = "MUTABLE"

  tags = local.common_tags
}


resource "aws_codebuild_project" "docker" {
  name          = "${local.namespace}-build-project"
  description   = "Build Avalon Docker image"
  build_timeout = "15"
  service_role  = aws_iam_role.build.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:2.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AVALON_REPO"
      value = var.avalon_repo
    }

    environment_variable {
      name  = "AVALON_BRANCH"
      value = var.avalon_branch
      # type  = "PARAMETER_STORE"
    }

    environment_variable {
      name  = "AVALON_DOCKER_REPO"
      value = aws_ecr_repository.avalon.repository_url
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "${aws_cloudwatch_log_group.compose_log_group.name}/build.log"
      stream_name = "build.log"
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = <<BUILDSPEC
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws --version
      - $(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)
      - AVALON_REV=`git ls-remote $AVALON_REPO refs/heads/$AVALON_BRANCH | cut -f 1`
      - AVALON_DOCKER_CACHE_TAG=$AVALON_REV
      - docker pull $AVALON_DOCKER_REPO:$AVALON_DOCKER_CACHE_TAG || docker pull $AVALON_DOCKER_REPO:latest || true
  build:
    commands:
       - git clone -b $AVALON_BRANCH --single-branch $AVALON_REPO
       - DOCKER_BUILDKIT=1 docker build -t $AVALON_DOCKER_REPO:$AVALON_REV -t $AVALON_DOCKER_REPO:latest --target=prod avalon
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $AVALON_DOCKER_REPO:$AVALON_REV 
      - docker push $AVALON_DOCKER_REPO:latest
      - aws ssm send-command --document-name "AWS-RunShellScript" --document-version "1" --targets '[{"Key":"InstanceIds","Values":["${aws_instance.compose.id}"]}]' --parameters '{"commands":["$(aws ecr get-login --region ${local.region} --no-include-email) && docker-compose pull avalon && docker-compose up -d avalon worker"],"workingDirectory":["/home/ec2-user/avalon-docker-aws_min"],"executionTimeout":["360"]}' --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --cloud-watch-output-config '{"CloudWatchLogGroupName":"avalon-demo/ssm","CloudWatchOutputEnabled":true}' --region us-east-1
BUILDSPEC
  }

  vpc_config {
    vpc_id             = module.vpc.vpc_id
    subnets            = module.vpc.private_subnets
    security_group_ids = [aws_security_group.compose.id]
  }

  tags = local.common_tags
}
