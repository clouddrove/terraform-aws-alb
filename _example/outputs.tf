output "arn" {
  value       = module.alb.*.arn
  description = "The ARN suffix of the ALB"
}

output "tags" {
  value       = module.alb.tags
  description = "A mapping of tags to assign to the alb."
}