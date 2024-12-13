module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  providers = {
    aws = aws.us-east-1
  }

  create_certificate   = var.domain_name != null ? true : false
  validate_certificate = var.domain_name != null ? true : false

  domain_name = coalesce(var.domain_name, "default")
  zone_id     = try(data.aws_route53_zone.current[0].id, null)

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }
}
