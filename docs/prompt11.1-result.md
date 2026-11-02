# Resultado — Prompt 11.1

Em 2026-11-02, a implementação foi **aplicada no checkout infra-k3s**. O patch e
o relatório do Prompt 11 estavam disponíveis em `/tmp/oficina-prompt11`.
`git apply --check` passou e os hashes dos fontes correspondiam integralmente à
base do patch. A correção Private DNS foi preparada e revisada antes da aplicação
do diff final, preservando as alterações locais anteriores.

## Alterações aplicadas

- `secretsmanager-endpoint.tf`: seis blocos opcionais — endpoint Interface em duas
  subnets/AZs privadas, SG próprio e ingresso/egress TCP 443 por SG para auth e app.
- Private DNS mantido. Policy do endpoint com statements separados: role auth
  pode ler seu ARN de segredo informado; role do nó pode ler os mesmos três
  segredos já autorizados em `app-secrets-iam.tf`. Somente `GetSecretValue`.
- `variables.tf`: toggle padrão false e dois ARNs auth validados, obrigatórios ao
  habilitar. `outputs.tf`: ID opcional separado do contrato v3, que foi preservado.
- Inventário, baselines e testes atualizados. Todos os registros anteriores das
  baselines de recursos, variáveis e outputs permanecem iguais.
- README, arquitetura, contrato e custos atualizados; detalhes de conectividade,
  IAM, ativação e disponibilidade em [Secrets Manager privado](secretsmanager-endpoint.md).
- `environments/staging.tfvars`, local e ignorado pelo Git: somente formatação.
  AST antes/depois comparada, preservando os valores sem exibi-los nos logs.

`security.tf`, `network.tf`, `compute.tf`, IAM existente, scripts operacionais,
provider e lockfile foram preservados byte a byte em relação ao início da sessão.
Isso inclui PostgreSQL 5432, IMDSv2, bloqueio de IMDS para pods, HTTPS existente e
controles anteriores. Nenhuma operação AWS, init, plan, apply/destroy, modificação
de state, outro repositório, commit, branch ou PR foi realizada. Nenhum recurso
ou segredo foi provisionado; NAT Gateway não foi adicionado.

## Validações no repositório atual

| Validação | Resultado |
|---|---|
| `terraform fmt -check -recursive` | Aprovado após formatação do `.tfvars` local; primeiro retorno 3 identificava somente esse arquivo |
| `terraform validate -no-color` | Bloqueado pelo sandbox ao iniciar o provider; não concluído |
| `python scripts/policy.py` | Aprovado, 29 blocos de recursos (23 anteriores + 6 opcionais) |
| `python -m unittest discover -s scripts -p 'test_*.py' -v` | 11 testes aprovados; 47 casos de mutação, além de bloqueios de recursos/ownership indevidos |
| `bash -n` para cada script shell | Aprovado |
| ShellCheck 0.11.0 nos scripts shell | Aprovado |
| Checkov Terraform 3.2.471, sem soft-fail | 86 aprovados, 1 falha preexistente, 6 exceções preexistentes, zero erros de parsing; retorno 1 |
| Checkov secrets | Retorno 0, zero achados; scanner reportou zero recursos, sem garantia de cobertura completa |
| `git diff --check` | Aprovado |
| Hashes e baselines anteriores | Arquivos fora da alteração e todos os registros anteriores preservados |

Terraform 1.14.6 e provider AWS 6.38.0 já estavam instalados. O diagnóstico local
do validate confirmou `listen unix /tmp/plugin…: setsockopt: operation not permitted`.
Não houve tentativa de desativar o sandbox. Reexecutar em ambiente que permita a
comunicação local com o provider. O parser HCL/Checkov não substitui esse validate.

Python/Checkov foram executados com `/tmp/fase3-tools/bin`, usando o parser
`bc-python-hcl2` instalado, e ShellCheck com
`/tmp/oficina-tools/shellcheck-v0.11.0/shellcheck`. O preflight completo não foi
invocado, pois inclui init; suas verificações acima foram executadas individualmente.
TFLint não foi executado nesta entrega.

Logs desta sessão: `/tmp/oficina-prompt11.1/{fmt.log,policy.log,tests.log,terraform-validate.log,terraform-validate-debug.log,checkov-terraform.json,checkov-secrets.json}`.
As cópias de revisão e o diff estão nesse diretório, além das alterações efetivas
no repositório. A [falha ECR CKV_AWS_136](checkov-ecr-CKV_AWS_136.md) está registrada
separadamente e continua reprovando o gate.

## Preparação para revisão de provisionamento

**Preparado para revisão, com pendências explícitas; validação completa ainda não
aprovada.** A revisão estática confirma que os SGs e a policy contemplam auth e
EC2/K3s, corrigindo o bloqueio auth-only causado pelo Private DNS no patch original.
Conectividade efetiva e identidade dos consumidores não foram testadas na AWS.

Antes de provisionar/ativar:

1. Concluir `terraform validate` em ambiente compatível e tratar separadamente a
   falha Checkov do ECR; o gate atual não está verde.
2. Confirmar ARNs/credenciais dos consumidores, IAM da Lambda com `aws:SourceVpce`,
   policies dos segredos e eventual KMS, mantendo o contrato e o IMDS existentes.
3. Confirmar disponibilidade nas AZs, DNS/NACLs, ausência de endpoint duplicado e
   orçamento regional. Duas AZs são a implementação; uma AZ é apenas comparação
   documentada, com menor disponibilidade. Padrão desligado: zero incremento.
4. Após provisionamento autorizado, testar DNS/TLS e leituras auth/app, negações
   por principal/segredo/ação e comportamento nas duas AZs, sem registrar valores.
   Fornecer o ID real à stack auth antes de ativar seus consumidores.
