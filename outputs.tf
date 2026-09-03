output "vpc_id" {
  value = module.networking.vpc_id
}
output "alb_dns_name" {
  value = module.load_balancing.alb_dns_name
}
output "ecr_repository_url" {
  value = module.compute.ecr_repository_url
}
output "ecs_cluster_name" {
  value = module.compute.ecs_cluster_name
}
output "ecs_service_name" {
  value = module.compute.ecs_service_name
}
output "assets_bucket_name" {
  value = module.storage.assets_bucket_name
}
output "db_endpoint" {
  value     = module.database.db_endpoint
  sensitive = true
}
output "failure_domains" {
  value = {
    nat_gateway_az        = module.networking.nat_gateway_az
    rds_availability_zone = module.database.db_availability_zone
    ecs_subnet_azs        = module.networking.private_subnet_azs
    single_nat_risk       = length(distinct(concat([module.networking.nat_gateway_az], module.networking.private_subnet_azs))) > 1
    note                  = "Single NAT saves ~$32/mo; cross-AZ egress for non-NAT AZ tasks."
  }
}
