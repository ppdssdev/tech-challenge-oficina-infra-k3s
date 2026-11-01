#!/bin/bash
# Execute dentro da EC2 via SSM, somente após provisionamento autorizado.
set -euo pipefail
sudo timeout 1200 cloud-init status --wait
sudo test -f /var/lib/oficina/bootstrap-complete
# Consultar unidades separadamente: is-active com várias pode passar se só uma estiver ativa.
for unit in k3s oficina-imds-guard snap.amazon-ssm-agent.amazon-ssm-agent; do
  sudo systemctl is-active --quiet "$unit"
  sudo systemctl is-enabled --quiet "$unit"
done
sudo test "$(sudo stat -c '%U:%a' /etc/rancher/k3s/k3s.yaml)" = root:600
sudo k3s --version
sudo k3s kubectl wait --for=condition=Ready nodes --all --timeout=180s
for deployment in coredns metrics-server local-path-provisioner; do
  sudo k3s kubectl -n kube-system rollout status "deployment/$deployment" --timeout=180s
done
sudo k3s kubectl wait --for=condition=Available apiservice/v1beta1.metrics.k8s.io --timeout=180s
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
sudo k3s kubectl get --raw=/readyz
metrics_ready=false
for _ in $(seq 1 18); do
  if sudo k3s kubectl top nodes; then metrics_ready=true; break; fi
  sleep 10
done
[ "$metrics_ready" = true ]
sudo k3s secrets-encrypt status
sudo iptables -C FORWARD -d 169.254.169.254/32 -j REJECT
# Teste funcional obrigatório separado: scripts/verify-imds.sh (ver runbook).
