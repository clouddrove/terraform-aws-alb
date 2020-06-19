provider "aws" {
  region = "eu-west-1"
}

module "keypair" {
  source = "git::https://github.com/clouddrove/terraform-aws-keypair.git?ref=tags/0.12.2"

  key_path        = "~/.ssh/id_rsa.pub"
  key_name        = "main-key"
  enable_key_pair = true
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
  source = "git::https://github.com/aashishgoyal246/terraform-aws-subnet.git?ref=slave"

  name        = "public-subnet"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  availability_zones = ["eu-west-1b", "eu-west-1c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
}

module "http_https" {
  source = "git::https://github.com/aashishgoyal246/terraform-aws-security-group.git?ref=slave"

  name        = "http-https"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = ["0.0.0.0/0"]
  allowed_ipv6  = ["2405:201:5e00:3684:cd17:9397:5734:a167/128", module.vpc.ipv6_cidr_block]
  allowed_ports = [80, 443]
}

module "ssh" {
  source = "git::https://github.com/aashishgoyal246/terraform-aws-security-group.git?ref=slave"

  name        = "ssh"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block, "0.0.0.0/0"]
  allowed_ipv6  = ["2405:201:5e00:3684:cd17:9397:5734:a167/128", module.vpc.ipv6_cidr_block]
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

  instance_count = 1
  ami            = "ami-0701e7be9b2a77600"
  instance_type  = "t2.micro"
  monitoring     = false
  tenancy        = "default"

  vpc_security_group_ids_list = [module.ssh.security_group_ids, module.http_https.security_group_ids]
  subnet_ids                  = tolist(module.public_subnets.public_subnet_id)

  assign_eip_address          = true
  associate_public_ip_address = true
  ipv6_address_count          = 1
  key_name                    = module.keypair.name

  instance_profile_enabled = true
  iam_instance_profile     = module.iam-role.name

  disk_size          = 8
  ebs_optimized      = false
  ebs_volume_enabled = true
  ebs_volume_type    = "gp2"
  ebs_volume_size    = 30
}


module "alb" {
  source = "./../../"

  name        = "alb"
  application = "clouddrove"
  environment = "test"
  label_order = ["environment", "application", "name"]

  enable                     = true
  internal                   = false
  load_balancer_type         = "application"
  instance_count             = module.ec2.instance_count
  security_groups            = [module.ssh.security_group_ids, module.http_https.security_group_ids]
  subnets                    = module.public_subnets.public_subnet_id
  enable_deletion_protection = false

  target_id = module.ec2.instance_id
  vpc_id    = module.vpc.vpc_id

  https_enabled            = true
  http_enabled             = false
  https_port               = 80
  listener_type            = "forward"
  listener_protocol        = "HTTP"
  listener_ssl_policy      = ""
  target_group_port        = 80
  ip_address_type          = "dualstack"

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
