resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "K3s: sem entrada por padrao; HTTPS opt-in"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.name}-app" }
}
resource "aws_security_group" "auth" {
  #checkov:skip=CKV2_AWS_5:SG reservado para ENIs da futura Lambda; entrada fechada, saída PostgreSQL privada.
  name        = "${local.name}-auth"
  description = "Identidade de rede da futura Lambda; saida PostgreSQL privada"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.name}-auth" }
}
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.app.id
  description       = "Bootstrap GitHub, registries e endpoints publicos SSM via TLS"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  tags              = { Name = "${local.name}-https-out" }
}
resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each          = var.enable_https_ingress ? var.https_ingress_cidrs : toset([])
  security_group_id = aws_security_group.app.id
  description       = "Ingress TLS futuro, explicitamente habilitado"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  tags              = { Name = "${local.name}-https-in" }
}

# Esta stack possui o egress; infra-rds possui somente o ingresso no SG do banco.
resource "aws_vpc_security_group_egress_rule" "app_to_postgres" {
  for_each          = aws_subnet.private
  security_group_id = aws_security_group.app.id
  description       = "PostgreSQL para subnet privada ${each.key}"
  cidr_ipv4         = each.value.cidr_block
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
}

# Esta stack possui o egress; infra-rds possui somente o ingresso no SG do banco.
resource "aws_vpc_security_group_egress_rule" "auth_to_postgres" {
  for_each          = aws_subnet.private
  security_group_id = aws_security_group.auth.id
  description       = "PostgreSQL para subnet privada ${each.key}"
  cidr_ipv4         = each.value.cidr_block
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
}
