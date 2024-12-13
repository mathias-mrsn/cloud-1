module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.12.0"

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
        target_group_key = "wp_asg"
      }
    }
  }

  target_groups = {
    wp_asg = {
      backend_protocol                  = "HTTP"
      backend_port                      = 80
      target_type                       = "instance"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true
      create_attachment                 = false
    }
  }

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }
}
