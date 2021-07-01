## Managed By : CloudDrove
## Description : This Script is used to create Aws Loadbalancer,Aws Loadbalancer Listeners.
## Copyright @ CloudDrove. All Right Reserved.

#Module      : label
#Description : This terraform module is designed to generate consistent label names and
#              tags for resources. You can use terraform-labels to implement a strict
#              naming convention.
module "labels" {
  source  = "clouddrove/labels/aws"
  version = "0.15.0"

  name        = var.name
  repository  = var.repository
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
  drop_invalid_header_fields       = true

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
  dynamic "subnet_mapping" {
    for_each = var.subnet_mapping

    content {
      subnet_id     = subnet_mapping.value.subnet_id
      allocation_id = lookup(subnet_mapping.value, "allocation_id", null)
    }
  }
}

# Module      : LOAD BALANCER LISTENER HTTPS
# Description : Provides a Load Balancer Listener resource.
resource "aws_lb_listener" "https" {
  count = var.enable == true && var.https_enabled == true && var.load_balancer_type == "application" ? 1 : 0

  load_balancer_arn = element(aws_lb.main.*.arn, count.index)
  port              = var.https_port
  protocol          = var.listener_protocol
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.listener_certificate_arn
  default_action {
    target_group_arn = element(aws_lb_target_group.main.*.arn, count.index)
    type             = var.listener_type
  }
}

# Module      : LOAD BALANCER LISTENER HTTP
# Description : Provides a Load Balancer Listener resource.
resource "aws_lb_listener" "http" {
  count = var.enable == true && var.http_enabled == true && var.load_balancer_type == "application" ? 1 : 0

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

# Module      : LOAD BALANCER LISTENER HTTPS
# Description : Provides a Load Balancer Listener resource.
resource "aws_lb_listener" "nhttps" {
  count = var.enable == true && var.https_enabled == true && var.load_balancer_type == "network" ? length(var.https_listeners) : 0

  load_balancer_arn = element(aws_lb.main.*.arn, count.index)
  port              = var.https_listeners[count.index]["port"]
  protocol          = lookup(var.https_listeners[count.index], "protocol", "HTTPS")
  certificate_arn   = var.https_listeners[count.index]["certificate_arn"]
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  default_action {
    target_group_arn = aws_lb_target_group.main[lookup(var.https_listeners[count.index], "target_group_index", count.index)].id
    type             = "forward"
  }
}

# Module      : LOAD BALANCER LISTENER HTTP
# Description : Provides a Load Balancer Listener resource.
resource "aws_lb_listener" "nhttp" {
  count = var.enable == true && var.load_balancer_type == "network" ? length(var.http_tcp_listeners) : 0

  load_balancer_arn = element(aws_lb.main.*.arn, 0)
  port              = var.http_tcp_listeners[count.index]["port"]
  protocol          = var.http_tcp_listeners[count.index]["protocol"]
  default_action {
    target_group_arn = aws_lb_target_group.main[lookup(var.http_tcp_listeners[count.index], "target_group_index", count.index)].id
    type             = "forward"
  }
}

# Module      : LOAD BALANCER TARGET GROUP
# Description : Provides a Target Group resource for use with Load Balancer resources.
resource "aws_lb_target_group" "main" {
  count                              = var.enable ? length(var.target_groups) : 0
  name                               = format("%s-%s", module.labels.id, count.index)
  port                               = lookup(var.target_groups[count.index], "backend_port", null)
  protocol                           = lookup(var.target_groups[count.index], "backend_protocol", null) != null ? upper(lookup(var.target_groups[count.index], "backend_protocol")) : null
  vpc_id                             = var.vpc_id
  target_type                        = lookup(var.target_groups[count.index], "target_type", null)
  deregistration_delay               = lookup(var.target_groups[count.index], "deregistration_delay", null)
  slow_start                         = lookup(var.target_groups[count.index], "slow_start", null)
  proxy_protocol_v2                  = lookup(var.target_groups[count.index], "proxy_protocol_v2", null)
  lambda_multi_value_headers_enabled = lookup(var.target_groups[count.index], "lambda_multi_value_headers_enabled", null)
  dynamic "health_check" {
    for_each = length(keys(lookup(var.target_groups[count.index], "health_check", {}))) == 0 ? [] : [lookup(var.target_groups[count.index], "health_check", {})]

    content {
      enabled             = lookup(health_check.value, "enabled", null)
      interval            = lookup(health_check.value, "interval", null)
      path                = lookup(health_check.value, "path", null)
      port                = lookup(health_check.value, "port", null)
      healthy_threshold   = lookup(health_check.value, "healthy_threshold", null)
      unhealthy_threshold = lookup(health_check.value, "unhealthy_threshold", null)
      timeout             = lookup(health_check.value, "timeout", null)
      protocol            = lookup(health_check.value, "protocol", null)
      matcher             = lookup(health_check.value, "matcher", null)
    }
  }

  dynamic "stickiness" {
    for_each = length(keys(lookup(var.target_groups[count.index], "stickiness", {}))) == 0 ? [] : [lookup(var.target_groups[count.index], "stickiness", {})]

    content {
      enabled         = lookup(stickiness.value, "enabled", null)
      cookie_duration = lookup(stickiness.value, "cookie_duration", null)
      type            = lookup(stickiness.value, "type", null)
    }
  }
}

# Module      : TARGET GROUP ATTACHMENT
# Description : Provides the ability to register instances and containers with an
#               Application Load Balancer (ALB) or Network Load Balancer (NLB) target group.
resource "aws_lb_target_group_attachment" "attachment" {
  count = var.enable && var.load_balancer_type == "application" && var.target_type == "" ? var.instance_count : 0

  target_group_arn = element(aws_lb_target_group.main.*.arn, count.index)
  target_id        = element(var.target_id, count.index)
  port             = var.target_group_port
}

resource "aws_lb_target_group_attachment" "nattachment" {
  count = var.enable && var.load_balancer_type == "network" ? length(var.https_listeners) : 0

  target_group_arn = element(aws_lb_target_group.main.*.arn, count.index)
  target_id        = element(var.target_id, 0)
  port             = lookup(var.target_groups[count.index], "backend_port", null)
}


# Module      : Classic LOAD BALANCER
# Description : This terraform module is used to create classic Load Balancer on AWS.
resource "aws_elb" "main" {
  count = var.clb_enable && var.load_balancer_type == "classic" == true ? 1 : 0

  name                        = module.labels.id
  instances                   = var.target_id
  internal                    = var.internal
  cross_zone_load_balancing   = var.enable_cross_zone_load_balancing
  idle_timeout                = var.idle_timeout
  connection_draining         = var.connection_draining
  connection_draining_timeout = var.connection_draining_timeout
  security_groups             = var.security_groups
  subnets                     = var.subnets

  dynamic "listener" {
    for_each = var.listeners
    content {
      instance_port      = listener.value.instance_port
      instance_protocol  = listener.value.instance_protocol
      lb_port            = listener.value.lb_port
      lb_protocol        = listener.value.lb_protocol
      ssl_certificate_id = listener.value.ssl_certificate_id
    }
  }

  health_check {
    target              = var.health_check_target
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    unhealthy_threshold = var.health_check_unhealthy_threshold
    healthy_threshold   = var.health_check_healthy_threshold
  }

  tags = module.labels.tags
}
