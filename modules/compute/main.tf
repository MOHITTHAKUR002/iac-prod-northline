locals {
  name_prefix = "${var.project_prefix}-${var.environment}"
  cps = [
    { capacity_provider = "FARGATE", weight = var.fargate_weight, base = var.fargate_base },
    { capacity_provider = "FARGATE_SPOT", weight = var.fargate_spot_weight, base = 0 },
  ]
}
