"""Fail-closed source policy. No plan, credentials or AWS calls required."""
import json
from pathlib import Path
import re
import hcl2

ROOT = Path(__file__).resolve().parents[1]

def validate(root=ROOT):
    resources = {}
    data_sources = {}
    config = {}
    for path in root.glob("*.tf"):
        doc = hcl2.loads(path.read_text())
        for forbidden in ("module", "import", "removed"):
            assert forbidden not in doc, f"Unexpected {forbidden}"
        for block in doc.get("resource", []):
            for kind, entries in block.items():
                for name, value in entries.items():
                    key = f"{kind}.{name}"
                    assert key not in resources
                    resources[key] = value
        for block in doc.get("data", []):
            for kind, entries in block.items():
                for name, value in entries.items():
                    data_sources[f"{kind}.{name}"] = value
        for block in doc.get("variable", []):
            config.update(block)
    assert data_sources == json.loads((ROOT / "policies/data-baseline.json").read_text()), "AMI identity or data source changed"
    expected = json.loads((ROOT / "policies/inventory.json").read_text())
    assert sorted(resources) == expected, "Resource inventory changed: review cost/security policy"
    # Security-sensitive AST snapshots reviewed alongside code. Prevent arbitrary
    # new rules, inline IAM, public private subnets, counts and provisioners.
    baseline = json.loads((ROOT / "policies/security-baseline.json").read_text())
    for key, value in baseline.items():
        assert resources[key] == value, f"Security boundary changed: {key}"
    for value in resources.values():
        assert not any(k in value for k in ("provisioner", "connection", "count"))
    variables = json.loads((ROOT / "policies/variables-baseline.json").read_text())
    assert config == variables, "Sizing/region/eligibility validation changed"
    providers = hcl2.loads((root / "providers.tf").read_text())
    assert providers == json.loads((ROOT / "policies/providers-baseline.json").read_text()), "Account/region/tags changed"
    workflow = (root / ".github/workflows/ci.yml").read_text()
    assert not re.search(r"terraform\s+(apply|destroy|plan)|id-token:\s*write|configure-aws-credentials", workflow)
    bootstrap = (root / "scripts/bootstrap.sh").read_text()
    assert "sha256sum --check --strict" in bootstrap
    assert "set -euo pipefail" in bootstrap
    assert not re.search(r"curl[^\n]*\|\s*(sh|bash)|set -x", bootstrap)
    assert 'secrets-encryption: true' in bootstrap
    assert '169.254.169.254/32 -j REJECT' in bootstrap
    print(f"Policy passed: {len(resources)} resource blocks; security, cost, IAM, CI boundaries checked")

if __name__ == "__main__":
    validate()
