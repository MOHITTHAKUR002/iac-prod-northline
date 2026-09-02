output "sns_topic_arn" {
  description = "SNS topic for CloudWatch alarms."
  value       = aws_sns_topic.alarms.arn
}
