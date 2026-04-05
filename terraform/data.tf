data "aws_route53_zone" "current" {
  # Looks up the public Route 53 hosted zone for the configured domain.
  count        = var.domain_name != null ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

data "aws_caller_identity" "current" {
  # Reads the current AWS account identity for policy generation.
}

data "aws_ecr_authorization_token" "this" {
  # Retrieves temporary ECR registry credentials for the Docker provider.
}

data "aws_ami" "ecs_ubuntu" {
  # Selects the latest Ubuntu AMI used as the ECS EC2 base image.

  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  # Reuses the managed CloudFront policy that forwards all viewer headers.

  name = "Managed-AllViewer"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  # Reuses the managed CloudFront cache policy that disables caching.

  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  # Reuses the managed CloudFront cache policy optimized for static content.

  name = "Managed-CachingOptimized"
}
