data "aws_ecr_authorization_token" "wordpress" {
  provider = aws.default
}

locals {
  wordpress_image_name = coalesce(var.wordpress_container_image, "${aws_ecr_repository.wordpress.repository_url}:latest")
  wordpress_build_files = concat(
    [".dockerignore"],
    tolist(fileset(path.root, "docker/wordpress/**"))
  )
  wordpress_build_hash = sha1(join("", [for file in local.wordpress_build_files : filesha1("${path.root}/${file}")]))
}

resource "aws_ecr_repository" "wordpress" {
  provider = aws.default

  name                 = "wordpress-${var.name}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Origin     = var.name
    DeployedBy = "Terraform"
  }
}

resource "docker_image" "wordpress" {
  name = local.wordpress_image_name

  build {
    context    = path.root
    dockerfile = "docker/wordpress/Dockerfile"
    platform   = "linux/amd64"
  }

  triggers = {
    source_hash = local.wordpress_build_hash
  }
}

resource "docker_registry_image" "wordpress" {
  name          = docker_image.wordpress.name
  keep_remotely = true

  triggers = {
    source_hash = local.wordpress_build_hash
  }
}

resource "random_password" "wordpress_auth_key" {
  length  = 64
  special = false
}

resource "random_password" "wordpress_secure_auth_key" {
  length  = 64
  special = false
}

resource "random_password" "wordpress_logged_in_key" {
  length  = 64
  special = false
}

resource "random_password" "wordpress_nonce_key" {
  length  = 64
  special = false
}

resource "random_password" "wordpress_auth_salt" {
  length  = 64
  special = false
}

resource "random_password" "wordpress_secure_auth_salt" {
  length  = 64
  special = false
}

resource "random_password" "wordpress_logged_in_salt" {
  length  = 64
  special = false
}

resource "random_password" "wordpress_nonce_salt" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "wordpress_admin_password" {
  provider = aws.default

  name                    = "wordpress-admin-password-${var.name}"
  description             = "WordPress admin password for ${var.name}"
  recovery_window_in_days = 0

  tags = {
    Origin     = var.name
    DeployedBy = "Terraform"
  }
}

ephemeral "random_password" "wordpress_admin_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret_version" "wordpress_admin_password" {
  provider = aws.default

  secret_id                = aws_secretsmanager_secret.wordpress_admin_password.id
  secret_string_wo         = ephemeral.random_password.wordpress_admin_password.result
  secret_string_wo_version = 1
}

locals {
  domain_name            = var.domain_name != null ? var.domain_name : module.cloudfront.cloudfront_distribution_domain_name
  phpmyadmin_enabled     = var.phpmyadmin_enabled && var.domain_name != null
  phpmyadmin_domain_name = local.phpmyadmin_enabled ? "${var.phpmyadmin_subdomain}.${var.domain_name}" : null
  ecs_tags = {
    Origin     = var.name
    DeployedBy = "Terraform"
  }
  ecs_cluster_arn = module.ecs_cluster.arn

  wordpress_service_name   = "wordpress-${var.name}"
  wordpress_task_family    = "wordpress-${var.name}"
  wordpress_container_name = "wordpress"
  wordpress_volume_name    = "wordpress-data"
  wordpress_log_group_name = "/ecs/${var.name}/wordpress"
  memcached_servers        = var.memcached_enabled ? [for node in aws_elasticache_cluster.memcached[0].cache_nodes : "${node.address}:${node.port}"] : []
  wordpress_environment = [
    {
      name  = "WORDPRESS_DB_HOST"
      value = module.aurora.cluster_endpoint
    },
    {
      name  = "WORDPRESS_DB_NAME"
      value = var.database_name
    },
    {
      name  = "WORDPRESS_TABLE_PREFIX"
      value = "wp_"
    },
    {
      name  = "WORDPRESS_SITE_TITLE"
      value = var.wp_site_title
    },
    {
      name  = "WORDPRESS_ADMIN_USER"
      value = var.wp_admin_username
    },
    {
      name  = "WORDPRESS_ADMIN_EMAIL"
      value = var.wp_admin_email
    },
    {
      name  = "WORDPRESS_VERSION"
      value = var.wp_version
    },
    {
      name  = "WORDPRESS_LOCALE"
      value = var.wp_language
    },
    {
      name  = "WORDPRESS_ENABLE_MEMCACHED"
      value = tostring(var.memcached_enabled)
    },
    {
      name  = "WORDPRESS_MEMCACHED_SERVERS"
      value = join(",", local.memcached_servers)
    },
    {
      name  = "WORDPRESS_SHARED_ROOT"
      value = var.wordpress_shared_root
    },
    {
      name  = "WORDPRESS_EFS_DIR"
      value = var.wordpress_shared_root
    },
    {
      name  = "WORDPRESS_SUBDIRECTORY"
      value = ""
    },
    {
      name  = "WORDPRESS_SITE_URL"
      value = "https://${local.domain_name}"
    },
    {
      name  = "WORDPRESS_SITE_HOST"
      value = local.domain_name
    },
    {
      name  = "WORDPRESS_AUTH_KEY"
      value = random_password.wordpress_auth_key.result
    },
    {
      name  = "WORDPRESS_SECURE_AUTH_KEY"
      value = random_password.wordpress_secure_auth_key.result
    },
    {
      name  = "WORDPRESS_LOGGED_IN_KEY"
      value = random_password.wordpress_logged_in_key.result
    },
    {
      name  = "WORDPRESS_NONCE_KEY"
      value = random_password.wordpress_nonce_key.result
    },
    {
      name  = "WORDPRESS_AUTH_SALT"
      value = random_password.wordpress_auth_salt.result
    },
    {
      name  = "WORDPRESS_SECURE_AUTH_SALT"
      value = random_password.wordpress_secure_auth_salt.result
    },
    {
      name  = "WORDPRESS_LOGGED_IN_SALT"
      value = random_password.wordpress_logged_in_salt.result
    },
    {
      name  = "WORDPRESS_NONCE_SALT"
      value = random_password.wordpress_nonce_salt.result
    },
    {
      name  = "AWS_REGION"
      value = var.region
    },
    {
      name  = "WORDPRESS_READINESS_FILE"
      value = "${var.wordpress_shared_root}/.health/ready"
    },
  ]
  wordpress_secrets = [
    {
      name      = "WORDPRESS_DB_USER"
      valueFrom = "${module.aurora.cluster_master_user_secret[0].secret_arn}:username::"
    },
    {
      name      = "WORDPRESS_DB_PASSWORD"
      valueFrom = "${module.aurora.cluster_master_user_secret[0].secret_arn}:password::"
    },
    {
      name      = "WORDPRESS_ADMIN_PASSWORD"
      valueFrom = aws_secretsmanager_secret.wordpress_admin_password.arn
    },
  ]

  phpmyadmin_service_name   = "phpmyadmin-${var.name}"
  phpmyadmin_task_family    = "phpmyadmin-${var.name}"
  phpmyadmin_container_name = "phpmyadmin"
  phpmyadmin_log_group_name = "/ecs/${var.name}/phpmyadmin"
}

resource "aws_security_group" "ecs_tasks" {
  provider = aws.default

  name        = "ecs-tasks-${var.name}"
  description = "Security group for ECS Fargate WordPress tasks"
  vpc_id      = module.vpc.vpc_id

  tags = local.ecs_tags
}

resource "aws_vpc_security_group_ingress_rule" "ecs_tasks_from_alb" {
  provider = aws.default

  security_group_id            = aws_security_group.ecs_tasks.id
  referenced_security_group_id = module.alb.security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow HTTP from the ALB"
}

resource "aws_vpc_security_group_egress_rule" "ecs_tasks_all" {
  provider = aws.default

  security_group_id = aws_security_group.ecs_tasks.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.5.0"

  providers = {
    aws = aws.default
  }

  name = "cluster-${var.name}"

  create_task_exec_iam_role          = true
  create_task_exec_policy            = true
  task_exec_iam_role_name            = "ecs-execution-${var.name}"
  task_exec_iam_role_use_name_prefix = false
  task_exec_secret_arns = [
    module.aurora.cluster_master_user_secret[0].secret_arn,
    aws_secretsmanager_secret.wordpress_admin_password.arn,
  ]
  create_cloudwatch_log_group = false

  tags = local.ecs_tags
}

module "ecs_service_wordpress" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  providers = {
    aws = aws.default
  }

  name        = local.wordpress_service_name
  family      = local.wordpress_task_family
  cluster_arn = module.ecs_cluster.arn

  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  desired_count            = var.ecs_desired_count
  launch_type              = "FARGATE"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  assign_public_ip       = false
  subnet_ids             = module.vpc.private_subnets
  security_group_ids     = [aws_security_group.ecs_tasks.id]
  enable_execute_command = false
  enable_autoscaling     = false

  create_security_group     = false
  create_iam_role           = false
  create_task_exec_iam_role = false
  create_tasks_iam_role     = false
  task_exec_iam_role_arn    = module.ecs_cluster.task_exec_iam_role_arn

  health_check_grace_period_seconds  = 600
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  force_new_deployment               = true
  propagate_tags                     = "SERVICE"

  load_balancer = {
    wordpress = {
      target_group_arn = module.alb.target_groups["wordpress"].arn
      container_name   = local.wordpress_container_name
      container_port   = 80
    }
  }

  volume = {
    wordpress_data = {
      name = local.wordpress_volume_name

      efs_volume_configuration = {
        file_system_id     = module.efs.id
        root_directory     = "/"
        transit_encryption = "ENABLED"

        authorization_config = {
          access_point_id = aws_efs_access_point.wordpress.id
          iam             = "DISABLED"
        }
      }
    }
  }

  container_definitions = {
    wordpress = {
      name                   = local.wordpress_container_name
      image                  = local.wordpress_image_name
      essential              = true
      cpu                    = var.ecs_task_cpu
      memory                 = var.ecs_task_memory
      readonlyRootFilesystem = false
      secrets                = local.wordpress_secrets
      environment            = local.wordpress_environment

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        },
      ]

      mountPoints = [
        {
          sourceVolume  = local.wordpress_volume_name
          containerPath = var.wordpress_shared_root
          readOnly      = false
        },
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/healthz.php || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }

      enable_cloudwatch_logging              = true
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_name              = local.wordpress_log_group_name
      cloudwatch_log_group_use_name_prefix   = false
      cloudwatch_log_group_retention_in_days = 7

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.wordpress_log_group_name
          awslogs-region        = var.region
          awslogs-stream-prefix = "wordpress"
        }
      }
    }
  }

  tags = local.ecs_tags
}

module "ecs_service_phpmyadmin" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "7.5.0"

  providers = {
    aws = aws.default
  }

  create = local.phpmyadmin_enabled

  name        = local.phpmyadmin_service_name
  family      = local.phpmyadmin_task_family
  cluster_arn = module.ecs_cluster.arn

  cpu                      = var.phpmyadmin_task_cpu
  memory                   = var.phpmyadmin_task_memory
  desired_count            = 1
  launch_type              = "FARGATE"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  assign_public_ip       = false
  subnet_ids             = module.vpc.private_subnets
  security_group_ids     = [aws_security_group.ecs_tasks.id]
  enable_execute_command = false
  enable_autoscaling     = false

  create_security_group     = false
  create_iam_role           = false
  create_task_exec_iam_role = false
  create_tasks_iam_role     = false
  task_exec_iam_role_arn    = module.ecs_cluster.task_exec_iam_role_arn

  health_check_grace_period_seconds  = 120
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200
  force_new_deployment               = true
  propagate_tags                     = "SERVICE"

  load_balancer = {
    phpmyadmin = {
      target_group_arn = module.alb.target_groups["phpmyadmin"].arn
      container_name   = local.phpmyadmin_container_name
      container_port   = 80
    }
  }

  container_definitions = {
    phpmyadmin = {
      name                   = local.phpmyadmin_container_name
      image                  = var.phpmyadmin_container_image
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
          value = "http://${local.phpmyadmin_domain_name}/"
        },
      ]

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        },
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }

      enable_cloudwatch_logging              = true
      create_cloudwatch_log_group            = true
      cloudwatch_log_group_name              = local.phpmyadmin_log_group_name
      cloudwatch_log_group_use_name_prefix   = false
      cloudwatch_log_group_retention_in_days = 7

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.phpmyadmin_log_group_name
          awslogs-region        = var.region
          awslogs-stream-prefix = "phpmyadmin"
        }
      }
    }
  }

  tags = local.ecs_tags
}
