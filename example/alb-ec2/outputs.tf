output "alb_dns_name" {
  value       = module.alb.dns_name
  description = "DNS name of the ALB."
}

output "alb_url" {
  value       = "http://${module.alb.dns_name}"
  description = "HTTP URL of the ALB."
}

output "main_target_group_arn" {
  value       = module.alb.main_target_group_arn
  description = "ARN of the shared target group."
}

output "apache_instance_id" {
  value       = module.ec2_apache.instance_id
  description = "Instance ID of the Apache EC2 instance."
}

output "nginx_instance_id" {
  value       = module.ec2_nginx.instance_id
  description = "Instance ID of the Nginx EC2 instance."
}

output "key_pair_name" {
  value       = module.keypair.name
  description = "Name of the generated SSH key pair."
}
