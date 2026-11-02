variable "environment" {
  type        = string
  default     = "staging"
  description = "Somente staging autorizado; production requer revisão e state separado."
  validation {
    condition     = var.environment == "staging"
    error_message = "Somente staging nesta fase."
  }
}
variable "aws_region" {
  type    = string
  default = "us-east-2"
  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "Somente Ohio."
  }
}
variable "aws_account_id" {
  type        = string
  description = "ID não secreto da conta aprovada; evita conta errada."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Informe 12 dígitos."
  }
}
variable "owner" {
  type        = string
  description = "Responsável/código da equipe, sem dados pessoais."
  validation {
    condition     = length(trimspace(var.owner)) > 2
    error_message = "Owner obrigatório."
  }
}
variable "ami_id" {
  type        = string
  description = "AMI regional imutável Ubuntu Server 24.04 amd64 Canonical, validada antes do plan. Sem latest."
  validation {
    condition     = can(regex("^ami-[0-9a-f]{17}$", var.ami_id))
    error_message = "Informe AMI fixa oficial de Ohio."
  }
}
variable "instance_type" {
  type    = string
  default = "t3.medium"
  validation {
    condition     = contains(["t3.medium", "c7i-flex.large"], var.instance_type)
    error_message = "Somente t3.medium ou c7i-flex.large (2 vCPU/4 GiB); confirmar Free Plan e preço."
  }
}
variable "root_volume_gib" {
  type    = number
  default = 30
  validation {
    condition     = var.root_volume_gib >= 30 && var.root_volume_gib <= 40 && floor(var.root_volume_gib) == var.root_volume_gib
    error_message = "gp3 entre 30 e 40 GiB."
  }
}
variable "eligibility_confirmed" {
  type        = bool
  default     = false
  description = "Somente true após revisão humana do plano, preço, saldo e tipo de instância. Não é autorização para provisionar."
}
variable "enable_https_ingress" {
  type    = bool
  default = false
}
variable "https_ingress_cidrs" {
  type        = set(string)
  default     = []
  description = "Origens IPv4 explicitamente aprovadas para o futuro ingress TLS."
  validation {
    condition     = alltrue([for c in var.https_ingress_cidrs : can(cidrnetmask(c))])
    error_message = "Use CIDRs IPv4 válidos."
  }
}
