# Backup e restauração — SQLite e volumes locais

Procedimento futuro em janela autorizada; não executado nesta revisão. Single-node
implica indisponibilidade. Definir RPO (último backup verificado), RTO medido no
ensaio, responsável, retenção e destino criptografado externo à EC2. Backup somente
no root desaparece junto com a instância. Não criar S3/snapshot pago automaticamente.

`user_data_replace_on_change=true` e `delete_on_termination=true`: alterar bootstrap
ou AMI pode substituir EC2 e apagar SQLite, tokens e volumes. Destroy também apaga.
Reboot/stop-start preserva root, mas não constitui backup. State Terraform não contém
os dados do cluster. Não autorizar replace/destroy antes de validar cópia externa.

## Captura consistente

1. Registrar SHA, versão/checksum do K3s, configuração, hostname/node name, AMI,
   UID/GID dos volumes e inventário PV/PVC (caminho real e nodeAffinity). Registrar
   réplicas/CronJobs antes de suspendê-los. Identificar hostPaths e local-path fora
   do diretório padrão; precisam de cópia própria. Inventário pode conter segredos:
   proteger como backup, fora do Git e de artifacts CI.
2. Bloquear tráfego e escritores; suspender jobs/controllers da aplicação, escalar
   workloads a zero e aguardar terminação. Fazer flush/backup específico da aplicação.
   Salvar sentinelas e checksums nos volumes para o ensaio. Manter esse estado até
   terminar a cópia. Não confundir parada do K3s com parada dos containers:
   `KillMode=process` permite que continuem vivos.
3. `sudo systemctl stop k3s`; confirmar serviço parado e ausência do processo server.
   Conferir `sudo k3s crictl ps` e parar containers remanescentes individualmente com
   `sudo k3s crictl stop ID` enquanto o runtime estiver acessível. Confirmar nenhum
   escritor/processo usando os caminhos. Se não for possível comprovar quiescência,
   interromper o backup; não copiar SQLite aberto. Não usar uninstall/remoção de dados.
4. Em shell root (`sudo -i`, sem tracing), com disco suficiente e K3s parado:

```sh
umask 077
backup_dir=$(mktemp -d /var/tmp/oficina-backup.XXXXXX)
tar --acls --xattrs --numeric-owner -C / -cpf "$backup_dir/cluster.tar" \
  var/lib/rancher/k3s/server \
  etc/rancher/k3s \
  etc/rancher/node \
  etc/systemd/system/k3s.service \
  etc/systemd/system/oficina-imds-guard.service
# Se houver PVCs no caminho padrão; caminhos customizados exigem arquivo separado.
if [ -d /var/lib/rancher/k3s/storage ]; then
  tar --acls --xattrs --numeric-owner -C / -cpf "$backup_dir/local-volumes.tar" \
    var/lib/rancher/k3s/storage
fi
(cd "$backup_dir" && sha256sum ./*.tar > SHA256SUMS)
```

O arquivo server inclui db SQLite completo (inclusive WAL/SHM presentes), TLS,
configuração de criptografia e tokens server/agent; preservar alvos de symlinks
customizados separadamente. `/etc/rancher/k3s` contém kubeconfig administrativo e
configuração; `/etc/rancher/node` preserva identidade/senha do nó. Não imprimir esses
arquivos. Proteger arquivo tar como segredo (0600 não é criptografia): criptografar
com ferramenta/chave aprovada e transferir via canal seguro ao destino aprovado.
Conferir checksum após transferência, retenção e acesso à chave antes de remover
staging. Falha de cópia bloqueia replace/destroy. Reiniciar K3s e workloads conforme
réplicas registradas se for continuar operando; repetir pós-deploy.

## Restauração e aceite

1. Em destino autorizado, mesma versão K3s e arquitetura, isolar tráfego. Impedir
   que nó antigo e restaurado operem simultaneamente com a mesma identidade.
   Esperar cloud-init terminar e parar K3s/containers antes de restaurar. Não repetir
   bootstrap sobre dados restaurados; ele reescreve configuração.
2. Recuperar/descriptografar arquivos em diretório root:0700 fora do Git, conferir
   `sha256sum -c SHA256SUMS` e listar caminhos do tar. Usar somente arquivo confiável.
   Preservar estado anterior do destino em cópia separada; restaurar em diretórios
   vazios, sem mesclar db/tokens/certificados de um cluster recém-criado.
3. Com K3s parado, extrair `cluster.tar` e arquivos de volumes no `/` com
   `tar --acls --xattrs --numeric-owner -xpf ARQUIVO -C /`. Preservar donos/modos
   originais, inclusive UID/GID da aplicação; não aplicar chown root recursivo nos
   PVCs. Kubeconfig deve ser root:0600. Restaurar token original junto com SQLite;
   nunca gerar token substituto. Não usar `etcd-snapshot`/`cluster-reset` para SQLite.
4. Preservar node name/hostname registrado antes de iniciar (e senha de nó), ou
   elaborar migração explícita de nodeAffinity dos PVs. EC2 nova pode ter outro IP
   e nome; copiar arquivos não resolve afinidade, DNS ou certificados sozinho.
   Não executar dois nós com a mesma identidade. Reavaliar endereço do kubeconfig
   e túnel SSM; distribuir cópia atualizada segura quando necessária.
5. `sudo systemctl daemon-reload` e `sudo systemctl start oficina-imds-guard k3s`.
   Repetir post-deploy e teste IMDS. Confirmar namespaces/Secrets legíveis, PVCs Bound,
   montagem e leitura/escrita de cada volume, checksums sentinela e teste funcional
   da aplicação. Retomar réplicas/jobs registrados somente após aceite; registrar
   tempo real (RTO) e ponto dos dados (RPO). Falha: manter tráfego fechado e preservar
   backup; não fazer downgrade sobre datastore migrado.

A exigência de preservar db e token segue o [guia K3s](https://docs.k3s.io/datastore/backup-restore).
Este procedimento amplia a cópia para configuração e dados locais; só o ensaio
comprova recuperabilidade. Snapshots EBS são opção futura cobrada e exigem a mesma
quiescência, criptografia, retenção e autorização. RDS terá backup/runbook próprio.
