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
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
