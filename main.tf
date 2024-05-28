module "credentials" {
  source = "./modules/credentials"

  iam_user = var.iam_user
  creds_user_path = var.creds_user_path
}


provider "aws" {
   # access_key = module.credentials.aws_access_key
   # access_key = "AKIA3AT2RHOX2SDRSX7G"
   # secret_key = module.credentials.aws_secret_key
   # secret_key = "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"

  shared_credentials_files = ["credentials/aws_creds/mamaurai/creds"]
   region = "eu-west-3"
}
module "vpc" { source = "./modules/vpc" }
