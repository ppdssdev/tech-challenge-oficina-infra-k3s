#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
python3 scripts/policy.py
python3 -m unittest discover -s scripts -p 'test_*.py'
bash -n scripts/bootstrap.sh scripts/post-deploy.sh
shellcheck scripts/*.sh
checkov --directory . --framework terraform --compact
checkov --directory . --framework secrets --compact
