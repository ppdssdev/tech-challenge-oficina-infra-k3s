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
# Outputs não aceitam type: tostring/tolist e o schema documentado fixam os tipos.
output "account_id" {
  description = "string: conta configurada e restringida por allowed_account_ids no provider."
  value       = tostring(var.aws_account_id)
  sensitive   = false
}

output "region" {
  description = "string: região do contrato."
  value       = tostring(var.aws_region)
  sensitive   = false
}

output "environment" {
  description = "string: ambiente do contrato."
  value       = tostring(var.environment)
  sensitive   = false
}

output "contract_version" {
  description = "number: versão do contrato de integração."
  value       = 3
  sensitive   = false
}

output "integration_contract" {
  description = "Contrato v3 não sensível; publicar somente este objeto para infra-rds/auth."
  sensitive   = false
  value = {
    schema_version         = 3
    account_id             = tostring(var.aws_account_id)
    region                 = tostring(var.aws_region)
    environment            = tostring(var.environment)
    vpc_id                 = tostring(aws_vpc.this.id)
    private_subnet_ids     = tolist([for key in sort(keys(aws_subnet.private)) : tostring(aws_subnet.private[key].id)])
    app_security_group_id  = tostring(aws_security_group.app.id)
    auth_security_group_id = tostring(aws_security_group.auth.id)
  }
}

output "secretsmanager_endpoint_id" {
  description = "ID não secreto para secrets_endpoint_id da stack auth; null quando desabilitado. Contrato v3 preservado."
  value       = try(aws_vpc_endpoint.secretsmanager["enabled"].id, null)
  sensitive   = false
}
