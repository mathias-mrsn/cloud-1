locals {
  cidr = "10.0.0.0/16"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = "${local.prefix}-vpc"
  cidr = local.cidr
  azs  = var.azs

  private_subnets      = [for i, az in var.azs : cidrsubnet(local.cidr, 8, i)]
  private_subnet_names = [for i, az in var.azs : "${local.prefix}-private-${az}"]
  private_subnet_tags = {
    Name = "${local.prefix}-private"
  }

  public_subnets      = [for i, az in var.azs : cidrsubnet(local.cidr, 8, i + 4)]
  public_subnet_names = [for i, az in var.azs : "${local.prefix}-public-${az}"]
  public_subnet_tags = {
    Name = "${local.prefix}-public"
  }

  database_subnets      = [for i, az in var.azs : cidrsubnet(local.cidr, 8, i + 8)]
  database_subnet_names = [for i, az in var.azs : "${local.prefix}-database-${az}"]
  database_subnet_tags = {
    Name = "${local.prefix}-database"
  }

  enable_dns_support = true
  enable_nat_gateway = true
  single_nat_gateway = true
  create_igw         = true

  tags = {
    Name       = "${local.prefix}-vpc"
    git_commit = "10c52b75dc0023d7c16f25f72703851e88ac9c20"
    git_file   = "terraform/network.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "vpc"
    yor_trace  = "c97e8b4d-fad4-4396-a978-80e80367b1da"
  }
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "6.6.0"

  vpc_id = module.vpc.vpc_id

  create_security_group      = true
  security_group_name        = "${local.prefix}-vpc-endpoints"
  security_group_description = "Security group for private VPC endpoints"
  security_group_rules = {
    ingress_https = {
      description              = "HTTPS from ECS instances"
      source_security_group_id = aws_security_group.ecs_instances.id
    }
  }

  subnet_ids = module.vpc.private_subnets

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags = {
        Name = "${local.prefix}-vpce-s3"
      }
    }
    ecs = {
      service             = "ecs"
      private_dns_enabled = true
      tags = {
        Name = "${local.prefix}-vpce-ecs"
      }
    }
    ecs_agent = {
      service             = "ecs-agent"
      private_dns_enabled = true
      tags = {
        Name = "${local.prefix}-vpce-ecs-agent"
      }
    }
    ecs_telemetry = {
      service             = "ecs-telemetry"
      private_dns_enabled = true
      tags = {
        Name = "${local.prefix}-vpce-ecs-telemetry"
      }
    }
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      tags = {
        Name = "${local.prefix}-vpce-ecr-api"
      }
    }
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      tags = {
        Name = "${local.prefix}-vpce-ecr-dkr"
      }
    }
    logs = {
      service             = "logs"
      private_dns_enabled = true
      tags = {
        Name = "${local.prefix}-vpce-logs"
      }
    }
    secretsmanager = {
      service             = "secretsmanager"
      private_dns_enabled = true
      tags = {
        Name = "${local.prefix}-vpce-secretsmanager"
      }
    }
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
      tags = {
        Name = "${local.prefix}-vpce-ssm"
      }
    }
    ssmmessages = {
      service             = "ssmmessages"
      private_dns_enabled = true
      tags = {
        Name = "${local.prefix}-vpce-ssmmessages"
      }
    }
    ec2messages = {
      service             = "ec2messages"
      private_dns_enabled = true
      tags = {
        Name = "${local.prefix}-vpce-ec2messages"
      }
    }
  }

  tags = {
    Name       = "${local.prefix}-vpc-endpoints"
    git_commit = "802082bf549a8f2b094eb3434dd4b52824dfb7ae"
    git_file   = "terraform/network.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "vpc_endpoints"
    yor_trace  = "2c52661b-4dda-4694-8919-eed68ae427ec"
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.5.0"

  name                       = "${local.prefix}-alb"
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
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
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

      rules = var.domain_name != null ? {
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
      target_type                       = "instance"
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
    }, var.domain_name != null ? {
    phpmyadmin = {
      backend_protocol                  = "HTTP"
      backend_port                      = 80
      target_type                       = "instance"
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
    Name       = "${local.prefix}-alb"
    git_commit = "802082bf549a8f2b094eb3434dd4b52824dfb7ae"
    git_file   = "terraform/network.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "alb"
    yor_trace  = "dba1f7ab-df75-47ac-b736-4f49a0ab2adc"
  }
}
