output "arn" {
  value       = module.nlb[*].arn
  description = "The ARN suffix of the ALB"
}

output "tags" {
  value       = module.nlb.tags
  description = "A mapping of tags to assign to the alb."
}

output "dns_name" {
  value       = module.nlb.dns_name
  description = "The DNS name of the load balancer."
}

output "zone_id" {
  value       = module.nlb.zone_id
  description = "The zone_id of the load balancer to assist with creating DNS records."
}

output "http_listener_arns" {
  value       = module.nlb.http_listener_arn
  description = "The ARN of the TCP and HTTP load balancer listeners created."
}

output "https_listener_arns" {
  value       = module.nlb.https_listener_arn
  description = "The ARNs of the HTTPS load balancer listeners created."
}
