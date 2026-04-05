resource "aws_security_group" "ecs_instances" {
  # Creates the security group attached to ECS container instances.
  # This group is reused by the ALB, Aurora, and EFS rules.

  name        = "${local.prefix}-ecs-instances"
  description = "Security group for ECS EC2 container instances"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${local.prefix}-ecs-instances"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_instances_from_alb" {
  # Allows the ALB to reach ECS container instances over TCP.
  # The full port range is open because bridge-mode tasks use dynamic host ports.

  security_group_id            = aws_security_group.ecs_instances.id
  referenced_security_group_id = module.alb.security_group_id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  description                  = "Allow ALB traffic to ECS container instances"
}

resource "aws_vpc_security_group_egress_rule" "ecs_instances_all" {
  # Allows ECS container instances to initiate outbound traffic to any IPv4 address.
  # The rule targets 0.0.0.0/0, not only the private subnets.

  security_group_id = aws_security_group.ecs_instances.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

module "ecs_autoscaling" {
  # Creates the Auto Scaling group that provides EC2 capacity for the ECS cluster.
  # User data mounts EFS and joins each instance to the expected ECS cluster.

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
    Name = "${local.prefix}-ecs"
  }
}
