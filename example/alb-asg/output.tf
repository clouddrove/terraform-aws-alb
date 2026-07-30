output "alb_dns_name" {
  value       = module.alb.dns_name
  description = "The DNS name of the ALB. Use this to send HTTP requests."
}

output "alb_url" {
  value       = "http://${module.alb.dns_name}"
  description = "Full HTTP URL of the ALB."
}

output "alb_arn" {
  value       = module.alb.arn
  description = "The ARN of the ALB."
}

output "target_group_arn" {
  value       = module.alb.main_target_group_arn
  description = "ARN of the ALB target group the ASG registers instances into."
}

output "asg_name" {
  value       = aws_autoscaling_group.asg.name
  description = "Name of the Auto Scaling Group."
}

output "launch_template_id" {
  value       = aws_launch_template.asg.id
  description = "ID of the launch template used by the ASG."
}

output "iam_instance_profile_name" {
  value       = aws_iam_instance_profile.asg.name
  description = "Name of the IAM instance profile attached to ASG instances."
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID of the VPC."
}

output "public_subnet_ids" {
  value       = module.public_subnets.public_subnet_id
  description = "IDs of the public subnets used by the ALB and ASG."
}
