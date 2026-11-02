# Separação Terraform — etapa 1 / contrato v3

Implementação local em 2026-11-02, após destruição informada dos 28 recursos.
State K3s conferido por leitura: zero recursos. Nenhuma migração/importação de state
é necessária neste cenário; não reutilizar o backup anterior como state ativo.
Nenhum provisionamento, plan ou acesso AWS foi executado nesta etapa.
Não foi localizado checkout infra-rds no workspace ou nos diretórios de projetos
inspecionados em /home/gnome-digital. Sua implementação fica para a etapa 2.

## Propriedade e dependências

| Responsabilidade | Dono único |
|---|---|
| VPC, subnets, rotas, IGW, SG default fechado | infra-k3s |
| EC2/K3s, IAM SSM/secrets/ECR, repositório ECR | infra-k3s |
| SG app e auth; egress app 443 e app/auth 5432 | infra-k3s |
| Endpoint Secrets Manager opcional, SG próprio, ingresso auth/app 443 e egress auth/app para endpoint 443 | infra-k3s |
| RDS privado, DB subnet group, SG do banco | infra-rds (etapa 2) |
| Ingress do banco TCP 5432 a partir de app e auth | infra-rds (etapa 2) |
| Função/role Lambda e associação às subnets/SG auth | stack auth (posterior) |

Dependência única: infra-rds consome o contrato produzido por infra-k3s. K3s não
recebe endpoint, secret ARN, SG ou state RDS. Banco e credenciais não são outputs
K3s. A stack RDS não pode criar/regerir VPC, subnets, SGs app/auth nem seus egress.
Usar states/backends distintos; nenhum recurso/regra deve pertencer a dois states.
Provisionamento futuro: K3s → RDS → aplicações/auth. Desmontagem futura em ordem
inversa, removendo primeiro dependências RDS e ENIs Lambda.

## Contrato final

Output canônico `integration_contract` (não sensível):

```hcl
object({
  schema_version         = number # exatamente 3
  account_id             = string # 12 dígitos; conta configurada no provider
  region                 = string # us-east-2
  environment            = string # staging
  vpc_id                 = string
  private_subnet_ids     = list(string) # ordem estável a, b
  app_security_group_id  = string
  auth_security_group_id = string # identidade de rede da Lambda
})
```

Outputs escalares mantidos: `vpc_id`, `private_subnet_ids`,
`app_security_group_id`, `auth_security_group_id`. Adicionados `account_id`,
`region`, `environment`, `contract_version` (number=3). Outputs operacionais
`public_subnet_id`, `instance_id`, `instance_public_ip` permanecem.
Terraform infere tipos de outputs; não aceita argumento `type`. Conversões
explícitas no objeto fixam strings/lista. A variável de conta é validada e o
provider mantém `allowed_account_ids`; não representa consulta STS nesta etapa.

V3 substitui o objeto v2 de planejamento (implemented/planned_fields).
Consumidores devem aceitar explicitamente v3. Após provisionamento autorizado,
publicar somente o objeto selecionado em JSON, com proveniência do produtor,
ambiente e revisão. Não compartilhar state completo, tfvars ou credenciais;
não usar terraform_remote_state. Nenhum canal de publicação foi criado aqui.
IDs reais só estarão disponíveis após provisionamento futuro.

Prompt 11 adiciona o output escalar opcional `secretsmanager_endpoint_id`
(string quando habilitado, null quando desabilitado) para `secrets_endpoint_id`
da stack auth. O objeto `integration_contract` e sua versão 3 ficam inalterados.
O endpoint e suas regras têm ownership exclusivo K3s; auth apenas consome o ID.
Não criar associações/policies/regras concorrentes em outro state.

Na etapa 2, infra-rds deve declarar variável com o tipo acima, rejeitar versão,
conta, região e ambiente incompatíveis e verificar em seu próprio contexto AWS
que VPC, duas subnets distintas em AZs distintas e os dois SGs pertencem à mesma
conta/VPC/região. Deve usar apenas essas subnets no DB subnet group, manter RDS
criptografado e `publicly_accessible=false`, preservar proteção contra exclusão
e definir backup/snapshot com revisão específica. Criar duas regras standalone
TCP 5432 no SG do banco, usando `referenced_security_group_id` app/auth; nunca
CIDR como origem do banco ou ingresso inline concorrente.

## Rede e segurança

O root K3s cria quatro egress: app/auth × subnets privadas a/b. Todos são TCP
5432 para `each.value.cidr_block` (10.30.10.0/24 e 10.30.11.0/24). Não usam IDs
ou outputs do banco. Comparado ao antigo destino por SG do banco, o destino de
saída passa a abranger os dois CIDRs privados por exigência desta separação;
isso permite alcançar qualquer listener 5432 nesses CIDRs que autorize a origem.
A restrição de ingresso por SG no RDS é obrigatória para completar o controle.
Não há egress PostgreSQL público, all-protocol ou rota privada de internet.
HTTPS app 443, ingress opt-in, IAM mínimo, ECR imutável/criptografado/scan,
IMDSv2 obrigatório/hop limit 1, firewall e bootstrap foram preservados.

Subnets privadas continuam isoladas, sem NAT Gateway ou recursos públicos do banco.
DNS da VPC permanece habilitado. Lambda precisa associar SG auth às ENIs privadas;
pods K3s dependem do masquerade do nó para serem identificados pelo SG app.
Conectividade TCP/TLS deve ser testada futuramente; validate não comprova runtime.
As regras PostgreSQL sozinhas não dão acesso a Secrets Manager/JWKS.
O [endpoint privado opcional do Prompt 11](secretsmanager-endpoint.md) prepara
HTTPS auth/app → Secrets Manager sem NAT; habilitação, custos e impacto Private DNS
exigem revisão antes da implantação. Não fornece acesso a JWKS público.

## Preservação e validação

`rds.tf` não rastreado foi avaliado e removido do root ativo: continha RDS,
DB subnet group, SG do banco, ingresso app, antigo egress app→SG banco e dois
outputs RDS. Backup pré-refatoração existente permanece intacto. Nenhuma cópia
ativa RDS foi criada dentro deste root. Arquivo vazio não rastreado `null`,
arquivos IAM/ECR locais, variáveis locais, tfvars, states e backups preservados.
Policies mantêm inventário fechado e snapshots AST; alterações de segurança
anteriores não foram descartadas. Snapshots também cobrem ECR, IAM ECR e contrato.
Testes de mutação verificam fronteiras, versões, SG auth e egress privado.

Executar fmt dos arquivos .tf, validate com provider já instalado, policy.py e
unittest local. Não executar preflight completo nesta etapa: inclui init e
scanners que podem depender de rede. Sem apply/destroy/import/refresh, alteração
de backend/state, branches, commits, PRs ou alterações de Java/Lambda.
