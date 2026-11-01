output "vpc_id" {
  description = "string, referência não sensível; disponível após apply autorizado."
  value       = aws_vpc.this.id
}

output "public_subnet_id" {
  description = "string, referência não sensível; disponível após apply autorizado."
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "list(string), AZ a/b ordenadas; disponível após apply autorizado."
  value       = tolist([for key in sort(keys(aws_subnet.private)) : aws_subnet.private[key].id])
}

output "app_security_group_id" {
  description = "string, referência não sensível; disponível após apply autorizado."
  value       = aws_security_group.app.id
}

output "auth_security_group_id" {
  description = "string, referência não sensível; disponível após apply autorizado."
  value       = aws_security_group.auth.id
}

output "instance_id" {
  description = "string, referência não sensível; disponível após apply autorizado."
  value       = aws_instance.node.id
}

output "instance_public_ip" {
  description = "string, referência não sensível; disponível após apply autorizado."
  value       = aws_instance.node.public_ip
}
output "integration_contract" {
  description = "v2: código implementado, valores somente após provisionamento. Registry continua planejado."
  value = {
    schema_version = 2
    implemented    = true
    environment    = var.environment
    region         = var.aws_region
    planned_fields = ["image_repository_url"]
  }
}
