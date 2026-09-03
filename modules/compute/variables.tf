variable "project_prefix" { type = string }
variable "environment" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "ecs_tasks_security_group_id" { type = string }
variable "ecs_desired_count" {
  type = number
  validation {
    condition     = var.ecs_desired_count >= 2
    error_message = "ecs_desired_count >= 2"
  }
}
variable "ecs_max_capacity" {
  type = number
  validation {
    condition     = var.ecs_max_capacity >= var.ecs_desired_count
    error_message = "max >= desired"
  }
}
variable "container_port" { type = number }
variable "container_image_tag" { type = string }
variable "db_endpoint" { type = string }
variable "db_port" { type = number }
variable "db_name" { type = string }
variable "assets_bucket_arn" { type = string }
variable "target_group_arn" { type = string }
