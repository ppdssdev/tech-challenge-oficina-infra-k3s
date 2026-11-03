# ADR 0002 — Terraform por repositório e contrato explícito

**Status:** Backends/contratos implementados; estado remoto não lido; 2026-11-03. Registro consolidado a partir das fontes; não inventa data de
aprovação original nem transforma propostas em implantação.

## Contexto

Separar ownership, ciclo de vida e revisão de rede/compute, dados e autenticação.

## Decisão

Roots separados para K3s, RDS e auth, backend S3 com chave/lock próprios. K3s publica integration_contract v3; RDS e auth validam entradas. API não assume ownership de recursos AWS por copiar Terraform.

## Consequências e reavaliação

Reduz acoplamento de state e blast radius, mas exige coordenação de versões, ordem de deploy e controle de acesso a outputs. Rede precede RDS/auth; teardown na ordem inversa. Backend configurado não comprova migração efetiva, versionamento ou permissões S3/KMS. Não usar workspace como substituto de isolamento.

## Evidências

[outputs.tf](../../outputs.tf), [backend.tf](../../backend.tf), [contrato](../stack-contract.md).
