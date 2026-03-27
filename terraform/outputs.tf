output "database_secret_arn" {
  description = "The ARN of the secret containing the master password for the Aurora database."
  value       = module.aurora.cluster_master_user_secret[0].secret_arn
}

output "cloudfront_dns_name" {
  description = "The DNS name of the CloudFront distribution."
  value       = module.cloudfront.cloudfront_distribution_domain_name
}

output "ecs_cluster_name" {
  description = "The ECS cluster name running WordPress."
  value       = module.ecs_cluster.name
}

output "ecs_service_name" {
  description = "The ECS service name running WordPress."
  value       = module.ecs_service_wordpress.name
}

output "memcached_configuration_endpoint" {
  description = "The Memcached configuration endpoint for WordPress caching."
  value       = var.memcached_enabled ? aws_elasticache_cluster.memcached[0].configuration_endpoint : null
}

output "notifications_topic_arn" {
  description = "The SNS topic ARN for WordPress operational notifications."
  value       = aws_sns_topic.wordpress.arn
}

output "wordpress_ecr_repository_url" {
  description = "The ECR repository URL that stores the managed WordPress image."
  value       = aws_ecr_repository.wordpress.repository_url
}

output "wordpress_admin_password_secret_arn" {
  description = "The ARN of the Secrets Manager secret storing the WordPress admin password."
  value       = aws_secretsmanager_secret.wordpress_admin_password.arn
}

output "wordpress_admin_password_secret_name" {
  description = "The name of the Secrets Manager secret storing the WordPress admin password."
  value       = aws_secretsmanager_secret.wordpress_admin_password.name
}

output "phpmyadmin_url" {
  description = "The phpMyAdmin URL when phpMyAdmin is enabled and a domain name is configured."
  value       = local.phpmyadmin_enabled ? "http://${local.phpmyadmin_domain_name}" : null
}

output "phpmyadmin_service_name" {
  description = "The ECS service name running phpMyAdmin when enabled."
  value       = try(module.ecs_service_phpmyadmin.name, null)
}
