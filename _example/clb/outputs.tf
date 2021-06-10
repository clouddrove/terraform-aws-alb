output "arn" {
  value       = module.clb.*.clb_arn
  description = "The ARN suffix of the ALB"
}

output "tags" {
  value       = module.clb.tags
  description = "A mapping of tags to assign to the alb."
}
