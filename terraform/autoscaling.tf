locals {
    domain_name = var.domain_name != null ? var.domain_name : module.cloudfront.cloudfront_distribution_domain_name
}

resource "aws_iam_policy" "asg-policy" {
  provider = aws.default

  name        = "AllowAuroraSecretAccess"
  path        = "/"
  description = "IAM Policy that allow the access to Aurora Secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = [module.aurora.cluster_master_user_secret[0].secret_arn]
      },
    ]
  })
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "8.0.0"

  providers = {
    aws = aws.default
  }

  name                   = "asg-${var.name}"
  vpc_zone_identifier    = module.vpc.private_subnets
  min_size               = var.asg_min
  max_size               = var.asg_max
  desired_capacity       = var.asg_min
  force_delete           = true
  create_launch_template = true

  create_iam_instance_profile = true
  iam_instance_profile_name   = "asg-profile-${var.name}"
  iam_role_description        = "IAM role used by ASG instances"
  iam_role_name               = "iam-${var.name}"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    Secret                       = aws_iam_policy.asg-policy.arn
  }
  iam_role_tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }

  launch_template_name        = "template-${var.name}"
  launch_template_description = "Launch template for ${var.name} instances"

  health_check_grace_period = 180
  health_check_type         = "EC2"

  instance_type = var.instance_type
  image_id      = "ami-0d3f86bfba5ee6472"

  user_data = base64encode(templatefile("./user_data/init.sh", {
    EfsId                          = module.efs.id,
    EfsDir                         = "/var/www/wordpress",
    Region                         = var.region,
    WPSubDirectory                 = "wp",
    WPLocale                       = var.wp_language,
    WPVersion                      = var.wp_version,
    DatabaseName                   = var.database_name,
    DatabaseSecretArn              = module.aurora.cluster_master_user_secret[0].secret_arn
    DatabaseClusterEndpointAddress = module.aurora.cluster_endpoint,
    WPTitle                        = var.wp_site_title,
    WPAdminUsername                = var.wp_admin_username,
    WPAdminPassword                = var.wp_admin_password,
    WPAdminEmail                   = var.wp_admin_email,
    WPDomainName                   = local.domain_name,
    ElasticCacheEndpoint           = module.elasticache.cluster_configuration_endpoint
  }))

  instance_name   = "i-${var.name}"
  security_groups = [module.autoscaling_sg.security_group_id]

  traffic_source_attachments = {
    loadbalancer = {
      traffic_source_identifier = module.alb.target_groups["wp_asg"].arn
      traffic_source_type       = "elbv2"
    }
  }

  block_device_mappings = [
    {
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 30
        volume_type           = "gp3"
      }
    }
  ]

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }

  depends_on = [
    module.efs,
    module.aurora,
    module.elasticache
  ]
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  providers = {
    aws = aws.default
  }

  name        = "asg-sg-${var.name}"
  description = "Autoscaling group security group"
  vpc_id      = module.vpc.vpc_id

  egress_rules = ["all-all"]
  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = 6
      description              = "Allow access for HTTP connection"
      source_security_group_id = module.alb.security_group_id
    },
  ]

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }

}

