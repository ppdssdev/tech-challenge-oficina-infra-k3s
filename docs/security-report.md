# Segurança e limites da evidência

Sem chamadas de provisionamento, plan real, credenciais AWS ou deploy no CI.
Terraform fixa 1.14.6 e AWS provider 6.38.0 com lockfile. Conta e região restritas;
staging único, allowlist t3.medium/c7i-flex.large, gp3 30–40 GiB, gate de elegibilidade.

Sem SSH/key pair, entradas 22/6443/5432 ou NodePort. HTTPS externo opt-in por CIDR;
saída 443 global é necessária a GitHub, registry e SSM com IPs dinâmicos, mas permite
exfiltração via TLS por workload comprometida. DNS Amazon e NTP link-local não
exigem regra de saída ampla. SG default vazio, privadas sem IP público/rota internet.
IMDSv2, hop limit 1 e firewall IMDS não substituem política de admissão Kubernetes.

IAM: trust apenas ec2.amazonaws.com, cinco ações SSM/ssmmessages. Resource=* é
necessário para essas APIs; sem GetParameter, S3, KMS decrypt, Secrets Manager,
AdministratorAccess ou permissões das futuras workloads. Operador de Session
Manager é administrador do host: restringir StartSession, documentos e instâncias
por role/tag, MFA/SSO, e TerminateSession a sessões próprias. Port forwarding não
produz transcrição do tráfego. SSM indisponível/permissão insuficiente bloqueia a
operação; não abrir SSH como contorno.

## Exceções Checkov locais e justificadas

| Check | Recurso | Justificativa/compensação |
|---|---|---|
| CKV_AWS_88 | EC2 | IPv4 de saída sem NAT; SG fechado por padrão |
| CKV_AWS_126 | EC2 | Sem detailed monitoring pago; métricas básicas + journal |
| CKV2_AWS_11 | VPC | Flow Logs adiados por custo; menor capacidade forense aceita para staging |
| CKV2_AWS_5 | SG auth | Reservado para futura Lambda; sem regras |
| CKV_AWS_290 / CKV_AWS_355 | IAM SSM | Canais Session Manager requerem Resource=*; ações fixadas |

Não há soft-fail nem skip global. Revisar exceções antes de produção. Checkov não
prova ausência de todas as vulnerabilidades. Policy AST compara inventário,
configurações de segurança e variáveis com baseline versionada: qualquer alteração
exige revisão explícita do código **e** da política. Nunca regenerar baseline
automaticamente no CI. Novos recursos (inclusive RDS público, EKS, NAT, segunda
instância) são rejeitados por padrão; a fase RDS deverá ter políticas próprias.
Os testes por mutação demonstram regressões rejeitadas. Baseline não é assinatura
contra autor malicioso que edite política e código: CODEOWNERS/revisão continuam
necessários. Checkov secrets analisa repositório; não publicar dumps ou tfvars.

Bootstrap testa sintaxe, ShellCheck e execução simulada de sucesso, checksum
inválido e readiness falha. Testes não validam kernel, snap, download real em EC2,
SSM, reboot, CNI, imagens ou rede AWS. Esses testes constam do runbook pós-deploy.
EBS usa chave gerenciada AWS; não cria CMK paga. Root e snapshots podem conter
segredos gerados pelo K3s e precisam acesso restrito. Dados não são protegidos
contra destruição da EC2: backup/restore é obrigação operacional.
