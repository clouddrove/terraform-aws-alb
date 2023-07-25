output "arn" {
  value       = module.alb.*.arn
  description = "The ARN suffix of the ALB"
}

output "tags" {
  value       = module.alb.tags
  description = "A mapping of tags to assign to the alb."
}

output "main_target_group_arn" {
  value       = module.alb.*.main_target_group_arn
  description = "The ARN target of the ALB"
}