output "vpc_id" {
  description = "VPC identifier."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet identifiers."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet identifiers."
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "ALB security group identifier."
  value       = aws_security_group.alb.id
}

output "ecs_tasks_security_group_id" {
  description = "ECS tasks security group identifier."
  value       = aws_security_group.ecs_tasks.id
}

output "nat_gateway_id" {
  description = "NAT gateway identifier."
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_az" {
  description = "Availability zone of the single NAT gateway."
  value       = aws_subnet.public[0].availability_zone
}

output "private_subnet_azs" {
  description = "Availability zones for private subnets."
  value       = aws_subnet.private[*].availability_zone
}
