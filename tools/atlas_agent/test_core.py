"""Deterministic unit tests: config, pricing/budget, sandbox, tool boundary, captures, git custody."""
from __future__ import annotations

import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from atlas_agent import atlas, captures, gitops, pricing, receipt as receipt_mod  # noqa: E402
from atlas_agent.budget import Budget  # noqa: E402
from atlas_agent.config import DEFAULTS, check_config, deep_merge  # noqa: E402
from atlas_agent.errors import ConfigError, LimitReached, SandboxViolation, SourceChanged, ToolError  # noqa: E402
from atlas_agent.fixtures.make_capture_bundle import make_bundle  # noqa: E402
from atlas_agent.procs import resolve_executables, run_allowlisted  # noqa: E402
from atlas_agent.sandbox import PathPolicy  # noqa: E402
from atlas_agent.tools import ToolExecutor  # noqa: E402

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "atlas-mini"
COLLECTION = "mini-vault"
PACK = f"docs/world-design/{COLLECTION}/pack.json"


def check_config_task_args(args: list) -> list:
    """Schema problems for task.capture_args (the pattern is the first line of defence)."""
    from atlas_agent.schema import load_schema, validate
    cfg = base_config()
    cfg["task"]["capture_args"] = args
    return validate(cfg, load_schema("config.schema.json"))


def links_unavailable(case: unittest.TestCase, what: str) -> None:
    """Local Windows accounts often cannot create links; CI (Linux) must run these tests."""
    if os.environ.get("ATLAS_AGENT_REQUIRE_LINKS") == "1":
        case.fail(f"{what} unavailable but ATLAS_AGENT_REQUIRE_LINKS=1")
    case.skipTest(f"{what} unavailable on this host")


def base_config(**task) -> dict:
    cfg = copy.deepcopy(DEFAULTS)
    cfg["task"].update({"collection": COLLECTION, "fixture": True})
    cfg["task"].update(task)
    return cfg


def make_workspace(writable: bool = True):
    tmp = tempfile.TemporaryDirectory(prefix="atlas-test-")
    work = Path(tmp.name) / "ws"
    work.mkdir()
    built = atlas.build_workspace(FIXTURE, COLLECTION, [], work)
    policy = PathPolicy(work, atlas.read_globs(COLLECTION, []), atlas.write_globs(COLLECTION, writable))
    return tmp, work, built, policy


class ConfigTests(unittest.TestCase):
    def test_defaults_validate_and_unknown_keys_are_rejected(self):
        check_config(base_config())
        bad = base_config()
        bad["limits"]["surprise"] = 1
        with self.assertRaises(ConfigError):
            check_config(bad)

    def test_hard_caps_cannot_be_exceeded(self):
        for section, key, value in (("limits", "max_iterations", 31), ("spend", "max_usd_per_run", 26),
                                    ("limits", "max_images", 13), ("limits", "max_retries", 7)):
            bad = base_config()
            bad[section][key] = value
            with self.assertRaises(ConfigError, msg=key):
                check_config(bad)

    def test_live_requires_explicit_model_and_safe_base_url(self):
        live = base_config()
        live["mode"] = "live"
        with self.assertRaises(ConfigError) as ctx:
            check_config(live)
        self.assertEqual(ctx.exception.reason_code, "model_not_selected")
        for url in ("https://evil.example.com/v1", "http://api.openai.com/v1", "http://10.0.0.5:8000/v1"):
            cfg = base_config()
            cfg["api"]["base_url"] = url
            with self.assertRaises(ConfigError, msg=url):
                check_config(cfg)
        cfg = base_config()
        cfg["api"]["base_url"] = "http://127.0.0.1:9/v1"
        check_config(cfg)

    def test_source_sha_must_be_full_hex(self):
        for sha in ("abc123", "G" * 40, "A" * 40, "0" * 39):
            with self.assertRaises(ConfigError, msg=sha) as ctx:
                check_config(base_config(expected_source_sha=sha))
            self.assertEqual(ctx.exception.reason_code, "invalid_source_sha")
        check_config(base_config(expected_source_sha="0" * 40))

    def test_inconsistent_limits_rejected(self):
        cfg = base_config()
        cfg["spend"]["max_usd_per_call"] = 1.0
        cfg["spend"]["max_usd_per_run"] = 0.5
        with self.assertRaises(ConfigError):
            check_config(cfg)
        self.assertEqual(deep_merge({"a": {"b": 1}}, {"a": {"c": 2}}), {"a": {"b": 1, "c": 2}})


class PricingBudgetTests(unittest.TestCase):
    def setUp(self):
        self.table = pricing.load_table()
        self.rates = pricing.rates_for("gpt-5.4-mini", self.table, enforce_age=False)

    def test_cost_math_distinguishes_cached_tokens(self):
        self.assertAlmostEqual(self.rates.cost(1_000_000, 0, 0), 0.75)
        self.assertAlmostEqual(self.rates.cost(1_000_000, 1_000_000, 0), 0.075)
        self.assertAlmostEqual(self.rates.cost(0, 0, 1_000_000), 4.5)
        self.assertAlmostEqual(self.rates.worst_case_cost(1000, 500), (1000 * 0.75 + 500 * 4.5) / 1e6)

    def test_unknown_model_and_stale_table_fail_closed(self):
        with self.assertRaises(pricing.PricingUnavailable) as ctx:
            pricing.rates_for("gpt-imaginary", self.table)
        self.assertEqual(ctx.exception.reason_code, "model_not_priced")
        import datetime as dt
        with self.assertRaises(pricing.PricingUnavailable) as ctx:
            pricing.rates_for("gpt-5.4-mini", self.table, dt.date(2027, 6, 1))
        self.assertEqual(ctx.exception.reason_code, "pricing_stale")

    def test_image_token_upper_bounds(self):
        self.assertEqual(pricing.image_tokens_upper_bound(self.rates, 1024, 1024, "high"), 1229)
        self.assertEqual(pricing.image_tokens_upper_bound(self.rates, 2048, 2048, "high"), 3000)
        self.assertEqual(pricing.image_tokens_upper_bound(self.rates, 8000, 8000, "high"), 3000)  # budget ceiling
        tile = pricing.rates_for("gpt-4.1", self.table, enforce_age=False)
        self.assertEqual(pricing.image_tokens_upper_bound(tile, 100, 100, "low"), 85)

    def test_gpt_6_luna_rates_and_conservative_image_bound(self):
        luna = pricing.rates_for("gpt-6-luna", self.table, enforce_age=False)
        self.assertAlmostEqual(luna.cost(1_000_000, 0, 1_000_000), 0.10 + 0.50)
        self.assertAlmostEqual(luna.cost(1_000_000, 1_000_000, 0), 0.01)
        self.assertTrue(luna.supports_reasoning)
        # no published image rule for this model: the bound must not undercut the highest published rule
        small = pricing.image_tokens_upper_bound(luna, 192, 96, "high")
        self.assertGreaterEqual(small, 6 * 3 * 2.46 - 1)
        self.assertGreaterEqual(pricing.image_tokens_upper_bound(luna, 6000, 6000, "high"), 73_000)

    def make_budget(self, live=False, **overrides):
        cfg = copy.deepcopy(DEFAULTS)
        cfg["limits"].update(overrides.pop("limits", {}))
        cfg["spend"].update(overrides.pop("spend", {}))
        clock = overrides.pop("clock", None)
        kwargs = {"clock": clock} if clock else {}
        return Budget(cfg["limits"], cfg["spend"], self.rates, live, **kwargs)

    def test_reserve_commit_reconcile(self):
        budget = self.make_budget()
        res = budget.reserve(10_000, 1_000)
        info = budget.commit(res, 8_000, 2_000, 400, 100)
        self.assertFalse(info["exceeded_reservation"])
        self.assertAlmostEqual(budget.computed_usd, self.rates.cost(8_000, 2_000, 400))
        self.assertEqual((budget.input_tokens, budget.cached_tokens, budget.output_tokens), (8_000, 2_000, 400))
        over = budget.reserve(1_000, 100)
        self.assertTrue(budget.commit(over, 5_000, 0, 100)["exceeded_reservation"])
        self.assertEqual(budget.overruns, 1)

    def test_refusals_per_call_and_per_run_and_authorised(self):
        with self.assertRaises(LimitReached) as ctx:
            self.make_budget(spend={"max_usd_per_call": 0.001}).reserve(10_000, 4_000)
        self.assertEqual(ctx.exception.reason_code, "per_call_cost_ceiling")
        budget = self.make_budget(spend={"max_usd_per_run": 0.02, "max_usd_per_call": 0.02})
        budget.mark_ambiguous(budget.reserve(2_000, 1_000))  # ambiguous: counted as spent
        with self.assertRaises(LimitReached) as ctx:
            budget.reserve(2_000, 3_000)
        self.assertEqual(ctx.exception.reason_code, "per_run_cost_ceiling")
        live = self.make_budget(live=True, spend={"authorised_ceiling_usd": 0.001})
        with self.assertRaises(LimitReached) as ctx:
            live.reserve(5_000, 1_000)
        self.assertEqual(ctx.exception.reason_code, "authorised_spend_exhausted")

    def test_call_iteration_token_and_time_limits(self):
        budget = self.make_budget(limits={"max_api_calls": 1})
        budget.release(budget.reserve(100, 64))
        with self.assertRaises(LimitReached) as ctx:
            budget.reserve(100, 64)
        self.assertEqual(ctx.exception.reason_code, "max_api_calls")
        budget = self.make_budget(limits={"max_iterations": 2})
        budget.start_iteration()
        budget.start_iteration()
        with self.assertRaises(LimitReached) as ctx:
            budget.start_iteration()
        self.assertEqual(ctx.exception.reason_code, "max_iterations")
        with self.assertRaises(LimitReached) as ctx:
            self.make_budget(limits={"max_input_tokens_per_call": 256}).reserve(257, 64)
        self.assertEqual(ctx.exception.reason_code, "max_input_tokens_per_call")
        with self.assertRaises(LimitReached) as ctx:
            self.make_budget(limits={"max_total_output_tokens": 64}).reserve(100, 65)
        self.assertEqual(ctx.exception.reason_code, "max_total_output_tokens")
        ticks = iter([0.0, 5.0, 5000.0])
        budget = self.make_budget(limits={"max_run_seconds": 10}, clock=lambda: next(ticks))
        with self.assertRaises(LimitReached) as ctx:
            budget.reserve(100, 64)
            budget.reserve(100, 64)
        self.assertEqual(ctx.exception.reason_code, "max_run_seconds")


class SandboxTests(unittest.TestCase):
    def setUp(self):
        self.tmp, self.work, self.built, self.policy = make_workspace()
        self.addCleanup(self.tmp.cleanup)

    def test_hostile_paths_are_rejected_before_any_access(self):
        hostile = ["../etc/passwd", "docs/../../x", "/etc/passwd", "C:/Windows/win.ini", "docs\\world-design",
                   "~/x", "docs/world-design/./mini-vault/pack.json", "docs//world-design", "", "a" * 400,
                   "docs/world-design/mini-vault/pack.json\x00.txt", "docs/world-design/mini-vault/pack.json:ads",
                   "docs/world-design/mini-vault/nul", ".git/config", "docs/world-design/mini-vault/x.pem", None, 5]
        for path in hostile:
            with self.assertRaises(SandboxViolation, msg=repr(path)):
                self.policy.check_read(path)
            with self.assertRaises(SandboxViolation, msg=repr(path)):
                self.policy.check_write(path)

    def test_write_custody_is_pack_and_readme_only(self):
        self.policy.check_write(PACK)
        for rel in ("docs/world-design/mini-vault/validate_pack.py", "docs/world-design/mini-vault/render_pack.py",
                    "docs/world-design/mini-vault/preview.svg", "docs/world-design/QUALITY_BAR.md",
                    "native/include/cybersand/material.hpp", "docs/world-design/other/pack.json"):
            with self.assertRaises(SandboxViolation, msg=rel) as ctx:
                self.policy.check_write(rel)
            self.assertEqual(ctx.exception.reason_code, "write_not_permitted")
        readonly = PathPolicy(self.work, atlas.read_globs(COLLECTION, []), atlas.write_globs(COLLECTION, False))
        with self.assertRaises(SandboxViolation):
            readonly.check_write(PACK)

    def test_symlink_and_hardlink_targets_rejected(self):
        outside = Path(self.tmp.name) / "outside.txt"
        outside.write_text("secret", encoding="utf-8")
        link = self.work / "docs/world-design/mini-vault/README.md"
        link.unlink()
        try:
            os.symlink(outside, link)
        except (OSError, NotImplementedError):
            links_unavailable(self, "symlinks")
        with self.assertRaises(SandboxViolation) as ctx:
            self.policy.check_read("docs/world-design/mini-vault/README.md")
        self.assertEqual(ctx.exception.reason_code, "symlink_escape")
        with self.assertRaises(SandboxViolation):
            self.policy.check_write("docs/world-design/mini-vault/README.md")
        self.assertEqual(outside.read_text(encoding="utf-8"), "secret")

    def test_hardlinked_write_target_rejected(self):
        outside = Path(self.tmp.name) / "linked.json"
        outside.write_text("{}", encoding="utf-8")
        target = self.work / PACK
        target.unlink()
        try:
            os.link(outside, target)
        except (OSError, NotImplementedError):
            links_unavailable(self, "hard links")
        with self.assertRaises(SandboxViolation) as ctx:
            self.policy.check_write(PACK)
        self.assertEqual(ctx.exception.reason_code, "hardlink_write")

    def test_replace_text_exactness_and_atomicity(self):
        original = (self.work / PACK).read_bytes()
        with self.assertRaises(ToolError) as ctx:
            self.policy.replace_text(PACK, "not present anywhere", "x", 1000, 10**6)
        self.assertEqual(ctx.exception.code, "no_match")
        with self.assertRaises(ToolError) as ctx:
            self.policy.replace_text(PACK, '"id": ', "x", 1000, 10**6)
        self.assertEqual(ctx.exception.code, "ambiguous_match")
        with self.assertRaises(ToolError) as ctx:
            self.policy.replace_text(PACK, "[9, 8, 6, 2, 65]", "y" * 2000, 100, 10**6)
        self.assertEqual(ctx.exception.code, "edit_too_large")
        self.assertEqual((self.work / PACK).read_bytes(), original)
        result = self.policy.replace_text(PACK, "[9, 8, 6, 2, 65]", "[9, 8, 6, 2, 54]", 1000, 10**6)
        self.assertNotEqual(result["before_sha256"], result["after_sha256"])
        self.assertFalse(list((self.work / "docs/world-design/mini-vault").glob("*.agent-tmp-*")))

    def test_read_is_bounded_and_text_only(self):
        result = self.policy.read_text(PACK, 1, 5, 10_000)
        self.assertEqual(result["end_line"], 5)
        self.assertTrue(result["truncated"])
        tiny = self.policy.read_text(PACK, 1, 400, 40)
        self.assertLessEqual(len(tiny["text"].encode()), 80)
        (self.work / "docs/world-design/mini-vault/README.md").write_bytes(b"\x00\x01binary")
        with self.assertRaises(ToolError) as ctx:
            self.policy.read_text("docs/world-design/mini-vault/README.md", 1, 10, 1000)
        self.assertEqual(ctx.exception.code, "binary_file")

    def test_allowlisted_process_rules(self):
        exes = resolve_executables()
        for argv in (["/bin/sh", "-c", "echo hi"], ["cmd", "/c", "echo hi"], ["git", "status"], []):
            with self.assertRaises(SandboxViolation):
                run_allowlisted(argv, self.work, 5, 1000, exes)
        done = run_allowlisted([sys.executable, "-c", "print('x'*5000)"], self.work, 20, 1000, exes)
        self.assertTrue(done["output_truncated"])
        self.assertEqual(len(done["stdout"]), 1000)
        slow = run_allowlisted([sys.executable, "-c", "import time; time.sleep(60)"], self.work, 1, 1000, exes)
        self.assertTrue(slow["timed_out"])
        self.assertLess(slow["duration_seconds"], 20)

    def test_subprocess_environment_never_holds_the_api_key(self):
        os.environ["OPENAI_API_KEY"] = "sk-test-should-not-leak-0000000000"
        self.addCleanup(os.environ.pop, "OPENAI_API_KEY", None)
        done = run_allowlisted([sys.executable, "-c", "import os; print(os.environ.get('OPENAI_API_KEY'))"],
                               self.work, 20, 1000, resolve_executables())
        self.assertEqual(done["stdout"].strip(), "None")


class ToolBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.tmp, self.work, self.built, self.policy = make_workspace()
        self.addCleanup(self.tmp.cleanup)
        self.sentinel = Path(self.tmp.name) / "sentinel.txt"
        self.sentinel.write_text("untouched", encoding="utf-8")
        self.cfg = base_config()
        self.executor = ToolExecutor(self.cfg, self.work, self.policy, COLLECTION, True, [],
                                     receipt_mod.Redactor(["sk-secret-value-123456"]))

    def call(self, name, args):
        return self.executor.execute(name, args if isinstance(args, str) else json.dumps(args), 1)

    def test_malformed_and_hostile_calls_cannot_escape(self):
        self.executor.limits["max_malformed_tool_calls"] = 100
        self.executor.limits["max_sandbox_violations"] = 100
        before = hashlib.sha256(b"".join(sorted(p.read_bytes() for p in self.work.rglob("*") if p.is_file()))).hexdigest()
        battery = [
            ("replace_text", "not json"), ("replace_text", "[1,2]"), ("replace_text", "null"),
            ("replace_text", {}), ("replace_text", {"path": PACK, "old_text": "x", "new_text": "y", "extra": 1}),
            ("replace_text", {"path": 7, "old_text": "x", "new_text": "y"}),
            ("replace_text", {"path": PACK, "old_text": "", "new_text": "y"}),
            ("replace_text", {"path": "../sentinel.txt", "old_text": "untouched", "new_text": "pwned"}),
            ("replace_text", {"path": str(self.sentinel), "old_text": "untouched", "new_text": "pwned"}),
            ("replace_text", {"path": "docs/world-design/mini-vault/validate_pack.py", "old_text": "sys.exit(1)",
                              "new_text": "sys.exit(0)"}),
            ("read_file", {"path": "../sentinel.txt", "start_line": 1, "max_lines": 5}),
            ("read_file", {"path": "/etc/passwd", "start_line": 1, "max_lines": 5}),
            ("read_file", {"path": PACK, "start_line": -3, "max_lines": 5}),
            ("read_file", {"path": PACK, "start_line": 1, "max_lines": 10**6}),
            ("list_files", {"prefix": "../"}), ("list_files", {"prefix": "/"}),
            ("inspect_pack", {"collection": "../../etc"}), ("inspect_pack", {"collection": "other-collection"}),
            ("run_validator", {"collection": "../x", "kind": "validate"}),
            ("run_validator", {"collection": COLLECTION, "kind": "shell"}),
            ("run_validator", {"collection": COLLECTION, "kind": "validate; rm -rf /"}),
            ("view_image", {"bundle": "input", "shot_id": "../x", "collection": ""}),
            ("nonexistent_tool", {}), ("run_shell", {"command": "echo pwned"}), ("", {}),
        ]
        for name, args in battery:
            outcome = self.call(name, args)
            self.assertFalse(outcome.ok, msg=f"{name} {args!r}")
        after = hashlib.sha256(b"".join(sorted(p.read_bytes() for p in self.work.rglob("*") if p.is_file()))).hexdigest()
        self.assertEqual(before, after, "workspace changed under hostile calls")
        self.assertEqual(self.sentinel.read_text(encoding="utf-8"), "untouched")
        self.assertGreater(self.executor.violations, 0)
        self.assertGreater(self.executor.malformed, 0)

    def test_violation_ceiling_aborts_run_with_sandbox_error(self):
        self.executor.limits["max_sandbox_violations"] = 2
        self.assertFalse(self.call("read_file", {"path": "../x", "start_line": 1, "max_lines": 1}).ok)
        with self.assertRaises(SandboxViolation):
            self.call("read_file", {"path": "../y", "start_line": 1, "max_lines": 1})

    def test_malformed_call_ceiling_stops_the_run(self):
        self.executor.limits["max_malformed_tool_calls"] = 2
        self.call("replace_text", "garbage")
        self.call("replace_text", "garbage")
        with self.assertRaises(LimitReached) as ctx:
            self.call("replace_text", "garbage")
        self.assertEqual(ctx.exception.reason_code, "max_malformed_tool_calls")

    def test_tool_call_and_duration_limits(self):
        self.executor.limits["max_tool_calls"] = 2
        self.call("list_files", {"prefix": ""})
        self.call("list_files", {"prefix": ""})
        with self.assertRaises(LimitReached) as ctx:
            self.call("list_files", {"prefix": ""})
        self.assertEqual(ctx.exception.reason_code, "max_tool_calls")
        self.executor.limits["max_tool_calls"] = 50
        self.executor.tool_seconds = 10**6
        with self.assertRaises(LimitReached) as ctx:
            self.call("list_files", {"prefix": ""})
        self.assertEqual(ctx.exception.reason_code, "max_total_tool_seconds")

    def test_real_validator_results_and_edit_guards(self):
        good = json.loads(self.call("run_validator", {"collection": COLLECTION, "kind": "validate"}).text)
        self.assertEqual(good["exit_code"], 0)
        self.assertIn("PASS", good["stdout"])
        # an in-bounds-violating edit is allowed to land but the real validator must now fail
        self.assertTrue(self.call("replace_text", {"path": PACK, "old_text": "[9, 8, 6, 2, 65]",
                                                   "new_text": "[9, 8, 600, 2, 65]"}).ok)
        bad = json.loads(self.call("run_validator", {"collection": COLLECTION, "kind": "validate"}).text)
        self.assertEqual(bad["exit_code"], 1)
        self.assertIn("out of bounds", bad["stdout"])
        self.assertFalse(self.executor.validation[-1]["passed"])
        # an edit that breaks JSON, or the schema id, is refused and rolled back
        before = (self.work / PACK).read_bytes()
        for old, new in (('"features": [', '"features": ['), ('{"id": "granite-arch"', '{{"id": "granite-arch"'),
                         ('"schema_version": 1', '"schema_version": 2')):
            outcome = self.call("replace_text", {"path": PACK, "old_text": old, "new_text": new})
            if old != new:
                self.assertEqual(outcome.error_code, "edit_rejected", msg=old)
        self.assertEqual((self.work / PACK).read_bytes(), before)

    def test_edit_budget_per_run(self):
        self.executor.limits["max_files_edited"] = 1
        self.assertTrue(self.call("replace_text", {"path": PACK, "old_text": "[9, 8, 6, 2, 65]",
                                                   "new_text": "[9, 8, 6, 2, 54]"}).ok)
        readme = "docs/world-design/mini-vault/README.md"
        with self.assertRaises(LimitReached) as ctx:
            self.call("replace_text", {"path": readme, "old_text": "Mini Vault", "new_text": "Vault"})
        self.assertEqual(ctx.exception.reason_code, "max_files_edited")

    def test_secrets_never_reach_model_visible_output(self):
        (self.work / "docs/world-design/mini-vault/README.md").write_text(
            "token sk-secret-value-123456 and sk-proj-abcdefghijklmnopqrstuvwxyz", encoding="utf-8")
        outcome = self.call("read_file", {"path": "docs/world-design/mini-vault/README.md", "start_line": 1,
                                          "max_lines": 5})
        self.assertNotIn("sk-secret-value-123456", outcome.text)
        self.assertNotIn("abcdefghijklmnopqrstuvwxyz", outcome.text)
        self.assertIn("[REDACTED]", outcome.text)

    def test_submit_report_consistency(self):
        report = {"outcome": "improved", "summary": "s", "visual_evidence_used": False, "critique": [],
                  "revision_proposals": [], "edits_applied": [], "validation_notes": ""}
        self.assertEqual(self.call("submit_report", report).error_code, "report_inconsistent")
        report["outcome"] = "no_change"
        report["visual_evidence_used"] = True
        self.assertEqual(self.call("submit_report", report).error_code, "report_inconsistent")
        report["visual_evidence_used"] = False
        self.assertEqual(self.call("submit_report", report).report["outcome"], "no_change")


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="atlas-cap-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.pack_dir = FIXTURE / "docs" / "world-design" / COLLECTION
        self.bundle = make_bundle(self.pack_dir, self.root / "before")

    def reseal(self, bundle: Path, **batch_changes):
        path = bundle / "batch-manifest.json"
        batch = json.loads(path.read_text(encoding="utf-8"))
        batch.update(batch_changes)
        captures.seal(batch)
        path.write_text(json.dumps(batch, sort_keys=True, indent=2), encoding="utf-8")

    def test_fixture_bundle_verifies_and_is_classified_as_fixture(self):
        summary = captures.summarize_bundle(self.bundle)
        self.assertTrue(summary["verified"], summary["problems"])
        self.assertEqual(summary["evidence_class"], "fixture")
        self.assertEqual(summary["shots"][0]["shot_id"], "full")

    def test_tampering_is_detected(self):
        png = next(self.bundle.rglob("full.png"))
        data = bytearray(png.read_bytes())
        data[-20] ^= 0xFF
        png.write_bytes(bytes(data))
        self.assertFalse(captures.summarize_bundle(self.bundle)["verified"])
        fresh = make_bundle(self.pack_dir, self.root / "second")
        batch = json.loads((fresh / "batch-manifest.json").read_text(encoding="utf-8"))
        batch["status"] = "failed"  # edited without resealing
        (fresh / "batch-manifest.json").write_text(json.dumps(batch), encoding="utf-8")
        summary = captures.summarize_bundle(fresh)
        self.assertFalse(summary["verified"])
        self.assertTrue(any("manifest_sha256" in p for p in summary["problems"]))
        with self.assertRaises(ToolError):
            captures.verify_bundle(self.root / "missing")

    def test_godot_class_needs_engine_identity(self):
        godot = make_bundle(self.pack_dir, self.root / "godot-like")
        self.reseal(godot, fixture=False)
        self.assertEqual(captures.summarize_bundle(godot)["evidence_class"], "unclassified")
        self.reseal(godot, fixture=False, engine={"executable_sha256": "a" * 64,
                                                  "display": {"rendering_driver": "opengl3"}})
        self.assertEqual(captures.summarize_bundle(godot)["evidence_class"], "godot-capture")

    def test_compare_bundles_reports_pixel_and_pack_change(self):
        edited = self.root / "edited"
        shutil.copytree(self.pack_dir, edited / COLLECTION)
        pack = edited / COLLECTION / "pack.json"
        pack.write_text(pack.read_text(encoding="utf-8").replace("[9, 8, 6, 2, 65]", "[9, 8, 6, 2, 54]"),
                        encoding="utf-8")
        after = make_bundle(edited / COLLECTION, self.root / "after")
        report = captures.compare_bundles(self.bundle, after)
        self.assertTrue(report["comparable"])
        self.assertTrue(report["visual_change_observed"])
        self.assertFalse(report["godot_to_godot"])
        same = captures.compare_bundles(self.bundle, make_bundle(self.pack_dir, self.root / "same"))
        self.assertFalse(same["visual_change_observed"])

    def test_launcher_contract_adapter(self):
        launcher = self.root / captures.LAUNCHER_NAME
        launcher.write_text(
            "import json, sys\n"
            "from pathlib import Path\n"
            "sys.path.insert(0, %r)\n"
            "from atlas_agent.fixtures.make_capture_bundle import make_bundle\n"
            "args = sys.argv\n"
            "mode = Path(%r).read_text().strip()\n"
            "out = Path(args[args.index('--output-dir') + 1]); pack = Path(args[args.index('--pack') + 1])\n"
            "if mode == 'ok':\n"
            "    out.mkdir(parents=True); make_bundle(pack, out)\n"
            "    print('WORLD_ART_CAPTURE_RESULT ' + json.dumps({'status': 'completed', 'bundle': str(out)})); sys.exit(0)\n"
            "if mode == 'nodisplay':\n"
            "    sys.stderr.write('WORLD_ART_ERROR no display'); sys.exit(7)\n"
            "print('no result line'); sys.exit(0)\n" % (str(Path(__file__).resolve().parents[1]), str(self.root / "mode.txt")),
            encoding="utf-8")
        godot = self.root / "Godot_fake.exe"
        godot.write_text("not a real engine", encoding="utf-8")
        exes = resolve_executables()
        for mode, expected in (("ok", "completed"), ("nodisplay", "no_display"), ("silent", "completed")):
            (self.root / "mode.txt").write_text(mode, encoding="utf-8")
            outcome = captures.run_capture(launcher, str(godot), self.pack_dir, self.root / f"out-{mode}", 60, exes)
            if mode == "silent":
                self.assertEqual(outcome["status"], "failed")  # exit 0 without the result line is not trusted
            elif mode == "ok":
                self.assertEqual(outcome["status"], "completed")
                self.assertTrue(captures.summarize_bundle(Path(outcome["bundle"]))["verified"])
            else:
                self.assertEqual((outcome["status"], outcome["reason"]), ("failed", expected))
        with self.assertRaises(ConfigError):
            captures.run_capture(self.root / "evil.py", str(godot), self.pack_dir, self.root / "o", 5, exes)
        with self.assertRaises(ConfigError):
            captures.run_capture(launcher, str(self.root / "missing.exe"), self.pack_dir, self.root / "o2", 5, exes)
        # only presentation flags may be forwarded; output/engine/source selection stays with the runner
        for evil in (["--output-dir=/tmp/x"], ["--godot=evil.exe"], ["--pack=/x"], ["--art-root=/x"], ["--allow-blank"]):
            with self.assertRaises(ConfigError, msg=str(evil)) as ctx:
                captures.run_capture(launcher, str(godot), self.pack_dir, self.root / "o3", 5, exes, evil)
            self.assertEqual(ctx.exception.reason_code, "capture_flag_not_allowed")
        (self.root / "mode.txt").write_text("ok", encoding="utf-8")
        outcome = captures.run_capture(launcher, str(godot), self.pack_dir, self.root / "out-flags", 60, exes,
                                       ["--rendering-driver=opengl3_angle", "--scale=1"])
        self.assertEqual(outcome["status"], "completed")
        for bad in ("--rendering-driver=a b", "rendering-driver=x", "--Scale=1", "--x;rm"):
            problems = check_config_task_args([bad])
            self.assertTrue(problems, msg=bad)


def git(cwd, *args):
    done = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True,
                          env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
                               "GIT_COMMITTER_EMAIL": "t@t"})
    return done.stdout.strip()


class GitCustodyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="atlas-git-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        shutil.copytree(FIXTURE, self.repo)
        # a second collection owned by a different lane, to prove ownership checks
        other = self.repo / "docs/world-design/silt-clockworks"
        shutil.copytree(self.repo / f"docs/world-design/{COLLECTION}", other)
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "base")
        self.head = git(self.repo, "rev-parse", "HEAD")
        pack = (self.repo / PACK).read_text(encoding="utf-8")
        edited = pack.replace("[9, 8, 6, 2, 65]", "[9, 8, 6, 2, 65], [10, 9, 2, 1, 54]")
        self.patch = self.root / "patch.diff"
        self.patch.write_text(gitops.unified_patch(PACK, pack.encode(), edited.encode()), encoding="utf-8", newline="\n")
        self.globs = atlas.patch_globs(COLLECTION, True)

    def publish(self, **kw):
        args = dict(repo=self.repo, patch_path=self.patch, expected_head=self.head, branch="atlas-agent/run-1",
                    write_globs=self.globs)
        args.update(kw)
        return gitops.publish_patch(**args)

    def test_patch_is_git_apply_compatible_and_publishes_to_new_branch(self):
        result = self.publish()
        self.assertEqual(result["base"], self.head)
        self.assertEqual(git(self.repo, "rev-parse", "main"), self.head, "base branch must not move")
        self.assertEqual(git(self.repo, "diff", "--name-only", self.head, result["commit"]), PACK)
        self.assertEqual(git(self.repo, "status", "--porcelain"), "")
        self.assertEqual(git(self.repo, "worktree", "list").count("\n"), 0, "disposable worktree not cleaned up")

    def test_competing_write_moves_upstream_head_and_is_refused(self):
        (self.repo / "docs/world-design/README.md").write_text("another worker\n", encoding="utf-8")
        git(self.repo, "commit", "-qam", "other worker lands first")
        moved = git(self.repo, "rev-parse", "HEAD")
        with self.assertRaises(SourceChanged) as ctx:
            self.publish()
        self.assertEqual(ctx.exception.reason_code, "upstream_head_changed")
        self.assertEqual(git(self.repo, "rev-parse", "HEAD"), moved)
        self.assertEqual(git(self.repo, "branch", "--list", "atlas-agent/*"), "")

    def test_existing_branch_is_never_overwritten(self):
        git(self.repo, "branch", "atlas-agent/run-1")
        with self.assertRaises(SourceChanged) as ctx:
            self.publish()
        self.assertEqual(ctx.exception.reason_code, "branch_exists")

    def test_unsafe_branch_names_and_protected_targets(self):
        for branch in ("main", "design/world-atlas-015-refinement-20261105", "claude/x", "atlas-agent/../main",
                       "atlas-agent/", "feature/x"):
            with self.assertRaises(SourceChanged, msg=branch) as ctx:
                self.publish(branch=branch)
            self.assertEqual(ctx.exception.reason_code, "branch_not_disposable")

    def test_foreign_lane_and_non_modification_patches_refused(self):
        foreign = "docs/world-design/silt-clockworks/pack.json"
        text = (self.repo / foreign).read_text(encoding="utf-8")
        self.patch.write_text(gitops.unified_patch(foreign, text.encode(), (text + " ").encode()), encoding="utf-8")
        with self.assertRaises(SourceChanged) as ctx:
            self.publish()
        self.assertEqual(ctx.exception.reason_code, "lane_ownership_violation")
        validator = f"docs/world-design/{COLLECTION}/validate_pack.py"
        body = (self.repo / validator).read_text(encoding="utf-8")
        self.patch.write_text(gitops.unified_patch(validator, body.encode(), (body + "#").encode()), encoding="utf-8")
        with self.assertRaises(SourceChanged):
            self.publish()
        for evil in ("diff --git a/x b/y\n", "diff --git a/docs/a b/docs/a\nnew file mode 100644\n",
                     "diff --git a/../a b/../a\n--- a\n+++ b\n", "diff --git a/docs/a b/docs/a\nGIT binary patch\n"):
            self.patch.write_text(evil, encoding="utf-8")
            with self.assertRaises(SourceChanged):
                self.publish()

    def test_remote_compare_and_swap_branch_collision(self):
        remote = self.root / "remote.git"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(remote)], check=True)
        git(self.repo, "remote", "add", "origin", str(remote))
        git(self.repo, "push", "-q", "origin", "main")
        rival = self.root / "rival"
        subprocess.run(["git", "clone", "-q", str(remote), str(rival)], check=True)
        git(rival, "switch", "-q", "-c", "atlas-agent/run-1")
        (rival / "docs/world-design/README.md").write_text("rival worker\n", encoding="utf-8")
        git(rival, "commit", "-qam", "rival")
        git(rival, "push", "-q", "origin", "atlas-agent/run-1")
        rival_head = git(remote, "rev-parse", "atlas-agent/run-1")
        with self.assertRaises(SourceChanged) as ctx:
            self.publish(remote="origin", push=True)
        self.assertEqual(ctx.exception.reason_code, "branch_exists")
        self.assertEqual(git(remote, "rev-parse", "atlas-agent/run-1"), rival_head, "rival branch overwritten!")
        pushed = self.publish(branch="atlas-agent/run-2", remote="origin", push=True)
        self.assertTrue(pushed["pushed"])
        self.assertEqual(git(remote, "rev-parse", "atlas-agent/run-2"), pushed["commit"])
        self.assertEqual(git(remote, "rev-parse", "main"), self.head)

    def test_expected_sha_checks(self):
        gitops.check_expected_sha(None, self.head)
        gitops.check_expected_sha(self.head, self.head)
        with self.assertRaises(SourceChanged) as ctx:
            gitops.check_expected_sha("1" * 40, self.head)
        self.assertEqual(ctx.exception.reason_code, "source_sha_mismatch")
        with self.assertRaises(ConfigError):
            gitops.check_expected_sha("nonsense", self.head)
        with self.assertRaises(SourceChanged):
            gitops.check_expected_sha(self.head, None)


class LaneTests(unittest.TestCase):
    def test_lane_table_matches_the_documented_split(self):
        self.assertEqual({k: len(v) for k, v in atlas.LANES.items()},
                         {"terrain-art": 5, "ruin-detail": 5, "art-curation": 5})
        owned = [c for members in atlas.LANES.values() for c in members]
        self.assertEqual(len(owned), len(set(owned)), "collections must have exactly one owner")
        self.assertEqual(atlas.resolve_lane("lumen-fault", None, False), ("terrain-art", True))
        self.assertEqual(atlas.resolve_lane("lumen-fault", "art-curation", False), ("art-curation", False))
        self.assertEqual(atlas.write_globs("lumen-fault", False), [])
        with self.assertRaises(ConfigError):
            atlas.resolve_lane("not-a-collection", None, False)


class ReceiptTests(unittest.TestCase):
    def test_seal_detects_edits_and_secrets_are_redacted(self):
        rec = receipt_mod.skeleton("run-1234", "dry-run", "2026-11-07T00:00:00Z", "mini-vault")
        rec["status"].update({"final": "success", "exit_code": 0, "reason_code": "completed", "phase": "done"})
        receipt_mod.seal(rec)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "receipt.json"
            path.write_text(receipt_mod.canonical(rec), encoding="utf-8")
            self.assertEqual(receipt_mod.verify_receipt(path), [])
            rec["usage"]["input_tokens"] = 1
            path.write_text(receipt_mod.canonical(rec), encoding="utf-8")
            self.assertTrue(any("receipt_sha256" in p for p in receipt_mod.verify_receipt(path)))
            rec["final_report"] = {"note": "sk-abcdefghijklmnopqrstuvwxyz123456"}
            receipt_mod.seal(rec)
            path.write_text(receipt_mod.canonical(rec), encoding="utf-8")
            self.assertTrue(any("credential" in p for p in receipt_mod.verify_receipt(path)))
        redactor = receipt_mod.Redactor(["exact-secret-value"])
        self.assertEqual(redactor.obj({"a": ["exact-secret-value", "Bearer abcdefghijklmnopqrstu"]}),
                         {"a": ["[REDACTED]", "[REDACTED]"]})


if __name__ == "__main__":
    unittest.main()
