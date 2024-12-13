module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.2.2"

  aliases = (var.domain_name != null ? [var.domain_name] : null)

  comment         = "Cloudfront for"
  http_version    = "http3"
  is_ipv6_enabled = false
  price_class     = var.distribution_price_class

  origin = {
    wordpress = {
      domain_name = module.alb.dns_name
      origin_id   = module.alb.id
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = module.alb.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    query_string           = true
    cookies_forward        = "all"
    headers                = ["Host"]
  }

  ordered_cache_behavior = [
    {
      target_origin_id       = module.alb.id
      path_pattern           = "wp-includes/*"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      min_ttl                = 900
      max_ttl                = 900
      default_ttl            = 900
      compress               = true
      query_string           = true
      headers                = ["Host"]
    },
    {
      target_origin_id       = module.alb.id
      path_pattern           = "wp-content/*"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      min_ttl                = 900
      max_ttl                = 900
      default_ttl            = 900
      compress               = true
      query_string           = true
      headers                = ["Host"]
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
    Origin     = var.name,
    DeployedBy = "Terraform"
  }
}

