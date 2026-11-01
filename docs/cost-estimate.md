# Estimativa de custos — Ohio, 2026-11-01

Cotação pública sem login AWS. Catálogo AmazonEC2 publicado em 2026-10-29T17:56:34Z,
consultado em 2026-11-01. [Evidência reduzida com SKUs](pricing-evidence.json), extraída
[do catálogo oficial us-east-2](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonEC2/current/us-east-2/index.json).
IPv4: [preço oficial AWS VPC](https://aws.amazon.com/vpc/pricing/), US$0,005/h.
Preços em USD, Linux Shared On-Demand, 730 h/mês, sem impostos, descontos ou créditos.

| Recurso | Hipótese | USD/h | USD/mês |
|---|---|---:|---:|
| EC2 t3.medium | 1 instância, CPU standard | 0,04160 | 30,368 |
| EBS gp3 | 30 GiB x 0,08/GiB-mês | 0,003288 equivalente | 2,400 |
| IPv4 público | 1 endereço | 0,00500 | 3,650 |
| **Total default** | **sem tráfego extra** | **0,049888 equivalente** | **36,418** |
| EC2 c7i-flex.large alternativa | substitui t3.medium | 0,08479 | 61,8967 |
| **Total alternativa** | **gp3 e IPv4 incluídos** | **0,093078 equivalente** | **67,9467** |

O valor horário do EBS é apenas mensal/730 para comparação. Armazenamento é
cobrado pelo volume provisionado, mesmo com EC2 parada. 40 GiB custariam US$3,20/mês.
Sem IOPS/throughput adicionais: gp3 baseline 3000 IOPS/125 MiB/s; não há configuração
de expansão automática. t3 usa créditos standard para evitar cobrança unlimited,
com risco de throttling sob carga sustentada. Não há Spot.

VPC, subnets, SG, tabelas, IGW e IAM não introduzem mensalidade horária própria
nesta topologia. Sem EIP reservado, CMK própria, NAT, EKS, load balancer, endpoints,
CloudWatch custom logs/detailed monitoring ou registry declarados. Logs ficam no
root; consumo de disco deve ser monitorado. SSM Session Manager para EC2 não é
orçado como serviço auxiliar por hora; recursos opcionais de logging/S3/KMS não
estão ativados. Confirmar condições vigentes antes de uso.

**Tráfego não é ilimitado nem incluído no total.** Download de imagens é entrada;
respostas públicas e comunicação futura entre AZs podem cobrar egress/transferência.
Volume de tráfego e franquia agregada da conta são desconhecidos: custo variável
pendente de simulação no [AWS Pricing Calculator](https://calculator.aws/) antes
do primeiro plan. Não inventar uma mensalidade fixa de tráfego. RDS em outra AZ,
snapshots de backup, registry, DNS, certificados pagos, S3 state e endpoints futuros
não estão incluídos; exigem estimativa separada. Para RDS privado + Lambda,
endpoints interface cobram por AZ/hora e GB: comparar com alternativas antes de
adicionar. NAT continua proibido nesta fase.

Uma janela de 8 h com EC2 ligada representa aproximadamente US$0,399 default ou
US$0,745 alternativa, assumindo EBS apagado no fim e rateio simplificado; não é
fatura garantida. Manter EBS/snapshots após a janela gera custo adicional.
O orçamento US$5 seria excedido por qualquer cenário mensal. Budget é alerta,
**não hard cap**; e-mails não estão confirmados. O proprietário deve acompanhar
Billing manualmente, créditos/expiração e desmontar após a apresentação.
Não presumir t3.medium elegível Free Plan: ver [compatibilidade](free-plan-compatibility.md).
