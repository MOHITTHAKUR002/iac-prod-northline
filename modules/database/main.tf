locals {
  name_prefix = "${var.project_prefix}-${var.environment}"
  db_name     = replace("${var.project_prefix}${var.environment}", "-", "")
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-db-subnet"
  }
}

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"

  engine                      = "postgres"
  engine_version              = "16.4"
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  storage_type                = "gp3"
  db_name                     = local.db_name
  username                    = "dbadmin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = false
  skip_final_snapshot = true
  deletion_protection = false

  backup_retention_period = 7
  storage_encrypted       = true

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}
