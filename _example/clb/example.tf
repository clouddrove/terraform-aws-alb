provider "aws" {
  region = "eu-west-1"
}

locals {
  name        = "clb"
  environment = "test"
}

##---------------------------------------------------------------------------------------------------------------------------
## A VPC is a virtual network that closely resembles a traditional network that you'd operate in your own data center.
##--------------------------------------------------------------------------------------------------------------------------
module "vpc" {
  source      = "clouddrove/vpc/aws"
  version     = "2.0.0"
  name        = local.name
  environment = local.environment
  cidr_block  = "172.16.0.0/16"
}

##-----------------------------------------------------
## A subnet is a range of IP addresses in your VPC.
##-----------------------------------------------------
module "public_subnets" {
  source             = "clouddrove/subnet/aws"
  version            = "2.0.1"
  name               = local.name
  environment        = local.environment
  availability_zones = ["eu-west-1b", "eu-west-1c"]
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
  version            = "1.3.0"
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
  version = "2.0.3"

  name                        = local.name
  environment                 = local.environment
  vpc_id                      = module.vpc.vpc_id
  ssh_allowed_ip              = ["0.0.0.0/0"]
  ssh_allowed_ports           = [22]
  instance_count              = 2
  ami                         = "ami-01dd271720c1ba44f"
  instance_type               = "t2.nano"
  monitoring                  = false
  tenancy                     = "default"
  public_key                  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCmPuPTJ58AMvweGBuAqKX+tkb0ylYq5k6gPQnl6+ivQ8i/jsUJ+juI7q/7vSoTpd0k9Gv7DkjGWg1527I+LJeropVSaRqwDcrnuM1IfUCu0QdRoU8e0sW7kQGnwObJhnRcxiGPa1inwnneq9zdXK8BGgV2E4POKdwbEBlmjZmW8j4JMnCsLvZ4hxBjZB/3fnvHhn7UCqd2C6FhOz9k+aK2kxXHxdDdO9BzKqtvm5dSAxHhw6nDHSU+cHupjiiY/SvmFH0QpR5Fn1kyZH7DxV4D8R9wvP9jKZe/RRTEkB2HY7FpVNz"
  subnet_ids                  = tolist(module.public_subnets.public_subnet_id)
  iam_instance_profile        = module.iam-role.name
  assign_eip_address          = true
  associate_public_ip_address = true
  instance_profile_enabled    = true

  ebs_optimized      = false
  ebs_volume_enabled = true
  ebs_volume_type    = "gp2"
  ebs_volume_size    = 30
}

##-----------------------------------------------------------------------------
## clb module call.
##-----------------------------------------------------------------------------
module "clb" {
  source = "./../../"

  name               = local.name
  load_balancer_type = "classic"
  clb_enable         = true
  internal           = true
  vpc_id             = module.vpc.vpc_id
  target_id          = module.ec2.instance_id
  subnets            = module.public_subnets.public_subnet_id
  with_target_group  = true
  listeners = [
    {
      lb_port            = 22000
      lb_protocol        = "TCP"
      instance_port      = 22000
      instance_protocol  = "TCP"
      ssl_certificate_id = null
    },
    {
      lb_port            = 4444
      lb_protocol        = "TCP"
      instance_port      = 4444
      instance_protocol  = "TCP"
      ssl_certificate_id = null
    }
  ]
  health_check_target              = "TCP:4444"
  health_check_timeout             = 10
  health_check_interval            = 30
  health_check_unhealthy_threshold = 5
  health_check_healthy_threshold   = 5
}
