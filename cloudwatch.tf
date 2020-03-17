resource "aws_cloudwatch_metric_alarm" "alb_web_healthyhosts" {
  alarm_name          = "${local.namespace}-web-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Number of web nodes healthy in Target Group"
  actions_enabled     = "true"
  alarm_actions       = [aws_sns_topic.notify.arn]
  ok_actions          = [aws_sns_topic.notify.arn]
  dimensions = {
    TargetGroup  = aws_alb_target_group.alb_web.arn_suffix
    LoadBalancer = aws_alb.alb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_streaming_healthyhosts" {
  alarm_name          = "${local.namespace}-streaming-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Number of streaming nodes healthy in Target Group"
  actions_enabled     = "true"
  alarm_actions       = [aws_sns_topic.notify.arn]
  ok_actions          = [aws_sns_topic.notify.arn]
  dimensions = {
    TargetGroup  = aws_alb_target_group.alb_streaming.arn_suffix
    LoadBalancer = aws_alb.alb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "compose_cpu" {
  alarm_name                = "${local.namespace}-ec2-cpu-80"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "This metric monitors ec2 cpu utilization"
  dimensions = {
    InstanceId = aws_instance.compose.id
  }
}