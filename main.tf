module "networking" {
  source = "./modules/networking"

  project_prefix     = var.project_prefix
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "database" {
  source = "./modules/database"

  project_prefix              = var.project_prefix
  environment                 = var.environment
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  ecs_tasks_security_group_id = module.networking.ecs_tasks_security_group_id
  db_instance_class           = var.db_instance_class
  db_allocated_storage        = var.db_allocated_storage
}

module "compute" {
  source = "./modules/compute"

  project_prefix              = var.project_prefix
  environment                 = var.environment
  vpc_id                      = module.networking.vpc_id
  public_subnet_ids           = module.networking.public_subnet_ids
  private_subnet_ids          = module.networking.private_subnet_ids
  alb_security_group_id       = module.networking.alb_security_group_id
  ecs_tasks_security_group_id = module.networking.ecs_tasks_security_group_id
  ecs_desired_count           = var.ecs_desired_count
  container_image_tag         = var.container_image_tag
  db_endpoint                 = module.database.db_endpoint
  db_port                     = module.database.db_port
  db_name                     = module.database.db_name
}

module "observability" {
  source = "./modules/observability"

  project_prefix          = var.project_prefix
  environment             = var.environment
  alarm_email             = var.alarm_email
  alb_arn_suffix          = module.compute.alb_arn_suffix
  target_group_arn_suffix = module.compute.target_group_arn_suffix
  ecs_cluster_name        = module.compute.ecs_cluster_name
  ecs_service_name        = module.compute.ecs_service_name
  db_instance_id          = module.database.db_instance_id
  nat_gateway_id          = module.networking.nat_gateway_id
}
