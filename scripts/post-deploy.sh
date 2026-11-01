#!/bin/bash
# Execute dentro da EC2 via SSM, somente após provisionamento autorizado.
set -euo pipefail
sudo cloud-init status --wait
sudo test -f /var/lib/oficina/bootstrap-complete
sudo systemctl is-active k3s oficina-imds-guard
sudo snap services amazon-ssm-agent
sudo k3s --version
sudo k3s kubectl wait --for=condition=Ready nodes --all --timeout=180s
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
sudo k3s kubectl get --raw=/readyz
sudo k3s kubectl top nodes
sudo k3s secrets-encrypt status
sudo iptables -C FORWARD -d 169.254.169.254/32 -j REJECT
