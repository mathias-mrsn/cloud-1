locals {
  aws_access_key = file("${path.cwd}/${var.creds_user_path}/${var.iam_user}/access.creds")
}

locals {
  aws_secret_key = file("${path.cwd}/${var.creds_user_path}/${var.iam_user}/secret.creds")
}
