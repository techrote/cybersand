"""Workflow entry tests: strict input validation, rejection diagnostics, dry-run and refused-live paths."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from atlas_agent import receipt as receipt_mod, workflow_run  # noqa: E402
from atlas_agent.errors import ConfigError  # noqa: E402

BASE = {"IN_SOURCE": "fixture", "IN_COLLECTION": "mini-vault", "IN_MODE": "dry-run", "IN_LANE": "auto"}


class InputValidationTests(unittest.TestCase):
    def reject(self, **changes):
        env = {**BASE, **changes}
        with self.assertRaises(ConfigError, msg=str(changes)):
            workflow_run.parse_inputs(env)

    def test_valid_defaults_parse(self):
        values = workflow_run.parse_inputs(BASE)
        self.assertEqual((values["mode"], values["max_usd"], values["iterations"]), ("dry-run", "0.25", "8"))

    def test_injection_shaped_and_malformed_inputs_are_rejected(self):
        hostile = ["../../etc", "Lumen", "a; rm -rf /", "$(id)", "`id`", "x\ny", "a b", "-flag", "mini-vault && echo",
                   "a" * 80]
        for value in hostile:
            self.reject(IN_COLLECTION=value)
        for value in ("bad/name", "a b", "$(id)", "`id`", "x" * 81, "a;b", "a\\b"):
            self.reject(IN_ARTIFACT_NAME=value)
        self.reject(IN_SOURCE="somewhere")
        self.reject(IN_LANE="admin")
        self.reject(IN_MODE="turbo")
        self.reject(IN_ATLAS_SHA="abc")
        self.reject(IN_ATLAS_SHA="G" * 40)
        self.reject(IN_MODEL="gpt 5; echo")
        self.reject(IN_MAX_USD_RUN="26")
        self.reject(IN_MAX_USD_RUN="1e3")
        self.reject(IN_MAX_USD_RUN="-1")
        self.reject(IN_AUTH_CEILING="1000")
        self.reject(IN_MAX_ITER="0")
        self.reject(IN_MAX_ITER="31")
        self.reject(IN_MAX_ITER="2; ls")
        self.reject(IN_ATTEST_JSON="{not json")
        self.reject(IN_ATTEST_JSON="[1, 2]")
        self.reject(IN_ATTEST_JSON="{" + '"a":' * 1500 + "1}")
        self.reject(IN_AUTH_REF="line1\nline2")
        self.reject(IN_COLLECTION="lumen-fault")  # fixture only offers mini-vault

    def test_chargeable_actions_runs_require_manual_dispatch(self):
        self.reject(IN_MODE="live", IN_MODEL="gpt-5.4-mini", GITHUB_ACTIONS="true",
                    GITHUB_EVENT_NAME="pull_request")
        self.reject(IN_MODE="live", IN_MODEL="gpt-5.4-mini", GITHUB_ACTIONS="true",
                    GITHUB_EVENT_NAME="workflow_call")
        ok = workflow_run.parse_inputs({**BASE, "IN_MODE": "live", "IN_MODEL": "gpt-5.4-mini",
                                        "GITHUB_ACTIONS": "true", "GITHUB_EVENT_NAME": "workflow_dispatch"})
        self.assertEqual(ok["mode"], "live")

    def test_live_requirements(self):
        self.reject(IN_MODE="live", IN_MODEL="")
        self.reject(IN_MODE="live", IN_MODEL="gpt-5.4-mini", IN_SOURCE="atlas-ref", IN_COLLECTION="lumen-fault")
        ok = workflow_run.parse_inputs({**BASE, "IN_MODE": "live", "IN_MODEL": "gpt-5.4-mini",
                                        "IN_SOURCE": "atlas-ref", "IN_COLLECTION": "lumen-fault",
                                        "IN_ATLAS_SHA": "a" * 40})
        self.assertEqual(ok["mode"], "live")


class EntryPointTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="atlas-wf-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = {**BASE, "RUNNER_TEMP": str(self.root / "tmp"), "ATLAS_AGENT_OUT": str(self.root / "out"),
                    "GITHUB_STEP_SUMMARY": str(self.root / "summary.md"), "GITHUB_OUTPUT": str(self.root / "output.txt"),
                    "GITHUB_WORKSPACE": str(self.root)}

    def test_rejected_inputs_still_leave_a_diagnostic_artifact(self):
        self.env["IN_COLLECTION"] = "../../x"
        self.assertEqual(workflow_run.main([], self.env), 2)
        info = json.loads((self.root / "out" / "input-rejected.json").read_text(encoding="utf-8"))
        self.assertTrue(info["rejected"])
        self.assertEqual(workflow_run.main(["--validate-only"], self.env), 2)

    def test_complete_fixture_dry_run(self):
        self.assertEqual(workflow_run.main([], self.env), 0)
        out = self.root / "out"
        self.assertEqual(receipt_mod.verify_receipt(out / "receipt.json"), [])
        rec = json.loads((out / "receipt.json").read_text(encoding="utf-8"))
        self.assertEqual((rec["status"]["final"], rec["run"]["mode"], rec["usage"]["api_responses"]),
                         ("success", "dry-run", 6))
        self.assertTrue((out / "patch.diff").is_file())
        summary = (self.root / "summary.md").read_text(encoding="utf-8")
        self.assertIn("**success**", summary)
        self.assertIn("simulated", summary)
        self.assertIn("exit_code=0", (self.root / "output.txt").read_text(encoding="utf-8"))

    def test_live_without_credentials_is_an_unmistakable_failure_with_diagnostics(self):
        self.env.update({"IN_MODE": "live", "IN_MODEL": "gpt-5.4-mini", "IN_AUTH_CEILING": "0.25",
                         "IN_AUTH_REF": "owner approval"})
        self.assertEqual(workflow_run.main([], self.env), 3)
        rec = json.loads((self.root / "out" / "receipt.json").read_text(encoding="utf-8"))
        self.assertEqual((rec["status"]["final"], rec["status"]["reason_code"]), ("failure", "credentials_missing"))
        self.assertEqual(rec["usage"]["api_attempts"], 0)
        summary = (self.root / "summary.md").read_text(encoding="utf-8")
        self.assertIn("Refused by the live gate", summary)
        self.assertIn("exit_code=3", (self.root / "output.txt").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
