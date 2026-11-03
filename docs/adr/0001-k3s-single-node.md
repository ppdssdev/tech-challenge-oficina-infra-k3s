# ADR 0001 — K3s single-node em vez de EKS

**Status:** Implementada em staging; consolidada em 2026-11-03. Registro consolidado a partir das fontes; não inventa data de
aprovação original nem transforma propostas em implantação.

## Contexto

O monólito precisa demonstrar orquestração e HPA em escopo acadêmico, mantendo implantação administrável.

## Decisão

Manter um nó K3s em EC2, SSM e ECR. Terraform permite t3.medium, c7i-flex.large ou m7i-flex.large; a auditoria encontrou m7i-flex.large. EKS não foi implantado.

## Consequências e reavaliação

Menos componentes no escopo, mas manutenção do K3s, backups e recuperação são responsabilidade da equipe. Nó/control plane e workloads compartilham falha; réplicas não dão HA. Reavaliar EKS/múltiplos nós quando houver SLO de disponibilidade, carga ou capacidade operacional que justifique.

## Evidências

[compute.tf](../../compute.tf), [variables.tf](../../variables.tf), [operação](../operational-validation.md).
