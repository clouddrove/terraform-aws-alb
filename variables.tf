#Module      : LABEL
#Description : Terraform label module variables
variable "name" {
  type        = string
  default     = ""
  description = "Name  (e.g. `app` or `cluster`)."
}

variable "application" {
  type        = string
  default     = ""
  description = "Application (e.g. `cd` or `clouddrove`)."
}

variable "environment" {
  type        = string
  default     = ""
  description = "Environment (e.g. `prod`, `dev`, `staging`)."
}

variable "label_order" {
  type        = list
  default     = []
  description = "Label order, e.g. `name`,`application`."
}

variable "attributes" {
  type        = list
  default     = []
  description = "Additional attributes (e.g. `1`)."
}

variable "delimiter" {
  type        = string
  default     = "-"
  description = "Delimiter to be used between `organization`, `environment`, `name` and `attributes`."
}

variable "tags" {
  type        = map
  default     = {}
  description = "Additional tags (e.g. map(`BusinessUnit`,`XYZ`)."
}

variable "managedby" {
  type        = string
  default     = "anmol@clouddrove.com"
  description = "ManagedBy, eg 'CloudDrove' or 'AnmolNagpal'."
}

# Module      : ALB
# Description : Terraform ALB module variables.
variable "alb_name" {
  type        = string
  default     = ""
  description = "The name of the LB. This name must be unique within your AWS account, can have a maximum of 32 characters, must contain only alphanumeric characters or hyphens, and must not begin or end with a hyphen. If not specified, Terraform will autogenerate a name beginning with tf-lb."
}

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

variable "security_groups" {
  type        = list
  default     = []
  description = "A list of security group IDs to assign to the LB. Only valid for Load Balancers of type application."
}

variable "subnets" {
  type        = list
  default     = []
  description = "A list of subnet IDs to attach to the LB. Subnets cannot be updated for Load Balancers of type network. Changing this value will for load balancers of type network will force a recreation of the resource."
}

variable "enable_deletion_protection" {
  type        = string
  default     = ""
  description = "If true, deletion of the load balancer will be disabled via the AWS API. This will prevent Terraform from deleting the load balancer. Defaults to false."
}

variable "subnet_id" {
  type        = string
  default     = ""
  description = "The id of the subnet of which to attach to the load balancer. You can specify only one subnet per Availability Zone."
}

variable "allocation_id" {
  type        = string
  default     = ""
  description = "The allocation ID of the Elastic IP address."
}

variable "alb_environment" {
  type        = string
  default     = ""
  description = "A mapping of tags to assign to the resource."
}

variable "https_port" {
  type        = number
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
  description = "The type of routing action. Valid values are forward, redirect, fixed-response, authenticate-cognito and authenticate-oidc."
}

variable "listener_ssl_policy" {
  type        = string
  default     = "ELBSecurityPolicy-2016-08"
  description = "The security policy if using HTTPS externally on the load balancer. [See](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-security-policy-table.html)."
}

variable "listener_certificate_arn" {
  type        = string
  default     = ""
  description = "The ARN of the SSL server certificate. Exactly one certificate is required if the protocol is HTTPS."
}

variable "target_group_port" {
  type        = string
  default     = ""
  description = "The port on which targets receive traffic, unless overridden when registering a specific target."
}

variable "target_group_protocol" {
  type        = string
  default     = ""
  description = "The protocol to use for routing traffic to the targets."
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "The identifier of the VPC in which to create the target group."
}

variable "target_id" {
  type        = list
  description = "The ID of the target. This is the Instance ID for an instance, or the container ID for an ECS container. If the target type is ip, specify an IP address."
}

variable "idle_timeout" {
  type        = number
  default     = 60
  description = "The time in seconds that the connection is allowed to be idle."
}

variable "enable_cross_zone_load_balancing" {
  type        = bool
  default     = false
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

variable "log_bucket_name" {
  type        = string
  default     = ""
  description = "S3 bucket (externally created) for storing load balancer access logs. Required if logging_enabled is true."
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

variable "access_logs" {
  type        = bool
  default     = false
  description = "Access logs Enable or Disable."
}

variable "target_type" {
  type        = string
  default     = "instance"
  description = "The type of target that you must specify when registering targets with this target group. The possible values are instance (targets are specified by instance ID) or ip (targets are specified by IP address) or lambda (targets are specified by lambda arn). The default is instance."
}

variable "deregistration_delay" {
  type        = number
  default     = 300
  description = "The amount time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused. The range is 0-3600 seconds. The default value is 300 seconds."
}

variable "health_check_path" {
  type        = string
  default     = "/"
  description = "The destination for the health check request."
}

variable "health_check_timeout" {
  type        = number
  default     = 10
  description = "The amount of time to wait in seconds before failing a health check request."
}

variable "health_check_healthy_threshold" {
  type        = number
  default     = 2
  description = "The number of consecutive health checks successes required before considering an unhealthy target healthy."
}

variable "health_check_unhealthy_threshold" {
  type        = number
  default     = 2
  description = "The number of consecutive health check failures required before considering the target unhealthy."
}

variable "health_check_interval" {
  type        = number
  default     = 15
  description = "The duration in seconds in between health checks."
}

variable "health_check_matcher" {
  type        = string
  default     = "200-399"
  description = "The HTTP response codes to indicate a healthy check."
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
  default     = true
  description = "If true, create alb."
}