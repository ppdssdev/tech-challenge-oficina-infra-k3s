#!/bin/bash
# Somente na EC2 via SSM após autorização. Cria/remove um namespace de teste.
set -euo pipefail
if [[ ${1:-} != --authorized ]]; then
  echo 'Uso: bash scripts/verify-imds.sh --authorized IMAGEM_CURL@sha256:DIGEST' >&2
  exit 2
fi
image=${2:-}
[[ $image =~ ^[a-zA-Z0-9./:_-]+@sha256:[a-f0-9]{64}$ ]] || { echo 'Exige imagem curl aprovada por digest.' >&2; exit 2; }
k() { sudo k3s kubectl "$@"; }
# Controle positivo no host: descarta token, não consulta credenciais da role.
code=$(curl --noproxy '*' -sS --connect-timeout 3 --max-time 10 -o /dev/null -w '%{http_code}' \
  -X PUT -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' http://169.254.169.254/latest/api/token)
[[ $code == 200 ]] || { echo 'IMDS indisponível no host: teste inconclusivo.' >&2; exit 1; }
sudo iptables -C FORWARD -d 169.254.169.254/32 -j REJECT
ns="imds-check-$(date +%s)-$$"
k create namespace "$ns"
trap 'k delete namespace "$ns" --wait=true --timeout=120s' EXIT
k label namespace "$ns" pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.34
k -n "$ns" apply -f - <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: probe
spec:
  automountServiceAccountToken: false
  hostNetwork: false
  hostPID: false
  hostIPC: false
  restartPolicy: Never
  activeDeadlineSeconds: 240
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: curl
      image: $image
      command: [sh, -c, 'sleep 230']
      securityContext:
        privileged: false
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: [ALL]
      resources:
        requests: {cpu: 10m, memory: 16Mi}
        limits: {cpu: 100m, memory: 64Mi}
      volumeMounts:
        - name: ca
          mountPath: /ca
          readOnly: true
  volumes:
    - name: ca
      configMap:
        name: kube-root-ca.crt
YAML
k -n "$ns" wait --for=condition=Ready pod/probe --timeout=180s
k -n "$ns" get pod probe -o wide
# Falha de imagem, DNS, TLS ou saída geral nunca é interpretada como bloqueio IMDS.
k -n "$ns" exec -i probe -- sh -s <<'PROBE'
set -eu
curl --noproxy '*' -fsS --connect-timeout 5 --max-time 15 -o /dev/null https://example.com
code=$(curl --noproxy '*' -sS --cacert /ca/ca.crt --connect-timeout 5 --max-time 15 -o /dev/null -w '%{http_code}' https://kubernetes.default.svc)
[ "$code" = 401 ] || [ "$code" = 403 ]
for method in GET PUT; do
  rc=0
  path=meta-data/
  [ "$method" != PUT ] || path=api/token
  code=$(curl --noproxy '*' -sS --connect-timeout 3 --max-time 5 -o /dev/null -w '%{http_code}' \
    -X "$method" -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' "http://169.254.169.254/latest/$path") || rc=$?
  echo "IMDS $method: curl=$rc HTTP=$code"
  # Qualquer resposta HTTP, inclusive 401/403, prova acesso e reprova o teste.
  [ "$code" = 000 ] && { [ "$rc" = 7 ] || [ "$rc" = 28 ]; } || exit 1
done
PROBE
sudo iptables -nvL FORWARD --line-numbers
printf '%s\n' 'PASS: pod restrito sem acesso HTTP ao IMDS; controles de rede passaram.'
