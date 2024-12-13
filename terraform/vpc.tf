locals {
  cidr = "10.0.0.0/16"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"

  providers = {
    aws = aws.default
  }

  name = "vpc-${var.name}"
  cidr = local.cidr
  azs  = var.azs

  private_subnets      = [for i, az in var.azs : cidrsubnet(local.cidr, 8, i)]
  private_subnet_names = [for i, az in var.azs : "${var.name}_private_${az}"]
  private_subnet_tags  = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }

  public_subnets      = [for i, az in var.azs : cidrsubnet(local.cidr, 8, i + 4)]
  public_subnet_names = [for i, az in var.azs : "${var.name}_public_${az}"]
  public_subnet_tags  = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }

  database_subnets      = [for i, az in var.azs : cidrsubnet(local.cidr, 8, i + 8)]
  database_subnet_names = [for i, az in var.azs : "${var.name}_database_${az}"]
  database_subnet_tags  = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }

  enable_dns_support = true
  enable_nat_gateway = true
  create_igw         = true

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }
}
