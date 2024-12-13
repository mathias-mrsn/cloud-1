module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.10.0"

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
  instance_class              = "db.serverless"
  instances                   = var.aurora_instances

  db_subnet_group_name = module.vpc.database_subnet_group_name
  security_group_rules = {
    allow_asg = {
      description              = "Allow ASG to access the Aurora Cluster"
      port                     = 5432
      source_security_group_id = module.autoscaling_sg.security_group_id
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
