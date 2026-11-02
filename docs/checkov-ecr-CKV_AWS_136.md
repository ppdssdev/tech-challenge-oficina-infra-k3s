# Pendência preexistente — CKV_AWS_136 no ECR

Registro do Prompt 11.1, em 2026-11-02.

- Recurso: `aws_ecr_repository.api`, em `ecr.tf`.
- Checkov 3.2.471: `Ensure that ECR repositories are encrypted using KMS`.
- Configuração atual: criptografia `AES256`; a regra exige KMS.
- Resultado: **falha aberta**, retorno 1 do scanner Terraform. Não há skip para
  essa regra, soft-fail ou redução da configuração para obter aprovação.

O relatório anterior `/tmp/oficina-prompt11/checkov-before.json` já contém a mesma
falha. Os hashes dos fontes anteriores coincidem com o checkout antes da aplicação
do Prompt 11.1. O novo relatório `/tmp/oficina-prompt11.1/checkov-terraform.json`
apresenta somente essa falha, 86 checks aprovados, seis exceções preexistentes e
zero erros de parsing. As seis exceções são as mesmas do relatório anterior.

`ecr.tf` foi preservado byte a byte. A decisão sobre criptografia KMS do ECR fica
para uma revisão própria, incluindo custo e impacto no recurso existente. Esta
entrega não resolve nem dispensa o finding; o gate Checkov continua reprovado.
