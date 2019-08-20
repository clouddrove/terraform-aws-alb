#####
#####  ALB
variable "application" {
  type        = "string"
  description = "Application (e.g. `cp` or `clouddrove`)"
}
variable "environment" {
  type        = "string"
  description = "Environment (e.g. `prod`, `dev`, `staging`)"
}

variable "name" {
  description = "Name  (e.g. `app` or `cluster`)"
  type        = "string"
}

variable "delimiter" {
  type        = "string"
  default     = "-"
  description = "Delimiter to be used between `namespace`, `stage`, `name` and `attributes`"
}

variable "attributes" {
  type        = "list"
  default     = []
  description = "Additional attributes (e.g. `1`)"
}
variable "tags" {
  type        = "map"
  default     = {}
  description = "Additional tags (e.g. map(`BusinessUnit`,`XYZ`)"
}
variable "alb_name" {
     description = "The name of the LB. This name must be unique within your AWS account, can have a maximum of 32 characters, must contain only alphanumeric characters or hyphens, and must not begin or end with a hyphen. If not specified, Terraform will autogenerate a name beginning with tf-lb."
     default     = ""
}

variable "internal" {
     description = "(Optional) If true, the LB will be internal."
     default     = ""
}

variable "load_balancer_type" {
     description = "(Optional) The type of load balancer to create. Possible values are application or network. The default value is application."
     default     = ""
}

variable "security_groups" {

     description = "(Optional) A list of security group IDs to assign to the LB. Only valid for Load Balancers of type application."
     default     = []
}

variable "subnets" {
     description = "(Optional) A list of subnet IDs to attach to the LB. Subnets cannot be updated for Load Balancers of type network. Changing this value will for load balancers of type network will force a recreation of the resource."
     default     = []
}

variable "enable_deletion_protection" {
     description = "(Optional) If true, deletion of the load balancer will be disabled via the AWS API. This will prevent Terraform from deleting the load balancer. Defaults to false."
     default     = ""
}



variable "alb_environment" {
     description = "(Optional) A mapping of tags to assign to the resource."
     default     = ""
}

#####  ALB LISTENER


variable "listener_port" {
     description = "The port on which the load balancer is listening. like 80 or 443"
     default     = ""
}

variable "listener_protocol" {
     description = "The protocol for connections from clients to the load balancer. Valid values are TCP, HTTP and HTTPS. Defaults to HTTP"
     default     = ""
}


variable "listener_ssl_policy" {
  description = "The security policy if using HTTPS externally on the load balancer. [See](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-security-policy-table.html)."
  default     = "ELBSecurityPolicy-2016-08"
}

variable "listener_certificate_arn" {
     description = "The ARN of the SSL server certificate. Exactly one certificate is required if the protocol is HTTPS"
     default     = ""
}


#####  ALB TARGET GROUP



variable "target_group_port" {
     description = "The port on which targets receive traffic, unless overridden when registering a specific target."
     default     = ""
}


variable "target_group_protocol" {
     description = "The protocol to use for routing traffic to the targets."
     default     = ""
}

variable "vpc_id" {
     description = "The identifier of the VPC in which to create the target group."
     default     = ""
}


variable "target_id" {
     description = "The ID of the target. This is the Instance ID for an instance, or the container ID for an ECS container. If the target type is ip, specify an IP address."
     default     =  []
}


variable "target_group_attachment_port" {
     description = "The port on which targets receive traffic."
     default     = ""
}

variable "idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle."
  default     = 60
}

variable "enable_cross_zone_load_balancing" {
  description = "Indicates whether cross zone load balancing should be enabled in application load balancers."
  default     = false
}

variable "enable_http2" {
  description = "Indicates whether HTTP/2 is enabled in application load balancers."
  default     = true
}

variable "ip_address_type" {
  description = "The type of IP addresses used by the subnets for your load balancer. The possible values are ipv4 and dualstack."
  default     = "ipv4"
}
variable "log_bucket_name" {
  description = "S3 bucket (externally created) for storing load balancer access logs. Required if logging_enabled is true."
  default     = ""
}

variable "log_location_prefix" {
  description = "S3 prefix within the log_bucket_name under which logs are stored."
  default     = ""
}

variable "load_balancer_create_timeout" {
  description = "Timeout value when creating the ALB."
  default = "10m"
}
variable "load_balancer_delete_timeout" {
    description = "Timeout value when deleting the ALB."
    default     = "10m"
  }
variable "load_balancer_update_timeout" {
  description = "Timeout value when updating the ALB."
  default     = "10m"
}

variable "instance_count" {
  description = "Push these instances to ALB"
  default = ""
}
variable "access_logs" {
  description = "Access logs Enable or Disable"
  default = false
}
