terraform {
  required_version = "~> 1.13.4"

  backend "s3" {
    bucket  = "terraform-states-757244967855"
    key     = "cloud1/terraform.tfstate"
    region  = "eu-west-3"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.34"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  region = "us-east-1"
  alias  = "cloudfront"
}

provider "docker" {
  registry_auth {
    address  = trimprefix(data.aws_ecr_authorization_token.this.proxy_endpoint, "https://")
    username = data.aws_ecr_authorization_token.this.user_name
    password = data.aws_ecr_authorization_token.this.password
  }
}
