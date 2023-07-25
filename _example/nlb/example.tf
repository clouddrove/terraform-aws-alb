##---------------------------------------------------------------------------------------------------------------------------
## Provider block added, Use the Amazon Web Services (AWS) provider to interact with the many resources supported by AWS.
##--------------------------------------------------------------------------------------------------------------------------
provider "aws" {
  region = "eu-west-1"
}

##---------------------------------------------------------------------------------------------------------------------------
## A VPC is a virtual network that closely resembles a traditional network that you'd operate in your own data center.
##--------------------------------------------------------------------------------------------------------------------------
module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "1.3.1"

  name        = "vpc"
  environment = "test"
  label_order = ["name", "environment"]

  cidr_block = "172.16.0.0/16"
}

##-----------------------------------------------------
## A subnet is a range of IP addresses in your VPC.
##-----------------------------------------------------
module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "1.3.0"

  name        = "public-subnet"
  environment = "test"
  label_order = ["name", "environment"]

  availability_zones = ["eu-west-1b", "eu-west-1c"]
  type               = "public"
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  igw_id             = module.vpc.igw_id
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block
}

##-----------------------------------------------------
## An AWS security group acts as a virtual firewall for incoming and outgoing traffic with http-https.
##-----------------------------------------------------
module "http-https" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.0"

  name        = "http-https"
  environment = "test"
  label_order = ["name", "environment"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = ["0.0.0.0/0"]
  allowed_ports = [80, 443]
}

##-----------------------------------------------------
## An AWS security group acts as a virtual firewall for incoming and outgoing traffic with ssh.
##-----------------------------------------------------
module "ssh" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.0"

  name        = "ssh"
  environment = "test"
  label_order = ["name", "environment"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block]
  allowed_ports = [22]
}

##-----------------------------------------------------
## When your trusted identities assume IAM roles, they are granted only the permissions scoped by those IAM roles.
##-----------------------------------------------------
module "iam-role" {
  source  = "clouddrove/iam-role/aws"
  version = "1.3.0"

  name        = "iam-role"
  environment = "test"
  label_order = ["name", "environment"]

  assume_role_policy = data.aws_iam_policy_document.default.json

  policy_enabled = true
  policy         = data.aws_iam_policy_document.iam-policy.json
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
  version = "1.3.0"

  name        = "ec2-instance"
  environment = "test"
  label_order = ["name", "environment"]

  instance_count              = 1
  ami                         = "ami-08d658f84a6d84a80"
  instance_type               = "t2.nano"
  monitoring                  = false
  tenancy                     = "default"
  vpc_security_group_ids_list = [module.ssh.security_group_ids, module.http-https.security_group_ids]
  subnet_ids                  = tolist(module.public_subnets.public_subnet_id)
  iam_instance_profile        = module.iam-role.name
  assign_eip_address          = true
  associate_public_ip_address = true
  instance_profile_enabled    = true
  ebs_optimized               = false
  ebs_volume_enabled          = true
  ebs_volume_type             = "gp2"
  ebs_volume_size             = 30
}

##-----------------------------------------------------------------------------
## nlb module call.
##-----------------------------------------------------------------------------
module "nlb" {
  source = "./../../"

  name                       = "nlb"
  enable                     = true
  internal                   = true
  load_balancer_type         = "network"
  instance_count             = module.ec2.instance_count
  subnets                    = module.public_subnets.public_subnet_id
  target_id                  = module.ec2.instance_id
  vpc_id                     = module.vpc.vpc_id
  enable_deletion_protection = false
  with_target_group          = true
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 0
    },
  ]
  target_groups = [
    {
      backend_protocol = "TCP"
      backend_port     = 80
      target_type      = "instance"
    },
    {
      backend_protocol = "TLS"
      backend_port     = 443
      target_type      = "instance"
    },
  ]
}