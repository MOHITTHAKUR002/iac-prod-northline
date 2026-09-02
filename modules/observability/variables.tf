variable "project_prefix" {
  description = "Short prefix for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
}

variable "alarm_email" {
  description = "Optional email for alarm notifications."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name."
  type        = string
}

variable "db_instance_id" {
  description = "RDS instance identifier."
  type        = string
}

variable "nat_gateway_id" {
  description = "NAT gateway identifier."
  type        = string
}

locals {
  name_prefix = "${var.project_prefix}-${var.environment}"
}
