# Evidência operacional — pendente de primeiro boot AWS

Nenhum comando deste documento foi executado na AWS. CI e mocks validam sintaxe,
políticas e tratamento de erros; não certificam boot, isolamento de rede ou recuperação.
Executar apenas após autorização de provisionamento, na revisão aprovada, via SSM.

## Checklist de aceite

Registrar data UTC, operador, SHA, AMI, instance ID, tipo, região, versão K3s e
resultado de cada item (PASS/FAIL/PENDENTE). Nunca anexar tokens, kubeconfig ou state.

- [ ] Antes de plan/apply: registrar tipo exato em tfvars, disponibilidade em Ohio,
  elegibilidade **da conta e do tipo** no Free Plan, data de expiração do plano,
  créditos restantes e validade, custo estimado por hora e mês para duração prevista.
  Consultar Billing/Free Tier/Credits e preços atuais; não inferir saldo de budgets.
  Incluir EC2, gp3, IPv4, tráfego, snapshots e impostos aplicáveis. Guardar evidência
  sanitizada e aprovação do proprietário. Estimativa antiga não autoriza consumo;
  `eligibility_confirmed=true` sozinho não comprova elegibilidade nem aprovação.
- [ ] `bash scripts/post-deploy.sh`: cloud-init concluído sem erro, marcador,
  cada serviço ativo/habilitado, kubeconfig root:0600, node Ready, deployments
  CoreDNS/Metrics Server/local-path disponíveis, API ready, APIService de métricas
  disponível e `top nodes` com amostras. Revisar `secrets-encrypt status`: enabled
  e hashes consistentes. Revisar pods Pending/CrashLoop e eventos; não aceitar só listagem.
- [ ] SSM aparece Online em `describe-instance-information`, sessão funciona com
  role mínima e túnel 16443 funciona sem entrada pública 22/6443. Agente ativo não
  comprova registro/conectividade com o serviço AWS.
- [ ] Executar teste IMDS abaixo e guardar saída sanitizada, identidade do pod,
  digest/imageID e regras/contadores antes/depois. Repetir após reboot e restart K3s.
- [ ] Reboot autorizado, reconexão SSM e todos os checks novamente; confirmar dados
  locais preservados. Não aceitar marcador antigo como prova de boot atual.
- [ ] Ensaio de backup/restauração aprovado conforme [runbook](backup-restore.md),
  com checksum de arquivo sentinela em cada PVC, leitura funcional e tempo de recuperação.

## Teste reproduzível do IMDS

Escolher imagem pública curl com `sh`, CA e suporte a UID 10001, revisar e fixar
**digest amd64**. Registrar referência e `imageID`; não usar `latest` nem digest
fictício. Copiar scripts da revisão aprovada para a EC2 por canal autorizado.

```sh
# IMAGEM_CURL é uma referência real revista, como registry/repo@sha256:<64 hex>.
bash scripts/verify-imds.sh --authorized "$IMAGEM_CURL"
```

O teste cria namespace temporário com Pod Security restricted v1.34, sem token de
service account, hostNetwork/hostPID/hostIPC, hostPath, capabilities ou privilégio.
Verifica IMDSv2 no host descartando o token; dentro do pod verifica DNS externo,
HTTPS e DNS/Service do Kubernetes com a CA do cluster. Só aceita IMDS GET e PUT sem
resposta HTTP e curl 7/28. HTTP 401/403 também reprova: demonstra acesso ao endpoint.
ImagePullBackOff, erro DNS/TLS, imagem incompatível ou controle do host falhando
são falha/inconclusivo, nunca sucesso. Namespace é removido ao sair; confirmar remoção
se a sessão SSM for interrompida. Não executar este teste em CI nem em máquina local.

O hop limit restringe a resposta PUT; a regra FORWARD complementa o bloqueio.
Veja [opções IMDS da AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-options.html).
A presença da regra não garante precedência sobre chains inseridas pelo K3s; usar
resultado funcional e contadores. Se houver acesso, bloquear deploy e revisar a
ordem das regras, sem aumentar hop limit nem remover a proteção para fazer passar.
IPv6 está fora desta topologia: habilitá-lo exige teste do endpoint `fd00:ec2::254`
e proteção correspondente. O resultado vale para a configuração e rede testadas,
não constitui prova universal contra workloads com acesso ao host.

Antes de workloads reais, aplicar PSA restricted nos namespaces de aplicação e
validar rejeição com `kubectl apply --dry-run=server` para variantes hostNetwork,
privileged, hostPath e capabilities extras. Manter exceções de sistema restritas
por RBAC. O teste isola seu namespace; não configura admission para aplicações futuras.

## O que obrigatoriamente precisa da AWS real

| Validação | Por que mock não certifica |
|---|---|
| AMI/cloud-init e pré-requisitos curl/iptables/snap/SSM | Conteúdo real da AMI, seed do snap, kernel e ordem do boot |
| Download K3s e imagens, checksum, systemd/cgroups/Flannel | DNS, rota/SG 443, registries, binário e kernel reais |
| SSM Online/sessão/túnel | IAM efetivo, credenciais IMDS e endpoints regionais |
| CoreDNS, API e Metrics Server | CNI, resolução, certificados e coleta kubelet reais |
| Bloqueio IMDS de pods | MetadataOptions efetivas, hops e ordem de netfilter |
| Reboot/stop-start e persistência | EBS, IP mutável e reconstrução de regras/serviços |
| Restore SQLite e PVCs | Consistência, identidade do nó, afinidade e dados reais |
| RDS futuro TCP/TLS 5432 | Exige também banco provisionado e regras nas duas pontas |

Elegibilidade, saldo e preço requerem evidência atual da conta, mas não exigem boot.
RDS e ensaio destrutivo de recuperação têm autorização própria; primeiro boot sozinho
não os certifica. Não declarar esses itens concluídos com base em testes locais.
