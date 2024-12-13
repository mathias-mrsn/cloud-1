module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "~> 1.6.4"

  providers = {
    aws = aws.default
  }

  name                               = "efs-${var.name}"
  creation_token                     = "efs-${var.name}"
  encrypted                          = true
  kms_key_arn                        = module.kms.key_arn
  attach_policy                      = true
  bypass_policy_lockout_safety_check = false
  mount_targets                      = { for k, v in zipmap(var.azs, module.vpc.private_subnets) : k => { subnet_id = v } }
  security_group_description         = "EFS security group"
  security_group_vpc_id              = module.vpc.vpc_id
  enable_backup_policy               = false

  create_replication_configuration = var.backup_region != null ? true : false
  replication_configuration_destination = {
    region = var.backup_region
  }

  policy_statements = [
    {
      actions = ["elasticfilesystem:ClientMount"]
      principals = [
        {
          type        = "AWS"
          identifiers = [data.aws_caller_identity.current.arn]
        }
      ]
    }
  ]

  security_group_rules = {
    vpc = {
      description              = "Allow access from ASG"
      port                     = -1
      source_security_group_id = module.autoscaling_sg.security_group_id
    }
  }

  access_points = {
    posix_example = {
      name = "posix-example"
      posix_user = {
        gid            = 1001
        uid            = 1001
        secondary_gids = [1002]
      }

      tags = {
        Additionl = "yes"
      }
    }
    # root_example = {
    #   root_directory = {
    #     path = "/example"
    #     creation_info = {
    #       owner_gid   = 1001
    #       owner_uid   = 1001
    #       permissions = "755"
    #     }
    #   }
    # }
  }

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }

}
