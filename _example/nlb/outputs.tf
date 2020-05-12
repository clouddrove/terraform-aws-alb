output "arn" {
  value       = module.nlb.*.arn
  description = "The ARN suffix of the ALB"
}

output "tags" {
  value       = module.nlb.tags
  description = "A mapping of tags to assign to the alb."
}