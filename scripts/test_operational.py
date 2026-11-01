"""Failure gates only; mocks do not certify AWS networking or services."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class OperationalTests(unittest.TestCase):
    def post_deploy(self, fail=''):
        with tempfile.TemporaryDirectory() as tmp:
            sudo = Path(tmp) / 'sudo'
            sudo.write_text('''#!/bin/bash
case "$*" in
  "stat "*) echo root:600;;
esac
[[ -z "$FAIL" || "$*" != *"$FAIL"* ]]
''')
            sudo.chmod(0o755)
            sleep = Path(tmp) / 'sleep'
            sleep.write_text('#!/bin/sh\nexit 0\n')
            sleep.chmod(0o755)
            return subprocess.run(['bash', str(ROOT / 'scripts/post-deploy.sh')],
                env=dict(os.environ, PATH=tmp + ':' + os.environ['PATH'], FAIL=fail),
                capture_output=True).returncode

    def test_healthy(self):
        self.assertEqual(self.post_deploy(), 0)

    def test_unhealthy_components_fail_closed(self):
        for failure in ('cloud-init', 'is-active --quiet k3s',
                        'is-active --quiet oficina-imds-guard',
                        'is-active --quiet snap.amazon-ssm-agent',
                        'deployment/coredns', 'deployment/metrics-server',
                        'apiservice/', 'top nodes', 'iptables'):
            with self.subTest(failure=failure):
                self.assertNotEqual(self.post_deploy(failure), 0)

    def test_imds_requires_explicit_invocation_and_digest(self):
        for args in ([], ['--authorized', 'curlimages/curl:latest']):
            result = subprocess.run(['bash', str(ROOT / 'scripts/verify-imds.sh'), *args],
                                    capture_output=True)
            self.assertEqual(result.returncode, 2)

    def test_imds_probe_rejects_http_and_unrelated_errors(self):
        source = (ROOT / 'scripts/verify-imds.sh').read_text()
        probe = source.split("<<'PROBE'\n", 1)[1].split('\nPROBE', 1)[0]
        with tempfile.TemporaryDirectory() as tmp:
            curl = Path(tmp) / 'curl'
            curl.write_text('''#!/bin/sh
case "$*" in
  *example.com*) exit "$CONTROL_RC";;
  *kubernetes.default.svc*) printf 401; exit 0;;
  *169.254.169.254*) printf '%s' "$IMDS_HTTP"; exit "$IMDS_RC";;
esac
exit 99
''')
            curl.chmod(0o755)
            for rc, http, control, passes in ((7, '000', 0, True), (28, '000', 0, True),
                    (0, '200', 0, False), (0, '401', 0, False), (0, '403', 0, False),
                    (6, '000', 0, False), (7, '000', 6, False)):
                with self.subTest(rc=rc, http=http, control=control):
                    result = subprocess.run(['sh', '-c', probe], capture_output=True,
                        env=dict(os.environ, PATH=tmp + ':' + os.environ['PATH'],
                                 IMDS_RC=str(rc), IMDS_HTTP=http, CONTROL_RC=str(control)))
                    self.assertEqual(result.returncode == 0, passes)
