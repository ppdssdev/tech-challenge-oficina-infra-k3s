data "aws_ami" "node" {
  owners = ["099720109477"]
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "aws_instance" "node" {
  #checkov:skip=CKV_AWS_88:IPv4 público necessário para saída HTTPS sem NAT; SG sem entrada por padrão.
  #checkov:skip=CKV_AWS_126:Monitoramento detalhado pago adiado; métricas básicas e logs locais.
  ami                         = data.aws_ami.node.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = aws_iam_instance_profile.node.name
  user_data                   = file("${path.module}/scripts/bootstrap.sh")
  user_data_replace_on_change = true
  ebs_optimized               = true
  monitoring                  = false
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }
  dynamic "credit_specification" {
    for_each = var.instance_type == "t3.medium" ? [1] : []
    content { cpu_credits = "standard" }
  }
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_gib
    encrypted             = true
    delete_on_termination = true
    tags                  = local.tags
  }
  tags       = { Name = "${local.name}-k3s" }
  depends_on = [aws_route.internet, aws_route_table_association.public, aws_iam_role_policy.ssm, aws_vpc_security_group_egress_rule.https]
  lifecycle {
    precondition {
      condition     = var.eligibility_confirmed
      error_message = "Bloqueado: confirme elegibilidade Free Plan, preço, saldo, permissões e aprovação antes de planejar."
    }
    precondition {
      condition     = !var.enable_https_ingress || length(var.https_ingress_cidrs) > 0
      error_message = "Defina explicitamente as origens HTTPS."
    }
  }
}
