provider "aws" {
  region = local.region
}

locals {
  name        = "alb-asg"
  environment = "test"
  region      = "us-east-1"
}

##---------------------------------------------------------------------------------------------------------------------------
## A VPC is a virtual network that closely resembles a traditional network that you'd operate in your own data center.
##---------------------------------------------------------------------------------------------------------------------------
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

##-----------------------------------------------------
## IAM role for EC2 instances.
## Uses the AWS-managed AmazonSSMManagedInstanceCore policy
## so Session Manager access works without a custom inline policy.
##-----------------------------------------------------
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

resource "aws_iam_instance_profile" "asg" {
  name = "${local.name}-${local.environment}-asg-profile"
  role = module.iam-role.name
}

##-----------------------------------------------------
## Security group for ASG instances.
## Allows HTTP only from the ALB security group.
## Public egress is required for apt package installation
## and SSM endpoint communication (instances use public IPs,
## no NAT Gateway needed).
##-----------------------------------------------------
resource "aws_security_group" "asg" {
  name        = "${local.name}-${local.environment}-asg-sg"
  description = "Allow HTTP from ALB and all egress."
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name        = "${local.name}-${local.environment}-asg-sg"
    Environment = local.environment
  }
}

resource "aws_security_group_rule" "asg_http_from_alb" {
  description              = "Allow HTTP from ALB security group."
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.alb.security_group_id
  security_group_id        = aws_security_group.asg.id
}

resource "aws_security_group_rule" "asg_egress" {
  description       = "Allow all egress."
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.asg.id
}

##-----------------------------------------------------
## Fetch the latest Ubuntu 22.04 LTS AMI (x86_64).
## the SSM Agent pre-installed on official Canonical AMIs.
##-----------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

##-----------------------------------------------------
## Launch template for ASG instances.
## - Ubuntu 22.04 LTS, t3.micro
## - Nginx installed via user data using apt
## - Serves instance ID so ALB load balancing is easy to verify
## - Session Manager used for access; no SSH key pair required
## - Instances get public IPs (public subnets, no NAT Gateway)
##-----------------------------------------------------
resource "aws_launch_template" "asg" {
  name_prefix   = "${local.name}-${local.environment}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.asg.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.asg.id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 15
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    HOSTNAME=$(hostname)
    cat > /var/www/html/index.html <<HTML
    <h1>Hello from EC2 instance: $INSTANCE_ID</h1>
    <p>Hostname: $HOSTNAME</p>
    HTML
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${local.name}-${local.environment}-asg-instance"
      Environment = local.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

##-----------------------------------------------------
## Auto Scaling Group.
## Registers instances with the ALB target group via
## target_group_arns — no manual aws_lb_target_group_attachment.
##-----------------------------------------------------
resource "aws_autoscaling_group" "asg" {
  name                = "${local.name}-${local.environment}-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = module.public_subnets.public_subnet_id

  target_group_arns = [module.alb.main_target_group_arn]

  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.asg.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-${local.environment}-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = local.environment
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

##-----------------------------------------------------------------------------
## ALB module.
##
## target_id is required by the module but the ASG handles its own registration
## via target_group_arns above. Passing an empty list disables the module's
## aws_lb_target_group_attachment resource (count = length(target_id) = 0).
##-----------------------------------------------------------------------------
module "alb" {
  source = "./../../"

  name                       = local.name
  enable                     = true
  internal                   = false
  load_balancer_type         = "application"
  instance_count             = 0
  target_id                  = []
  subnets                    = module.public_subnets.public_subnet_id
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
