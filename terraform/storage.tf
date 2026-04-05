module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "4.2.0"

  aliases               = ["${local.prefix}-efs"]
  description           = "KMS key used by EFS storage"
  enable_default_policy = true

  deletion_window_in_days = 7

  tags = {
    Name = "${local.prefix}-efs-kms"
  }
}

module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "2.2.0"

  name                               = "${local.prefix}-efs"
  creation_token                     = "${local.prefix}-efs"
  encrypted                          = true
  kms_key_arn                        = module.kms.key_arn
  attach_policy                      = false
  bypass_policy_lockout_safety_check = false
  mount_targets                      = { for k, v in zipmap(var.azs, module.vpc.private_subnets) : k => { subnet_id = v } }
  security_group_description         = "EFS security group"
  security_group_vpc_id              = module.vpc.vpc_id
  enable_backup_policy               = false

  create_replication_configuration = var.backup_region != null
  replication_configuration_destination = {
    region = var.backup_region
  }

  policy_statements = {
    mount = {
      actions = ["elasticfilesystem:ClientMount"]
      principals = [
        {
          type        = "AWS"
          identifiers = [data.aws_caller_identity.current.arn]
        }
      ]
    }
  }

  security_group_ingress_rules = {
    ecs_instances = {
      description                  = "Allow access from ECS EC2 container instances"
      referenced_security_group_id = aws_security_group.ecs_instances.id
    }
  }

  tags = {
    Name = "${local.prefix}-efs"
  }

}

resource "aws_efs_access_point" "wordpress" {
  file_system_id = module.efs.id

  posix_user {
    gid = 33
    uid = 33
  }

  root_directory {
    path = "/wordpress"

    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = "0755"
    }
  }

  tags = {
    Name = "${local.prefix}-wordpress-access-point"
  }
}
