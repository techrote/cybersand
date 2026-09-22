import tempfile
from pathlib import Path
import unittest

from check_ci_provider_policy import check


class CiProviderPolicyTests(unittest.TestCase):
    def repo(self):
        temp = tempfile.TemporaryDirectory()
        root = Path(temp.name)
        (root / ".github" / "workflows").mkdir(parents=True)
        return temp, root

    def test_github_hosted_workflow_passes(self):
        temp, root = self.repo()
        with temp:
            (root / ".github/workflows/native.yml").write_text(
                "jobs:\\n  native:\\n    runs-on: ubuntu-24.04\\n", encoding="utf-8"
            )
            self.assertEqual(check(root)["status"], "passed")

    def test_circleci_config_is_rejected(self):
        temp, root = self.repo()
        with temp:
            (root / ".circleci").mkdir()
            (root / ".circleci/config.yml").write_text("version: 2.1\\n", encoding="utf-8")
            self.assertEqual(check(root)["status"], "failed")

    def test_external_runner_label_is_rejected(self):
        temp, root = self.repo()
        with temp:
            (root / ".github/workflows/native.yml").write_text(
                "jobs:\\n  native:\\n    runs-on: sengi-standard-2-ubuntu-2404\\n",
                encoding="utf-8",
            )
            result = check(root)
            self.assertEqual(result["status"], "failed")
            self.assertTrue(any("external CI/provider" in e for e in result["errors"]))

    def test_runner_variable_indirection_is_rejected(self):
        temp, root = self.repo()
        with temp:
            (root / ".github/workflows/native.yml").write_text(
                "jobs:\\n  native:\\n"
                "    runs-on: ${{ vars.NATIVE_RUNNER || 'ubuntu-24.04' }}\\n",
                encoding="utf-8",
            )
            result = check(root)
            self.assertEqual(result["status"], "failed")
            self.assertTrue(any("*_RUNNER" in e for e in result["errors"]))

    def test_self_hosted_is_rejected(self):
        temp, root = self.repo()
        with temp:
            (root / ".github/workflows/native.yml").write_text(
                "jobs:\\n  native:\\n    runs-on: self-hosted\\n", encoding="utf-8"
            )
            self.assertEqual(check(root)["status"], "failed")

    def test_historical_docs_are_out_of_scope(self):
        temp, root = self.repo()
        with temp:
            (root / ".github/workflows/native.yml").write_text(
                "jobs:\\n  native:\\n    runs-on: ubuntu-24.04\\n", encoding="utf-8"
            )
            (root / "docs").mkdir()
            (root / "docs/history.md").write_text(
                "Historical Avrea, Sengi and CircleCI notes.\\n", encoding="utf-8"
            )
            self.assertEqual(check(root)["status"], "passed")


if __name__ == "__main__":
    unittest.main()
