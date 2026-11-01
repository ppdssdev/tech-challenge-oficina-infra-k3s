# Primeiro provisionamento — somente após autorização explícita futura

Este documento contém comandos previstos. Nenhum plan/apply/destroy foi executado
na implementação. Não habilitar CD. Abra um terminal no repositório infra-k3s,
na revisão aprovada, e reserve tempo para desmontar depois da apresentação.

Siga o [checklist de evidências e limites dos mocks](operational-validation.md).

1. Leia custo, arquitetura, segurança e Free Plan. Confirme autorização, saldo,
   região Ohio, permissões mínimas e tipo elegível. Budget não limita gasto.
2. Instale Git, Terraform 1.14.6, AWS CLI v2, plugin Session Manager, Python 3.12,
   ShellCheck e TFLint 0.61.0. Use autenticação temporária SSO/role; nunca root/key fixa.
3. Validação local não exige login AWS:

```sh
python3 -m venv .venv
. .venv/bin/activate
pip install checkov==3.2.471 bc-python-hcl2==0.4.3
bash scripts/preflight.sh
tflint --init
tflint
```

4. Somente na etapa autorizada, faça login com perfil SSO previamente configurado:

```sh
export AWS_PROFILE=oficina-staging
export AWS_REGION=us-east-2
aws sso login --profile "$AWS_PROFILE"
aws sts get-caller-identity
aws ec2 describe-instance-types --instance-types t3.medium c7i-flex.large   --query 'InstanceTypes[].{Type:InstanceType,Free:FreeTierEligible,Memory:MemoryInfo.SizeInMiB}'
aws ec2 describe-instance-type-offerings --location-type availability-zone   --filters Name=location,Values=us-east-2a Name=instance-type,Values=c7i-flex.large
aws ec2 describe-images --owners 099720109477   --filters 'Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*'   Name=state,Values=available --query 'Images[].{ID:ImageId,Name:Name,Date:CreationDate}'
cp environments/staging.tfvars.example environments/staging.tfvars
```

Selecione uma AMI regional e registre seu ID/nome/data na revisão. **Não usar o
placeholder**. Preencha aws_account_id, owner, ami_id e instance_type. Marque
eligibility_confirmed=true só após verificação documentada. TF valida owner/arquitetura
na consulta AMI do plan; não seleciona versão mais recente automaticamente.
O snapshot da imagem fixa OS, mas imagens dos componentes K3s serão baixadas pelo
containerd; acesso HTTPS aos registries deve funcionar. Nunca inserir segredo em tfvars.

5. State: inicialmente local, criptografe disco/backup e restrinja acesso (um
   operador por vez). Não commitar state. Para remoto, responsável deve preparar
   bucket separado privado, versionado, criptografado, PublicAccessBlock, política
   TLS e acesso mínimo; não há bucket/backend ativo neste código. Após autorização,
   adicionar `terraform { backend "s3" {} }` em backend.tf e configurar:

```hcl
bucket       = "BUCKET-APROVADO"
key          = "staging/k3s/terraform.tfstate"
region       = "us-east-2"
encrypt      = true
use_lockfile = true
```

Salve em arquivo local backend.hcl sem credenciais. Use `terraform init
-migrate-state -backend-config=backend.hcl` com backup prévio e sem outros operadores.
Role precisa ListBucket limitado ao prefixo, Get/PutObject do state e
Get/Put/DeleteObject de .tflock; sem DeleteObject rotineiro no state. Não criar
DynamoDB. Não usar force-unlock sem confirmar ausência de execução.

6. Plan **somente nesta etapa autorizada**; não usar -target ou -refresh=false:

```sh
umask 077
terraform init -input=false -lockfile=readonly
terraform plan -var-file=environments/staging.tfvars -out=staging.tfplan
terraform show -no-color staging.tfplan
```

Confira conta/região, 1 EC2 On-Demand, 1 root gp3, 1 IPv4, 1 VPC, 3 subnets,
3 route tables, 3 associações, 1 IGW, 1 rota pública, SG default fechado + app/auth,
role/policy/profile. Sem NAT, RDS, EKS ou balanceadores. HTTPS ingress tem zero
regras por padrão. Preços e total aprovados devem corresponder ao tipo escolhido.
Uma mudança inesperada exige interromper e revisar. Plan é arquivo sensível local.

7. Após revisão do plano e autorização do proprietário:

```sh
terraform apply staging.tfplan
terraform output -json > /tmp/oficina-staging-outputs.json
INSTANCE_ID=$(terraform output -raw instance_id)
aws ssm describe-instance-information --filters Key=InstanceIds,Values="$INSTANCE_ID"
aws ssm start-session --target "$INSTANCE_ID"
```

Dentro da sessão, verificar `sudo cloud-init status --wait`,
`sudo tail -n 100 /var/log/oficina-bootstrap.log`, `sudo journalctl -u k3s -n 100`.
Execute os comandos de scripts/post-deploy.sh. Se falhar, não instalar aplicação;
verifique SG 443, rota/IPv4, role, snap SSM, disco, checksum e logs. Sem SSM, usar
console output read-only (não contém kubeconfig); corrigir código e recriar com
aprovação e backup. Nunca abrir 22 ou 6443 para diagnóstico.

8. Kubernetes: preferir `sudo k3s kubectl` dentro do SSM. Para cliente local,
   túnel sem abrir SG:

```sh
aws ssm start-session --target "$INSTANCE_ID"   --document-name AWS-StartPortForwardingSession   --parameters '{"portNumber":["6443"],"localPortNumber":["16443"]}'
```

Em sessão separada autorizada, obter /etc/rancher/k3s/k3s.yaml em canal seguro,
arquivo local 0600 fora do Git; trocar server por https://127.0.0.1:16443,
preservar CA/certificados, não usar insecure-skip-tls-verify. Remover kubeconfig ao
terminar e limitar RBAC para usuários futuros. Não publicar conteúdo no ticket/log.

9. Reboot controlado pelo SSM; reconectar e repetir pós-deploy, confirmar node Ready,
   dados preservados, firewall IMDS e metrics-server. Demonstrar que pod comum não
   obtém token IMDS. Testar admission contra hostNetwork/privileged antes de workloads.
10. Exportar contrato não sensível; seguir ordem K3s -> RDS -> migrações/app ->
    Lambda/auth -> observabilidade/testes ponta a ponta. Sem leitura cruzada de states.

## Rollback/recriação

Procedimento detalhado obrigatório: [backup e restauração](backup-restore.md).

Antes de mudar AMI/user-data/K3s: interromper workloads e K3s em janela de manutenção;
criar backup consistente de /var/lib/rancher/k3s e /etc/rancher/k3s (inclui token e
chaves), ou snapshot EBS consistente autorizado e criptografado. Registrar custo e
retenção. Não copiar datastore SQLite em uso. Backup não é fornecido automaticamente.
Validar restauração em procedimento aprovado antes de depender de dados importantes.
Reverter commit para versão conhecida, revisar plan de replace e aprovar; EC2 nova
recebe IP diferente e root novo. Restaurar dados com K3s parado e mesma versão,
permissões root e token originais; verificar Ready, pods e volumes antes de liberar.
Nunca fazer downgrade sobre datastore migrado sem backup compatível.
