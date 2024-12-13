provider "aws" {
  region = var.region
  alias  = "default"
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

