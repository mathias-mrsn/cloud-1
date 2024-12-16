output "database_secret_arn" {
  description = "The ARN of the secret containing the master password for the Aurora database."
  value       = module.aurora.cluster_master_user_secret[0].secret_arn
}

output "cloudfront_dns_name" {
  description = "The DNS name of the CloudFront distribution."
  value       = module.cloudfront.cloudfront_distribution_domain_name
}

