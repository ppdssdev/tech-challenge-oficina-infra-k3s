# Evidências consolidadas — Fase 3, Grupo 97

Pedro Paulo dos Santos Silva · Discord pedropaulo6447. Auditoria: 2026-11-03.
Baseline deste repositório: `10fa81e88e8e5cd9ab06fe8661cf1a735be26675`. Alterações desta PR são somente documentais.
Não houve deploy, alteração funcional, Terraform apply/state nem pipeline.

A fonte central de status é a [entrega Fase 3](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/README.md), com
[matriz](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/evidence-matrix.md),
[coleta operacional](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/operational-evidence.md),
[diagramas](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/deployment-architecture.md)
e [RFCs/ADRs](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/decisions.md).
Links novos em main dependem do merge da PR documental da API; durante revisão,
consultar a branch da PR. Fontes de código anteriores permanecem fixadas por SHA.

| Evidência | Situação |
|---|---|
| Implementação | Código/main auditado, não só bootstrap |
| CI da baseline | Success conforme run abaixo; não equivale a deploy |
| Cloud | Consultas somente leitura e inventário SSM registrados centralmente |
| OIDC/CD | PR preparatória aberta; SCP impede auditoria provider; sem CD main |
| Produção | Não implantada/demonstrada nesta entrega |
| Evidências históricas | Resultados datados, não estado atual |

[CI K3s](https://github.com/ppdssdev/tech-challenge-oficina-infra-k3s/actions/runs/41625905236).
Observados: EC2 m7i-flex.large running, K3s v1.34.6+k3s1, um nó Ready, API 3/3,
SSM Online, ECR IMMUTABLE/KMS/scanOnPush, endpoint Secrets Manager Interface em duas
subnets com private DNS. SG app sem ingressos. Prometheus/Grafana/tracing ausentes
do inventário do cluster; Metrics Server operacional. Sem leitura de state, não
foi certificada ausência de drift nem migração efetiva de backend.

Reprodução local: `bash scripts/preflight.sh`, com dependências do README.
Via SSM, somente leitura: `sudo k3s kubectl get deployments -A`,
`sudo k3s kubectl -n oficina-staging get hpa`, `sudo k3s kubectl top nodes`.
Pendentes: reboot/restore/IMDS nos pods, HPA sob carga, observabilidade e OIDC/CD.

Consulta complementar GitHub: PR/checks obrigatórios, zero aprovações humanas
exigidas; soat-architecture ainda não adicionado neste repo. Subject OIDC usa IDs
imutáveis e diverge da trust por nomes na PR K3s #5. Correções de IAM/governança
não fazem parte desta PR documental.
[Fontes e comandos](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/governance-audit.md).
