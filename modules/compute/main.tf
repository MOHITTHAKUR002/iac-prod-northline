locals {
  name_prefix    = "${var.project_prefix}-${var.environment}"
  container_port = var.container_port
  cps = [
    { capacity_provider = "FARGATE", weight = 1, base = 1 },
    { capacity_provider = "FARGATE_SPOT", weight = 3, base = 0 },
  ]
}
