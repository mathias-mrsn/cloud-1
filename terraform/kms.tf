module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.0"

  providers = {
    aws = aws.default
  }

  aliases               = ["${var.name}/efs"]
  description           = "KMS Key used by EFS Storage - ${var.name}"
  enable_default_policy = true

  deletion_window_in_days = 7

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }
}
