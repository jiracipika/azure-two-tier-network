from pathlib import Path
import re
import unittest

root = Path(__file__).resolve().parents[1]


class Tests(unittest.TestCase):
    def test_agent_docs(self):
        self.assertTrue((root / "AGENTS.md").exists())
        self.assertTrue((root / "docs/GLM_TASKS.md").exists())

    def test_safety_gate(self):
        self.assertRegex(
            (root / "infra/terraform/variables.tf").read_text(),
            r'"deploy_enabled"\s*\{[^}]*default\s*=\s*false',
        )
        self.assertNotIn("terraform apply", (root / ".github/workflows/validate.yml").read_text())

    def test_architecture(self):
        self.assertIn("flowchart", (root / "diagrams/architecture.mmd").read_text())

    def test_terraform_layout(self):
        expected_modules = ["hub_network", "bastion", "web_tier", "app_tier"]
        for module in expected_modules:
            self.assertTrue((root / "infra/terraform/modules" / module / "main.tf").exists(),
                            f"module {module} is missing")

    def test_gitignore_keeps_environment_tfvars(self):
        """Scaffold trap: tfvars negation must not be root-anchored only."""
        gi = (root / ".gitignore").read_text()
        self.assertIn("!**/environments/*.tfvars", gi)
        self.assertIn(".mimosa/", gi)

    def test_env_file_exists_and_keeps_deploy_off(self):
        tfvars = (root / "infra/terraform/environments/dev.tfvars").read_text()
        self.assertRegex(tfvars, r"deploy_enabled\s*=\s*false")


if __name__ == "__main__":
    unittest.main()
