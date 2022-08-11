provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "0.15.1"

  name        = "vpc"
  environment = "test"
  label_order = ["name", "environment"]

  cidr_block = "172.16.0.0/16"
}

module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "0.15.3"

  name        = "public-subnet"
  environment = "test"
  label_order = ["name", "environment"]


  availability_zones = ["eu-west-1b", "eu-west-1c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block
}

module "http_https" {
  source  = "clouddrove/security-group/aws"
  version = "1.0.1"

  name        = "http-https"
  environment = "test"
  label_order = ["name", "environment"]


  vpc_id        = module.vpc.vpc_id
  allowed_ip    = ["0.0.0.0/0"]
  allowed_ports = [80, 443]
}

module "ssh" {
  source  = "clouddrove/security-group/aws"
  version = "1.0.1"

  name        = "ssh"
  environment = "test"
  label_order = ["name", "environment"]


  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block]
  allowed_ports = [22]
}

module "iam-role" {
  source  = "clouddrove/iam-role/aws"
  version = "1.0.1"

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

module "ec2" {
  source  = "clouddrove/ec2/aws"
  version = "1.0.1"

  name        = "ec2-instance"
  environment = "test"
  label_order = ["name", "environment"]

  instance_count = 2
  ami            = "ami-08d658f84a6d84a80"
  instance_type  = "t2.nano"
  monitoring     = true
  tenancy        = "default"

  vpc_security_group_ids_list = [module.ssh.security_group_ids, module.http_https.security_group_ids]
  subnet_ids                  = tolist(module.public_subnets.public_subnet_id)

  assign_eip_address          = true
  associate_public_ip_address = true

  instance_profile_enabled = true
  iam_instance_profile     = module.iam-role.name


  ebs_optimized      = false
  ebs_volume_enabled = true
  ebs_volume_type    = "gp2"
  ebs_volume_size    = 30
}

module "alb" {
  source = "./../../"

  name                       = "alb"
  enable                     = true
  internal                   = true
  load_balancer_type         = "application"
  instance_count             = module.ec2.instance_count
  security_groups            = [module.ssh.security_group_ids, module.http_https.security_group_ids]
  subnets                    = module.public_subnets.public_subnet_id
  enable_deletion_protection = false
  with_target_group          = true

  target_id = module.ec2.instance_id
  vpc_id    = module.vpc.vpc_id

  https_enabled            = true
  http_enabled             = true
  https_port               = 443
  listener_type            = "forward"
  listener_certificate_arn = "arn:aws:acm:eu-west-1:924144197303:certificate/0418d2ba-91f7-4196-991b-28b5c60cd4cf"
  target_group_port        = 80

  target_groups = [
    {
      backend_protocol     = "HTTP"
      backend_port         = 80
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
}
