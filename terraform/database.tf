module "aurora" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "10.2.0"

  vpc_id = module.vpc.vpc_id

  name                        = "${local.prefix}-aurora-mysql"
  engine                      = "aurora-mysql"
  engine_mode                 = "provisioned"
  engine_version              = var.mysql_version
  storage_encrypted           = true
  database_name               = var.database_name
  master_username             = var.aurora_master_username
  manage_master_user_password = true
  apply_immediately           = true
  skip_final_snapshot         = true
  cluster_instance_class      = "db.serverless"
  instances                   = var.aurora_instances

  db_subnet_group_name = module.vpc.database_subnet_group_name
  security_group_ingress_rules = {
    allow_ecs_instances = {
      description                  = "Allow ECS EC2 container instances to access the Aurora cluster"
      from_port                    = 3306
      to_port                      = 3306
      referenced_security_group_id = aws_security_group.ecs_instances.id
    }
  }

  serverlessv2_scaling_configuration = {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  tags = {
    Name       = "${local.prefix}-aurora"
    git_commit = "2a4f56d4539e2a0165b1f39b93759876ef2ad15f"
    git_file   = "terraform/database.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "aurora"
    yor_trace  = "194d253a-63bd-41ac-947a-b83c8676c0cf"
  }
}
