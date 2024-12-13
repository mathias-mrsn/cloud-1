module "records_domaine_to_main_zone" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "4.1.0"

  create = var.domain_name != null ? true : false

  zone_id = try(data.aws_route53_zone.current[0].zone_id, null)

  records = [
    {
      name = ""
      type = "A"
      alias = {
        name    = module.cloudfront.cloudfront_distribution_domain_name
        zone_id = module.cloudfront.cloudfront_distribution_hosted_zone_id
      }
    },
  ]
}
