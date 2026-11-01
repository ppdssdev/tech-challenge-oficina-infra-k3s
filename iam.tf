resource "aws_iam_role" "node" {
  name = "${local.name}-node"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }]
  })
  tags = { Name = "${local.name}-node" }
}
resource "aws_iam_role_policy" "ssm" {
  #checkov:skip=CKV_AWS_290:SSM Session Manager exige canais com Resource wildcard; ações explicitamente limitadas.
  #checkov:skip=CKV_AWS_355:Estas cinco APIs SSM não suportam restrição por ARN; sem GetParameter, S3 ou Secrets Manager.
  name = "session-manager-minimal"
  role = aws_iam_role.node.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:UpdateInstanceInformation", "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
      Resource = "*"
    }]
  })
}
resource "aws_iam_instance_profile" "node" {
  name = "${local.name}-node"
  role = aws_iam_role.node.name
  tags = { Name = "${local.name}-node" }
}
