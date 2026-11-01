"""Mutation tests prove the gate rejects regressions without an AWS plan."""
import shutil
import tempfile
import unittest
from pathlib import Path
from policy import ROOT, validate

class PolicyTests(unittest.TestCase):
    def test_baseline(self):
        validate()

    def test_mutations(self):
        cases = [
            ("compute.tf", 'http_tokens                 = "required"', 'http_tokens                 = "optional"'),
            ("compute.tf", 'encrypted             = true', 'encrypted             = false'),
            ("security.tf", 'from_port         = 443', 'from_port         = 22'),
            ("network.tf", 'map_public_ip_on_launch = false', 'map_public_ip_on_launch = true'),
            ("iam.tf", 'ssm:UpdateInstanceInformation', 'iam:*'),
            ("variables.tf", 'var.root_volume_gib <= 40', 'var.root_volume_gib <= 4000'),
            ("variables.tf", '["t3.medium", "c7i-flex.large"]', '["t3.medium", "p5.48xlarge"]'),
            ("providers.tf", 'CostCenter', 'MissingCostTag'),
        ]
        for filename, before, after in cases:
            with self.subTest(filename=filename, change=after), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                for source in ROOT.glob("*.tf"):
                    shutil.copy(source, root / source.name)
                path = root / filename
                content = path.read_text()
                # Formatting-independent replacement for HCL whitespace.
                import re
                pattern = r"\s*".join(re.escape(s) for s in before.split())
                content, count = re.subn(pattern, lambda _: after, content)
                self.assertGreater(count, 0)
                path.write_text(content)
                with self.assertRaises(AssertionError):
                    validate(root)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for source in ROOT.glob("*.tf"):
                shutil.copy(source, root / source.name)
            (root / "extra.tf").write_text('resource "aws_nat_gateway" "bad" {}')
            with self.assertRaises(AssertionError):
                validate(root)

if __name__ == "__main__":
    unittest.main()
