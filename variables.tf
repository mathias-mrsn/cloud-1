# Credentials

variable "iam_user" {
  description = "user directory where your credentials are stored"
  type        = string
  default     = "default"
}

variable "creds_user_path" {
  description = "directory where every user creds directory are listed"
  type        = string
  default     = "credentials/aws_creds"
}
