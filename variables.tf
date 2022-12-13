variable "app_name" {
  default = "avalon"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "aws_profile" {
  default = "default"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "availability_zone" {
  default = "us-east-1a"
}

variable "avalon_admin" {
  default = "admin@example.com"
}

variable "avalon_repo" {
  default = "https://github.com/avalonmediasystem/avalon"
}

variable "avalon_branch" {
  default = "demo"
}

variable "bib_retriever_protocol" {
  default = "sru"
}

variable "bib_retriever_url" {
  default = "http://zgate.example.edu:9000/exampledb"
}

variable "bib_retriever_query" {
  default = "rec.id='%s'"
}

variable "bib_retriever_host" {
  default = ""
}

variable "bib_retriever_port" {
  default = ""
}

variable "bib_retriever_database" {
  default = ""
}

variable "bib_retriever_attribute" {
  default = ""
}

variable "bib_retriever_class" {
  default = "Avalon::BibRetriever::SRU"
}

variable "bib_retriever_class_require" {
  default = "avalon/bib_retriever/sru"
}

variable "bastion_instance_type" {
  default = "t2.micro"
}

variable "compose_instance_type" {
  default = "t3.large"
}

variable "compose_volume_size" {
  type = number
  default = 75
  description = "The root volume size, in gigabytes, of the ec2 that runs the avalon docker containers"
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

variable "fcrepo_db_ssl" {
  type = bool
  default = false
  description = "Forces SSL on the fedora database connection"
}

variable "hosted_zone_name" {
  type = string
}

variable "postgres_version" {
  default = "14.4"
}

#variable "sms_notification" {
#  type = string
#}

variable "ssh_cidr_blocks" {
  description = "Allow inbound SSH connections from given CIDR ranges"
  type    = list(string)
  default = []
}

variable "stack_name" {
  default = "stack"
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

variable "zone_prefix" {
  description = "An optional prefix string to the hosted zone names"
  type = string
  default = ""
}

locals {
  namespace         = "${var.stack_name}-${var.environment}"
  public_zone_name  = "${var.zone_prefix}${var.environment}.${var.hosted_zone_name}"
  private_zone_name = "vpc.${var.zone_prefix}${var.environment}.${var.hosted_zone_name}"

  common_tags = merge(
    var.tags,
    {
      "Terraform"   = "true"
      "Environment" = local.namespace
      "Project"     = "Infrastructure"
    },
  )
}

