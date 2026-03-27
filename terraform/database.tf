module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "10.2.0"

  providers = {
    aws = aws.default
  }

  vpc_id = module.vpc.vpc_id

  name                        = "aurora-${var.name}-mysqlv2"
  engine                      = "aurora-mysql"
  engine_mode                 = "provisioned"
  engine_version              = var.mysql_version
  storage_encrypted           = true
  database_name               = var.database_name
  master_username             = var.aurora_master_username
  manage_master_user_password = true
  apply_immediately           = true
  skip_final_snapshot         = var.aurora_skip_final_snapshot
  cluster_instance_class      = "db.serverless"
  instances                   = var.aurora_instances

  db_subnet_group_name = module.vpc.database_subnet_group_name
  security_group_ingress_rules = {
    allow_ecs = {
      description                  = "Allow ECS Fargate tasks to access the Aurora cluster"
      from_port                    = 3306
      to_port                      = 3306
      referenced_security_group_id = aws_security_group.ecs_tasks.id
    }
  }

  serverlessv2_scaling_configuration = {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }
}

resource "aws_security_group" "memcached" {
  provider = aws.default
  count    = var.memcached_enabled ? 1 : 0

  name        = "memcached-${var.name}"
  description = "Security group for the WordPress Memcached cluster"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Origin     = var.name
    DeployedBy = "Terraform"
  }
}

resource "aws_vpc_security_group_ingress_rule" "memcached_from_ecs" {
  provider = aws.default
  count    = var.memcached_enabled ? 1 : 0

  security_group_id            = aws_security_group.memcached[0].id
  referenced_security_group_id = aws_security_group.ecs_tasks.id
  from_port                    = 11211
  to_port                      = 11211
  ip_protocol                  = "tcp"
  description                  = "Allow Memcached traffic from ECS Fargate tasks"
}

resource "aws_elasticache_subnet_group" "memcached" {
  provider = aws.default
  count    = var.memcached_enabled ? 1 : 0

  name       = var.name
  subnet_ids = module.vpc.database_subnets

  tags = {
    Origin     = var.name
    DeployedBy = "Terraform"
  }
}

resource "aws_elasticache_parameter_group" "memcached" {
  provider = aws.default
  count    = var.memcached_enabled ? 1 : 0

  name   = var.name
  family = "memcached1.6"

  tags = {
    Origin     = var.name
    DeployedBy = "Terraform"
  }
}

resource "aws_elasticache_cluster" "memcached" {
  provider = aws.default
  count    = var.memcached_enabled ? 1 : 0

  cluster_id           = "memcache-${var.name}"
  engine               = "memcached"
  node_type            = var.memcached_node_type
  num_cache_nodes      = var.memcached_num_cache_nodes
  az_mode              = "cross-az"
  port                 = 11211
  apply_immediately    = true
  maintenance_window   = "sun:05:00-sun:09:00"
  subnet_group_name    = aws_elasticache_subnet_group.memcached[0].name
  parameter_group_name = aws_elasticache_parameter_group.memcached[0].name
  security_group_ids   = [aws_security_group.memcached[0].id]

  tags = {
    Origin     = var.name
    DeployedBy = "Terraform"
  }
}
