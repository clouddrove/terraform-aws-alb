#Module      : ALB
#Description : This terraform module is used to create ALB on AWS.
output "name" {
  value       = join("", aws_lb.main.*.name)
  description = "The ARN suffix of the ALB."
}

output "arn" {
  value       = join("", concat(aws_lb.main.*.arn))
  description = "The ARN of the ALB."
}

output "clb_arn" {
  value       = join("", concat(aws_elb.main.*.arn))
  description = "The ARN of the CLB."
}
output "arn_suffix" {
  value       = join("", aws_lb.main.*.arn_suffix)
  description = "The ARN suffix of the ALB."
}

output "dns_name" {
  value       = join("", aws_lb.main.*.dns_name)
  description = "DNS name of ALB."
}

output "clb_name" {
  value       = join("", aws_elb.main.*.dns_name)
  description = "DNS name of CLB."
}
output "zone_id" {
  value       = join("", aws_lb.main.*.zone_id)
  description = "The ID of the zone which ALB is provisioned."
}

output "clb_zone_id" {
  value       = join("", aws_elb.main.*.zone_id)
  description = "The ID of the zone which ALB is provisioned."
}
output "main_target_group_arn" {
  value       = join("", aws_lb_target_group.main.*.arn)
  description = "The main target group ARN."
}

output "http_listener_arn" {
  value       = join("", aws_lb_listener.http.*.arn)
  description = "The ARN of the HTTP listener."
}

output "https_listener_arn" {
  value       = join("", aws_lb_listener.https.*.arn)
  description = "The ARN of the HTTPS listener."
}

output "listener_arns" {
  value       = compact(concat(aws_lb_listener.http.*.arn, aws_lb_listener.https.*.arn))
  description = "A list of all the listener ARNs."
}

output "tags" {
  value       = module.labels.tags
  description = "A mapping of tags to assign to the resource."
}