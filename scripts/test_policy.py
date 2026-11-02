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
            ("variables.tf", '["t3.medium", "c7i-flex.large", "m7i-flex.large"]', '["t3.medium", "p5.48xlarge"]'),
            ("providers.tf", 'CostCenter', 'MissingCostTag'),
            ("security.tf", 'cidr_ipv4         = each.value.cidr_block', 'cidr_ipv4 = "0.0.0.0/0"'),
            ("security.tf", 'from_port         = 5432', 'from_port = 5431'),
            ("security.tf", 'security_group_id = aws_security_group.auth.id', 'security_group_id = aws_security_group.app.id'),
            ("outputs.tf", 'schema_version         = 3', 'schema_version = 2'),
            ("outputs.tf", 'sensitive   = false', 'sensitive = true'),
            ("outputs.tf", 'account_id             = tostring(var.aws_account_id)', 'account_id = "000000000000"'),
            ("ecr.tf", 'image_tag_mutability = "IMMUTABLE"', 'image_tag_mutability = "MUTABLE"'),
            ("ecr-pull.tf", 'ecr:BatchGetImage', 'ecr:*'),
            ("secretsmanager-endpoint.tf", 'var.enable_secretsmanager_endpoint ? toset(["enabled"]) : toset([])', 'toset(["enabled"])'),
            ("secretsmanager-endpoint.tf", 'for_each = aws_security_group.secretsmanager_endpoint', 'for_each = { enabled = {} }'),
            ("secretsmanager-endpoint.tf", 'private_dns_enabled = true', 'private_dns_enabled = false'),
            ("secretsmanager-endpoint.tf", 'vpc_endpoint_type = "Interface"', 'vpc_endpoint_type = "Gateway"'),
            ("secretsmanager-endpoint.tf", 'com.amazonaws.us-east-2.secretsmanager', 'com.amazonaws.us-east-1.secretsmanager'),
            ("secretsmanager-endpoint.tf", '[for key in sort(keys(aws_subnet.private)) : aws_subnet.private[key].id]', '[aws_subnet.public.id]'),
            ("secretsmanager-endpoint.tf", 'security_group_ids = [each.value.id]', 'security_group_ids = [aws_security_group.app.id]'),
            ("secretsmanager-endpoint.tf", 'referenced_security_group_id = aws_security_group.auth.id', 'cidr_ipv4 = "0.0.0.0/0"'),
            ("secretsmanager-endpoint.tf", 'referenced_security_group_id = aws_security_group.auth.id', 'referenced_security_group_id = aws_security_group.app.id'),
            ("secretsmanager-endpoint.tf", 'referenced_security_group_id = each.value.id', 'cidr_ipv4 = "10.30.0.0/16"'),
            ("secretsmanager-endpoint.tf", 'security_group_id = aws_security_group.auth.id', 'security_group_id = aws_security_group.app.id'),
            ("secretsmanager-endpoint.tf", 'from_port = 443', 'from_port = 0'),
            ("secretsmanager-endpoint.tf", 'to_port = 443', 'to_port = 65535'),
            ("secretsmanager-endpoint.tf", 'ip_protocol = "tcp"', 'ip_protocol = "-1"'),
            ("secretsmanager-endpoint.tf", 'Action = "secretsmanager:GetSecretValue"', 'Action = "secretsmanager:*"'),
            ("secretsmanager-endpoint.tf", 'Resource = var.secretsmanager_endpoint_secret_arn', 'Resource = "*"'),
            ("secretsmanager-endpoint.tf", '"aws:PrincipalArn" = var.secretsmanager_endpoint_role_arn', '"aws:PrincipalArn" = "*"'),
            ("secretsmanager-endpoint.tf", '"aws:PrincipalArn" = aws_iam_role.node.arn', '"aws:PrincipalArn" = "*"'),
            ("secretsmanager-endpoint.tf", 'jsondecode(aws_iam_role_policy.app_secrets.policy).Statement[0].Resource', '"*"'),
            ("secretsmanager-endpoint.tf", 'jsondecode(aws_iam_role_policy.app_secrets.policy).Statement[0].Resource', 'var.secretsmanager_endpoint_secret_arn'),
            ("secretsmanager-endpoint.tf", 'referenced_security_group_id = aws_security_group.app.id', 'referenced_security_group_id = aws_security_group.auth.id'),
            ("secretsmanager-endpoint.tf", 'security_group_id = aws_security_group.app.id', 'security_group_id = aws_security_group.auth.id'),
            ("app-secrets-iam.tf", 'secretsmanager:GetSecretValue', 'secretsmanager:*'),
            ("app-secrets-iam.tf", 'oficina/staging/jwt-secret', 'oficina/staging/*'),
            ("network.tf", 'enable_dns_support = true', 'enable_dns_support = false'),
            ("network.tf", 'enable_dns_hostnames = true', 'enable_dns_hostnames = false'),
            ("secretsmanager-endpoint.tf", 'var.secretsmanager_endpoint_secret_arn != null && var.secretsmanager_endpoint_role_arn != null', 'true'),
            ("variables.tf", 'variable "enable_secretsmanager_endpoint" { type = bool default = false', 'variable "enable_secretsmanager_endpoint" { type = bool default = true'),
            ("variables.tf", '^arn:aws:secretsmanager:us-east-2:${var.aws_account_id}', '^arn:aws:secretsmanager:.*:.*'),
            ("variables.tf", '^arn:aws:iam::${var.aws_account_id}:role/', '^arn:aws:iam::.*:role/'),
            ("outputs.tf", 'try(aws_vpc_endpoint.secretsmanager["enabled"].id, null)', 'aws_vpc_endpoint.secretsmanager["enabled"].id'),
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

    def test_stack_boundaries(self):
        for extra in ('resource "aws_db_instance" "postgres" {}',
                      'resource "aws_db_subnet_group" "postgres" {}',
                      'resource "aws_security_group" "postgres" {}',
                      'data "terraform_remote_state" "rds" { backend = "local" }',
                      'data "aws_secretsmanager_secret_version" "forbidden" { secret_id = "forbidden" }',
                      'resource "aws_vpc_endpoint_security_group_association" "duplicate" {}',
                      'resource "aws_vpc_endpoint_policy" "duplicate" {}',
                      'resource "aws_security_group_rule" "duplicate" {}'):
            with self.subTest(extra=extra), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                for source in ROOT.glob("*.tf"):
                    shutil.copy(source, root / source.name)
                (root / "extra.tf").write_text(extra)
                with self.assertRaises(AssertionError):
                    validate(root)

if __name__ == "__main__":
    unittest.main()
