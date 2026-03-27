<p align="center">
  <img src="./.images/banner.jpg" alt="banner">
</p>

---

> Complete WordPress architecture deployed on AWS.

## 🗂️ Table of Contents

* [⛔️ Warning](#-warning)
* [❓ What is it](#-what-is-it)
* [📊 Prerequisites](#-prerequisites)
* [🔧 Installation](#-installation)
* [🚀 Terraform Deployment](#-terraform-deployment)
* [🏫 42 Correction Deployment](#-42-correction-deployment)

## ⛔️ Warning

This architecture, once deployed, may incur costs as not all resources are covered under the AWS free tier. If you set the `domain_name` variable, ensure you have a hosted zone for this domain name in the same AWS account used to deploy the infrastructure.

## ❓ What is it

This project is designed to deploy a fully functional WordPress website using AWS as the cloud provider. The architecture ensures high availability, resilience to availability zone (AZ) failures, and scalability. The deployment is managed through Terraform and includes the following components:

![Architecture](./.images/archi.png)

### Architecture Breakdown

- **Route 53**: Amazon's DNS service for creating DNS records for your domain.
- **CloudFront**: Provides access to AWS edge locations for faster content delivery and caching of WordPress assets.
- **Application Load Balancer**: Routes traffic to the ECS service running WordPress.
- **Aurora Serverless Cluster**: A highly available, multi-AZ, fully managed MySQL database service.
- **ECS Fargate**: Runs two WordPress tasks across private subnets without managing EC2 instances.
- **Elastic File System (EFS)**: A shared file system for WordPress instances to access common resources.

## 📊 Prerequisites

Ensure the following tools are installed before deploying the architecture:

- [Terraform](https://www.terraform.io)
- [AWS CLI](https://github.com/aws/aws-cli)

## 🔧 Installation

### AWS CLI Configuration

Set up AWS CLI with your credentials:

```sh
aws configure
```

## 🚀 Terraform Deployment

### Initialization

Navigate to the `terraform/` directory and initialize the Terraform environment:

```sh
terraform init
```

### Pre-commit Checks

Install and run the repository hooks:

```sh
pre-commit install --install-hooks
pre-commit install --hook-type commit-msg
pre-commit run --all-files
```

### Terraform Variables

This section is generated automatically from the Terraform code.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

### Applying the Configuration

Deploy the infrastructure using:

```sh
terraform apply
```

### Outputs

After deployment, Terraform prints the generated outputs in the terminal. The inputs and outputs reference above is maintained automatically by `terraform-docs`.

### Running a Startup Script in the WordPress Container

You can define `wordpress_startup_script` to execute shell commands each time the WordPress container starts. The script runs just before Apache starts, so keep it idempotent.

```hcl
wordpress_startup_script = <<-EOT
  wp plugin is-installed redis-cache --path=/var/www/html --allow-root || \
    wp plugin install redis-cache --activate --path=/var/www/html --allow-root
EOT
```

### Destroying the Infrastructure

To delete all resources:

```sh
terraform destroy
```

## 🏫 42 Correction Deployment

To meet 42's requirements, you can deploy the architecture using a `docker-compose` file with Terraform's official Docker image.

### Initialization

1. Create a `.env` file based on `.env.template` and update it with your credentials.
2. Initialize the Terraform environment using Docker Compose:

```sh
docker-compose run --rm terraform init
```

### Applying the Configuration

Deploy the infrastructure with Docker Compose:

```sh
docker-compose run --rm terraform apply -auto-approve
```

### Destroying the Infrastructure

Delete all resources using Docker Compose:

```sh
docker-compose run --rm terraform destroy -auto-approve
```

## 👥 Authors

- [@mathias-mrsn](https://github.com/mathias-mrsn)
- [@xchalle](https://github.com/xchalle)
