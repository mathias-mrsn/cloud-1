locals {
  managed_container_build_paths = concat(
    [
      "${local.repository_root}/.dockerignore",
      "${local.repository_root}/Makefile",
      "${local.repository_root}/docker-compose.yaml",
    ],
    [for file in fileset(local.repository_root, "docker/wordpress/**") : "${local.repository_root}/${file}"],
    [for file in fileset(local.repository_root, "docker/nginx/**") : "${local.repository_root}/${file}"],
    [for file in fileset(local.repository_root, "docker/phpmyadmin/**") : "${local.repository_root}/${file}"]
  )

  managed_container_build_hash = sha1(join("", [for file in local.managed_container_build_paths : filesha1(file)]))

  managed_container_image_names = {
    wordpress  = format("%s:latest", aws_ecr_repository.container["wordpress"].repository_url)
    nginx      = format("%s:latest", aws_ecr_repository.container["nginx"].repository_url)
    phpmyadmin = format("%s:latest", aws_ecr_repository.container["phpmyadmin"].repository_url)
  }
}

resource "aws_ecr_repository" "container" {
  for_each = toset(["nginx", "wordpress", "phpmyadmin"])

  name         = "${local.prefix}-${each.value}"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.prefix}-${each.value}"
  }
}

resource "terraform_data" "container_images_build" {

  triggers_replace = [
    local.managed_container_build_hash,
    local.managed_container_image_names.wordpress,
    local.managed_container_image_names.nginx,
    local.managed_container_image_names.phpmyadmin,
  ]

  provisioner "local-exec" {
    command     = "make docker-build WORDPRESS_IMAGE_NAME=${local.managed_container_image_names.wordpress} NGINX_IMAGE_NAME=${local.managed_container_image_names.nginx} PHPMYADMIN_IMAGE_NAME=${local.managed_container_image_names.phpmyadmin} DOCKER_PLATFORM=linux/amd64"
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

  tags = {
    Name = "${local.prefix}-wordpress-admin-credentials"
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
    admin_user  = var.wp_admin_username
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
    Name = "${local.prefix}-ecs-cluster"
  }
}

module "ecs_service_wordpress" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  depends_on = [docker_registry_image.container]

  name        = "${local.prefix}-wordpress"
  family      = "${local.prefix}-wordpress"
  cluster_arn = module.ecs_cluster.arn

  cpu                      = var.wordpress_task_cpu + var.nginx_task_cpu
  memory                   = var.wordpress_task_memory + var.nginx_task_memory
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
  force_delete                       = true
  force_new_deployment               = true
  propagate_tags                     = "SERVICE"

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
      container_name   = "nginx"
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
      image                  = local.managed_container_image_names.wordpress
      essential              = true
      cpu                    = var.wordpress_task_cpu
      memory                 = var.wordpress_task_memory
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
        containerPort = 9000
        hostPort      = 0
        protocol      = "tcp"
      }]

      mountPoints = [{
        sourceVolume  = "wordpress-data"
        containerPath = var.wordpress_shared_root
        readOnly      = false
      }]

      healthCheck = {
        command     = ["CMD-SHELL", "php-fpm -t || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }

      enable_cloudwatch_logging              = true
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_name              = "/ecs/${local.prefix}-wordpress"
      cloudwatch_log_group_use_name_prefix   = false
      cloudwatch_log_group_retention_in_days = 7

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.prefix}-wordpress"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "wordpress"
        }
      }
    }

    nginx = {
      name                   = "nginx"
      image                  = local.managed_container_image_names.nginx
      essential              = true
      cpu                    = var.nginx_task_cpu
      memory                 = var.nginx_task_memory
      readonlyRootFilesystem = false

      dependsOn = [{
        containerName = "wordpress"
        condition     = "HEALTHY"
      }]

      links = ["wordpress"]

      environment = [
        {
          name  = "WORDPRESS_DOCUMENT_ROOT"
          value = var.wordpress_shared_root
        },
        {
          name  = "WORDPRESS_FPM_HOST"
          value = "wordpress:9000"
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
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost/healthz.php || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }

      enable_cloudwatch_logging              = true
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_name              = "/ecs/${local.prefix}-nginx"
      cloudwatch_log_group_use_name_prefix   = false
      cloudwatch_log_group_retention_in_days = 7

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.prefix}-nginx"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "nginx"
        }
      }
    }
  }

  tags = {
    Name = "${local.prefix}-wordpress"
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

  cpu                      = var.phpmyadmin_task_cpu
  memory                   = var.phpmyadmin_task_memory
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
      cpu                    = var.phpmyadmin_task_cpu
      memory                 = var.phpmyadmin_task_memory
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
    Name = "${local.prefix}-phpmyadmin"
  }
}
