module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.3.0"

  providers = {
    aws = aws.cloudfront
  }

  create_certificate   = var.domain_name != null
  validate_certificate = var.domain_name != null

  domain_name = coalesce(var.domain_name, "default")
  subject_alternative_names = var.domain_name != null ? [
    local.phpmyadmin_domain_name,
  ] : []
  validation_method = "DNS"
  zone_id           = try(data.aws_route53_zone.current[0].zone_id, null)

  tags = {
    Name       = "${local.prefix}-acm"
    git_commit = "10c52b75dc0023d7c16f25f72703851e88ac9c20"
    git_file   = "terraform/edge.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "acm"
    yor_trace  = "8e7b89b8-cd14-473b-b36a-2b318acfc982"
  }
}

module "acm_alb" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.3.0"

  create_certificate   = var.domain_name != null
  validate_certificate = var.domain_name != null

  domain_name       = coalesce(local.performance_domain_name, "default")
  validation_method = "DNS"
  zone_id           = try(data.aws_route53_zone.current[0].zone_id, null)

  tags = {
    Name       = "${local.prefix}-alb-acm"
    git_commit = "802082bf549a8f2b094eb3434dd4b52824dfb7ae"
    git_file   = "terraform/edge.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "acm_alb"
    yor_trace  = "cc982d91-0ceb-4101-b580-72cbdc1506cd"
  }
}

module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.4.0"

  aliases = var.domain_name != null ? compact([
    var.domain_name,
    local.phpmyadmin_domain_name,
  ]) : null

  comment         = "Cloudfront for"
  http_version    = "http3"
  is_ipv6_enabled = false
  price_class     = var.distribution_price_class

  origin = {
    wordpress = {
      domain_name = var.domain_name != null ? local.performance_domain_name : module.alb.dns_name
      origin_id   = module.alb.id
      custom_header = {
        "X-CloudFront-Proto" = "https"
      }
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = var.domain_name != null ? "https-only" : "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id         = module.alb.id
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    use_forwarded_values     = false
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  ordered_cache_behavior = [
    {
      target_origin_id         = module.alb.id
      path_pattern             = "wp-admin/*"
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      use_forwarded_values     = false
      cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    },
    {
      target_origin_id         = module.alb.id
      path_pattern             = "wp-login.php"
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      use_forwarded_values     = false
      cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    },
    {
      target_origin_id         = module.alb.id
      path_pattern             = "wp-includes/*"
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      use_forwarded_values     = false
      cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    },
    {
      target_origin_id         = module.alb.id
      path_pattern             = "wp-content/*"
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      use_forwarded_values     = false
      cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
      origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    }

  ]

  viewer_certificate = (var.domain_name != null ? {
    acm_certificate_arn = module.acm.acm_certificate_arn
    ssl_support_method  = "sni-only"
    } : {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1"
  })

  tags = {
    Name       = "${local.prefix}-cloudfront"
    git_commit = "802082bf549a8f2b094eb3434dd4b52824dfb7ae"
    git_file   = "terraform/edge.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "cloudfront"
    yor_trace  = "7781623d-3d4d-4426-8104-82a0805a16a1"
  }
}

module "records_domaine_to_main_zone" {
  source  = "terraform-aws-modules/route53/aws"
  version = "6.4.0"

  create = var.domain_name != null

  create_zone = false
  name        = var.domain_name

  records = {
    root = {
      full_name = var.domain_name
      type      = "A"
      alias = {
        name    = module.cloudfront.cloudfront_distribution_domain_name
        zone_id = module.cloudfront.cloudfront_distribution_hosted_zone_id
      }
    },

    phpmyadmin = {
      full_name = local.phpmyadmin_domain_name
      type      = "A"
      alias = {
        name    = module.cloudfront.cloudfront_distribution_domain_name
        zone_id = module.cloudfront.cloudfront_distribution_hosted_zone_id
      }
    },

    performance = {
      full_name = local.performance_domain_name
      type      = "A"
      alias = {
        name    = module.alb.dns_name
        zone_id = module.alb.zone_id
      }
    }
  }
  tags = {
    git_commit = "802082bf549a8f2b094eb3434dd4b52824dfb7ae"
    git_file   = "terraform/edge.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "records_domaine_to_main_zone"
    yor_trace  = "ad759266-282b-4712-9127-216d3c62865f"
  }
}
