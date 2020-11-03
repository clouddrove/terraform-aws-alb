provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source      = "clouddrove/vpc/aws"
  version     = "0.13.0"
  name        = "vpc"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  cidr_block = "172.16.0.0/16"
}

module "public_subnets" {
  source      = "clouddrove/subnet/aws"
  version     = "0.13.0"
  name        = "public-subnet"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  availability_zones = ["eu-west-1b", "eu-west-1c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block
}

module "http-https" {
  source      = "clouddrove/security-group/aws"
  version     = "0.13.0"
  name        = "http-https"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = ["0.0.0.0/0"]
  allowed_ports = [80, 443]
}

module "ssh" {
  source      = "clouddrove/security-group/aws"
  version     = "0.13.0"
  name        = "ssh"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block]
  allowed_ports = [22]
}

module "iam-role" {
  source             = "clouddrove/iam-role/aws"
  version            = "0.13.0"
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
  source         = "clouddrove/ec2/aws"
  version        = "0.13.0"
  name           = "ec2-instance"
  application    = "clouddrove"
  environment    = "test"
  label_order    = ["environment", "application", "name"]
  instance_count = 1
  ami            = "ami-08d658f84a6d84a80"
  instance_type  = "t2.nano"
  monitoring     = false
  tenancy        = "default"

  vpc_security_group_ids_list = [module.ssh.security_group_ids, module.http-https.security_group_ids]
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


module "nlb" {
  source = "./../../"

  name        = "nlb"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  enable                     = true
  internal                   = false
  load_balancer_type         = "network"
  instance_count             = module.ec2.instance_count
  subnets                    = module.public_subnets.public_subnet_id
  enable_deletion_protection = false

  target_id = module.ec2.instance_id
  vpc_id    = module.vpc.vpc_id

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 0
    },
  ]

  // TLS
  https_listeners = [
    {
      port               = 443
      protocol           = "TLS"
      certificate_arn    = "arn:aws:acm:eu-west-1:924144197303:certificate/0418d2ba-91f7-4196-991b-28b5c60cd4cf"
      target_group_index = 1
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