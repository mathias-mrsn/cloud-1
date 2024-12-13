module "elasticache" {
  providers = {
    aws = aws.default
  }
  source = "terraform-aws-modules/elasticache/aws"

  cluster_id               = "memcache-${var.name}"
  create_cluster           = true
  create_replication_group = false

  engine          = "memcached"
  node_type       = "cache.t4g.small"
  num_cache_nodes = 3
  az_mode         = "cross-az"

  maintenance_window = "sun:05:00-sun:09:00"
  apply_immediately  = true

  # Security Group
  vpc_id = module.vpc.vpc_id
  security_group_rules = {
    ingress_vpc = {
      # Default type is `ingress`
      # Default port is based on the default engine port
      description                  = "ASG traffic"
      referenced_security_group_id = module.autoscaling_sg.security_group_id
    }
  }

  # Subnet Group
  subnet_group_name        = var.name
  subnet_group_description = "${title(var.name)} subnet group"
  subnet_ids               = module.vpc.database_subnets

  # W3 Cache doesnt support transit encryption yet
  transit_encryption_enabled = false

  # Parameter Group
  create_parameter_group      = true
  parameter_group_name        = var.name
  parameter_group_family      = "memcached1.6"
  parameter_group_description = "${title(var.name)} parameter group"
}
