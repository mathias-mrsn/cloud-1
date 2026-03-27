variable "name" {
  description = "The name used for all resources."
  type        = string
  default     = "wordpress"

  validation {
    condition     = length(var.name) > 6
    error_message = "The project name must be at least 7 characters long."
  }
}

variable "region" {
  description = "The region where most resources will be deployed."
  type        = string
  default     = "eu-west-3"
}

variable "azs" {
  description = "The availability zones where WordPress will be placed. These zones must be within the specified region."
  type        = list(string)
  default     = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]

  validation {
    condition     = length(var.azs) > 1
    error_message = "You must specify at least 2 availability zones."
  }
}

variable "domain_name" {
  description = "The domain name where a new record pointing to the CloudFront distribution will be created. If not null, ensure that a hosted zone already exists in your account."
  type        = string
  default     = null
}

variable "distribution_price_class" {
  description = "The price class for this distribution. Valid options are PriceClass_All, PriceClass_200, and PriceClass_100."
  type        = string
  default     = null
}

variable "ecs_desired_count" {
  description = "The number of WordPress tasks to keep running in ECS Fargate."
  type        = number
  default     = 2

  validation {
    condition     = var.ecs_desired_count >= 2
    error_message = "The ECS service must keep at least 2 tasks running."
  }
}

variable "ecs_task_cpu" {
  description = "The CPU units allocated to each WordPress ECS Fargate task."
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "The memory in MiB allocated to each WordPress ECS Fargate task."
  type        = number
  default     = 512
}

variable "ecs_instance_type" {
  description = "Deprecated. Former ECS on EC2 instance type input kept temporarily to avoid tfvars warnings during the Fargate rollback."
  type        = string
  default     = null
}

variable "ecs_root_volume_size" {
  description = "Deprecated. Former ECS on EC2 root volume size input kept temporarily to avoid tfvars warnings during the Fargate rollback."
  type        = number
  default     = null
}

variable "wordpress_container_image" {
  description = "Optional override for the WordPress container image. Leave null to use the Terraform-managed ECR image."
  type        = string
  default     = null
}

variable "phpmyadmin_enabled" {
  description = "Whether to deploy a dedicated phpMyAdmin Fargate service. Requires domain_name to expose it via a subdomain."
  type        = bool
  default     = false
}

variable "phpmyadmin_subdomain" {
  description = "The subdomain used to expose phpMyAdmin when enabled."
  type        = string
  default     = "pma"
}

variable "phpmyadmin_container_image" {
  description = "The container image used for phpMyAdmin."
  type        = string
  default     = "phpmyadmin:5.2.2-apache"
}

variable "phpmyadmin_task_cpu" {
  description = "The CPU units allocated to the phpMyAdmin ECS Fargate task."
  type        = number
  default     = 256
}

variable "phpmyadmin_task_memory" {
  description = "The memory in MiB allocated to the phpMyAdmin ECS Fargate task."
  type        = number
  default     = 512
}

variable "wordpress_shared_root" {
  description = "The path where the shared EFS WordPress content is mounted inside each container."
  type        = string
  default     = "/var/www/html"
}

variable "wp_version" {
  description = "The WordPress version downloaded during bootstrap."
  type        = string
  default     = "latest"
}

variable "wp_language" {
  description = "The WordPress locale downloaded during bootstrap."
  type        = string
  default     = "en_US"
}

variable "memcached_enabled" {
  description = "Whether to restore the Memcached cache layer and configure WordPress to use it."
  type        = bool
  default     = false
}

variable "memcached_node_type" {
  description = "The ElastiCache node type used for WordPress Memcached."
  type        = string
  default     = "cache.t4g.small"
}

variable "memcached_num_cache_nodes" {
  description = "The number of Memcached nodes to run across availability zones."
  type        = number
  default     = 3
}

variable "wp_site_title" {
  description = "The title of the WordPress website."
  type        = string
  default     = "website"
}

variable "wp_admin_username" {
  description = "The username for the WordPress administrator account."
  type        = string
  default     = "admin"
}

variable "wp_admin_email" {
  description = "The email address for the WordPress administrator account."
  type        = string
}

# -----------------------------------------------------------------------------
# Aurora
# -----------------------------------------------------------------------------

variable "mysql_version" {
  description = "The MySQL version used by Aurora."
  type        = string
  default     = "8.0"
}

variable "aurora_master_username" {
  description = "The MySQL master username for connecting to the database."
  type        = string
  default     = "master"
}

variable "aurora_min_capacity" {
  description = "The minimum capacity of the Aurora cluster."
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "The maximum capacity of the Aurora cluster."
  type        = number
  default     = 1
}

variable "database_name" {
  description = "The name of the MySQL database."
  type        = string
  default     = "wordpress"
}

variable "aurora_instances" {
  description = "The Aurora instances used by the Aurora Serverless cluster."
  type        = map(any)
  default     = { one = {} }
}

variable "aurora_skip_final_snapshot" {
  description = "Whether to skip the final snapshot before deleting the cluster."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# EFS
# -----------------------------------------------------------------------------

variable "backup_region" {
  description = "If set, EFS will create a replica in the specified region."
  type        = string
  default     = null
}
