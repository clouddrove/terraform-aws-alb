provider "aws" {
  region = local.region
}

locals {
  name        = "alb-ec2"
  environment = "test"
  region      = "us-east-1"
}

##---------
## VPC
##---------
module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "2.0.5"

  name        = local.name
  environment = local.environment
  cidr_block  = "172.16.0.0/16"
}

##----------------------------------
## Public subnets across two AZs
##----------------------------------
module "public_subnets" {
  source  = "clouddrove/subnet/aws"
  version = "2.0.2"

  name               = local.name
  environment        = local.environment
  availability_zones = ["${local.region}b", "${local.region}c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
  igw_id             = module.vpc.igw_id
  ipv6_cidr_block    = module.vpc.ipv6_cidr_block
}

##-----------------------------------------------------------------------
## IAM role with SSM managed policy — enables Session Manager access
##-----------------------------------------------------------------------
module "iam-role" {
  source  = "clouddrove/iam-role/aws"
  version = "1.4.0"

  name               = local.name
  environment        = local.environment
  assume_role_policy = data.aws_iam_policy_document.default.json
  policy_enabled     = false
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
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

##-----------------------------------------------------------------------
## SSH key pair — auto-generated, private key stored in Terraform state
##-----------------------------------------------------------------------
module "keypair" {
  source  = "clouddrove/keypair/aws"
  version = "1.3.4"

  name               = local.name
  environment        = local.environment
  enable_key_pair    = true
  enable_private_key = true
  public_key         = ""
}

##--------------------------------------------------------
## ALB security group — allows HTTP :80 from internet
##--------------------------------------------------------
module "sg_alb" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.3"

  name        = "${local.name}-alb"
  environment = local.environment
  vpc_id      = module.vpc.vpc_id

  new_sg_ingress_rules = [{
    key         = "http-public"
    ip_protocol = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_ipv4   = "0.0.0.0/0"
    description = "Allow HTTP from internet."
  }]

  #tfsec:ignore:aws-ec2-no-public-egress-sgr
  new_sg_egress_rules = [{
    key         = "all-outbound"
    ip_protocol = "-1"
    cidr_ipv4   = "0.0.0.0/0"
    description = "Allow all outbound."
  }]
}

##-----------------------------------------------------------------------
## EC2 security group — allows HTTP :80 only from the ALB security group
##-----------------------------------------------------------------------
module "sg_ec2" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.3"

  name        = "${local.name}-ec2"
  environment = local.environment
  vpc_id      = module.vpc.vpc_id

  new_sg_ingress_rules = [{
    key                          = "http-from-alb"
    ip_protocol                  = "tcp"
    from_port                    = 80
    to_port                      = 80
    referenced_security_group_id = module.sg_alb.security_group_id
    description                  = "Allow HTTP from ALB security group."
  }]

  #tfsec:ignore:aws-ec2-no-public-egress-sgr
  new_sg_egress_rules = [{
    key         = "all-outbound"
    ip_protocol = "-1"
    cidr_ipv4   = "0.0.0.0/0"
    description = "Allow all outbound."
  }]
}

##-----------------------------------------------------------------------
## EC2 instance running Apache — user data installs and starts Apache
##-----------------------------------------------------------------------
module "ec2_apache" {
  source = "clouddrove/ec2/aws"
  version = "2.1.1"

  name        = "${local.name}-apache"
  environment = local.environment

  vpc_id                   = module.vpc.vpc_id
  sg_ids                   = [module.sg_ec2.security_group_id]
  instance_count           = 1
  kms_key_enabled          = false
  enable_key_pair          = false
  key_name                 = module.keypair.name
  instance_profile_enabled = true
  iam_instance_profile     = module.iam-role.name
  assign_eip_address       = false
  ebs_volume_enabled       = false
  subnet_ids               = [module.public_subnets.public_subnet_id[0]]

  instance_configuration = {
    ami_id = "ami-0b6d9d3d33ba97d99"
    ami = {
      type         = "ubuntu"
      architecture = "x86"
      version      = "22.04"
      region       = "us-east-1"
    }
    instance_type               = "t3.micro"
    associate_public_ip_address = true
    root_block_device = [{
      volume_type           = "gp3"
      volume_size           = 15
      delete_on_termination = true
    }]
    user_data = file("apache.sh")
  }
}

##-----------------------------------------------------------------------
## EC2 instance running Nginx — user data installs and starts Nginx
##-----------------------------------------------------------------------
module "ec2_nginx" {
  source = "clouddrove/ec2/aws"
  version = "2.1.1"

  name        = "${local.name}-nginx"
  environment = local.environment

  vpc_id                   = module.vpc.vpc_id
  sg_ids                   = [module.sg_ec2.security_group_id]
  instance_count           = 1
  kms_key_enabled          = false
  enable_key_pair          = false
  key_name                 = module.keypair.name
  instance_profile_enabled = true
  iam_instance_profile     = module.iam-role.name
  assign_eip_address       = false
  ebs_volume_enabled       = false
  subnet_ids               = [module.public_subnets.public_subnet_id[1]]

  instance_configuration = {
    ami_id = "ami-0b6d9d3d33ba97d99"
    ami = {
      type         = "ubuntu"
      architecture = "x86"
      version      = "22.04"
      region       = "us-east-1"
    }
    instance_type               = "t3.micro"
    associate_public_ip_address = true
    root_block_device = [{
      volume_type           = "gp3"
      volume_size           = 15
      delete_on_termination = true
    }]
    user_data = file("nginx.sh")
  }
}

##---------------------------------------------------------------------------
## ALB — forwards HTTP :80 to both EC2 instances via a single target group
##---------------------------------------------------------------------------
module "alb" {
  source = "./../../"

  name                       = local.name
  enable                     = true
  internal                   = false
  load_balancer_type         = "application"
  instance_count             = 2
  subnets                    = module.public_subnets.public_subnet_id
  target_id                  = concat(module.ec2_apache.instance_id, module.ec2_nginx.instance_id)
  vpc_id                     = module.vpc.vpc_id
  sg_ids                     = [module.sg_alb.security_group_id]
  allowed_ip                 = ["0.0.0.0/0"]
  allowed_ports              = [80]
  enable_deletion_protection = false
  with_target_group          = true
  https_enabled              = false
  http_enabled               = true
  http_listener_type         = "forward"
  listener_type              = "forward"
  target_group_port          = 80

  target_groups = [{
    name                 = "${local.name}-tg"
    backend_protocol     = "HTTP"
    backend_port         = 80
    target_type          = "instance"
    deregistration_delay = 60
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
  }]
}
