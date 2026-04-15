resource "aws_security_group" "ecs_instances" {
  name        = "${local.prefix}-ecs-instances"
  description = "Security group for ECS EC2 container instances"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name       = "${local.prefix}-ecs-instances"
    git_commit = "7e53d5b6fbc10d7e6272953e3580cd2a4f238a90"
    git_file   = "terraform/asg.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "ecs_instances"
    yor_trace  = "c902d1b5-5417-424d-8cfb-7cc332c0d607"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_instances_from_alb" {
  security_group_id            = aws_security_group.ecs_instances.id
  referenced_security_group_id = module.alb.security_group_id
  from_port                    = 32768
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "Allow ALB traffic to ECS container instances"
  tags = {
    git_commit = "7fde757f440ccca2e4ae4f3bb532d308067b3dd4"
    git_file   = "terraform/asg.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "ecs_instances_from_alb"
    yor_trace  = "558b6c33-7593-4130-a6f0-fb9329a0002c"
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_instances_all" {
  security_group_id = aws_security_group.ecs_instances.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  tags = {
    git_commit = "7e53d5b6fbc10d7e6272953e3580cd2a4f238a90"
    git_file   = "terraform/asg.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "ecs_instances_all"
    yor_trace  = "40255844-e259-439b-9bb2-44be28b3aa36"
  }
}

# checkov:skip=CKV_AWS_341: IMDSv2 hop limit 2 is required so the WordPress container can query EC2 instance metadata.
module "ecs_autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 9.0"

  name = "${local.prefix}-ecs"

  image_id      = data.aws_ami.ecs_ubuntu.id
  instance_type = var.ecs_instance_type

  security_groups = [aws_security_group.ecs_instances.id]
  user_data = base64encode(templatefile("${path.module}/templates/ecs_instance_user_data.sh.tftpl", {
    ecs_cluster_name        = "${local.prefix}-ecs-cluster"
    region                  = var.aws_region
    efs_id                  = module.efs.id
    efs_mount_point         = local.ecs_instance_host_data_path
    wordpress_host_path     = local.wordpress_host_path
    ecs_container_tags_json = jsonencode({ Name = "${local.prefix}-ecs-instance" })
  }))

  create_iam_instance_profile = true
  iam_role_name               = "${local.prefix}-ecs"
  iam_role_use_name_prefix    = false
  iam_role_description        = "IAM role for ECS EC2 container instances"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  vpc_zone_identifier = module.vpc.private_subnets
  health_check_type   = "EC2"

  min_size                  = var.ecs_instance_min_size
  desired_capacity          = var.ecs_instance_desired_capacity
  max_size                  = var.ecs_instance_max_size
  default_instance_warmup   = 180
  health_check_grace_period = 300

  block_device_mappings = [{
    device_name = "/dev/sda1"
    ebs = {
      delete_on_termination = true
      encrypted             = true
      volume_size           = var.ecs_root_volume_size
      volume_type           = "gp3"
    }
  }]

  metadata_options = {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  tags = {
    Name       = "${local.prefix}-ecs"
    git_commit = "7e53d5b6fbc10d7e6272953e3580cd2a4f238a90"
    git_file   = "terraform/asg.tf"
    git_org    = "mathias-mrsn"
    git_repo   = "cloud-1"
    yor_name   = "ecs_autoscaling"
    yor_trace  = "328e5a1d-5bfa-4f38-84fd-382353a07366"
  }
}
