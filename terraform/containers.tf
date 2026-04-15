locals {
  managed_container_build_paths = concat(
    [
      "${local.repository_root}/.dockerignore",
      "${local.repository_root}/Makefile",
      "${local.repository_root}/docker-compose.yaml",
    ],
    [for file in fileset(local.repository_root, "docker/wordpress/**") : "${local.repository_root}/${file}"],
    [for file in fileset(local.repository_root, "docker/phpmyadmin/**") : "${local.repository_root}/${file}"]
  )

  managed_container_build_hash = sha1(join("", [for file in local.managed_container_build_paths : filesha1(file)]))

  managed_container_image_names = {
    wordpress_apache = format("%s:latest", aws_ecr_repository.container["wordpress-apache"].repository_url)
    phpmyadmin       = format("%s:latest", aws_ecr_repository.container["phpmyadmin"].repository_url)
  }
}

# checkov:skip=CKV_AWS_51: The deployment workflow republishes the mutable latest tag on each apply, so immutable tags would break image updates.
resource "aws_ecr_repository" "container" {
  for_each = toset(["wordpress-apache", "phpmyadmin"])

  name                 = "${local.prefix}-${each.value}"
  force_delete         = true
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = module.kms.key_arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name       = "${local.prefix}-${each.value}"
    git_commit = "442e87b23ae4faf0c9944bee932d85b94c780215"
    git_file   = "terraform/containers.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "container"
    yor_trace  = "fdbc117b-b064-44e1-ba8e-44870d6527d5"
  }
}

resource "terraform_data" "container_images_build" {

  triggers_replace = [
    local.managed_container_build_hash,
    local.managed_container_image_names.wordpress_apache,
    local.managed_container_image_names.phpmyadmin,
  ]

  provisioner "local-exec" {
    command     = "make docker-build WORDPRESS_APACHE_IMAGE_NAME=${local.managed_container_image_names.wordpress_apache} PHPMYADMIN_IMAGE_NAME=${local.managed_container_image_names.phpmyadmin} DOCKER_PLATFORM=linux/amd64 ENABLE_LOCAL_STACK=false"
    working_dir = path.cwd
  }
}

resource "docker_registry_image" "container" {
  for_each = local.managed_container_image_names

  name = each.value

  depends_on = [
    terraform_data.container_images_build,
  ]

  lifecycle {
    replace_triggered_by = [terraform_data.container_images_build]
  }
}


resource "aws_secretsmanager_secret" "wordpress_admin_credentials" {
  name                    = "/cloud1/wordpress/users/admin/credentials"
  description             = "WordPress admin credentials"
  recovery_window_in_days = 0
  kms_key_id              = module.kms.key_arn

  tags = {
    Name       = "${local.prefix}-wordpress-admin-credentials"
    git_commit = "442e87b23ae4faf0c9944bee932d85b94c780215"
    git_file   = "terraform/containers.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "wordpress_admin_credentials"
    yor_trace  = "62d00cae-755b-4969-bc3f-ddcd9dfb756d"
  }
}

ephemeral "random_password" "wordpress_admin_password" {
  length           = 32
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret_version" "wordpress_admin_credentials" {
  secret_id = aws_secretsmanager_secret.wordpress_admin_credentials.id

  secret_string_wo = jsonencode({
    username    = var.wp_admin_username
    admin_email = var.wp_admin_email
    password    = ephemeral.random_password.wordpress_admin_password.result
  })

  secret_string_wo_version = 1
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.5.0"

  name = "${local.prefix}-ecs-cluster"

  default_capacity_provider_strategy = {
    ec2 = {
      name   = "${local.prefix}-ecs-ec2"
      base   = 1
      weight = 1
    }
  }

  capacity_providers = {
    ec2 = {
      name = "${local.prefix}-ecs-ec2"

      auto_scaling_group_provider = {
        auto_scaling_group_arn         = module.ecs_autoscaling.autoscaling_group_arn
        managed_draining               = "DISABLED"
        managed_termination_protection = "DISABLED"

        managed_scaling = {
          maximum_scaling_step_size = 1
          minimum_scaling_step_size = 1
          status                    = "ENABLED"
          target_capacity           = 100
        }
      }
    }
  }

  create_task_exec_iam_role          = true
  create_task_exec_policy            = true
  task_exec_iam_role_name            = "${local.prefix}-ecs-execution"
  task_exec_iam_role_use_name_prefix = false
  task_exec_secret_arns = [
    module.aurora.cluster_master_user_secret[0].secret_arn,
  ]
  create_cloudwatch_log_group = false

  tags = {
    Name       = "${local.prefix}-ecs-cluster"
    git_commit = "N/A"
    git_file   = "terraform/containers.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "ecs_cluster"
    yor_trace  = "11595efb-5558-4616-88b7-630a1bfef7ad"
  }
}

module "ecs_service_wordpress" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  depends_on = [docker_registry_image.container]

  name        = "${local.prefix}-wordpress"
  family      = "${local.prefix}-wordpress"
  cluster_arn = module.ecs_cluster.arn

  cpu                      = null
  memory                   = null
  desired_count            = var.ecs_desired_count
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]

  capacity_provider_strategy = {
    ec2 = {
      capacity_provider = module.ecs_cluster.capacity_providers["ec2"].name
      base              = 1
      weight            = 1
    }
  }

  create_security_group          = false
  create_iam_role                = true
  create_task_exec_iam_role      = false
  create_tasks_iam_role          = true
  task_exec_iam_role_arn         = module.ecs_cluster.task_exec_iam_role_arn
  tasks_iam_role_name            = "${local.prefix}-wordpress-tasks"
  tasks_iam_role_use_name_prefix = false
  tasks_iam_role_statements = [
    {
      sid       = "ReadWordPressParameters"
      actions   = ["ssm:GetParameter", "ssm:GetParameters"]
      resources = [for parameter in values(aws_ssm_parameter.wordpress_runtime) : parameter.arn]
    },
    {
      sid       = "ReadWordPressAdminSecret"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [aws_secretsmanager_secret.wordpress_admin_credentials.arn]
    },
    {
      sid       = "DecryptWordPressRuntimeValues"
      actions   = ["kms:Decrypt"]
      resources = ["*"]
      condition = [{
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["ssm.${var.aws_region}.amazonaws.com", "secretsmanager.${var.aws_region}.amazonaws.com"]
      }]
    },
  ]

  health_check_grace_period_seconds  = 600
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  enable_autoscaling                 = true
  autoscaling_min_capacity           = var.ecs_desired_count
  autoscaling_max_capacity           = var.ecs_max_task_count
  autoscaling_policies = {
    requests = {
      policy_type = "TargetTrackingScaling"

      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ALBRequestCountPerTarget"
          resource_label         = "${module.alb.arn_suffix}/${module.alb.target_groups["wordpress"].arn_suffix}"
        }
        target_value       = var.ecs_autoscaling_requests_per_target
        scale_in_cooldown  = var.ecs_autoscaling_scale_in_cooldown
        scale_out_cooldown = var.ecs_autoscaling_scale_out_cooldown
      }
    }
  }
  force_delete         = true
  force_new_deployment = true
  propagate_tags       = "SERVICE"

  ordered_placement_strategy = [{
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }]

  placement_constraints = {
    distinct_instance = {
      type = "distinctInstance"
    }
  }

  load_balancer = {
    wordpress = {
      target_group_arn = module.alb.target_groups["wordpress"].arn
      container_name   = "wordpress"
      container_port   = 80
    }
  }

  volume = {
    wordpress_data = {
      name      = "wordpress-data"
      host_path = local.wordpress_host_path
    }
  }

  container_definitions = {
    wordpress = {
      name                   = "wordpress"
      image                  = local.managed_container_image_names.wordpress_apache
      essential              = true
      memoryReservation      = 256
      readonlyRootFilesystem = false

      secrets = [
        {
          name      = "WORDPRESS_DB_USER"
          valueFrom = "${module.aurora.cluster_master_user_secret[0].secret_arn}:username::"
        },
        {
          name      = "WORDPRESS_DB_PASSWORD"
          valueFrom = "${module.aurora.cluster_master_user_secret[0].secret_arn}:password::"
        },
      ]

      environment = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        },
        {
          name  = "PREFIX"
          value = local.prefix
        },
        {
          name  = "WORDPRESS_ADMIN_SECRET_ARN"
          value = aws_secretsmanager_secret.wordpress_admin_credentials.arn
        },
      ]

      portMappings = [{
        containerPort = 80
        hostPort      = 0
        protocol      = "tcp"
      }]

      mountPoints = [{
        sourceVolume  = "wordpress-data"
        containerPath = var.wordpress_shared_root
        readOnly      = false
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "test -f ${var.wordpress_shared_root}/healthz.php || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }

      enable_cloudwatch_logging              = true
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_name              = "/ecs/${local.prefix}-wordpress-apache"
      cloudwatch_log_group_use_name_prefix   = false
      cloudwatch_log_group_retention_in_days = 7

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.prefix}-wordpress-apache"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "wordpress-apache"
        }
      }
    }
  }

  tags = {
    Name       = "${local.prefix}-wordpress"
    git_commit = "442e87b23ae4faf0c9944bee932d85b94c780215"
    git_file   = "terraform/containers.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "ecs_service_wordpress"
    yor_trace  = "03bac99d-9a20-4341-b321-944597caca38"
  }
}

module "ecs_service_phpmyadmin" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  depends_on = [docker_registry_image.container]

  create = var.domain_name != null

  name        = "${local.prefix}-phpmyadmin"
  family      = "${local.prefix}-phpmyadmin"
  cluster_arn = module.ecs_cluster.arn

  cpu                      = null
  memory                   = null
  desired_count            = 1
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]

  capacity_provider_strategy = {
    ec2 = {
      capacity_provider = module.ecs_cluster.capacity_providers["ec2"].name
      base              = 1
      weight            = 1
    }
  }

  create_security_group     = false
  create_iam_role           = true
  create_task_exec_iam_role = false
  create_tasks_iam_role     = false
  task_exec_iam_role_arn    = module.ecs_cluster.task_exec_iam_role_arn

  health_check_grace_period_seconds  = 120
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200
  enable_autoscaling                 = false
  force_delete                       = true
  force_new_deployment               = true
  propagate_tags                     = "SERVICE"

  ordered_placement_strategy = [{
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }]

  load_balancer = {
    phpmyadmin = {
      target_group_arn = module.alb.target_groups["phpmyadmin"].arn
      container_name   = "phpmyadmin"
      container_port   = 80
    }
  }

  container_definitions = {
    phpmyadmin = {
      name                   = "phpmyadmin"
      image                  = local.managed_container_image_names.phpmyadmin
      essential              = true
      memoryReservation      = 128
      readonlyRootFilesystem = false

      environment = [
        {
          name  = "PMA_HOST"
          value = module.aurora.cluster_endpoint
        },
        {
          name  = "PMA_PORT"
          value = "3306"
        },
        {
          name  = "PMA_ARBITRARY"
          value = "0"
        },
        {
          name  = "PMA_ABSOLUTE_URI"
          value = "https://${local.phpmyadmin_domain_name}/"
        },
      ]

      portMappings = [{
        containerPort = 80
        hostPort      = 0
        protocol      = "tcp"
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      enable_cloudwatch_logging              = true
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_name              = "/ecs/${local.prefix}-phpmyadmin"
      cloudwatch_log_group_use_name_prefix   = false
      cloudwatch_log_group_retention_in_days = 7

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.prefix}-phpmyadmin"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "phpmyadmin"
        }
      }
    }
  }

  tags = {
    Name       = "${local.prefix}-phpmyadmin"
    git_commit = "442e87b23ae4faf0c9944bee932d85b94c780215"
    git_file   = "terraform/containers.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "ecs_service_phpmyadmin"
    yor_trace  = "9484a506-1414-4c51-b1ab-5c7a2d2ad0da"
  }
}
