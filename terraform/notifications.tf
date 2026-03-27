resource "aws_sns_topic" "wordpress" {
  provider = aws.default

  name         = "sns-${var.name}"
  display_name = "WordPress notifications for ${var.name}"

  tags = {
    Origin     = var.name
    DeployedBy = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "email_target" {
  provider = aws.default

  topic_arn = aws_sns_topic.wordpress.arn
  protocol  = "email"
  endpoint  = var.wp_admin_email
}

data "aws_iam_policy_document" "wordpress_notifications" {
  statement {
    sid     = "AllowEventBridgePublish"
    effect  = "Allow"
    actions = ["sns:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.wordpress.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.ecs_failures.arn]
    }
  }
}

resource "aws_sns_topic_policy" "wordpress" {
  provider = aws.default

  arn    = aws_sns_topic.wordpress.arn
  policy = data.aws_iam_policy_document.wordpress_notifications.json
}

resource "aws_cloudwatch_event_rule" "ecs_failures" {
  provider = aws.default

  name        = "ecs-${var.name}-failures"
  description = "Send ECS deployment and placement failures to SNS"

  event_pattern = jsonencode({
    source        = ["aws.ecs"]
    "detail-type" = ["ECS Service Action"]
    detail = {
      clusterArn  = [module.ecs_cluster.arn]
      eventName   = ["SERVICE_DEPLOYMENT_FAILED", "SERVICE_TASK_PLACEMENT_FAILURE"]
      serviceName = ["wordpress-${var.name}"]
    }
  })
}

resource "aws_cloudwatch_event_target" "ecs_failures_sns" {
  provider = aws.default

  rule = aws_cloudwatch_event_rule.ecs_failures.name
  arn  = aws_sns_topic.wordpress.arn
}
