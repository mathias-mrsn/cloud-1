output "database_secret_arn" {
  # Exposes the ARN of the Secrets Manager secret generated for Aurora.
  description = "The ARN of the secret containing the master password for the Aurora database."
  value       = module.aurora.cluster_master_user_secret[0].secret_arn
}

output "aurora_cluster_endpoint" {
  # Exposes the writer endpoint used by WordPress and phpMyAdmin.
  description = "The Aurora cluster writer endpoint."
  value       = module.aurora.cluster_endpoint
}

output "cloudfront_dns_name" {
  # Exposes the CloudFront domain name that fronts the public site.
  description = "The DNS name of the CloudFront distribution."
  value       = module.cloudfront.cloudfront_distribution_domain_name
}

output "ecs_cluster_name" {
  # Exposes the ECS cluster name that runs the application services.
  description = "The ECS cluster name running WordPress."
  value       = module.ecs_cluster.name
}

output "ecs_autoscaling_group_name" {
  # Exposes the Auto Scaling group name that backs ECS on EC2.
  description = "The Auto Scaling group name backing ECS on EC2."
  value       = module.ecs_autoscaling.autoscaling_group_name
}

output "ecs_launch_template_id" {
  # Exposes the launch template ID used by the ECS Auto Scaling group.
  description = "The launch template ID used by the ECS Auto Scaling group."
  value       = module.ecs_autoscaling.launch_template_id
}

output "ecs_service_wordpress_name" {
  # Exposes the ECS service name that runs the main WordPress workload.
  description = "The ECS service name running WordPress."
  value       = module.ecs_service_wordpress.name
}

output "wordpress_ecr_repository_url" {
  description = "The ECR repository URL that stores the managed WordPress-Apache image."
  value       = aws_ecr_repository.container["wordpress-apache"].repository_url
}

output "phpmyadmin_ecr_repository_url" {
  # Exposes the ECR repository URL that stores the managed phpMyAdmin image.
  description = "The ECR repository URL that stores the managed phpMyAdmin image."
  value       = try(aws_ecr_repository.container["phpmyadmin"].repository_url, null)
}

output "wordpress_admin_password_secret_arn" {
  # Exposes the ARN of the secret that stores the WordPress admin password.
  description = "The ARN of the Secrets Manager secret storing the WordPress admin password."
  value       = aws_secretsmanager_secret.wordpress_admin_credentials.arn
}

output "wordpress_admin_password_secret_name" {
  # Exposes the name of the secret that stores the WordPress admin password.
  description = "The name of the Secrets Manager secret storing the WordPress admin password."
  value       = aws_secretsmanager_secret.wordpress_admin_credentials.name
}

output "phpmyadmin_url" {
  # Exposes the phpMyAdmin URL when a public domain name is configured.
  description = "The phpMyAdmin URL when a domain name is configured."
  value       = var.domain_name != null ? "https://${local.phpmyadmin_domain_name}" : null
}

output "phpmyadmin_service_name" {
  # Exposes the ECS service name for phpMyAdmin when that service is created.
  description = "The ECS service name running phpMyAdmin when a domain name is configured."
  value       = try(module.ecs_service_phpmyadmin.name, null)
}

output "cloudffront_url" {
  value = "https://${coalesce(var.domain_name, module.cloudfront.cloudfront_distribution_domain_name)}"

}
