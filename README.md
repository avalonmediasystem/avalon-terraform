Turnkey solution for Avalon on AWS, using Terraform

# Architecture diagram
![](diagram.jpg)

# Getting started
## Prerequisites

1. Download and install [Terraform](https://www.terraform.io/downloads.html)
1. Clone this repo
1. Create or import an [EC2 key-pair](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) for your region.
1. Create an S3 bucket to hold the terraform state, this is useful when
    executing terraform on multiple machines (or working as a team) because it allows state to remain in sync. 
1. Copy `dev.tfbackend.example` to `dev.tfbackend` and fill in the previously created bucket name.

    ```
    bucket = "my-terraform-state"
    key    = "state.tfstate"
    region = "us-east-1"
    ````
1. Create an IAM user that Fedora will use to sign its S3 requests.
1. Create a [public hosted zone in Route53](http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html); Terraform will automatically manage DNS entries in this zone. A registered domain name is needed to pair with the Route53 hosted zone. You can [use Route53 to register a new domain](http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html) or [use Route53 to manage an existing domain](http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/MigratingDNS.html).
1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in the relevant information:
    ```
    environment         = "dev"
    hosted_zone_name    = "mydomain.org"
    ec2_keyname         = "my-ec2-key"
    ec2_private_keyfile = "/local/path/my-ec2-key.pem"
    stack_name          = "mystack"
    fcrepo_binary_bucket_username = "iam_user"
    fcrepo_binary_bucket_access_key = "***********"
    fcrepo_binary_bucket_secret_key = "***********"
    tags {
      Creator    = "me"
      AnotherTag = "Whatever value I want!"
    }
    ```
    * Note: You can have more than one variable file and pass the name on the command line to manage more than one stack.
1. Execute `terraform init  -reconfigure -backend-config=dev.tfbackend`.

## Bringing up the stack

To see the changes Terraform will make:

    terraform plan

To actually make those changes:

    terraform apply

# Maintenance

## Update the stack
You can proceed with `terraform plan` and `terraform apply` as often as you want to see and apply changes to the
stack. Changes you make to the `*.tf` files  will automatically be reflected in the resources under Terraform's
control.

## Destroy the stack
Special care must be taken if you want to retain all data when destroying the stack. If that wasn't a concern, you can simply run
    
    terraform destroy

## Update the containers
Since Avalon, Fedora, Solr and Nginx are running inside Docker containers managed by docker-compose, you can SSH to the EC2 box and run docker-compose commands as usual.

    docker-compose pull
    docker-compose up -d

