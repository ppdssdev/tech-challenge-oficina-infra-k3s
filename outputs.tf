# Metadados de contrato; não são outputs de recursos provisionados.
output "integration_contract" {
  description = "Nomes dos outputs que serão implementados em uma futura PR."
  value = {
    schema_version = 1
    implemented    = false
    environment    = var.environment
    region         = var.aws_region
    planned_fields = ["vpc_id", "private_subnet_ids", "app_security_group_id", "auth_security_group_id", "image_repository_url"]
  }
}
