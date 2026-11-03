# Integração privada CPF: transporte e sequência documental

Adendo de 2026-11-03 sobre [K3s #6](https://github.com/ppdssdev/tech-challenge-oficina-infra-k3s/pull/6), base `e1994e2275f4b1c708d3655be7bf0fe2a7728f88`. Mantém o README, [runbook histórico](../deployment-runbook.md), [evidência histórica](../fase3-evidence.md) e [contrato da stack](../stack-contract.md). Os comandos de sessão abaixo foram preparados, **não executados nesta revisão**. Não são autorização para deploy, alteração de IAM/rede/Terraform, banco, Lambda ou Gateway.

## Bloqueio HTTPS e adapter restrito

O [manifest Java auditado](https://github.com/ppdssdev/tech-challenge-oficina/blob/469984555ea3b1d0d40580ada20144e2d01550b1/k8s/staging/api.yaml) define `oficina-api` como ClusterIP, `http:8080`; não oferece HTTPS Java. Port-forward SSM apenas transporta bytes: não converte o listener HTTP em HTTPS. Portanto o requisito HTTPS original de `scripts/cpf_demo.py` da [Lambda #6](https://github.com/ppdssdev/tech-challenge-oficina-auth-lambda/pull/6) é incompatível com o caminho observado sem adapter explícito. Não criar Ingress, LoadBalancer, NodePort, abrir Gateway ou desabilitar validação TLS para contornar.

A correção proposta deve ser revisada e testada antes da operação: `java_transport: "ssm-loopback"`, `java_url: "http://127.0.0.1:18080"`, `ssm_tunnel_attested: true`. Só admite essa origem e os GETs `/api/v1/customer/work-orders/<UUID canônico>` e `/api/v1/admin/work-orders`; rejeita outros hosts, portas, caminhos, redirects e proxies. O modo HTTPS continua padrão; JWKS e issuer continuam HTTPS com CA/hostname, e assinatura RS256, issuer, audience, kid e validade temporal continuam verificados. Ativar o adapter não habilita Lambda.

O adapter não comprova sozinho quem possui o listener local. A atestação deve vincular sessão SSM, conta, região, instância, pod, digest e listener aos valores inspecionados. Operador e nó devem ser confiáveis; o HTTP termina no pod por port-forward. **Não declarar HTTPS fim a fim até o servidor Java**: trata-se de HTTP em loopback dentro de canais SSM/Kubernetes autenticados e criptografados. Se a política exigir HTTPS terminado no próprio Java, manter bloqueado e encaminhar a outra frente; não alterar Java aqui.

## Operador: consultas e estabelecimento do caminho privado

Primeiro, consultas somente leitura com perfil já configurado. Não imprimir variáveis completas da Lambda, Secrets ou ConfigMaps com credenciais:

```bash
test "$(aws --profile oficina-staging --region us-east-2 sts get-caller-identity --query Account --output text)" = 797781632267
aws --profile oficina-staging --region us-east-2 ssm describe-instance-information \
  --filters Key=InstanceIds,Values=i-0ab373b1ba5c14b3e \
  --query 'InstanceInformationList[].{Id:InstanceId,Status:PingStatus}'
aws --profile oficina-staging --region us-east-2 ec2 describe-instances \
  --instance-ids i-0ab373b1ba5c14b3e \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,Vpc:VpcId,Groups:SecurityGroups[].GroupId}'
aws --profile oficina-staging --region us-east-2 lambda get-function-concurrency \
  --function-name oficina-staging-auth
aws --profile oficina-staging --region us-east-2 apigatewayv2 get-api \
  --api-id t6p562hkc9 --query '{Id:ApiId,Disabled:DisableExecuteApiEndpoint}'
aws --profile oficina-staging --region us-east-2 apigatewayv2 get-routes \
  --api-id t6p562hkc9 --query 'Items[].{Route:RouteKey,Auth:AuthorizationType}'
```

A instância/API são referências documentadas, não descoberta garantida. Se não coincidirem com o ambiente aprovado, interromper. Exigir SSM Online, concorrência zero, execute-api desabilitado e rota AWS_IAM. Não corrigir divergência automaticamente. Uma falha de permissão é bloqueio; não alterar acesso.

Para futura sessão privada autorizada, terminal 1 do operador:

```bash
aws --profile oficina-staging --region us-east-2 ssm start-session \
  --target i-0ab373b1ba5c14b3e
```

Dentro do nó, inspecionar somente nomes, portas, estado e imagens:

```bash
sudo k3s kubectl -n oficina-staging get service oficina-api \
  -o jsonpath='{.spec.type}{" "}{.spec.ports[*].port}{"\n"}'
sudo k3s kubectl -n oficina-staging get deployment oficina-api \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="api")].image}{"\n"}'
sudo k3s kubectl -n oficina-staging get pods -l app=oficina-api \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.deletionTimestamp}{" "}{.status.containerStatuses[?(@.name=="api")].ready}{" "}{.status.containerStatuses[?(@.name=="api")].imageID}{"\n"}{end}'
```

Selecionar pod Ready sem término, pertencente ao deployment/digest aprovado; conferir ownerReferences e UID antes de continuar. O smoke em um pod não comprova todos os pods. Não selecionar pod novo automaticamente após perda da sessão.

```bash
read -r -p 'Pod validado: ' JAVA_POD
sudo k3s kubectl -n oficina-staging get pod "$JAVA_POD" \
  -o jsonpath='{.metadata.uid}{" "}{.metadata.ownerReferences}{"\n"}'
sudo ss -ltnp 'sport = :18080'
sudo k3s kubectl -n oficina-staging port-forward --address 127.0.0.1 \
  "pod/$JAVA_POD" 18080:8080
```

A porta deve estar livre antes de iniciar. Preservar CA, hostname e autenticação do kubeconfig nativo K3s; não usar `--insecure-skip-tls-verify`. Em terminal 2 do operador, conferir que 18080 local está livre e criar a sessão de encaminhamento:

```bash
ss -ltnp 'sport = :18080'
aws --profile oficina-staging --region us-east-2 ssm start-session \
  --target i-0ab373b1ba5c14b3e --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["18080"],"localPortNumber":["18080"]}'
```

Conferir listener somente em loopback e proprietário do processo. Nenhum JWT/CPF passa por argumentos de shell ou comandos SSM; o bearer futuro permanece em memória do smoke e no stream encaminhado. Não ativar tracing HTTP, captura de tráfego ou gravação de terminal. Falha de sessão/listener, pod substituído ou diferença de digest invalida a atestação e bloqueia a janela. Encerrar ambos os processos após a operação. Não expor `0.0.0.0`.

Para RDS usar [inventário e TLS privado](https://github.com/ppdssdev/tech-challenge-oficina-infra-rds/blob/docs/fase3-final-audit/docs/fase3/security-integration-review.md): sessão SSM separada até o hostname RDS e `hostaddr=127.0.0.1 port=15432`, preservando `host` RDS/CA/`verify-full`. Esse documento acompanha a PR RDS #8; o link usa a branch documental até a integração em main. Não executar bootstrap ou SQL destrutivo.

## Gates de dados, janela e aceite

Inventariar sem pressupor A/B/C/D. Dois donos distintos devem possuir OS existentes e provar **200** individualmente antes da negação cruzada; inventário agregado não prova origem sintética/allowlist. Sem fixtures aprovadas, registrar bloqueio e plano mínimo na frente RDS, sem criar dados. Ausência de token exige **401**, CUSTOMER em ADMIN exige **403**, OS alheia exige **404**. Divergência entre JWKS na cadeia CUSTOMER e PEM na cadeia ADMIN não autoriza mudar expectativa para 401.

O preflight é somente leitura; a janela de emissão requer autorização separada, recuperação em host/credenciais independentes, prazo limitado e leitura final comprovando concorrência zero. Não executar `window`, `watchdog` ou `close` nesta entrega: os dois últimos também escrevem concorrência. Nunca assumir que trap local cobre perda do host/rede. JWT já emitido continua válido até expirar, mesmo com concorrência zero.

## CI, evidências e integração

`.github/workflows/ci.yml` roda preflight estático, políticas, formatação e TFLint; não demonstra SSM, Kubernetes, RDS ou comportamento Java em staging. Scripts e sessões operacionais são outra camada, manual, sem constituir CD. A auditoria de promoção por digest pertence ao [runbook API](https://github.com/ppdssdev/tech-challenge-oficina/blob/469984555ea3b1d0d40580ada20144e2d01550b1/docs/staging/release-local.md); distinguir imagem produzida/publicada de digest observado no deployment e em cada pod. Não executar release nesta frente.

Roteiro preliminar: registrar UTC/SHAs/checks reais; estado fechado inicial; digest/UID e transporte aprovado; inventário agregado e proveniência privada; gates criptográficos; matriz 200/401/403/404; estado final de concorrência zero lido por duas vias. Prints e logs não devem conter tokens, CPFs, senhas, dados pessoais, Secrets ou bodies de OS.

Integrar [API #13](https://github.com/ppdssdev/tech-challenge-oficina/pull/13) antes de [API #14](https://github.com/ppdssdev/tech-challenge-oficina/pull/14), e [Lambda #6](https://github.com/ppdssdev/tech-challenge-oficina-auth-lambda/pull/6) com correção antes de [Lambda #7](https://github.com/ppdssdev/tech-challenge-oficina-auth-lambda/pull/7). Relacionar [K3s #6](https://github.com/ppdssdev/tech-challenge-oficina-infra-k3s/pull/6) e [RDS #8](https://github.com/ppdssdev/tech-challenge-oficina-infra-rds/pull/8), reconsultando heads/checks após cada alteração futura. Esta revisão não faz merge, deploy nem modifica o README de outra frente.

## Snapshot consultado e correção preparada

[Snapshot GitHub/AWS e acesso efetivo](https://github.com/ppdssdev/tech-challenge-oficina/blob/docs/fase3-final-audit/docs/fase3/security-review-evidence.md):
checks das bases consultadas aprovados; API write e outros três read para
`soat-architecture`, sem convites pendentes. Lambda zero, Gateway desabilitado
AWS_IAM, API 3/3 privada; nenhuma consulta SQL no RDS. Não confundir esses
checks anteriores com validação dos novos heads documentais.

[Lambda #8](https://github.com/ppdssdev/tech-challenge-oficina-auth-lambda/pull/8)
contém a correção do adapter e prazo de cleanup, empilhada sobre #6. Sua base não
aciona o workflow atual; exigir CI no SHA final antes da integração em main.
O [runbook corretivo](https://github.com/ppdssdev/tech-challenge-oficina-auth-lambda/blob/fix/private-cpf-review/docs/fase3/private-transport-review.md)
traz os comandos privados e limites. A janela continua não autorizada nesta frente.
