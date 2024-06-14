output "arn" {
  value       = module.clb[*].arn
  description = "The ARN suffix of the ALB"
}

output "tags" {
  value       = module.clb.tags
  description = "A mapping of tags to assign to the alb."
}

output "main_target_group_arn" {
  value       = module.clb[*].main_target_group_arn
  description = "The ARN target of the ALB"
}

output "dns_name" {
  value       = module.clb.dns_name
  description = "The DNS name of the load balancer."
}

output "zone_id" {
  value       = module.clb.zone_id
  description = "The zone_id of the load balancer to assist with creating DNS records."
}
