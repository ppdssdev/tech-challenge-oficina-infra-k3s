"""Execute bootstrap with fake OS commands in a disposable directory.
Verifies fail-closed checksum and no ready marker on unhealthy cluster.
Never installs software/services on the test host.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from policy import ROOT

class BootstrapTests(unittest.TestCase):
    def run_bootstrap(self, fail, stale_marker=False):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for directory in ('etc/modules-load.d', 'etc/sysctl.d', 'etc/systemd/system', 'var/log', 'usr/local/bin'):
                (root / directory).mkdir(parents=True)
            if stale_marker:
                (root / 'var/lib/oficina').mkdir(parents=True)
                (root / 'var/lib/oficina/bootstrap-complete').touch()
            source = (ROOT / 'scripts/bootstrap.sh').read_text()
            for prefix in ('/var/', '/etc/', '/usr/local/'):
                source = source.replace(prefix, tmp + prefix)
            (root / 'bin').mkdir()
            mock = '#!/bin/bash\nname=$(basename "$0")\n[[ "$name" != "$FAIL" ]] || exit 1\nif [[ "$name" == curl ]]; then touch "${@: -1}"; fi\nif [[ "$name" == install ]]; then cp "$K3S_MOCK" "${@: -1}"; chmod +x "${@: -1}"; fi\n'
            for name in ('modprobe', 'sysctl', 'snap', 'curl', 'iptables', 'sha256sum', 'install', 'systemctl', 'sleep'):
                path = root / 'bin' / name
                path.write_text(mock)
                path.chmod(0o755)
            k3s = root / 'mock-k3s'
            k3s.write_text('#!/bin/bash\n[[ "$FAIL" != readiness ]]\n')
            env = dict(os.environ, PATH=str(root / 'bin') + ':' + os.environ['PATH'], FAIL=fail, K3S_MOCK=str(k3s))
            result = subprocess.run(['bash', '-c', source], env=env, capture_output=True)
            return result.returncode, (root / 'var/lib/oficina/bootstrap-complete').exists(), (root / 'usr/local/bin/k3s').exists()

    def test_success(self):
        self.assertEqual(self.run_bootstrap(''), (0, True, True))

    def test_checksum_failure(self):
        code, marker, binary = self.run_bootstrap('sha256sum')
        self.assertNotEqual(code, 0)
        self.assertFalse(marker)
        self.assertFalse(binary)

    def test_failed_rerun_removes_stale_marker(self):
        code, marker, _ = self.run_bootstrap('sha256sum', stale_marker=True)
        self.assertNotEqual(code, 0)
        self.assertFalse(marker)

    def test_unhealthy_cluster(self):
        code, marker, _ = self.run_bootstrap('readiness')
        self.assertNotEqual(code, 0)
        self.assertFalse(marker)

if __name__ == '__main__':
    unittest.main()
