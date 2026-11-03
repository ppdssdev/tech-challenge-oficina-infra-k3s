import tempfile
import shutil
import unittest
from pathlib import Path
from policy import ROOT, validate

class OidcBoundary(unittest.TestCase):
    def test_rejects_trust_and_permission_mutations(self):
        source = (ROOT / "github_oidc.tf").read_text()
        for old, new in [
            ('sts.amazonaws.com', 'evil.example'),
            ('refs/heads/main', 'refs/heads/*'),
            ('repo:ppdssdev/', 'repo:*/'),
            ('ref:refs/heads/main', 'pull_request'),
            ('default     = false', 'default     = true'),
            ('max_session_duration = 3600', 'max_session_duration = 43200'),
        ]:
            with self.subTest(new=new), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                for p in ROOT.glob("*.tf"):
                    shutil.copy(p, root / p.name)
                self.assertIn(old, source)
                (root / "github_oidc.tf").write_text(source.replace(old, new))
                with self.assertRaises(AssertionError):
                    validate(root)
