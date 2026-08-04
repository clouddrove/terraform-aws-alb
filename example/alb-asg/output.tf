output "alb_dns_name" {
  value       = module.alb.dns_name
  description = "DNS name of the ALB."
}

output "alb_url" {
  value       = "http://${module.alb.dns_name}"
  description = "HTTP URL of the ALB."
}

output "target_group_arn" {
  value       = module.alb.main_target_group_arn
  description = "ARN of the ALB target group."
}

output "asg_name" {
  value       = module.ec2_autoscaling.autoscaling_group_name
  description = "Name of the Auto Scaling Group."
}
