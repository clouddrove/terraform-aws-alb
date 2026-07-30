provider "aws" {
  region = local.region
}

locals {
  name        = "alb-ec2"
  environment = "test"
  region      = "us-east-1"
}

##---------------------------------------------------------------------------------------------------------------------------
## A VPC is a virtual network that closely resembles a traditional network that you'd operate in your own data center.
##--------------------------------------------------------------------------------------------------------------------------
module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "2.0.5"

  name        = local.name
  environment = local.environment
  cidr_block  = "172.16.0.0/16"
}

##-----------------------------------------------------
## A subnet is a range of IP addresses in your VPC.
##-----------------------------------------------------
module "public_subnets" {
  source             = "clouddrove/subnet/aws"
  version            = "2.0.2"
  name               = local.name
  environment        = local.environment
  availability_zones = ["${local.region}b", "${local.region}c"]
  vpc_id             = module.vpc.vpc_id
  cidr_block         = module.vpc.vpc_cidr_block
  type               = "public"
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
## EC2 instance running Apache HTTP server.
##-----------------------------------------------------
module "ec2_apache" {
  source  = "clouddrove/ec2/aws"
  version = "2.1.1"

  name        = "${local.name}-apache"
  environment = local.environment

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block]
  allowed_ports = [80]

  ssh_allowed_ip    = ["0.0.0.0/0"]
  ssh_allowed_ports = [22]

  public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuqN7deBeHSLx1FjNT45UDYV9JbOxV2AXsm6wZwPAQexrdiTosl1ovMYmVtSSWw/ebTlQOB3aeF/54Wy7DmNEvLol//o6F+MW7a/kvvDlyI/eRZc3UnsV4HItId3lwcCrRZ+C99nzwuRQwtAFnQxseQDzLcjbPwXrrBO7iMLdQW40YgIOFW/G/ja122KbDMswzGKO5rFZ/I3cLfz6fUXYqFKUhF90x8LNPSLSiNGwyPB0DlOBTyG6v7b3VHGHR4dv/d3fs5NW4tWJnQc3xbJgV4TOghXxHKsuLXCjgZiSFihMv24m1h6+gGMV0QtHM9yHTuUVfFnEZAbntoDfA50L0VwP2sqEvYgP1p5ZmgIJqnwcB8oWEhg0l1dOIYU1weXuUThYRN2KwXbt+vDU3i7zBuTf5Y6WviQ0xgdFmjMP6OwstV458rEHiUIhREHgiebQuLC/KPCmXyfNGmNKIUJMIaE8fNHmre82rLFrpxxMyUIHEWv8cLmw/jaskNsOxqHWgNO0YpqqhYRghzcnaaqyNrEyhA+/V7XRT8AAAwrDVGdxerfgetg5ttmh2KC/FaDc7WxsvxPIuVWxBpWdjZOzRWsb6G0gRHq4gerdgngrfgberwgjse4567ygbf+i/XSXwAjfTiKpMXlA2ZJC/JqHMw3ijvqPL4gfQJI0vaN4CL3cCLT0RtJC9M5hKw=="
  instance_count  = 1
  kms_key_enabled = false
  enable_key_pair = false

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
    root_block_device = [
      {
        volume_type           = "gp3"
        volume_size           = 15
        delete_on_termination = true
      }
    ]
    user_data = file("apache.sh")
  }

  subnet_ids               = [module.public_subnets.public_subnet_id[0]]
  iam_instance_profile     = module.iam-role.name
  assign_eip_address       = false
  instance_profile_enabled = true
  ebs_volume_enabled       = false
}


##-----------------------------------------------------
## EC2 instance running Nginx web server.
##-----------------------------------------------------
module "ec2_nginx" {
  source  = "clouddrove/ec2/aws"
  version = "2.1.1"

  name        = "${local.name}-nginx"
  environment = local.environment

  vpc_id        = module.vpc.vpc_id
  allowed_ip    = [module.vpc.vpc_cidr_block]
  allowed_ports = [80]

  ssh_allowed_ip    = ["0.0.0.0/0"]
  ssh_allowed_ports = [22]

  public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuqN7deBeHSLx1FjNT45UDYV9JbOxV2AXsm6wZwPAQexrdiTosl1ovMYmVtSSWw/ebTlQOB3aeF/54Wy7DmNEvLol//o6F+MW7a/kvvDlyI/eRZc3UnsV4HItId3lwcCrRZ+C99nzwuRQwtAFnQxseQDzLcjbPwXrrBO7iMLdQW40YgIOFW/G/ja122KbDMswzGKO5rFZ/I3cLfz6fUXYqFKUhF90x8LNPSLSiNGwyPB0DlOBTyG6v7b3VHGHR4dv/d3fs5NW4tWJnQc3xbJgV4TOghXxHKsuLXCjgZiSFihMv24m1h6+gGMV0QtHM9yHTuUVfFnEZAbntoDfA50L0VwP2sqEvYgP1p5ZmgIJqnwcB8oWEhg0l1dOIYU1weXuUThYRN2KwXbt+vDU3i7zBuTf5Y6WviQ0xgdFmjMP6OwstV458rEHiUIhREHgiebQuLC/KPCmXyfNGmNKIUJMIaE8fNHmre82rLFrpxxMyUIHEWv8cLmw/jaskNsOxqHWgNO0YpqqhYRghzcnaaqyNrEyhA+/V7XRT8AAAwrDVGdxerfgetg5ttmh2KC/FaDc7WxsvxPIuVWxBpWdjZOzRWsb6G0gRHq4gerdgngrfgberwgjse4567ygbf+i/XSXwAjfTiKpMXlA2ZJC/JqHMw3ijvqPL4gfQJI0vaN4CL3cCLT0RtJC9M5hKw=="
  instance_count  = 1
  kms_key_enabled = false
  enable_key_pair = false

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
    root_block_device = [
      {
        volume_type           = "gp3"
        volume_size           = 15
        delete_on_termination = true
      }
    ]
    user_data = file("nginx.sh")
  }

  subnet_ids               = [module.public_subnets.public_subnet_id[1]]
  iam_instance_profile     = module.iam-role.name
  assign_eip_address       = false
  instance_profile_enabled = true
  ebs_volume_enabled       = false
}


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
  allowed_ip                 = ["0.0.0.0/0"]
  allowed_ports              = [80]
  enable_deletion_protection = false
  with_target_group          = true
  https_enabled              = false
  http_enabled               = true
  http_listener_type         = "forward"
  listener_type              = "forward"
  target_group_port          = 80

  target_groups = [
    {
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
    },
  ]
}
