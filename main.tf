##-----------------------------------------------------------------------------
## Labels module callled that will be used for naming and tags.
##-----------------------------------------------------------------------------
module "labels" {
  source      = "clouddrove/labels/aws"
  version     = "1.3.0"
  name        = var.name
  repository  = var.repository
  environment = var.environment
  managedby   = var.managedby
  label_order = var.label_order
}

##------------------------------------------------------------------------------
## Below resources will create SECURITY-GROUP and its components.
##------------------------------------------------------------------------------
resource "aws_security_group" "default" {
  count = var.enable_security_group && length(var.sg_ids) < 1 ? 1 : 0

  name        = format("%s-sg", module.labels.id)
  vpc_id      = var.vpc_id
  description = var.sg_description
  tags        = module.labels.tags
  lifecycle {
    create_before_destroy = true
  }
}

##------------------------------------------------------------------------------
## Below resources will create SECURITY-GROUP-RULE and its components.
##------------------------------------------------------------------------------
#tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group_rule" "egress" {
  count = (var.enable_security_group == true && length(var.sg_ids) < 1 && var.is_external == false && var.egress_rule == true) ? 1 : 0

  description       = var.sg_egress_description
  type              = "egress"
  from_port         = var.from_port
  to_port           = var.to_port
  protocol          = var.egress_protocol
  cidr_blocks       = var.cidr_blocks
  security_group_id = join("", aws_security_group.default[*].id)
}
#tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group_rule" "egress_ipv6" {
  count = (var.enable_security_group == true && length(var.sg_ids) < 1 && var.is_external == false) && var.egress_rule == true ? 1 : 0

  description       = var.sg_egress_ipv6_description
  type              = "egress"
  from_port         = var.from_port
  to_port           = var.to_port
  protocol          = var.egress_protocol
  ipv6_cidr_blocks  = var.ipv6_cidr_blocks
  security_group_id = join("", aws_security_group.default[*].id)
}

resource "aws_security_group_rule" "ingress" {
  count = length(var.allowed_ip) > 0 == true && length(var.sg_ids) < 1 ? length(compact(var.allowed_ports)) : 0

  description       = var.sg_ingress_description
  type              = "ingress"
  from_port         = element(var.allowed_ports, count.index)
  to_port           = element(var.allowed_ports, count.index)
  protocol          = var.protocol
  cidr_blocks       = var.allowed_ip
  security_group_id = join("", aws_security_group.default[*].id)
}

##-----------------------------------------------------------------------------
## A load balancer serves as the single point of contact for clients. The load balancer distributes incoming application traffic across multiple targets.
##-----------------------------------------------------------------------------
resource "aws_lb" "main" {
  count                                       = var.enable ? 1 : 0
  name                                        = module.labels.id
  internal                                    = var.internal
  load_balancer_type                          = var.load_balancer_type
  security_groups                             = length(var.sg_ids) < 1 ? aws_security_group.default[*].id : var.sg_ids
  subnets                                     = var.subnets
  enable_deletion_protection                  = var.enable_deletion_protection
  idle_timeout                                = var.idle_timeout
  enable_cross_zone_load_balancing            = var.enable_cross_zone_load_balancing
  enable_http2                                = var.enable_http2
  enable_tls_version_and_cipher_suite_headers = var.enable_tls_version_and_cipher_suite_headers
  enable_xff_client_port                      = var.enable_xff_client_port
  preserve_host_header                        = var.preserve_host_header
  enable_waf_fail_open                        = var.enable_waf_fail_open
  desync_mitigation_mode                      = var.desync_mitigation_mode
  xff_header_processing_mode                  = var.xff_header_processing_mode
  ip_address_type                             = var.ip_address_type
  tags                                        = module.labels.tags
  drop_invalid_header_fields                  = true

  timeouts {
    create = var.load_balancer_create_timeout
    delete = var.load_balancer_delete_timeout
    update = var.load_balancer_update_timeout
  }

  dynamic "access_logs" {
    for_each = length(var.access_logs) > 0 ? [var.access_logs] : []

    content {
      enabled = try(access_logs.value.enabled, try(access_logs.value.bucket, null) != null)
      bucket  = try(access_logs.value.bucket, null)
      prefix  = try(access_logs.value.prefix, null)
    }
  }

  dynamic "subnet_mapping" {
    for_each = var.subnet_mapping

    content {
      subnet_id            = subnet_mapping.value.subnet_id
      allocation_id        = lookup(subnet_mapping.value, "allocation_id", null)
      private_ipv4_address = lookup(subnet_mapping.value, "private_ipv4_address", null)
      ipv6_address         = lookup(subnet_mapping.value, "ipv6_address", null)
    }
  }
}

##-----------------------------------------------------------------------------
## A listener is a process that checks for connection requests.
## It is configured with a protocol and a port for front-end (client to load balancer) connections, and a protocol and a port for back-end (load balancer to back-end instance) connections.
##-----------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  count = var.enable == true && var.with_target_group && var.https_enabled == true && var.load_balancer_type == "application" ? 1 : 0

  load_balancer_arn = element(aws_lb.main[*].arn, count.index)
  port              = var.https_port
  protocol          = var.listener_protocol
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.listener_certificate_arn
  default_action {
    target_group_arn = join("", aws_lb_target_group.main[*].arn)
    type             = var.listener_type

    dynamic "redirect" {
      for_each = var.listener_https_fixed_response != null ? [var.listener_https_fixed_response] : []

      content {
        path        = lookup(redirect.value, "path", null)
        host        = lookup(redirect.value, "host", null)
        port        = lookup(redirect.value, "port", null)
        protocol    = lookup(redirect.value, "protocol", null)
        query       = lookup(redirect.value, "query", null)
        status_code = redirect.value["status_code"]
      }
    }

    dynamic "forward" {
      for_each = var.listener_https_fixed_response != null ? [var.listener_https_fixed_response] : []

      content {
        dynamic "target_group" {
          for_each = forward.value["target_groups"]

          content {
            arn    = aws_lb_target_group.main[target_group.value["target_group_index"]].id
            weight = lookup(target_group.value, "weight", null)
          }
        }
      }
    }
    dynamic "fixed_response" {
      for_each = var.listener_https_fixed_response != null ? [var.listener_https_fixed_response] : []

      content {
        content_type = fixed_response.value["content_type"]
        message_body = fixed_response.value["message_body"]
        status_code  = fixed_response.value["status_code"]
      }
    }
  }
}

##-----------------------------------------------------------------------------
## A listener is a process that checks for connection requests.
## It is configured with a protocol and a port for front-end (client to load balancer) connections, and a protocol and a port for back-end (load balancer to back-end instance) connections.
##-----------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  count = var.enable == true && var.with_target_group && var.http_enabled == true && var.load_balancer_type == "application" ? 1 : 0

  load_balancer_arn = element(aws_lb.main[*].arn, count.index)
  port              = var.http_port
  protocol          = "HTTP"
  default_action {
    target_group_arn = element(aws_lb_target_group.main[*].arn, count.index)
    type             = var.http_listener_type
    redirect {
      port        = var.https_port
      protocol    = var.listener_protocol
      status_code = var.status_code
    }
  }
}

##-----------------------------------------------------------------------------
## A listener is a process that checks for connection requests.
## It is configured with a protocol and a port for front-end (client to load balancer) connections, and a protocol and a port for back-end (load balancer to back-end instance) connections.
##-----------------------------------------------------------------------------
resource "aws_lb_listener" "nhttps" {
  count = var.enable == true && var.with_target_group && var.https_enabled == true && var.load_balancer_type == "network" ? length(var.https_listeners) : 0

  load_balancer_arn = element(aws_lb.main[*].arn, count.index)
  port              = var.https_listeners[count.index]["port"]
  protocol          = lookup(var.https_listeners[count.index], "protocol", "HTTPS")
  certificate_arn   = var.https_listeners[count.index]["certificate_arn"]
  ssl_policy        = var.ssl_policy
  default_action {
    target_group_arn = aws_lb_target_group.main[lookup(var.https_listeners[count.index], "target_group_index", count.index)].id
    type             = "forward"
  }
}

##-----------------------------------------------------------------------------
## A listener is a process that checks for connection requests.
## It is configured with a protocol and a port for front-end (client to load balancer) connections, and a protocol and a port for back-end (load balancer to back-end instance) connections.
##-----------------------------------------------------------------------------
resource "aws_lb_listener" "nhttp" {
  count = var.enable == true && var.with_target_group && var.load_balancer_type == "network" ? length(var.http_tcp_listeners) : 0

  load_balancer_arn = element(aws_lb.main[*].arn, 0)
  port              = var.http_tcp_listeners[count.index]["port"]
  protocol          = var.http_tcp_listeners[count.index]["protocol"]
  default_action {
    target_group_arn = aws_lb_target_group.main[lookup(var.http_tcp_listeners[count.index], "target_group_index", count.index)].id
    type             = "forward"
  }
}

##-----------------------------------------------------------------------------
## aws_lb_target_group. Provides a Target Group resource for use with Load Balancer resources.
##-----------------------------------------------------------------------------
resource "aws_lb_target_group" "main" {
  count                              = var.enable && var.with_target_group ? length(var.target_groups) : 0
  name                               = format("%s-%s", module.labels.id, count.index)
  port                               = lookup(var.target_groups[count.index], "backend_port", null)
  protocol                           = lookup(var.target_groups[count.index], "backend_protocol", null) != null ? upper(lookup(var.target_groups[count.index], "backend_protocol")) : null
  vpc_id                             = var.vpc_id
  target_type                        = lookup(var.target_groups[count.index], "target_type", null)
  deregistration_delay               = lookup(var.target_groups[count.index], "deregistration_delay", null)
  slow_start                         = lookup(var.target_groups[count.index], "slow_start", null)
  proxy_protocol_v2                  = lookup(var.target_groups[count.index], "proxy_protocol_v2", null)
  lambda_multi_value_headers_enabled = lookup(var.target_groups[count.index], "lambda_multi_value_headers_enabled", null)
  preserve_client_ip                 = lookup(var.target_groups[count.index], "preserve_client_ip", null)
  load_balancing_algorithm_type      = lookup(var.target_groups[count.index], "load_balancing_algorithm_type", null)
  connection_termination             = lookup(var.target_groups[count.index], "connection_termination", null)
  ip_address_type                    = lookup(var.target_groups[count.index], "ip_address_type", null)
  load_balancing_cross_zone_enabled  = lookup(var.target_groups[count.index], "load_balancing_cross_zone_enabled", null)

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

##-----------------------------------------------------------------------------
## For attaching resources with Elastic Load Balancer (ELB), see the aws_elb_attachment resource.
##-----------------------------------------------------------------------------
resource "aws_lb_target_group_attachment" "attachment" {
  #  count = var.enable && var.with_target_group && var.load_balancer_type == "application" && var.target_type == "" ? var.instance_count : 0
  count = var.enable && var.with_target_group && var.load_balancer_type == "application" ? length(var.https_listeners) : 0

  target_group_arn = element(aws_lb_target_group.main[*].arn, count.index)
  target_id        = element(var.target_id, count.index)
  port             = var.target_group_port
}

resource "aws_lb_target_group_attachment" "nattachment" {
  count = var.enable && var.with_target_group && var.load_balancer_type == "network" ? length(var.https_listeners) : 0

  target_group_arn = element(aws_lb_target_group.main[*].arn, count.index)
  target_id        = element(var.target_id, 0)
  port             = lookup(var.target_groups[count.index], "backend_port", null)
}

##-----------------------------------------------------------------------------
## Elastic Load Balancing (ELB) automatically distributes incoming application traffic across multiple targets and virtual appliances in one or more Availability Zones (AZs)
##-----------------------------------------------------------------------------
resource "aws_elb" "main" {
  count = var.clb_enable && var.load_balancer_type == "classic" == true ? 1 : 0

  name                        = module.labels.id
  instances                   = var.target_id
  internal                    = var.internal
  cross_zone_load_balancing   = var.enable_cross_zone_load_balancing
  idle_timeout                = var.idle_timeout
  connection_draining         = var.connection_draining
  connection_draining_timeout = var.connection_draining_timeout
  security_groups             = length(var.sg_ids) < 1 ? aws_security_group.default[*].id : var.sg_ids
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

##-----------------------------------------------------------------------------
## aws_lb_listener_rule. Provides a Load Balancer Listener Rule resource.
##-----------------------------------------------------------------------------
resource "aws_lb_listener_rule" "http_tcp_listener_rule" {
  count = var.enable ? length(var.http_tcp_listener_rules) : 0

  listener_arn = aws_lb_listener.nhttp[lookup(var.http_tcp_listener_rules[count.index], "http_tcp_listener_index", count.index)].arn
  priority     = lookup(var.http_tcp_listener_rules[count.index], "priority", null)

  # redirect actions
  dynamic "action" {
    for_each = [
      for action_rule in var.http_tcp_listener_rules[count.index].actions :
      action_rule
      if action_rule.type == "redirect"
    ]

    content {
      type = action.value["type"]
      redirect {
        host        = lookup(action.value, "host", null)
        path        = lookup(action.value, "path", null)
        port        = lookup(action.value, "port", null)
        protocol    = lookup(action.value, "protocol", null)
        query       = lookup(action.value, "query", null)
        status_code = action.value["status_code"]
      }
    }
  }

  # fixed-response actions
  dynamic "action" {
    for_each = [
      for action_rule in var.http_tcp_listener_rules[count.index].actions :
      action_rule
      if action_rule.type == "fixed-response"
    ]

    content {
      type = action.value["type"]
      fixed_response {
        message_body = lookup(action.value, "message_body", null)
        status_code  = lookup(action.value, "status_code", null)
        content_type = action.value["content_type"]
      }
    }
  }

  # forward actions
  dynamic "action" {
    for_each = [
      for action_rule in var.http_tcp_listener_rules[count.index].actions :
      action_rule
      if action_rule.type == "forward"
    ]

    content {
      type             = action.value["type"]
      target_group_arn = aws_lb_target_group.main[lookup(action.value, "target_group_index", count.index)].id
    }
  }

  # weighted forward actions
  dynamic "action" {
    for_each = [
      for action_rule in var.http_tcp_listener_rules[count.index].actions :
      action_rule
      if action_rule.type == "weighted-forward"
    ]

    content {
      type = "forward"
      forward {
        dynamic "target_group" {
          for_each = action.value["target_groups"]

          content {
            arn    = aws_lb_target_group.main[target_group.value["target_group_index"]].id
            weight = target_group.value["weight"]
          }
        }
        dynamic "stickiness" {
          for_each = [lookup(action.value, "stickiness", {})]

          content {
            enabled  = try(stickiness.value["enabled"], false)
            duration = try(stickiness.value["duration"], 1)
          }
        }
      }
    }
  }

  # Path Pattern condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.http_tcp_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "path_patterns", [])) > 0
    ]

    content {
      path_pattern {
        values = condition.value["path_patterns"]
      }
    }
  }

  # Host header condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.http_tcp_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "host_headers", [])) > 0
    ]

    content {
      host_header {
        values = condition.value["host_headers"]
      }
    }
  }

  # Http header condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.http_tcp_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "http_headers", [])) > 0
    ]

    content {
      dynamic "http_header" {
        for_each = condition.value["http_headers"]

        content {
          http_header_name = http_header.value["http_header_name"]
          values           = http_header.value["values"]
        }
      }
    }
  }

  # Http request method condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.http_tcp_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "http_request_methods", [])) > 0
    ]

    content {
      http_request_method {
        values = condition.value["http_request_methods"]
      }
    }
  }

  # Query string condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.http_tcp_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "query_strings", [])) > 0
    ]

    content {
      dynamic "query_string" {
        for_each = condition.value["query_strings"]

        content {
          key   = lookup(query_string.value, "key", null)
          value = query_string.value["value"]
        }
      }
    }
  }

  # Source IP address condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.http_tcp_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "source_ips", [])) > 0
    ]

    content {
      source_ip {
        values = condition.value["source_ips"]
      }
    }
  }

  tags = module.labels.tags
}

resource "aws_lb_listener_rule" "https_listener_rule" {
  count = var.enable ? length(var.https_listener_rules) : 0

  listener_arn = aws_lb_listener.nhttps[lookup(var.https_listener_rules[count.index], "https_listener_index", count.index)].arn
  priority     = lookup(var.https_listener_rules[count.index], "priority", null)

  # authenticate-cognito actions
  dynamic "action" {
    for_each = [
      for action_rule in var.https_listener_rules[count.index].actions :
      action_rule
      if action_rule.type == "authenticate-cognito"
    ]

    content {
      type = action.value["type"]
      authenticate_cognito {
        authentication_request_extra_params = lookup(action.value, "authentication_request_extra_params", null)
        on_unauthenticated_request          = lookup(action.value, "on_authenticated_request", null)
        scope                               = lookup(action.value, "scope", null)
        session_cookie_name                 = lookup(action.value, "session_cookie_name", null)
        session_timeout                     = lookup(action.value, "session_timeout", null)
        user_pool_arn                       = action.value["user_pool_arn"]
        user_pool_client_id                 = action.value["user_pool_client_id"]
        user_pool_domain                    = action.value["user_pool_domain"]
      }
    }
  }

  # authenticate-oidc actions
  dynamic "action" {
    for_each = [
      for action_rule in var.https_listener_rules[count.index].actions :
      action_rule
      if action_rule.type == "authenticate-oidc"
    ]

    content {
      type = action.value["type"]
      authenticate_oidc {
        # Max 10 extra params
        authentication_request_extra_params = lookup(action.value, "authentication_request_extra_params", null)
        authorization_endpoint              = action.value["authorization_endpoint"]
        client_id                           = action.value["client_id"]
        client_secret                       = action.value["client_secret"]
        issuer                              = action.value["issuer"]
        on_unauthenticated_request          = lookup(action.value, "on_unauthenticated_request", null)
        scope                               = lookup(action.value, "scope", null)
        session_cookie_name                 = lookup(action.value, "session_cookie_name", null)
        session_timeout                     = lookup(action.value, "session_timeout", null)
        token_endpoint                      = action.value["token_endpoint"]
        user_info_endpoint                  = action.value["user_info_endpoint"]
      }
    }
  }

  # redirect actions
  dynamic "action" {
    for_each = [
      for action_rule in var.https_listener_rules[count.index].actions :
      action_rule
      if action_rule.type == "redirect"
    ]

    content {
      type = action.value["type"]
      redirect {
        host        = lookup(action.value, "host", null)
        path        = lookup(action.value, "path", null)
        port        = lookup(action.value, "port", null)
        protocol    = lookup(action.value, "protocol", null)
        query       = lookup(action.value, "query", null)
        status_code = action.value["status_code"]
      }
    }
  }

  # fixed-response actions
  dynamic "action" {
    for_each = [
      for action_rule in var.https_listener_rules[count.index].actions :
      action_rule
      if action_rule.type == "fixed-response"
    ]

    content {
      type = action.value["type"]
      fixed_response {
        message_body = lookup(action.value, "message_body", null)
        status_code  = lookup(action.value, "status_code", null)
        content_type = action.value["content_type"]
      }
    }
  }

  # forward actions
  dynamic "action" {
    for_each = [
      for action_rule in var.https_listener_rules[count.index].actions :
      action_rule
      if action_rule.type == "forward"
    ]

    content {
      type             = action.value["type"]
      target_group_arn = aws_lb_target_group.main[lookup(action.value, "target_group_index", count.index)].id
    }
  }

  # weighted forward actions
  dynamic "action" {
    for_each = [
      for action_rule in var.https_listener_rules[count.index].actions :
      action_rule
      if action_rule.type == "weighted-forward"
    ]

    content {
      type = "forward"
      forward {
        dynamic "target_group" {
          for_each = action.value["target_groups"]

          content {
            arn    = aws_lb_target_group.main[target_group.value["target_group_index"]].id
            weight = target_group.value["weight"]
          }
        }
        dynamic "stickiness" {
          for_each = [lookup(action.value, "stickiness", {})]

          content {
            enabled  = try(stickiness.value["enabled"], false)
            duration = try(stickiness.value["duration"], 1)
          }
        }
      }
    }
  }

  # Path Pattern condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "path_patterns", [])) > 0
    ]

    content {
      path_pattern {
        values = condition.value["path_patterns"]
      }
    }
  }

  # Host header condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "host_headers", [])) > 0
    ]

    content {
      host_header {
        values = condition.value["host_headers"]
      }
    }
  }

  # Http header condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "http_headers", [])) > 0
    ]

    content {
      dynamic "http_header" {
        for_each = condition.value["http_headers"]

        content {
          http_header_name = http_header.value["http_header_name"]
          values           = http_header.value["values"]
        }
      }
    }
  }

  # Http request method condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "http_request_methods", [])) > 0
    ]

    content {
      http_request_method {
        values = condition.value["http_request_methods"]
      }
    }
  }

  # Query string condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "query_strings", [])) > 0
    ]

    content {
      dynamic "query_string" {
        for_each = condition.value["query_strings"]

        content {
          key   = lookup(query_string.value, "key", null)
          value = query_string.value["value"]
        }
      }
    }
  }

  # Source IP address condition
  dynamic "condition" {
    for_each = [
      for condition_rule in var.https_listener_rules[count.index].conditions :
      condition_rule
      if length(lookup(condition_rule, "source_ips", [])) > 0
    ]

    content {
      source_ip {
        values = condition.value["source_ips"]
      }
    }
  }

  tags = module.labels.tags
}

##-----------------------------------------------------------------------------
## Terraform comes with aws_lb_listener_certificate that allows you to attach a certificate to any aws_lb_listerner.
##-----------------------------------------------------------------------------
resource "aws_lb_listener_certificate" "https_listener" {
  count           = var.enable ? length(var.extra_ssl_certs) : 0
  listener_arn    = aws_lb_listener.https[var.extra_ssl_certs[count.index]["https_listener_index"]].arn
  certificate_arn = var.extra_ssl_certs[count.index]["certificate_arn"]
}
