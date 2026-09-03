output "alb_dns_name" {
  description = "ALB DNS name."
  value       = aws_lb.main.dns_name
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics."
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn" {
  description = "Target group ARN for ECS service attachment."
  value       = aws_lb_target_group.api.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch metrics."
  value       = aws_lb_target_group.api.arn_suffix
}

output "https_listener_arn" {
  description = "HTTPS listener ARN (dependency for ECS service)."
  value       = aws_lb_listener.https.arn
}
