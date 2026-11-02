resource "aws_iam_role_policy" "app_secrets" {
  name = "oficina-app-secrets-read"
  role = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyApplicationSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          for secret_name in [
            "oficina/staging/app-db-password",
            "oficina/staging/jwt-secret",
            "oficina/staging/admin-password"
          ] :
          "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${secret_name}-??????"
        ]
      }
    ]
  })
}
