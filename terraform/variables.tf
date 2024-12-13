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

# -----------------------------------------------------------------------------
# Auto Scaling Group
# -----------------------------------------------------------------------------

variable "asg_min" {
  description = "The minimum size of the auto-scaling group."
  type        = number
  default     = 1
}

variable "asg_max" {
  description = "The maximum size of the auto-scaling group."
  type        = number
  default     = 3
}

variable "instance_type" {
  description = "The instance type used by the auto-scaling group."
  type        = string
  default     = "t2.micro"
}

# -----------------------------------------------------------------------------
# WordPress
# -----------------------------------------------------------------------------

variable "wp_version" {
  description = "The version of WordPress to be installed."
  type        = string
  default     = "latest"
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
  description = "The email address for the WordPress administrator account. This address will also be used by SNS to send notifications about auto-scaling group changes."
  type        = string
}

variable "wp_admin_password" {
  description = "The password for the WordPress administrator account."
  type        = string
}

variable "wp_language" {
  description = "The language to be installed for WordPress."
  type        = string
  default     = "en_US"
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
