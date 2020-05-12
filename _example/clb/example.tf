provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source = "git::https://github.com/clouddrove/terraform-aws-vpc.git?ref=tags/0.12.5"

  name        = "vpc"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  cidr_block = "172.16.0.0/16"
}

module "public_subnets" {
  source = "git::https://github.com/clouddrove/terraform-aws-subnet.git?ref=tags/0.12.6"

  name        = "public-subnet"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  availability_zones = ["eu-west-1b", "eu-west-1c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
}

module "http_https" {
  source = "git::https://github.com/clouddrove/terraform-aws-security-group.git?ref=tags/0.12.4"

  name        = "http-https"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = ["0.0.0.0/0"]
  allowed_ports = [80, 443]
}

module "ssh" {
  source = "git::https://github.com/clouddrove/terraform-aws-security-group.git?ref=tags/0.12.4"

  name        = "ssh"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block]
  allowed_ports = [22]
}

module "iam-role" {
  source = "git::https://github.com/clouddrove/terraform-aws-iam-role.git?ref=tags/0.12.3"

  name               = "iam-role"
  application        = "clouddrove"
  environment        = "test"
  label_order        = ["environment", "application", "name"]
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
  source = "git::https://github.com/clouddrove/terraform-aws-ec2.git?ref=tags/0.12.4"

  name        = "ec2-instance"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  instance_count = 2
  ami            = "ami-08d658f84a6d84a80"
  instance_type  = "t2.nano"
  monitoring     = false
  tenancy        = "default"

  vpc_security_group_ids_list = [module.ssh.security_group_ids, module.http_https.security_group_ids]
  subnet_ids                  = tolist(module.public_subnets.public_subnet_id)

  assign_eip_address          = true
  associate_public_ip_address = true

  instance_profile_enabled = true
  iam_instance_profile     = module.iam-role.name

  disk_size          = 8
  ebs_optimized      = false
  ebs_volume_enabled = true
  ebs_volume_type    = "gp2"
  ebs_volume_size    = 30
}

module "clb" {
  source = "./../../"

  name        = "clb"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  load_balancer_type = "classic"
  clb_enable         = true
  internal           = false
  target_id          = module.ec2.instance_id
  security_groups    = [module.ssh.security_group_ids, module.http_https.security_group_ids]
  subnets            = module.public_subnets.public_subnet_id

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