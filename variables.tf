variable "app_name" {
  default = "avalon"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "availability_zone" {
  default = "us-east-1a"
}

variable "avalon_repo" {
  default = "https://github.com/avalonmediasystem/avalon"
}

variable "avalon_branch" {
  default = "demo"
}

variable "autoscale_min" {
  default = 1
}

variable "autoscale_max" {
  default = 2
}

variable "autoscale_desired" {
  default = 2
}

variable "bastion_instance_type" {
  default = "t2.micro"
}

variable "db_avalon_username" {
  default = "dbavalon"
}

variable "db_fcrepo_username" {
  default = "dbfcrepo"
}

variable "ec2_keyname" {
  type = string
}

variable "ec2_private_keyfile" {
  type = string
}

variable "ecs_instance_type" {
  default = "t3.large"
}

variable "email_comments" {
  type = string
}

variable "email_notification" {
  type = string
}

variable "email_support" {
  type = string
}

variable "environment" {
  type = string
}

variable "fcrepo_binary_bucket_username" {
  type = string
}

variable "fcrepo_binary_bucket_access_key" {
  type = string
}

variable "fcrepo_binary_bucket_secret_key" {
  type = string
}

variable "hosted_zone_name" {
  type = string
}

variable "postgres_version" {
  default = "10.6"
}

variable "sms_notification" {
  type = string
}

variable "stack_name" {
  default = "stack"
}

variable "stack_bucket" {
  type = string
}

variable "stack_key" {
  type    = string
  default = "stack.tfstate"
}

variable "stack_region" {
  type    = string
  default = "us-east-1"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vpc_cidr_block" {
  default = "10.1.0.0/16"
}

variable "vpc_public_subnets" {
  type    = list(string)
  default = ["10.1.2.0/24", "10.1.4.0/24", "10.1.6.0/24"]
}

variable "vpc_private_subnets" {
  type    = list(string)
  default = ["10.1.1.0/24", "10.1.3.0/24", "10.1.5.0/24"]
}

locals {
  namespace         = "${var.stack_name}-${var.environment}"
  public_zone_name  = "${var.environment}.${var.hosted_zone_name}"
  private_zone_name = "vpc.${var.environment}.${var.hosted_zone_name}"

  common_tags = merge(
    var.tags,
    {
      "Terraform"   = "true"
      "Environment" = local.namespace
      "Project"     = "Infrastructure"
    },
  )
}

