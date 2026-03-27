locals {
  cidr = "10.0.0.0/16"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  providers = {
    aws = aws.default
  }

  name = "vpc-${var.name}"
  cidr = local.cidr
  azs  = var.azs

  private_subnets      = [for i, az in var.azs : cidrsubnet(local.cidr, 8, i)]
  private_subnet_names = [for i, az in var.azs : "${var.name}_private_${az}"]
  private_subnet_tags = {
    Origin     = var.name,
    Type       = "private",
    DeployedBy = "Terraform"
  }

  public_subnets      = [for i, az in var.azs : cidrsubnet(local.cidr, 8, i + 4)]
  public_subnet_names = [for i, az in var.azs : "${var.name}_public_${az}"]
  public_subnet_tags = {
    Origin     = var.name,
    Type       = "public",
    DeployedBy = "Terraform"
  }

  database_subnets      = [for i, az in var.azs : cidrsubnet(local.cidr, 8, i + 8)]
  database_subnet_names = [for i, az in var.azs : "${var.name}_database_${az}"]
  database_subnet_tags = {
    Origin     = var.name,
    Type       = "database",
    DeployedBy = "Terraform"
  }

  enable_dns_support = true
  enable_nat_gateway = true
  single_nat_gateway = true
  create_igw         = true

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.5.0"

  providers = {
    aws = aws.default
  }

  name                       = "alb-${var.name}"
  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.public_subnets
  enable_deletion_protection = false

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  listeners = {
    wordpress = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "wordpress"
      }

      rules = local.phpmyadmin_enabled ? {
        phpmyadmin = {
          priority = 10

          actions = [
            {
              forward = {
                target_group_key = "phpmyadmin"
              }
            }
          ]

          conditions = [
            {
              host_header = {
                values = [local.phpmyadmin_domain_name]
              }
            }
          ]
        }
      } : {}
    }
  }

  target_groups = merge({
    wordpress = {
      backend_protocol                  = "HTTP"
      backend_port                      = 80
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true
      create_attachment                 = false

      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 3
        interval            = 30
        timeout             = 5
        matcher             = "200-399"
        path                = "/healthz.php"
        port                = "traffic-port"
        protocol            = "HTTP"
      }
    }
    }, local.phpmyadmin_enabled ? {
    phpmyadmin = {
      backend_protocol                  = "HTTP"
      backend_port                      = 80
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true
      create_attachment                 = false

      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 3
        interval            = 30
        timeout             = 5
        matcher             = "200-399"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
      }
    }
  } : {})

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }
}
