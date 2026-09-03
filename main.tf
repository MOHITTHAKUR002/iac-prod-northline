module "networking" {
  source             = "./modules/networking"
  project_prefix     = var.project_prefix
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  container_port     = var.container_port
}
module "storage" {
  source         = "./modules/storage"
  project_prefix = var.project_prefix
  environment    = var.environment
}
module "database" {
  source                      = "./modules/database"
  project_prefix              = var.project_prefix
  environment                 = var.environment
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  ecs_tasks_security_group_id = module.networking.ecs_tasks_security_group_id
  db_instance_class           = var.db_instance_class
  db_allocated_storage        = var.db_allocated_storage
  skip_final_snapshot         = var.skip_final_snapshot
  deletion_protection         = var.deletion_protection
}
module "load_balancing" {
  source                = "./modules/load_balancing"
  project_prefix        = var.project_prefix
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
  acm_certificate_arn   = var.acm_certificate_arn
  container_port        = var.container_port
}
module "compute" {
  source                      = "./modules/compute"
  project_prefix              = var.project_prefix
  environment                 = var.environment
  private_subnet_ids          = module.networking.private_subnet_ids
  ecs_tasks_security_group_id = module.networking.ecs_tasks_security_group_id
  ecs_desired_count           = var.ecs_desired_count
  ecs_max_capacity            = var.ecs_max_capacity
  container_port              = var.container_port
  container_image_tag         = var.container_image_tag
  db_endpoint                 = module.database.db_endpoint
  db_port                     = module.database.db_port
  db_name                     = module.database.db_name
  assets_bucket_arn           = module.storage.assets_bucket_arn
  target_group_arn            = module.load_balancing.target_group_arn
}
module "observability" {
  source                  = "./modules/observability"
  project_prefix          = var.project_prefix
  environment             = var.environment
  alarm_email             = var.alarm_email
  alb_arn_suffix          = module.load_balancing.alb_arn_suffix
  target_group_arn_suffix = module.load_balancing.target_group_arn_suffix
  ecs_cluster_name        = module.compute.ecs_cluster_name
  ecs_service_name        = module.compute.ecs_service_name
  db_instance_id          = module.database.db_instance_id
  nat_gateway_id          = module.networking.nat_gateway_id
}
