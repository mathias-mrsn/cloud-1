resource "aws_sns_topic" "this" {
  provider = aws.default

  name         = "sns-${var.name}"
  display_name = "ASG Notification for ${var.name}"

  tags = {
    Origin     = var.name,
    DeployedBy = "Terraform"
  }
}

resource "aws_autoscaling_notification" "this" {
  provider = aws.default

  group_names = [module.autoscaling.autoscaling_group_name]
  topic_arn   = aws_sns_topic.this.arn

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR"
  ]
}

resource "aws_sns_topic_subscription" "email-target" {
  provider = aws.default

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = var.wp_admin_email
}
