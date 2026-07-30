output "arn" {
  value       = module.alb[*].arn
  description = "The ARN of the ALB."
}

output "dns_name" {
  value       = module.alb.dns_name
  description = "The DNS name of the load balancer."
}

output "zone_id" {
  value       = module.alb.zone_id
  description = "The zone_id of the load balancer to assist with creating DNS records."
}

output "tags" {
  value       = module.alb.tags
  description = "A mapping of tags to assign to the alb."
}

output "main_target_group_arn" {
  value       = module.alb[*].main_target_group_arn
  description = "The ARN of the shared target group (Apache + Nginx)."
}

output "apache_instance_id" {
  value       = module.ec2_apache.instance_id
  description = "Instance ID of the Apache EC2 instance."
}

output "nginx_instance_id" {
  value       = module.ec2_nginx.instance_id
  description = "Instance ID of the Nginx EC2 instance."
}
