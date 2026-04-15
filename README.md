<p align="center">
  <img src="./.images/banner.jpg" alt="banner">
</p>

> Deploys a highly available WordPress platform on AWS with Terraform, plus a local Docker workflow for manual testing.

[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)
![Terraform](https://img.shields.io/badge/Terraform_version-~%3E1.13.4-blue)
![AWS Provider](https://img.shields.io/badge/AWS_provider-~%3E6.34-blue)

## Table of Contents

<!--TOC-->

- [Table of Contents](#table-of-contents)
- [⛔️ Warning](#-warning)
- [Introduction](#introduction)
- [Infrastructure diagram](#infrastructure-diagram)
- [⚠️ Important notes](#-important-notes)
- [Architecture overview](#architecture-overview)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [1. Configure AWS access](#1-configure-aws-access)
  - [2. Review your Terraform variables](#2-review-your-terraform-variables)
  - [3. Initialize Terraform](#3-initialize-terraform)
  - [4. Plan the infrastructure](#4-plan-the-infrastructure)
  - [5. Apply the infrastructure](#5-apply-the-infrastructure)
  - [6. Destroy the infrastructure](#6-destroy-the-infrastructure)
- [Local Docker workflow](#local-docker-workflow)
  - [Prerequisites](#prerequisites-1)
  - [1. Create your local .env file](#1-create-your-local-env-file)
  - [2. Start the local stack](#2-start-the-local-stack)
  - [3. Stop or reset the local stack](#3-stop-or-reset-the-local-stack)
- [Load testing](#load-testing)
- [Terraform docs](#terraform-docs)

<!--TOC-->

## ⛔️ Warning

The sharing of this project on my GitHub aims to help peoples to open their minds to new logics or help peoples in case of difficulty. In no way, that aims to copy and paste this work on your own repository.

## Introduction

The aim of this project is to create and deploy a WordPress architecture in the cloud. The goal of deploying this kind of architecture in the cloud is to have a solution that can automatically scale in and out based on the current load, ensure high availability, take advantage of major cloud provider managed services, and avoid having to keep your Mac on all day to host your website.

In this project, you will find an architecture hosted on AWS and deployed using Terraform that aims to accomplish all the key points previously mentioned about the cloud.

## Infrastructure diagram

![Infrastructure Diagram](./.images/archi.png)

## ⚠️ Important notes

**AWS costs**: this infrastructure is not limited to free-tier resources. Running the full stack can incur charges.

**Hosted zone requirement**: the domain used in `domain_name` must already exist as a Route53 hosted zone in the same AWS account.

## Architecture overview

The currently deployed traffic paths are:

- `mamaurai.fr`
  - Route53 → CloudFront → ALB → WordPress ECS service
- `pma.mamaurai.fr`
  - Route53 → CloudFront → ALB → phpMyAdmin ECS service
- `performance.mamaurai.fr`
  - Route53 → direct HTTPS to ALB → WordPress ECS service

WordPress containers run on **ECS EC2 instances** in private subnets.

- The EC2 instances mount **EFS** on the host.
- WordPress uses the shared EFS content path from the host.
- WordPress connects to **Aurora MySQL** in the database subnets.

## Installation

### Prerequisites

Before deploying the AWS infrastructure, make sure you have:

| Requirement | Description |
|-------------|-------------|
| Terraform | Version `~> 1.13.4` |
| AWS CLI | Configured with credentials that can create the deployed resources |
| Docker | Required for local image builds during Terraform apply |
| jq | Used by Make and helper scripts |
| Route53 hosted zone | Must already exist for the chosen public domain |

### 1. Configure AWS access

Configure the AWS CLI with credentials that can manage the full infrastructure:

```sh
aws configure
```

### 2. Review your Terraform variables

The repository uses:

```text
terraform/main.auto.tfvars.json
```

Review it carefully before deployment.

### 3. Initialize Terraform

```sh
make terraform-init
```

### 4. Plan the infrastructure

```sh
make terraform-plan
```

### 5. Apply the infrastructure

```sh
make terraform-apply
```

### 6. Destroy the infrastructure

```sh
make terraform-destroy
```

## Local Docker workflow

### Prerequisites

The local stack uses Docker Compose and a local MySQL container.

### 1. Create your local .env file

Create a local `.env` file from the template:

```sh
cp .env.template .env
```

Then set at minimum:

```env
ENABLE_LOCAL_STACK=true
```

You can also provide AWS credentials in `.env` if you want the local WordPress bootstrap to fetch secrets and SSM parameters.

### 2. Start the local stack

```sh
make docker-up ENABLE_LOCAL_STACK=true
```

Local entrypoints:

- WordPress: `http://localhost:8080`
- phpMyAdmin: `http://localhost:8081`

### 3. Stop or reset the local stack

Stop the stack:

```sh
make docker-down ENABLE_LOCAL_STACK=true
```

Rebuild and restart it:

```sh
make docker-reset ENABLE_LOCAL_STACK=true
```

If you want logs in the foreground when starting the stack:

```sh
make docker-up ENABLE_LOCAL_STACK=true DETACH_CONTAINERS=false
```

## Load testing

The repository includes a `siege` target for quick load tests.

Default usage:

```sh
make siege
```

Example against the performance hostname:

```sh
make siege SIEGE_CONCURRENCY=80 SIEGE_DURATION=10M SIEGE_DELAY=0
```

Useful variables:

- `SIEGE_URL`
- `SIEGE_CONCURRENCY`
- `SIEGE_DURATION`
- `SIEGE_DELAY`
- `SIEGE_FILE`

## Terraform docs

_This section is intended for generated Terraform documentation._

<!-- BEGIN_TF_DOCS -->
_This section is generated automatically from the Terraform code._

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.13.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.34 |
| <a name="requirement_docker"></a> [docker](#requirement\_docker) | ~> 3.6 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.40.0 |
| <a name="provider_docker"></a> [docker](#provider\_docker) | 3.9.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | 6.3.0 |
| <a name="module_acm_alb"></a> [acm\_alb](#module\_acm\_alb) | terraform-aws-modules/acm/aws | 6.3.0 |
| <a name="module_alb"></a> [alb](#module\_alb) | terraform-aws-modules/alb/aws | 10.5.0 |
| <a name="module_aurora"></a> [aurora](#module\_aurora) | terraform-aws-modules/rds-aurora/aws | 10.2.0 |
| <a name="module_cloudfront"></a> [cloudfront](#module\_cloudfront) | terraform-aws-modules/cloudfront/aws | 6.4.0 |
| <a name="module_ecs_autoscaling"></a> [ecs\_autoscaling](#module\_ecs\_autoscaling) | terraform-aws-modules/autoscaling/aws | ~> 9.0 |
| <a name="module_ecs_cluster"></a> [ecs\_cluster](#module\_ecs\_cluster) | terraform-aws-modules/ecs/aws//modules/cluster | 7.5.0 |
| <a name="module_ecs_service_phpmyadmin"></a> [ecs\_service\_phpmyadmin](#module\_ecs\_service\_phpmyadmin) | terraform-aws-modules/ecs/aws//modules/service | 7.5.0 |
| <a name="module_ecs_service_wordpress"></a> [ecs\_service\_wordpress](#module\_ecs\_service\_wordpress) | terraform-aws-modules/ecs/aws//modules/service | 7.5.0 |
| <a name="module_efs"></a> [efs](#module\_efs) | terraform-aws-modules/efs/aws | 2.2.0 |
| <a name="module_kms"></a> [kms](#module\_kms) | terraform-aws-modules/kms/aws | 4.2.0 |
| <a name="module_records_domaine_to_main_zone"></a> [records\_domaine\_to\_main\_zone](#module\_records\_domaine\_to\_main\_zone) | terraform-aws-modules/route53/aws | 6.4.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 6.6.0 |
| <a name="module_vpc_endpoints"></a> [vpc\_endpoints](#module\_vpc\_endpoints) | terraform-aws-modules/vpc/aws//modules/vpc-endpoints | 6.6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_ecr_repository.container](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_efs_access_point.wordpress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point) | resource |
| [aws_secretsmanager_secret.wordpress_admin_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.wordpress_admin_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.ecs_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.wordpress_runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_egress_rule.ecs_instances_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.ecs_instances_from_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [docker_registry_image.container](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/registry_image) | resource |
| [random_password.wordpress_secret_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [terraform_data.container_images_build](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_ami.ecs_ubuntu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_cloudfront_cache_policy.caching_disabled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_cache_policy.caching_optimized](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy) | data source |
| [aws_cloudfront_origin_request_policy.all_viewer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_origin_request_policy) | data source |
| [aws_ecr_authorization_token.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |
| [aws_route53_zone.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aurora_instances"></a> [aurora\_instances](#input\_aurora\_instances) | The Aurora instances used by the Aurora Serverless cluster. | `map(any)` | <pre>{<br/>  "one": {}<br/>}</pre> | no |
| <a name="input_aurora_master_username"></a> [aurora\_master\_username](#input\_aurora\_master\_username) | The MySQL master username for connecting to the database. | `string` | `"master"` | no |
| <a name="input_aurora_max_capacity"></a> [aurora\_max\_capacity](#input\_aurora\_max\_capacity) | The maximum capacity of the Aurora cluster. | `number` | `1` | no |
| <a name="input_aurora_min_capacity"></a> [aurora\_min\_capacity](#input\_aurora\_min\_capacity) | The minimum capacity of the Aurora cluster. | `number` | `0.5` | no |
| <a name="input_aurora_skip_final_snapshot"></a> [aurora\_skip\_final\_snapshot](#input\_aurora\_skip\_final\_snapshot) | Whether to skip the final snapshot before deleting the cluster. | `bool` | `false` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The region where most resources will be deployed. | `string` | `"eu-west-3"` | no |
| <a name="input_azs"></a> [azs](#input\_azs) | The availability zones where WordPress will be placed. These zones must be within the specified region. | `list(string)` | <pre>[<br/>  "eu-west-3a",<br/>  "eu-west-3b"<br/>]</pre> | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | The name of the MySQL database. | `string` | `"wordpress"` | no |
| <a name="input_distribution_price_class"></a> [distribution\_price\_class](#input\_distribution\_price\_class) | The price class for this distribution. Valid options are PriceClass\_All, PriceClass\_200, and PriceClass\_100. | `string` | `null` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | The domain name where a new record pointing to the CloudFront distribution will be created. If not null, ensure that a hosted zone already exists in your account. | `string` | `null` | no |
| <a name="input_ecs_autoscaling_requests_per_target"></a> [ecs\_autoscaling\_requests\_per\_target](#input\_ecs\_autoscaling\_requests\_per\_target) | The ALB request count per target used to autoscale the WordPress ECS service. | `number` | `200` | no |
| <a name="input_ecs_autoscaling_scale_in_cooldown"></a> [ecs\_autoscaling\_scale\_in\_cooldown](#input\_ecs\_autoscaling\_scale\_in\_cooldown) | Cooldown in seconds before scaling in WordPress ECS tasks. | `number` | `60` | no |
| <a name="input_ecs_autoscaling_scale_out_cooldown"></a> [ecs\_autoscaling\_scale\_out\_cooldown](#input\_ecs\_autoscaling\_scale\_out\_cooldown) | Cooldown in seconds before scaling out WordPress ECS tasks. | `number` | `60` | no |
| <a name="input_ecs_desired_count"></a> [ecs\_desired\_count](#input\_ecs\_desired\_count) | The number of WordPress tasks to keep running in ECS. | `number` | `2` | no |
| <a name="input_ecs_instance_desired_capacity"></a> [ecs\_instance\_desired\_capacity](#input\_ecs\_instance\_desired\_capacity) | The desired number of EC2 instances in the ECS Auto Scaling group. | `number` | `2` | no |
| <a name="input_ecs_instance_max_size"></a> [ecs\_instance\_max\_size](#input\_ecs\_instance\_max\_size) | The maximum number of EC2 instances in the ECS Auto Scaling group. | `number` | `3` | no |
| <a name="input_ecs_instance_min_size"></a> [ecs\_instance\_min\_size](#input\_ecs\_instance\_min\_size) | The minimum number of EC2 instances in the ECS Auto Scaling group. | `number` | `2` | no |
| <a name="input_ecs_instance_type"></a> [ecs\_instance\_type](#input\_ecs\_instance\_type) | The EC2 instance type used by the ECS Auto Scaling group. | `string` | `"t2.micro"` | no |
| <a name="input_ecs_max_task_count"></a> [ecs\_max\_task\_count](#input\_ecs\_max\_task\_count) | The maximum number of WordPress ECS tasks allowed for the service. | `number` | `4` | no |
| <a name="input_ecs_root_volume_size"></a> [ecs\_root\_volume\_size](#input\_ecs\_root\_volume\_size) | The root EBS volume size in GiB for ECS EC2 instances. | `number` | `30` | no |
| <a name="input_mysql_version"></a> [mysql\_version](#input\_mysql\_version) | The MySQL version used by Aurora. | `string` | `"8.0"` | no |
| <a name="input_performance_subdomain"></a> [performance\_subdomain](#input\_performance\_subdomain) | The subdomain used to expose the direct ALB performance testing endpoint. | `string` | `"performance"` | no |
| <a name="input_phpmyadmin_subdomain"></a> [phpmyadmin\_subdomain](#input\_phpmyadmin\_subdomain) | The subdomain used to expose phpMyAdmin when enabled. | `string` | `"pma"` | no |
| <a name="input_wordpress_shared_root"></a> [wordpress\_shared\_root](#input\_wordpress\_shared\_root) | The path where the shared EFS WordPress content is mounted inside each container. | `string` | `"/var/www/html"` | no |
| <a name="input_wp_admin_email"></a> [wp\_admin\_email](#input\_wp\_admin\_email) | The email address for the WordPress administrator account. | `string` | n/a | yes |
| <a name="input_wp_admin_username"></a> [wp\_admin\_username](#input\_wp\_admin\_username) | The username for the WordPress administrator account. | `string` | `"admin"` | no |
| <a name="input_wp_language"></a> [wp\_language](#input\_wp\_language) | The WordPress locale downloaded during bootstrap. | `string` | `"en_US"` | no |
| <a name="input_wp_site_title"></a> [wp\_site\_title](#input\_wp\_site\_title) | The title of the WordPress website. | `string` | `"website"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aurora_cluster_endpoint"></a> [aurora\_cluster\_endpoint](#output\_aurora\_cluster\_endpoint) | The Aurora cluster writer endpoint. |
| <a name="output_cloudffront_url"></a> [cloudffront\_url](#output\_cloudffront\_url) | n/a |
| <a name="output_cloudfront_dns_name"></a> [cloudfront\_dns\_name](#output\_cloudfront\_dns\_name) | The DNS name of the CloudFront distribution. |
| <a name="output_database_secret_arn"></a> [database\_secret\_arn](#output\_database\_secret\_arn) | The ARN of the secret containing the master password for the Aurora database. |
| <a name="output_ecs_autoscaling_group_name"></a> [ecs\_autoscaling\_group\_name](#output\_ecs\_autoscaling\_group\_name) | The Auto Scaling group name backing ECS on EC2. |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | The ECS cluster name running WordPress. |
| <a name="output_ecs_launch_template_id"></a> [ecs\_launch\_template\_id](#output\_ecs\_launch\_template\_id) | The launch template ID used by the ECS Auto Scaling group. |
| <a name="output_ecs_service_wordpress_name"></a> [ecs\_service\_wordpress\_name](#output\_ecs\_service\_wordpress\_name) | The ECS service name running WordPress. |
| <a name="output_performance_url"></a> [performance\_url](#output\_performance\_url) | The direct ALB HTTPS URL used for performance testing. |
| <a name="output_phpmyadmin_ecr_repository_url"></a> [phpmyadmin\_ecr\_repository\_url](#output\_phpmyadmin\_ecr\_repository\_url) | The ECR repository URL that stores the managed phpMyAdmin image. |
| <a name="output_phpmyadmin_service_name"></a> [phpmyadmin\_service\_name](#output\_phpmyadmin\_service\_name) | The ECS service name running phpMyAdmin when a domain name is configured. |
| <a name="output_phpmyadmin_url"></a> [phpmyadmin\_url](#output\_phpmyadmin\_url) | The phpMyAdmin URL when a domain name is configured. |
| <a name="output_wordpress_admin_password_secret_arn"></a> [wordpress\_admin\_password\_secret\_arn](#output\_wordpress\_admin\_password\_secret\_arn) | The ARN of the Secrets Manager secret storing the WordPress admin password. |
| <a name="output_wordpress_admin_password_secret_name"></a> [wordpress\_admin\_password\_secret\_name](#output\_wordpress\_admin\_password\_secret\_name) | The name of the Secrets Manager secret storing the WordPress admin password. |
| <a name="output_wordpress_ecr_repository_url"></a> [wordpress\_ecr\_repository\_url](#output\_wordpress\_ecr\_repository\_url) | The ECR repository URL that stores the managed WordPress-Apache image. |
<!-- END_TF_DOCS -->
