resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn
  container_definitions = jsonencode([{
    name         = "api"
    image        = "${aws_ecr_repository.api.repository_url}:${var.container_image_tag}"
    essential    = true
    portMappings = [{ containerPort = local.container_port, hostPort = local.container_port, protocol = "tcp" }]
    environment = [
      { name = "PORT", value = tostring(local.container_port) },
      { name = "DB_HOST", value = var.db_endpoint },
      { name = "DB_PORT", value = tostring(var.db_port) },
      { name = "DB_NAME", value = var.db_name },
      { name = "NODE_ENV", value = "production" },
    ]
    mountPoints = [{ sourceVolume = "tmp", containerPath = "/tmp", readOnly = false }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "api"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "/app/healthcheck.sh"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
    readonlyRootFilesystem = true
    user                   = "1000:1000"
  }])
  volume { name = "tmp" }
  tags = { Name = "${local.name_prefix}-api-task" }
}
