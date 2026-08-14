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
##--------------------------------------------------------------------------------------------------------------------------
module "vpc" {
  source  = "clouddrove/vpc/aws"
  version = "2.0.5"

  name        = local.name
  environment = local.environment
  cidr_block  = "172.16.0.0/16"
}

##-----------------------------------
## Public subnets across two AZs
##-----------------------------------
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
## ALB security group — allows HTTP :80 from internet
##-----------------------------------------------------------------------
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
## ASG security group — allows HTTP :80 only from the ALB security group
##-----------------------------------------------------------------------
module "sg_asg" {
  source  = "clouddrove/security-group/aws"
  version = "2.0.3"

  name        = "${local.name}-asg"
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

##-----------------------------------------------------------------------------
## Latest Ubuntu 22.04 LTS AMI — SSM Agent is pre-installed on Canonical AMIs
##-----------------------------------------------------------------------------
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

##-----------------------------------------------------------------------
## ASG — Launch Template + Auto Scaling Group managed by the module.
## Instances register with the ALB target group via target_group_arns.
## Access instances via Session Manager (no SSH key needed).
##-----------------------------------------------------------------------
module "ec2_autoscaling" {
  source  = "clouddrove/ec2-autoscaling/aws"
  version = "1.3.4"

  name        = local.name
  environment = local.environment

  # Instance
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # IAM — module creates the instance profile; pass the role name here
  iam_instance_profile_name = module.iam-role.name

  # Network — public IPs needed for apt and SSM (no NAT Gateway)
  associate_public_ip_address = true
  security_group_ids          = [module.sg_asg.security_group_id]
  subnet_ids                  = tolist(module.public_subnets.public_subnet_id)

  # Root volume
  volume_size = 15
  volume_type = "gp3"

  # User data — installs Nginx and serves the instance ID for easy ALB verification
  user_data_base64 = base64encode(<<-EOF
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

  # ASG sizing
  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  # ALB integration — ELB health checks, grace period for apt+nginx startup
  target_group_arns         = [module.alb.main_target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120
}

##----------------------------------------------------------------------------------------
## ALB — forwards HTTP :80 to the ASG target group.
## target_id = [] disables static attachments; ASG self-registers via target_group_arns.
##-----------------------------------------------------------------------
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
