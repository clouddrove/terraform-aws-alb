provider "aws" {
  region = "us-east-1"
}

locals {
  name        = "alb"
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
  availability_zones = ["us-east-1b", "us-east-1c"]
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
##----------------------------------------------------------------------------------
## Terraform module to create instance module on AWS.
##----------------------------------------------------------------------------------
module "ec2" {
  source      = "clouddrove/ec2/aws"
  version     = "2.0.3"
  name        = "local.name"
  environment = "local.environment"

  ##----------------------------------------------------------------------------------
  ## Below A security group controls the traffic that is allowed to reach and leave the resources that it is associated with.
  ##----------------------------------------------------------------------------------
  #tfsec:aws-ec2-no-public-ingress-sgr
  vpc_id            = module.vpc.vpc_id
  ssh_allowed_ip    = ["0.0.0.0/0"]
  ssh_allowed_ports = [22]

  #instance
  instance_count = 1
  instance_configuration = {
    ami           = "ami-084a7d336e816906b"
    instance_type = "t2.nano"

    #Root Volume
    root_block_device = [
      {
        volume_type           = "gp2"
        volume_size           = 30
        delete_on_termination = true
      }
    ]
  }

  #Networking
  subnet_ids = tolist(module.public_subnets.public_subnet_id)

  #Keypair
  public_key = "ssh-rsa xxxxxxxxxx"
  #IAM
  iam_instance_profile = module.iam-role.name


  #Tags
  instance_tags = { "snapshot" = true }

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
  allowed_ports              = [3306]
  listener_certificate_arn   = module.acm.arn
  enable_deletion_protection = false
  with_target_group          = true
  https_enabled              = true
  http_enabled               = true
  https_port                 = 443
  listener_type              = "forward"
  target_group_port          = 80

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 0
    },
    {
      port               = 81
      protocol           = "TCP"
      target_group_index = 0
    },
  ]
  https_listeners = [
    {
      port               = 443
      protocol           = "TLS"
      target_group_index = 0
      certificate_arn    = module.acm.arn
    },
    {
      port               = 84
      protocol           = "TLS"
      target_group_index = 0
      certificate_arn    = module.acm.arn
    },
  ]

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

  extra_ssl_certs = [
    {
      https_listener_index = 0
      certificate_arn      = module.acm.arn
    }
  ]
}
