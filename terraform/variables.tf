variable "aws_region" {
  description = "The region where most resources will be deployed."
  type        = string
  default     = "eu-west-3"
}

variable "azs" {
  description = "The availability zones where WordPress will be placed. These zones must be within the specified region."
  type        = list(string)

  default = [
    "eu-west-3a",
    "eu-west-3b",
  ]

  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least 2 availability zones are required for the ALB and Aurora subnet group."
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
  description = "The number of WordPress tasks to keep running in ECS."
  type        = number
  default     = 2

  validation {
    condition     = var.ecs_desired_count >= 2
    error_message = "The ECS service must keep at least 2 tasks running."
  }
}

variable "wordpress_task_cpu" {
  description = "The CPU units allocated to the WordPress container in the main ECS task."
  type        = number
  default     = 256
}

variable "wordpress_task_memory" {
  description = "The memory in MiB allocated to the WordPress container in the main ECS task."
  type        = number
  default     = 512
}

variable "nginx_task_cpu" {
  description = "The CPU units allocated to the Nginx container in the main ECS task."
  type        = number
  default     = 256
}

variable "nginx_task_memory" {
  description = "The memory in MiB allocated to the Nginx container in the main ECS task."
  type        = number
  default     = 512
}

variable "ecs_instance_type" {
  description = "The EC2 instance type used by the ECS Auto Scaling group."
  type        = string
  default     = "t2.micro"
}

variable "ecs_root_volume_size" {
  description = "The root EBS volume size in GiB for ECS EC2 instances."
  type        = number
  default     = 30
}

variable "ecs_instance_min_size" {
  description = "The minimum number of EC2 instances in the ECS Auto Scaling group."
  type        = number
  default     = 2

  validation {
    condition     = var.ecs_instance_min_size > 0 && var.ecs_instance_min_size <= var.ecs_instance_desired_capacity
    error_message = "ecs_instance_min_size must be greater than 0 and lower than or equal to ecs_instance_desired_capacity."
  }
}

variable "ecs_instance_desired_capacity" {
  description = "The desired number of EC2 instances in the ECS Auto Scaling group."
  type        = number
  default     = 2

  validation {
    condition     = var.ecs_instance_desired_capacity >= var.ecs_desired_count
    error_message = "ecs_instance_desired_capacity must be greater than or equal to ecs_desired_count."
  }
}

variable "ecs_instance_max_size" {
  description = "The maximum number of EC2 instances in the ECS Auto Scaling group."
  type        = number
  default     = 3

  validation {
    condition     = var.ecs_instance_max_size >= var.ecs_instance_desired_capacity
    error_message = "ecs_instance_max_size must be greater than or equal to ecs_instance_desired_capacity."
  }
}

variable "phpmyadmin_subdomain" {
  description = "The subdomain used to expose phpMyAdmin when enabled."
  type        = string
  default     = "pma"
}

variable "phpmyadmin_task_cpu" {
  description = "The CPU units allocated to the phpMyAdmin ECS task."
  type        = number
  default     = 256
}

variable "phpmyadmin_task_memory" {
  description = "The memory in MiB allocated to the phpMyAdmin ECS task."
  type        = number
  default     = 512
}

variable "wordpress_shared_root" {
  description = "The path where the shared EFS WordPress content is mounted inside each container."
  type        = string
  default     = "/var/www/html"
}

variable "wp_language" {
  description = "The WordPress locale downloaded during bootstrap."
  type        = string
  default     = "en_US"
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

variable "backup_region" {
  description = "If set, EFS will create a replica in the specified region."
  type        = string
  default     = null
}
