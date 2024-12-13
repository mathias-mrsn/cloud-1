data "aws_route53_zone" "current" {
  count        = var.domain_name != null ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

data "aws_caller_identity" "current" {}
