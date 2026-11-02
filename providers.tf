provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  default_tags { tags = local.tags }
}
locals {
  name = "oficina-${var.environment}"
  tags = {
    Project     = "fiap-oficina"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = "fiap-fase3"
    ManagedBy   = "terraform"
  }
}
