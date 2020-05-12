## Managed By : CloudDrove
## Description : This Script is used to create Aws Loadbalancer,Aws Loadbalancer Listeners.
## Copyright @ CloudDrove. All Right Reserved.

#Module      : label
#Description : This terraform module is designed to generate consistent label names and
#              tags for resources. You can use terraform-labels to implement a strict
#              naming convention.
module "labels" {
  source = "git::https://github.com/clouddrove/terraform-labels.git?ref=tags/0.12.0"

  name        = var.name
  application = var.application
  environment = var.environment
  managedby   = var.managedby
  label_order = var.label_order
}

# Module      : APPLICATION LOAD BALANCER
# Description : This terraform module is used to create ALB on AWS.
resource "aws_lb" "main" {
  count                            = var.enable ? 1 : 0
  name                             = module.labels.id
  internal                         = var.internal
  load_balancer_type               = var.load_balancer_type
  security_groups                  = var.security_groups
  subnets                          = var.subnets
  enable_deletion_protection       = var.enable_deletion_protection
  idle_timeout                     = var.idle_timeout
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  enable_http2                     = var.enable_http2
  ip_address_type                  = var.ip_address_type
  tags                             = module.labels.tags

  timeouts {
    create = var.load_balancer_create_timeout
    delete = var.load_balancer_delete_timeout
    update = var.load_balancer_update_timeout
  }
  access_logs {
    enabled = var.access_logs
    bucket  = var.log_bucket_name
    prefix  = module.labels.id
  }
}

# Module      : LOAD BALANCER LISTENER HTTPS
# Description : Provides a Load Balancer Listener resource.
resource "aws_lb_listener" "https" {
  count = var.enable == true && var.https_enabled == true ? 1 : 0

  load_balancer_arn = element(aws_lb.main.*.arn, count.index)
  port              = var.https_port
  protocol          = var.listener_protocol
  ssl_policy        = var.listener_ssl_policy
  certificate_arn   = var.listener_certificate_arn
  default_action {
    target_group_arn = element(aws_lb_target_group.main.*.arn, count.index)
    type             = var.listener_type
  }
}

# Module      : LOAD BALANCER LISTENER HTTP
# Description : Provides a Load Balancer Listener resource.
resource "aws_lb_listener" "http" {
  count = var.enable == true && var.http_enabled == true ? 1 : 0

  load_balancer_arn = element(aws_lb.main.*.arn, count.index)
  port              = var.http_port
  protocol          = "HTTP"
  default_action {
    target_group_arn = element(aws_lb_target_group.main.*.arn, count.index)
    type             = var.http_listener_type
    redirect {
      port        = var.https_port
      protocol    = var.listener_protocol
      status_code = var.status_code
    }
  }
}

# Module      : LOAD BALANCER TARGET GROUP
# Description : Provides a Target Group resource for use with Load Balancer resources.
resource "aws_lb_target_group" "main" {
  count                = var.enable ? 1 : 0
  name                 = module.labels.id
  port                 = var.target_group_port
  protocol             = var.target_group_protocol
  vpc_id               = var.vpc_id
  target_type          = var.target_type
  deregistration_delay = var.deregistration_delay
  health_check {
    path                = var.health_check_path
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
  }
}

# Module      : TARGET GROUP ATTACHMENT
# Description : Provides the ability to register instances and containers with an
#               Application Load Balancer (ALB) or Network Load Balancer (NLB) target group.
resource "aws_lb_target_group_attachment" "attachment" {
  count = var.enable ? var.instance_count : 0

  target_group_arn = element(aws_lb_target_group.main.*.arn, count.index)
  target_id        = element(var.target_id, count.index)
  port             = var.target_group_port
}