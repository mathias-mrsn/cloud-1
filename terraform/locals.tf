locals {
  repository_root             = abspath("${path.root}/..")
  prefix                      = "cloud1"
  ecs_instance_host_data_path = "/mnt/efs"
  wordpress_host_path         = "${local.ecs_instance_host_data_path}/wordpress"
  phpmyadmin_domain_name      = var.domain_name != null ? "${var.phpmyadmin_subdomain}.${var.domain_name}" : null
}
