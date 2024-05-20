module "credentials" {
  source = "./modules/credentials"

  iam_user = var.iam_user
  creds_user_path = var.creds_user_path
}

module "vpc" {
  source = "./modules/vpc"
}

provider "aws" {
   access_key = module.credentials.aws_access_key
   secret_key = module.credentials.aws_secret_key
   region = "eu-west-1"
}
