# Compatibilidade Free Plan — verificação em 2026-11-01

Não foi consultada a conta AWS. Saldo, data de abertura, quotas, permissões e
serviços disponíveis permanecem desconhecidos. Nenhum crédito foi usado para
validar infraestrutura. Budget US$5 é alerta, não bloqueio de consumo; e-mails ainda
não confirmados. Não fazer upgrade nem criar chaves permanentes para contornar erro.

[AWS EC2 Free Tier](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html)
lista t3.micro, t3.small, t4g.micro, t4g.small, c7i-flex.large e m7i-flex.large para
contas novas elegíveis. **t3.medium não consta dessa lista**. O default é proposta
de dimensionamento, bloqueada por eligibility_confirmed=false; não é promessa de
execução no Free Plan. c7i-flex.large (x86, 2 vCPU/4 GiB) é alternativa explicitamente
permitida, sujeita a preço, quota e disponibilidade Ohio. Não trocar automaticamente
nem tentar lançar t3.medium se a conta não permitir. t3.small 2 GiB não é alternativa
suficiente presumida para Java + control plane + observabilidade.

Antes de autorizar: proprietário verifica Billing, créditos/expiração, plano,
EC2 instance types elegíveis, disponibilidade em us-east-2a e quotas On-Demand.
Verificar SSM Session Manager e snap/AMI aprovados, IAM role/profile e PassRole,
permissões EC2/VPC/EBS, KMS gerenciada e eventuais SCP/permission boundaries.
Permissão de console não implica permissão IAM para Terraform. Solicitar role
específica ao responsável pela conta, sem presumir AdministratorAccess nem root.
Se uma dependência exigir Paid Plan, parar e apresentar alternativa/custo ao dono.

Sem garantia de serviços gratuitos: EC2, EBS e IPv4 debitam créditos conforme conta.
Parar EC2 não remove EBS; evitar unlimited CPU credits (t3 usa standard). Esta fase
não cria endpoints, logs, NAT, EKS, ALB/NLB, RDS ou segundo ambiente.
