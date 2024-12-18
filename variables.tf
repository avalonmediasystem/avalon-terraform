variable "alt_hostname" {
  description = "Specify an alternative hostname for the public website url (instead of public_zone_name)"
  type    = map(object({
              zone_id = string
              hostname = string
            }))
  default = {}
  #
  #  To use alt_hostname, you first need to delegate it as a DNS zone to Route53.
  #  AWS will then create appropriate DNS records.
  #
  # alt_hostname = {
  #                "my-zone" = {
  #                  zone_id = "Z0123456789ABCDEFGHI"
  #                  hostname = "my-alt.added.domain.edu"
  #                }
  #              }
}

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
  default = ""
}

variable "avalon_repo" {
  description = "The repository to pull when building the Avalon image"
  default = "https://github.com/avalonmediasystem/avalon"
}

variable "avalon_branch" {
  description = "The branch to use when building the Avalon image"
  default = "demo"
}

variable "avalon_commit" {
  description = "The full commit hash to use when building the Avalon image (empty defaults to most recent for the avalon_branch)"
  default = ""
}

variable "avalon_docker_code_repo" {
  description = "The avalon-docker repository to pull when running docker-compose"
  default = "https://github.com/avalonmediasystem/avalon-docker"
}

variable "avalon_docker_code_branch" {
  description = "The avalon-docker branch to use when running docker-compose"
  default = "aws_min"
}

variable "avalon_docker_code_commit" {
  description = "The full avalon-docker commit hash to use when running docker-compose (empty defaults to most recent for the avalon_docker_code_branch)"
  default = ""
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
  default = null
  description = "The name of an AWS EC2 key pair to use for authenticating"
}

variable "ec2_public_key" {
  type = string
  default = ""
  description = "A SSH public key string to use for authenticating"
}

variable "ec2_users" {
  type = map(object({
    gecos = optional(string, "")
    ssh_keys = optional(list(string), [])
    setup_commands = optional(list(string), [])
  }))
  default = {}
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

variable "extra_docker_environment_variables" {
  description = "These are passed in to the compose-init.sh script"
  type = map(string)
  default = {}
}

variable "fcrepo_binary_bucket_username" {
  type = string
  default = ""
  description = "AWS IAM user for fedora bucket (will attempt to create if left blank)"
}

variable "fcrepo_binary_bucket_access_key" {
  type = string
  default = ""
  description = "AWS IAM user access key for fedora bucket (will attempt to create if username blank)"
}

variable "fcrepo_binary_bucket_secret_key" {
  type = string
  default = ""
  description = "AWS IAM user secret key for fedora bucket (will attempt to create if username blank)"
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
  default = "14.12"
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
  ec2_hostname      = "ec2.${local.public_zone_name}"

  common_tags = merge(
    var.tags,
    {
      "Terraform"   = "true"
      "Environment" = local.namespace
      "Project"     = "Infrastructure"
    },
  )
}

