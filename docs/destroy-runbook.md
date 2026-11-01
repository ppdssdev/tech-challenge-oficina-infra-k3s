# Destruição e recursos órfãos — somente com autorização futura

Não executado nesta entrega. Confirmar conta/perfil/região e state staging correto.
Obter autorização explícita e decidir o que preservar: root EBS e todos os volumes
local-path serão apagados com a EC2. Stop/start não é cleanup e EBS continua cobrado.

1. Suspender consumidores e tráfego; exportar somente evidências não sensíveis.
2. Fazer backup consistente se necessário (ver deployment-runbook). Snapshots têm
   custo e não são excluídos automaticamente pelo destroy desta stack.
3. Destruir stacks consumidoras na ordem inversa: auth/Lambda (aguardar liberação
   de ENIs), aplicação, RDS conforme seu runbook com proteção/snapshot final; por
   último K3s/rede. Regras RDS nas SG app/auth precisam ser removidas pela stack RDS.
4. Não remover state para resolver dependências. Nunca excluir SG/VPC manualmente
   sem avaliar dependentes. Avaliar plano destrutivo com o proprietário:

```sh
aws sts get-caller-identity
terraform state list
terraform plan -destroy -var-file=environments/staging.tfvars -out=cleanup.tfplan
terraform show -no-color cleanup.tfplan
# Somente após aprovação do plano de destruição:
terraform apply cleanup.tfplan
# Alternativa equivalente, interativa e igualmente sujeita a autorização:
# terraform destroy -var-file=environments/staging.tfvars
terraform state list
```

5. State list vazio não prova ausência de órfãos. Consultas read-only em us-east-2:

```sh
aws ec2 describe-instances --filters Name=tag:Project,Values=fiap-oficina Name=tag:Environment,Values=staging
aws ec2 describe-volumes --filters Name=tag:Project,Values=fiap-oficina
aws ec2 describe-snapshots --owner-ids self --filters Name=tag:Project,Values=fiap-oficina
aws ec2 describe-network-interfaces --filters Name=tag:Project,Values=fiap-oficina
aws ec2 describe-addresses
aws ec2 describe-nat-gateways --filter Name=state,Values=available
aws ec2 describe-vpc-endpoints
aws elbv2 describe-load-balancers
```

Também pesquisar por ID da VPC antes da remoção, para encontrar ENIs sem tags;
conferir EC2 Volumes/Snapshots, RDS, logs, S3, registry, IAM role/profile e serviços
criados por stacks futuras. Nada nesta lista autoriza apagar recursos de outros
projetos. Terminated instances podem aparecer temporariamente no console.
Revisar Billing/Cost Explorer no dia seguinte e após atraso de contabilização.
Eliminar snapshots/backups apenas com aprovação de retenção; conservar state
remoto versionado e evidências conforme política aprovada. Se destroy falhar,
corrigir dependências e replanejar; não repetir cegamente nem abandonar recursos.
