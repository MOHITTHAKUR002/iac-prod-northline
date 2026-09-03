locals {
  alb_alarms = {
    "5xx"     = { metric_name = "HTTPCode_Target_5XX_Count", period = 300, statistic = "Sum", threshold = 10 }
    unhealthy = { metric_name = "UnHealthyHostCount", period = 60, statistic = "Maximum", threshold = 0 }
  }
}

resource "aws_cloudwatch_metric_alarm" "alb" {
  for_each            = local.alb_alarms
  alarm_name          = "${local.name_prefix}-alb-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = each.value.metric_name
  namespace           = "AWS/ApplicationELB"
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
}
