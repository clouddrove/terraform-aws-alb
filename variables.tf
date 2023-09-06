#Module      : LABEL
#Description : Terraform label module variables
variable "name" {
  type        = string
  default     = ""
  description = "Name  (e.g. `app` or `cluster`)."
}

variable "repository" {
  type        = string
  default     = "https://github.com/clouddrove/terraform-aws-alb"
  description = "Terraform current module repo"

  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^https://", var.repository))
    error_message = "The module-repo value must be a valid Git repo link."
  }
}


variable "environment" {
  type        = string
  default     = "test"
  description = "Environment (e.g. `prod`, `dev`, `staging`)."
}

variable "label_order" {
  type        = list(any)
  default     = ["name", "environment"]
  description = "Label order, e.g. `name`,`application`."
}

variable "managedby" {
  type        = string
  default     = "hello@clouddrove.com"
  description = "ManagedBy, eg 'CloudDrove'."
}

# Module      : ALB
# Description : Terraform ALB module variables.

variable "instance_count" {
  type        = number
  default     = 0
  description = "The count of instances."
}

variable "internal" {
  type        = string
  default     = ""
  description = "If true, the LB will be internal."
}

variable "load_balancer_type" {
  type        = string
  default     = ""
  description = "The type of load balancer to create. Possible values are application or network. The default value is application."
}


variable "subnet_mapping" {
  default     = []
  type        = list(map(string))
  description = "A list of subnet mapping blocks describing subnets to attach to network load balancer"
}

variable "https_listeners" {
  type        = list(map(string))
  default     = []
  description = "A list of maps describing the HTTPS listeners for this ALB. Required key/values: port, certificate_arn. Optional key/values: ssl_policy (defaults to ELBSecurityPolicy-2016-08), target_group_index (defaults to 0)"
}

variable "http_tcp_listeners" {
  type        = any
  default     = []
  description = "A list of maps describing the HTTP listeners or TCP ports for this ALB. Required key/values: port, protocol. Optional key/values: target_group_index (defaults to http_tcp_listeners[count.index])"
}

variable "target_groups" {
  description = "A list of maps containing key/value pairs that define the target groups to be created. Order of these maps is important and the index of these are to be referenced in listener definitions. Required key/values: name, backend_protocol, backend_port. Optional key/values are in the target_groups_defaults variable."
  type        = any
  default     = []
}

variable "subnets" {
  type        = list(any)
  default     = []
  description = "A list of subnet IDs to attach to the LB. Subnets cannot be updated for Load Balancers of type network. Changing this value will for load balancers of type network will force a recreation of the resource."
}

variable "enable_deletion_protection" {
  type        = bool
  default     = false
  description = "If true, deletion of the load balancer will be disabled via the AWS API. This will prevent Terraform from deleting the load balancer. Defaults to false."
}

variable "https_port" {
  type        = number
  default     = 443
  description = "The port on which the load balancer is listening. like 80 or 443."
}

variable "listener_protocol" {
  type        = string
  default     = "HTTPS"
  description = "The protocol for connections from clients to the load balancer. Valid values are TCP, HTTP and HTTPS. Defaults to HTTP."
}

variable "http_port" {
  type        = number
  default     = 80
  description = "The port on which the load balancer is listening. like 80 or 443."
}

variable "https_enabled" {
  type        = bool
  default     = true
  description = "A boolean flag to enable/disable HTTPS listener."
}

variable "http_enabled" {
  type        = bool
  default     = true
  description = "A boolean flag to enable/disable HTTP listener."
}

variable "listener_type" {
  type        = string
  default     = "forward"
  description = "The type of routing action. Valid values are forward, redirect, fixed-response, authenticate-cognito and authenticate-oidc."
}


variable "listener_certificate_arn" {
  type        = string
  sensitive   = true
  default     = ""
  description = "The ARN of the SSL server certificate. Exactly one certificate is required if the protocol is HTTPS."
}

variable "target_group_port" {
  type        = string
  default     = 80
  description = "The port on which targets receive traffic, unless overridden when registering a specific target."
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "The identifier of the VPC in which to create the target group."
}

variable "target_id" {
  type        = list(any)
  description = "The ID of the target. This is the Instance ID for an instance, or the container ID for an ECS container. If the target type is ip, specify an IP address."
}

variable "idle_timeout" {
  type        = number
  default     = 60
  description = "The time in seconds that the connection is allowed to be idle."
}

variable "enable_cross_zone_load_balancing" {
  type        = bool
  default     = true
  description = "Indicates whether cross zone load balancing should be enabled in application load balancers."
}

variable "enable_http2" {
  type        = bool
  default     = true
  description = "Indicates whether HTTP/2 is enabled in application load balancers."
}

variable "ip_address_type" {
  type        = string
  default     = "ipv4"
  description = "The type of IP addresses used by the subnets for your load balancer. The possible values are ipv4 and dualstack."
}

variable "load_balancer_create_timeout" {
  type        = string
  default     = "10m"
  description = "Timeout value when creating the ALB."
}

variable "load_balancer_delete_timeout" {
  type        = string
  default     = "10m"
  description = "Timeout value when deleting the ALB."
}

variable "load_balancer_update_timeout" {
  type        = string
  default     = "10m"
  description = "Timeout value when updating the ALB."
}


variable "http_listener_type" {
  type        = string
  default     = "redirect"
  description = "The type of routing action. Valid values are forward, redirect, fixed-response, authenticate-cognito and authenticate-oidc."
}

variable "status_code" {
  type        = string
  default     = "HTTP_301"
  description = " The HTTP redirect code. The redirect is either permanent (HTTP_301) or temporary (HTTP_302)."
}

variable "enable" {
  type        = bool
  default     = false
  description = "If true, create alb."
}

variable "clb_enable" {
  type        = bool
  default     = false
  description = "If true, create clb."
}

variable "listeners" {
  default = []
  type = list(object({
    lb_port : number
    lb_protocol : string
    instance_port : number
    instance_protocol : string
    ssl_certificate_id : string
  }))
  description = "A list of listener configurations for the ELB."
}

variable "connection_draining_timeout" {
  type        = number
  default     = 300
  description = "The time after which connection draining is aborted in seconds."
}

variable "connection_draining" {
  type        = bool
  default     = false
  description = "TBoolean to enable connection draining. Default: false."
}

variable "health_check_target" {
  description = "The target to use for health checks."
  type        = string
  default     = "TCP:80"
}

variable "health_check_timeout" {
  type        = number
  default     = 5
  description = "The time after which a health check is considered failed in seconds."
}

variable "health_check_interval" {
  description = "The time between health check attempts in seconds."
  type        = number
  default     = 30
}

variable "health_check_unhealthy_threshold" {
  type        = number
  default     = 2
  description = "The number of failed health checks before an instance is taken out of service."
}

variable "health_check_healthy_threshold" {
  type        = number
  default     = 10
  description = "The number of successful health checks before an instance is put into service."
}

variable "access_logs" {
  type        = map(string)
  default     = {}
  description = "Map containing access logging configuration for load balancer."
}

variable "listener_https_fixed_response" {
  description = "Have the HTTPS listener return a fixed response for the default action."
  type = object({
    content_type = string
    message_body = string
    status_code  = string
  })
  default = null
}

variable "with_target_group" {
  type        = bool
  default     = true
  description = "Create LoadBlancer without target group"
}

variable "enable_security_group" {
  type        = bool
  default     = true
  description = "Enable default Security Group with only Egress traffic allowed."
}

variable "sg_ids" {
  type        = list(any)
  default     = []
  description = "of the security group id."
}

variable "sg_description" {
  type        = string
  default     = "Instance default security group (only egress access is allowed)."
  description = "The security group description."
}

variable "is_external" {
  type        = bool
  default     = false
  description = "enable to udated existing security Group"
}

variable "egress_rule" {
  type        = bool
  default     = true
  description = "Enable to create egress rule"
}

variable "sg_egress_description" {
  type        = string
  default     = "Description of the rule."
  description = "Description of the egress and ingress rule"
}

variable "sg_egress_ipv6_description" {
  type        = string
  default     = "Description of the rule."
  description = "Description of the egress_ipv6 rule"
}

variable "allowed_ip" {
  type        = list(any)
  default     = []
  description = "List of allowed ip."
}

variable "allowed_ports" {
  type        = list(any)
  default     = []
  description = "List of allowed ingress ports"
}

variable "sg_ingress_description" {
  type        = string
  default     = "Description of the ingress rule use elasticache."
  description = "Description of the ingress rule"
}

variable "protocol" {
  type        = string
  default     = "tcp"
  description = "The protocol. If not icmp, tcp, udp, or all use the."
}

variable "enable_tls_version_and_cipher_suite_headers" {
  type        = bool
  default     = false
  description = "Indicates whether the two headers (x-amzn-tls-version and x-amzn-tls-cipher-suite), which contain information about the negotiated TLS version and cipher suite, are added to the client request before sending it to the target."
}

variable "enable_xff_client_port" {
  type        = bool
  default     = true
  description = "Indicates whether the X-Forwarded-For header should preserve the source port that the client used to connect to the load balancer in application load balancers."
}

variable "preserve_host_header" {
  type        = bool
  default     = false
  description = "Indicates whether Host header should be preserve and forward to targets without any change. Defaults to false."
}

variable "enable_waf_fail_open" {
  type        = bool
  default     = false
  description = "Indicates whether to route requests to targets if lb fails to forward the request to AWS WAF"
}

variable "desync_mitigation_mode" {
  type        = string
  default     = "defensive"
  description = "Determines how the load balancer handles requests that might pose a security risk to an application due to HTTP desync."
}

variable "xff_header_processing_mode" {
  type        = string
  default     = "append"
  description = "Determines how the load balancer modifies the X-Forwarded-For header in the HTTP request before sending the request to the target."
}

variable "http_tcp_listener_rules" {
  type        = any
  default     = []
  description = "A list of maps describing the Listener Rules for this ALB. Required key/values: actions, conditions. Optional key/values: priority, http_tcp_listener_index (default to http_tcp_listeners[count.index])"
}

variable "https_listener_rules" {
  type        = any
  default     = []
  description = "A list of maps describing the Listener Rules for this ALB. Required key/values: actions, conditions. Optional key/values: priority, https_listener_index (default to https_listeners[count.index])"
}

variable "ssl_policy" {
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
  description = "Name of the SSL Policy for the listener. Required if protocol is HTTPS or TLS."
}

variable "extra_ssl_certs" {
  description = "A list of maps describing any extra SSL certificates to apply to the HTTPS listeners. Required key/values: certificate_arn, https_listener_index (the index of the listener within https_listeners which the cert applies toward)."
  type        = list(map(string))
  default     = []
}

variable "from_port" {
  type        = number
  default     = 0
  description = " (Required) Start port (or ICMP type number if protocol is icmp or icmpv6)."
}

variable "to_port" {
  type        = number
  default     = 65535
  description = "equal to 0. The supported values are defined in the IpProtocol argument on the IpPermission API reference"
}

variable "egress_protocol" {
  type        = number
  default     = -1
  description = "equal to 0. The supported values are defined in the IpProtocol argument on the IpPermission API reference"
}

variable "cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "equal to 0. The supported values are defined in the IpProtocol argument on the IpPermission API reference"
}

variable "ipv6_cidr_blocks" {
  type        = list(string)
  default     = ["::/0"]
  description = "Enable to create egress rule"
}
