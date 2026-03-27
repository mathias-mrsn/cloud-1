provider "aws" {
  region = var.region
}

provider "aws" {
  region = var.region
  alias  = "default"
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

provider "docker" {
  registry_auth {
    address  = data.aws_ecr_authorization_token.wordpress.proxy_endpoint
    username = data.aws_ecr_authorization_token.wordpress.user_name
    password = data.aws_ecr_authorization_token.wordpress.password
  }
}
