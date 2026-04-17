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
    condition     = var.ecs_desired_count >= 2 && var.ecs_desired_count <= var.ecs_max_task_count
    error_message = "ecs_desired_count must be between 2 and ecs_max_task_count."
  }
}

variable "ecs_max_task_count" {
  description = "The maximum number of WordPress ECS tasks allowed for the service."
  type        = number
  default     = 4
}

variable "ecs_autoscaling_requests_per_target" {
  description = "The ALB request count per target used to autoscale the WordPress ECS service."
  type        = number
  default     = 50
}

variable "ecs_autoscaling_scale_in_cooldown" {
  description = "Cooldown in seconds before scaling in WordPress ECS tasks."
  type        = number
  default     = 60
}

variable "ecs_autoscaling_scale_out_cooldown" {
  description = "Cooldown in seconds before scaling out WordPress ECS tasks."
  type        = number
  default     = 60
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
