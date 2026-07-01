provider "aws" {
  region = "us-west-2"
}

locals {
  name        = "alb-harsh"
  environment = "test"
}

##---------------------------------------------------------------------------------------------------------------------------
## A VPC is a virtual network that closely resembles a traditional network that you'd operate in your own data center.
##--------------------------------------------------------------------------------------------------------------------------
module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "2.0.0"

  name        = local.name
  environment = local.environment
  cidr_block  = "172.16.0.0/16"
}

##-----------------------------------------------------
## A subnet is a range of IP addresses in your VPC.
##-----------------------------------------------------
module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "2.0.1"

  name               = local.name
  environment        = local.environment
  availability_zones = ["us-west-2b", "us-west-2c"]
  type               = "public"
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  igw_id             = module.vpc.igw_id
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block
}

##-----------------------------------------------------
## When your trusted identities assume IAM roles, they are granted only the permissions scoped by those IAM roles.
##-----------------------------------------------------
module "iam-role" {
  source             = "clouddrove/iam-role/aws"
  version            = "1.3.2"
  name               = local.name
  environment        = local.environment
  assume_role_policy = data.aws_iam_policy_document.default.json
  policy_enabled     = true
  policy             = data.aws_iam_policy_document.iam-policy.json
}

data "aws_iam_policy_document" "default" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "iam-policy" {
  statement {
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
    "ssmmessages:OpenDataChannel"]
    effect    = "Allow"
    resources = ["*"]
  }
}

##-----------------------------------------------------
## Amazon EC2 provides cloud hosted virtual machines, called "instances", to run applications.
##-----------------------------------------------------
module "ec2" {
  source  = "clouddrove/ec2/aws"
  version = "2.0.4"

  name              = "ec2-${local.name}"
  environment       = local.environment
  vpc_id            = module.vpc.vpc_id
  ssh_allowed_ip    = ["0.0.0.0/0"]
  ssh_allowed_ports = [22]
  public_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCZCFnP8yRx14RdjDDMcZPE+1i9g/o1SI/e0/mAp5ICJU5LQXwxLHeHOLMJDIejfMslJpU3QoVUUe0Hq9+fvnKWktCBoxntcSZ7vAITj1ljzWstb/0p1vSl7lg+dclyWWPF9E8GvoVIElwPFpKBhSzrRQKHKJCvRFsyRqdQPcyT+Oz8vGoi4CHBPhk5G+1wfDB4UufecuZ7Z6diNVzelsCLNmM/yGp30qtQLWNBV0WHKOIuKxNg6xA2FvFzfizi8AgAQ/SDXEOQtflcsWSVdOHRg0aRkAbTCIZ0VW081QZHciml3K64OD307MbZ7E2oI1WDazCYqGzM2mBrWjOKg5H/RbMh+uZjgPlHhgyF3Oc8wSRKR1UJJV7LMUKW9A8blQVkmsD6M5JbZ/eQ/lYjup8VJuXupGseACBDltwqNsAwkgnf/GOldRfNqX01T3OP4YDYpHKDTH6THbiRoUqYTy/TcLXbYtVMT06VcPkxWSKbHSb+z7bXioRJU2e8IQSsHLk= harshal.lohar@CD-IN-MAC-0003.local"
  instance_count    = 1
  instance_configuration = {
    ami                         = "ami-096f5760b00bcd95c"
    instance_type               = "t2.nano"
    tenancy                     = "default"
    monitoring                  = false
    associate_public_ip_address = true
    ebs_optimized               = false
  }
  subnet_ids               = tolist(module.public_subnets.public_subnet_id)
  iam_instance_profile     = module.iam-role.name
  assign_eip_address       = true
  instance_profile_enabled = true
  ebs_volume_enabled       = true
  ebs_volume_type          = "gp2"
  ebs_volume_size          = 30
}

module "acm" {
  source      = "clouddrove/acm/aws"
  version     = "1.4.1"
  name        = local.name
  environment = local.environment

  enable_aws_certificate    = true
  domain_name               = "clouddrove.ca"
  subject_alternative_names = ["*.clouddrove.ca"]
  validation_method         = "DNS"
  enable_dns_validation     = false
}

##-----------------------------------------------------------------------------
## alb module call.
##-----------------------------------------------------------------------------
module "alb" {
  source = "./../../"

  name                       = local.name
  enable                     = true
  internal                   = true
  load_balancer_type         = "application"
  instance_count             = module.ec2.instance_count
  subnets                    = module.public_subnets.public_subnet_id
  target_id                  = module.ec2.instance_id
  vpc_id                     = module.vpc.vpc_id
  allowed_ip                 = [module.vpc.vpc_cidr_block]
  allowed_ports              = [80, 443]
  listener_certificate_arn   = module.acm.arn
  enable_deletion_protection = false
  with_target_group          = true
  https_enabled              = false
  http_enabled               = true
  https_port                 = 443
  listener_type              = "forward"
  target_group_port          = 80

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      target_group_index = 1
      certificate_arn    = module.acm.arn
    }
  ]

  target_groups = [
    {
      backend_protocol     = "HTTP"
      backend_port         = 8001
      target_type          = "instance"
      deregistration_delay = 300
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 10
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    },
    {
      backend_protocol     = "HTTP"
      backend_port         = 8002
      target_type          = "instance"
      deregistration_delay = 300
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 10
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    }
  ]
  http_tcp_listener_rules = [
    {
      http_listener_index = 0
      priority            = 100

      actions = [{
        type               = "forward"
        target_group_index = 0
      }]

      conditions = [{
        host_headers = ["nginx.clouddrove.ca"]
      }]
    },

    {
      http_listener_index = 0
      priority            = 101

      actions = [{
        type               = "forward"
        target_group_index = 1
      }]

      conditions = [{
        host_headers = ["apache.clouddrove.ca"]
      }]
    }

  ]

  extra_ssl_certs = [
    {
      https_listener_index = 0
      certificate_arn      = module.acm.arn
    }
  ]
}
