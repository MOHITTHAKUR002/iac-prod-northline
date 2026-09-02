variable "project_prefix" {
  description = "Short prefix for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
}

variable "vpc_id" {
  description = "VPC identifier."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet identifiers for RDS."
  type        = list(string)
}

variable "ecs_tasks_security_group_id" {
  description = "ECS tasks security group for RDS ingress."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GiB."
  type        = number
}
