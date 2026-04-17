locals {
  wordpress_parameter_values = {
    "/${local.prefix}/aurora/endpoint" = {
      type  = "String"
      value = module.aurora.cluster_endpoint
    }
    "/${local.prefix}/aurora/name" = {
      type  = "String"
      value = var.database_name
    }
    "/${local.prefix}/wordpress/title" = {
      type  = "String"
      value = var.wp_site_title
    }
    "/${local.prefix}/wordpress/locale" = {
      type  = "String"
      value = var.wp_language
    }
    "/${local.prefix}/wordpress/shared_root" = {
      type  = "String"
      value = var.wordpress_shared_root
    }
    "/${local.prefix}/wordpress/url" = {
      type  = "String"
      value = "https://${coalesce(var.domain_name, module.cloudfront.cloudfront_distribution_domain_name)}"
    }
    "/${local.prefix}/wordpress/auth_key" = {
      type  = "SecureString"
      value = random_password.wordpress_secret_key["auth_key"].result
    }
    "/${local.prefix}/wordpress/secure_auth_key" = {
      type  = "SecureString"
      value = random_password.wordpress_secret_key["secure_auth_key"].result
    }
    "/${local.prefix}/wordpress/logged_in_key" = {
      type  = "SecureString"
      value = random_password.wordpress_secret_key["logged_in_key"].result
    }
    "/${local.prefix}/wordpress/nonce_key" = {
      type  = "SecureString"
      value = random_password.wordpress_secret_key["nonce_key"].result
    }
    "/${local.prefix}/wordpress/auth_salt" = {
      type  = "SecureString"
      value = random_password.wordpress_secret_key["auth_salt"].result
    }
    "/${local.prefix}/wordpress/secure_auth_salt" = {
      type  = "SecureString"
      value = random_password.wordpress_secret_key["secure_auth_salt"].result
    }
    "/${local.prefix}/wordpress/logged_in_salt" = {
      type  = "SecureString"
      value = random_password.wordpress_secret_key["logged_in_salt"].result
    }
    "/${local.prefix}/wordpress/nonce_salt" = {
      type  = "SecureString"
      value = random_password.wordpress_secret_key["nonce_salt"].result
    }
  }
}

resource "random_password" "wordpress_secret_key" {
  for_each = toset([
    "auth_key",
    "secure_auth_key",
    "logged_in_key",
    "nonce_key",
    "auth_salt",
    "secure_auth_salt",
    "logged_in_salt",
    "nonce_salt",
  ])

  length  = 64
  special = false
}

resource "aws_ssm_parameter" "wordpress_runtime" {
  for_each = local.wordpress_parameter_values

  name  = each.key
  type  = each.value.type
  value = each.value.value

  tags = {
    Name       = replace(trimprefix(each.key, "/"), "/", "-")
    git_commit = "44406d3b5d909b6b1e277e6f5389544c03a243eb"
    git_file   = "terraform/parameters.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "wordpress_runtime"
    yor_trace  = "216b8410-c7b4-4f93-a638-d5fa7ec91e3d"
  }
}
