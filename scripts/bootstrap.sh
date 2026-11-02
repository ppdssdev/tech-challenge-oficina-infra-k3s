#!/bin/bash
set -euo pipefail
umask 077
exec >>/var/log/oficina-bootstrap.log 2>&1
trap 'echo "Bootstrap failed at line $LINENO"' ERR
# No remote installer, secrets or shell tracing. Immutable binary and digest.
K3S_VERSION='v1.34.6+k3s1'
K3S_SHA256='7c81556ac1212213a07180f92eca57db8caef886e58bbad15e9dada10782c10d'
mkdir -p /var/lib/oficina /etc/rancher/k3s /var/lib/rancher/k3s
# Uma repetição malsucedida não pode preservar evidência de sucesso anterior.
rm -f /var/lib/oficina/bootstrap-complete
cat >/etc/modules-load.d/k3s.conf <<'EOF'
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
cat >/etc/sysctl.d/90-k3s.conf <<'EOF'
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sysctl --system
# Noble official cloud image includes curl, iptables, snap and SSM agent.
command -v curl
command -v iptables
snap list amazon-ssm-agent
snap start --enable amazon-ssm-agent
cat >/etc/rancher/k3s/config.yaml <<'EOF'
write-kubeconfig-mode: "0600"
secrets-encryption: true
disable:
  - traefik
  - servicelb
kube-apiserver-arg:
  - anonymous-auth=false
kubelet-arg:
  - system-reserved=cpu=200m,memory=384Mi
  - kube-reserved=cpu=200m,memory=384Mi
EOF
curl --fail --location --proto '=https' --tlsv1.2 --retry 5 --retry-delay 5 \
  "https://github.com/k3s-io/k3s/releases/download/$K3S_VERSION/k3s" -o /var/lib/oficina/k3s.download
printf '%s  %s\n' "$K3S_SHA256" /var/lib/oficina/k3s.download | sha256sum --check --strict
install -m 0755 /var/lib/oficina/k3s.download /usr/local/bin/k3s
rm /var/lib/oficina/k3s.download
# Defense for ordinary pod networking; hostNetwork/privileged need admission controls.
cat >/etc/systemd/system/oficina-imds-guard.service <<'EOF'
[Unit]
Description=Block pod access to instance metadata
Before=k3s.service
After=network-online.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c '/usr/sbin/iptables -C FORWARD -d 169.254.169.254/32 -j REJECT || /usr/sbin/iptables -I FORWARD 1 -d 169.254.169.254/32 -j REJECT'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
cat >/etc/systemd/system/k3s.service <<'EOF'
[Unit]
Description=K3s server
Wants=network-online.target
After=network-online.target oficina-imds-guard.service
Requires=oficina-imds-guard.service
[Service]
Type=notify
ExecStart=/usr/local/bin/k3s server
Restart=always
RestartSec=10
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=0
TasksMax=infinity
TimeoutStartSec=0
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now oficina-imds-guard.service k3s.service
ready=false
for _ in $(seq 1 90); do
  if /usr/local/bin/k3s kubectl wait --for=condition=Ready node --all --timeout=10s; then
    ready=true
    break
  fi
  sleep 10
done
[ "$ready" = true ]
touch /var/lib/oficina/bootstrap-complete
echo 'K3s bootstrap completed; run post-deploy checks before deploying workloads.'
