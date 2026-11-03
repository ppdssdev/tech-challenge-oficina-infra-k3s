# Shared OIDC ownership stays in the existing staging/k3s state.
variable "manage_github_oidc_provider" {
  description = "Enable only after audit confirms absence, or after an explicitly approved import. Default references the existing provider."
  type        = bool
  default     = false
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.manage_github_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.manage_github_oidc_provider ? 0 : 1
  arn   = "arn:aws:iam::797781632267:oidc-provider/token.actions.githubusercontent.com"
}

locals {
  github_repositories = {
    app    = "tech-challenge-oficina"
    k3s    = "tech-challenge-oficina-infra-k3s"
    rds    = "tech-challenge-oficina-infra-rds"
    lambda = "tech-challenge-oficina-auth-lambda"
  }
  github_provider_arn = var.manage_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "github_validation" {
  for_each             = local.github_repositories
  name                 = "oficina-staging-github-${each.key}"
  description          = "Identity validation only; deployment permissions reserved for Etapa 3."
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = local.github_provider_arn }
      Condition = { StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "repo:ppdssdev/${each.value}:ref:refs/heads/main"
      } }
    }]
  })
  lifecycle {
    precondition {
      condition     = var.aws_account_id == "797781632267" && var.aws_region == "us-east-2" && var.environment == "staging"
      error_message = "GitHub OIDC is restricted to staging account 797781632267 in us-east-2."
    }
  }
}

# GetCallerIdentity requires no identity policy. No S3/state access is needed.
output "github_validation_role_arns" {
  value = { for key, role in aws_iam_role.github_validation : key => role.arn }
}
