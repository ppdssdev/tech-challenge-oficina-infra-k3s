# Ownership exclusivo infra-k3s: endpoint, SG e regras HTTPS de auth/app.
# Sem regras inline; respostas do endpoint usam o comportamento stateful do SG.
resource "aws_security_group" "secretsmanager_endpoint" {
  for_each    = var.enable_secretsmanager_endpoint ? toset(["enabled"]) : toset([])
  name        = "${local.name}-secretsmanager-endpoint"
  description = "Secrets Manager privado: HTTPS de auth e EC2/K3s"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.name}-secretsmanager-endpoint" }
}

resource "aws_vpc_security_group_ingress_rule" "auth_to_secretsmanager" {
  for_each                     = aws_security_group.secretsmanager_endpoint
  security_group_id            = each.value.id
  referenced_security_group_id = aws_security_group.auth.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS da Lambda auth para Secrets Manager privado"
}

resource "aws_vpc_security_group_egress_rule" "auth_to_secretsmanager" {
  for_each                     = aws_security_group.secretsmanager_endpoint
  security_group_id            = aws_security_group.auth.id
  referenced_security_group_id = each.value.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS auth somente para SG do endpoint Secrets Manager"
}

resource "aws_vpc_security_group_ingress_rule" "app_to_secretsmanager" {
  for_each                     = aws_security_group.secretsmanager_endpoint
  security_group_id            = each.value.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS da EC2/K3s para Secrets Manager privado"
}

# Explicita o caminho privado; o egress HTTPS existente para bootstrap permanece.
resource "aws_vpc_security_group_egress_rule" "app_to_secretsmanager" {
  for_each                     = aws_security_group.secretsmanager_endpoint
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = each.value.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS app para SG do endpoint Secrets Manager"
}

resource "aws_vpc_endpoint" "secretsmanager" {
  for_each            = aws_security_group.secretsmanager_endpoint
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.us-east-2.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for key in sort(keys(aws_subnet.private)) : aws_subnet.private[key].id]
  security_group_ids  = [each.value.id]
  tags                = { Name = "${local.name}-secretsmanager" }

  # Referências não secretas, sem consultar/criar role ou conteúdo de segredo.
  # ArnEquals restringe Principal à role exata, inclusive suas sessões assumidas.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AuthReadOnlyApplicationSecret"
      Effect    = "Allow"
      Principal = "*"
      Action    = "secretsmanager:GetSecretValue"
      Resource  = var.secretsmanager_endpoint_secret_arn
      Condition = {
        ArnEquals = { "aws:PrincipalArn" = var.secretsmanager_endpoint_role_arn }
      }
      }, {
      Sid       = "NodeReadOnlyApplicationSecrets"
      Effect    = "Allow"
      Principal = "*"
      Action    = "secretsmanager:GetSecretValue"
      # Mesmos três ARNs do IAM existente, sem ampliar acesso nem duplicar a lista.
      Resource = jsondecode(aws_iam_role_policy.app_secrets.policy).Statement[0].Resource
      Condition = {
        ArnEquals = { "aws:PrincipalArn" = aws_iam_role.node.arn }
      }
    }]
  })

  lifecycle {
    precondition {
      condition = (
        var.secretsmanager_endpoint_secret_arn != null &&
        var.secretsmanager_endpoint_role_arn != null
      )
      error_message = "Endpoint habilitado exige ARN exato do segredo de aplicação e da role Lambda."
    }
  }

  depends_on = [
    aws_vpc_security_group_ingress_rule.auth_to_secretsmanager,
    aws_vpc_security_group_egress_rule.auth_to_secretsmanager,
    aws_vpc_security_group_ingress_rule.app_to_secretsmanager,
    aws_vpc_security_group_egress_rule.app_to_secretsmanager,
  ]
}
