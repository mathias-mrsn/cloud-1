data "aws_route53_zone" "current" {
  count        = var.domain_name != null ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

data "aws_caller_identity" "current" {}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}
