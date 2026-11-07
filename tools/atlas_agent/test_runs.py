"""End-to-end run tests: no-key dry-run, live gate refusals, retries, limits and the real SDK
against a loopback API double (see testing_stub_api.py). No test makes a chargeable request."""
from __future__ import annotations

import base64
import copy
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from atlas_agent import captures, receipt as receipt_mod, runner  # noqa: E402
from atlas_agent.errors import ConfigError  # noqa: E402
from atlas_agent.fixtures.make_capture_bundle import make_bundle  # noqa: E402
from atlas_agent.testing_stub_api import (StubApi, error, function_call, message, ok, response_body,  # noqa: E402
                                          usage)

try:
    import importlib.util
    HAVE_SDK = importlib.util.find_spec("openai") is not None
except ImportError:
    HAVE_SDK = False

if os.environ.get("ATLAS_AGENT_REQUIRE_SDK") == "1" and not HAVE_SDK:
    raise RuntimeError("ATLAS_AGENT_REQUIRE_SDK=1 but the official openai package is not installed")

needs_sdk = unittest.skipUnless(HAVE_SDK, "official openai SDK not installed")
FIXTURE = Path(__file__).resolve().parent / "fixtures" / "atlas-mini"
PLAN = Path(__file__).resolve().parent / "fixtures" / "mini-vault-plan.json"
NOW = dt.datetime(2026, 11, 8, 12, 0, 0, tzinfo=dt.timezone.utc)
KEY = "sk-test-0123456789abcdefghijklmnopqrstuv"
COL = "lumen-fault"  # real lane-table name so non-fixture lane rules apply to the synthetic content
PACK = f"docs/world-design/{COL}/pack.json"
MODEL = "gpt-5.4-mini"


def git(cwd, *args):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True,
                          env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
                               "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}).stdout.strip()


def attestation(**kw) -> dict:
    base = {"checked_utc": "2026-11-08T11:00:00Z", "remaining_usd": 5.0, "expires_utc": "2027-01-31",
            "auto_recharge_disabled": True, "api_only": True, "eligible_models": [MODEL],
            "source": "billing dashboard, owner check", "attested_by": "owner"}
    base.update(kw)
    return base


class Env:
    """Temp git repo with the synthetic collection under a real lane name, plus an output root."""

    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="atlas-run-")
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        shutil.copytree(FIXTURE, self.repo)
        shutil.move(self.repo / "docs/world-design/mini-vault", self.repo / f"docs/world-design/{COL}")
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "base")
        self.head = git(self.repo, "rev-parse", "HEAD")
        self.bundle = make_bundle(self.repo / "docs/world-design" / COL, self.root / "bundle")
        self.plan = self.root / "plan.json"
        plan = json.loads(PLAN.read_text(encoding="utf-8"))
        plan["edits"][0]["path"] = PACK
        self.plan.write_text(json.dumps(plan), encoding="utf-8")
        self.count = 0

    def out(self) -> Path:
        self.count += 1
        return self.root / f"out{self.count}"

    def overrides(self, live=False, **extra) -> dict:
        ov = {"mode": "live" if live else "dry-run", "task": {"collection": COL, "atlas_root": str(self.repo)},
              "limits": {"backoff_base_seconds": 1.0}}
        if live:
            ov.update({"model": MODEL, "spend": {"authorised_ceiling_usd": 0.25, "authorisation_ref": "owner approval ref",
                                                 "credit_attestation": attestation()}})
        for section, values in extra.items():
            if isinstance(values, dict):
                ov.setdefault(section, {}).update(values)
            else:
                ov[section] = values
        return ov

    def run(self, overrides, env=None, sleeps=None, **kw):
        sleeps = sleeps if sleeps is not None else []
        return runner.execute(None, overrides, self.out(), env=env if env is not None else {}, sleep=sleeps.append,
                              now=NOW, **kw)

    def close(self):
        self.tmp.cleanup()


class UrlOnly:
    """Placeholder so overrides can be built before a stub server exists (URL is replaced when it starts)."""
    base_url = "http://127.0.0.1:9/v1"


def api_overrides(env: Env, stub: StubApi, **extra) -> dict:
    return env.overrides(live=True, api={"base_url": stub.base_url, "reasoning_effort": "low", "timeout_seconds": 20},
                         **extra)


def good_models() -> dict:
    return {MODEL: (200, {"openai-organization": "org-test", "openai-project": "proj_test",
                          "x-ratelimit-limit-requests": "500"})}


def report_call(call_id="call_report", outcome="no_change", **kw) -> dict:
    args = {"outcome": outcome, "summary": "reviewed", "visual_evidence_used": False,
            "critique": [{"dimension": "silhouette_scale_hierarchy", "score_0_to_5": 3, "evidence": "ok"}],
            "revision_proposals": [{"target": "arch", "change": "add seam", "rationale": "detail"}],
            "edits_applied": [], "validation_notes": "validated"}
    args.update(kw)
    return function_call("submit_report", args, call_id)


class RunCase(unittest.TestCase):
    def setUp(self):
        self.env = Env()
        self.addCleanup(self.env.close)

    def verify(self, result):
        self.assertEqual(receipt_mod.verify_receipt(result.receipt_path, receipt_mod.Redactor([KEY])), [])
        return result.receipt


class DryRunTests(RunCase):
    def test_no_key_dry_run_with_evidence_succeeds_and_patch_applies(self):
        before = dict(os.environ)
        result = self.env.run(self.env.overrides(task={"capture_bundle": str(self.env.bundle),
                                                       "dry_run_plan": str(self.env.plan)}))
        rec = self.verify(result)
        self.assertEqual((rec["status"]["final"], result.exit_code), ("success", 0))
        self.assertTrue(rec["run"]["model_calls_simulated"])
        self.assertTrue(rec["cost"]["simulated"])
        self.assertEqual(rec["model"]["api_endpoint"], "none")
        self.assertTrue(all(c["kind"] == "simulated" for c in rec["calls"]))
        self.assertEqual(rec["source"]["repository_head"], self.env.head)
        self.assertTrue(rec["source"]["source_unchanged_after_run"])
        self.assertEqual(rec["source"]["lane"], "terrain-art")
        self.assertEqual(len(rec["edits"]), 1)
        kinds = [(v["kind"], v["exit_code"]) for v in rec["validation"]]
        self.assertEqual(kinds[0], ("validate", 0))
        self.assertIn(("render_check", 0), kinds)
        self.assertTrue(any(v.get("runner_final_check") for v in rec["validation"]))
        self.assertEqual(rec["images"][0]["evidence_class"], "fixture")
        self.assertFalse(rec["visual_cycle"]["claimed"])
        self.assertEqual(rec["captures"]["input_bundle"]["evidence_class"], "fixture")
        # the patch is real: it applies cleanly to the committed source and touches only assigned files
        patch = result.receipt_path.parent / "patch.diff"
        self.assertEqual(rec["artifacts"]["patch"]["files"], [PACK, f"docs/world-design/{COL}/preview.svg"])
        git(self.env.repo, "apply", "--check", str(patch))
        self.assertEqual(git(self.env.repo, "status", "--porcelain"), "", "source checkout must stay untouched")
        self.assertEqual(os.environ.get("OPENAI_API_KEY"), before.get("OPENAI_API_KEY"))

    def test_dry_run_without_evidence_or_plan_is_read_only(self):
        result = self.env.run(self.env.overrides())
        rec = self.verify(result)
        self.assertEqual(result.exit_code, 0)
        self.assertEqual(rec["edits"], [])
        self.assertIsNone(rec["artifacts"]["patch"])
        self.assertNotIn("view_image", rec["policy"]["tools_advertised"])

    def test_other_lane_gets_read_only_critique(self):
        result = self.env.run(self.env.overrides(task={"lane": "art-curation", "capture_bundle": str(self.env.bundle),
                                                       "dry_run_plan": str(self.env.plan)}))
        rec = self.verify(result)
        self.assertEqual(result.exit_code, 0)
        self.assertFalse(rec["source"]["lane_writable"])
        self.assertEqual(rec["policy"]["write_globs"], [])
        self.assertNotIn("replace_text", rec["policy"]["tools_advertised"])
        self.assertEqual(rec["edits"], [])
        self.assertIsNone(rec["artifacts"]["patch"])

    def test_limits_terminate_with_stopped_status(self):
        cases = [
            ({"limits": {"max_iterations": 2}}, "max_iterations"),
            ({"limits": {"max_api_calls": 1}}, "max_api_calls"),
            ({"limits": {"max_tool_calls": 2}}, "max_tool_calls"),
            ({"limits": {"max_tool_calls_per_response": 1}}, "max_tool_calls_per_response"),
            ({"limits": {"max_images": 0}}, "max_images"),
            ({"limits": {"max_image_edge_pixels": 16}}, "image_too_large"),
            ({"limits": {"max_input_tokens_per_call": 256}}, "max_input_tokens_per_call"),
            ({"limits": {"max_total_input_tokens": 2000}}, "max_total_input_tokens"),
            ({"spend": {"max_usd_per_call": 0.0001, "max_usd_per_run": 0.001}}, "per_call_cost_ceiling"),
            ({"limits": {"max_total_output_tokens": 64, "max_output_tokens_per_call": 64}}, None),
        ]
        for extra, reason in cases:
            task = {"capture_bundle": str(self.env.bundle), "dry_run_plan": str(self.env.plan)}
            result = self.env.run(self.env.overrides(task=task, **extra))
            rec = self.verify(result)
            if reason is None:
                continue
            if reason == "image_too_large":
                # a per-tool refusal is model-visible, not a run stop; the dry-run planner then cannot proceed
                self.assertTrue(any(t["error_code"] == "image_too_large" for t in rec["tools"]), msg=str(extra))
                continue
            self.assertEqual((rec["status"]["final"], result.exit_code, rec["status"]["reason_code"]),
                             ("stopped", 4, reason), msg=str(extra))
            self.assertEqual(rec["status"]["phase"], "loop")

    def test_run_time_limit_uses_the_clock(self):
        ticks = {"n": 0}

        def clock():
            ticks["n"] += 1
            return ticks["n"] * 600.0

        result = self.env.run(self.env.overrides(limits={"max_run_seconds": 900}), clock=clock)
        rec = self.verify(result)
        self.assertEqual((rec["status"]["final"], rec["status"]["reason_code"]), ("stopped", "max_run_seconds"))

    def test_slow_validator_is_killed_at_the_tool_time_limit(self):
        script = self.env.repo / "docs/world-design" / COL / "validate_pack.py"
        script.write_text("import time\ntime.sleep(60)\n", encoding="utf-8")
        git(self.env.repo, "commit", "-qam", "slow validator")
        started = dt.datetime.now()
        result = self.env.run(self.env.overrides(limits={"max_tool_seconds": 1, "max_total_tool_seconds": 5}))
        rec = self.verify(result)
        self.assertLess((dt.datetime.now() - started).total_seconds(), 40)
        self.assertTrue(rec["validation"][0]["timed_out"])
        self.assertFalse(rec["validation"][0]["passed"])

    def test_output_directory_rules(self):
        result = self.env.run(self.env.overrides())
        with self.assertRaises(ConfigError) as ctx:
            runner.execute(None, self.env.overrides(), result.receipt_path.parent, env={}, now=NOW)
        self.assertEqual(ctx.exception.reason_code, "output_not_empty")
        inside = self.env.repo / "out-inside-source"
        result = runner.execute(None, self.env.overrides(), inside, env={}, now=NOW)
        self.assertEqual(result.receipt["status"]["reason_code"], "unsafe_output_dir")
        self.assertEqual(result.exit_code, 2)
        self.assertEqual(git(self.env.repo, "status", "--porcelain", "--untracked-files=no"), "")


class SourceIdentityTests(RunCase):
    def test_invalid_and_mismatched_source_sha_are_rejected(self):
        result = self.env.run(self.env.overrides(task={"expected_source_sha": "deadbeef"}))
        self.assertEqual((result.exit_code, result.receipt["status"]["reason_code"]), (2, "invalid_source_sha"))
        result = self.env.run(self.env.overrides(task={"expected_source_sha": "1" * 40}))
        self.assertEqual((result.exit_code, result.receipt["status"]["reason_code"]), (8, "source_sha_mismatch"))
        self.assertEqual(result.receipt["usage"]["api_attempts"], 0)
        result = self.env.run(self.env.overrides(task={"expected_source_sha": self.env.head}))
        self.assertEqual(result.exit_code, 0)
        self.assertEqual(result.receipt["source"]["expected_source_sha"], self.env.head)

    def test_source_changing_during_the_run_blocks_the_patch(self):
        target = self.env.repo / "docs/world-design/README.md"
        state = {"n": 0}

        def clock():
            state["n"] += 1
            if state["n"] == 5:
                target.write_text("a competing writer changed the source mid-run\n", encoding="utf-8")
            return float(state["n"]) * 0.001

        result = self.env.run(self.env.overrides(task={"dry_run_plan": str(self.env.plan)}), clock=clock)
        rec = self.verify(result)
        self.assertEqual((result.exit_code, rec["status"]["reason_code"]), (8, "source_changed_during_run"))
        self.assertFalse(rec["source"]["source_unchanged_after_run"])
        self.assertIsNone(rec["artifacts"]["patch"], "no publishable patch after a competing change")

    def test_unknown_collection_and_missing_root(self):
        result = self.env.run(self.env.overrides(task={"collection": "not-in-atlas"}))
        self.assertEqual(result.receipt["status"]["reason_code"], "unknown_collection")
        result = self.env.run(self.env.overrides(task={"atlas_root": str(self.env.root / "nowhere")}))
        self.assertEqual(result.receipt["status"]["reason_code"], "atlas_root_missing")


@needs_sdk
class LiveGateTests(RunCase):
    """Charged execution must be refused before the first request unless every check passes."""

    def refused(self, reason, overrides=None, env=None, models=None, costs=None, phase="gate", **kw):
        with StubApi(models=models if models is not None else good_models(), costs=costs) as stub:
            overrides = overrides or api_overrides(self.env, stub)
            overrides.setdefault("api", {})["base_url"] = stub.base_url
            result = self.env.run(overrides, env=env if env is not None else {"OPENAI_API_KEY": KEY}, **kw)
            rec = self.verify(result)
            self.assertEqual((rec["status"]["final"], result.exit_code, rec["status"]["reason_code"]),
                             ("failure", 3, reason))
            self.assertEqual(stub.response_posts(), [], "a charged request was sent despite the refusal")
            self.assertEqual(rec["usage"]["api_attempts"], 0)
            self.assertEqual(rec["cost"]["committed_usd"], 0.0)
            self.assertEqual(rec["status"]["phase"], phase)
            return rec

    def test_missing_api_credentials_fail_safely(self):
        rec = self.refused("credentials_missing", env={})
        self.assertFalse(rec["credit_gate"]["passed"])
        names = {c["name"]: c["ok"] for c in rec["credit_gate"]["checks"]}
        self.assertFalse(names["api_key_present"])
        for bad in ("", "short", "sk-has space in the middle of it 0000000"):
            self.refused("credentials_missing", env={"OPENAI_API_KEY": bad})

    def test_unverified_or_unsuitable_credit_is_refused(self):
        base = api_overrides(self.env, UrlOnly)

        def variant(**spend):
            ov = copy.deepcopy(base)
            ov["spend"].update(spend)
            return ov

        self.refused("credit_unverified", variant(credit_attestation=None))
        self.refused("credit_expired", variant(credit_attestation=attestation(expires_utc="2026-11-08")))
        self.refused("credit_expired", variant(credit_attestation=attestation(expires_utc="2026-11-08T20:00:00Z")))
        self.refused("credit_expired", variant(credit_attestation=attestation(checked_utc="2026-10-01T00:00:00Z")))
        self.refused("credit_insufficient", variant(credit_attestation=attestation(remaining_usd=0.10)))
        self.refused("credit_insufficient", variant(credit_attestation=attestation(api_only=False)))
        self.refused("auto_recharge_not_disabled", variant(credit_attestation=attestation(auto_recharge_disabled=False)))
        self.refused("model_eligibility_unattested", variant(credit_attestation=attestation(eligible_models=["gpt-4.1"])))
        self.refused("model_eligibility_unattested", variant(credit_attestation=attestation(eligible_models=[])))
        self.refused("spend_not_authorised", variant(authorised_ceiling_usd=0.0))
        self.refused("spend_not_authorised", variant(authorised_ceiling_usd=0.10))
        self.refused("spend_not_authorised", variant(authorisation_ref="   "))

    def test_pricing_model_source_and_project_checks(self):
        ov = api_overrides(self.env, UrlOnly)
        ov["model"] = "gpt-5.99-imaginary"
        self.refused("model_not_priced", ov, phase="preflight")
        # a pricing table older than max_age_days relative to "now" refuses charged execution
        with StubApi(models=good_models()) as s2:
            result = runner.execute(None, api_overrides(self.env, s2), self.env.out(), env={"OPENAI_API_KEY": KEY},
                                    now=dt.datetime(2027, 3, 1, tzinfo=dt.timezone.utc), sleep=lambda s: None)
            self.assertEqual((result.exit_code, result.receipt["status"]["reason_code"]), (3, "pricing_stale"))
            self.assertEqual(s2.response_posts(), [])
        (self.env.repo / "docs/world-design/README.md").write_text("dirty\n", encoding="utf-8")
        self.refused("source_dirty")
        git(self.env.repo, "checkout", "-q", "--", ".")
        self.refused("model_not_eligible", models={})
        ov = api_overrides(self.env, UrlOnly, spend={"expected_project": "proj_other"})
        self.refused("project_mismatch", ov)

    def test_costs_api_crosscheck(self):
        costs = {"object": "page", "has_more": False, "data": [
            {"object": "bucket", "results": [{"amount": {"value": 4.95, "currency": "usd"}}]}]}
        env = {"OPENAI_API_KEY": KEY, "OPENAI_ADMIN_KEY": "sk-admin-0123456789abcdefghijklmnop"}
        rec = self.refused("headroom_unverifiable", api_overrides(self.env, UrlOnly), env=env, costs=costs)
        self.assertIn("measured headroom", " ".join(c["detail"] for c in rec["credit_gate"]["checks"]))
        costs["data"][0]["results"][0]["amount"]["value"] = 0.5
        with StubApi(models=good_models(), costs=costs) as s2:
            s2.queue = [ok(response_body([report_call()]))]
            result = self.env.run(api_overrides(self.env, s2), env=env)
            rec = self.verify(result)
            self.assertEqual(result.exit_code, 0)
            self.assertEqual(rec["credit_gate"]["headroom_basis"], "attestation-minus-costs-api")
        rec = self.refused("headroom_unverifiable",
                           api_overrides(self.env, UrlOnly, spend={"require_costs_crosscheck": True}),
                           env={"OPENAI_API_KEY": KEY}, costs=costs)
        self.assertEqual(rec["credit_gate"]["headroom_basis"], "owner-attestation-only")


@needs_sdk
class LiveRunTests(RunCase):
    def live(self, queue, models=None, overrides=None, env=None, sleeps=None, default=None, **kw):
        stub = StubApi(models=models if models is not None else good_models())
        stub.queue = list(queue)
        stub.default = default
        with stub:
            ov = overrides if overrides is not None else api_overrides(self.env, stub)
            ov.setdefault("api", {})["base_url"] = stub.base_url
            result = self.env.run(ov, env=env if env is not None else {"OPENAI_API_KEY": KEY},
                                  sleeps=sleeps, **kw)
            return stub, result, self.verify(result)

    def test_full_orchestration_through_the_real_sdk(self):
        ids = iter(f"call_{i}" for i in range(100))
        queue = [
            ok(response_body([function_call("inspect_pack", {"collection": COL}, next(ids)),
                              function_call("run_validator", {"collection": COL, "kind": "validate"}, next(ids))],
                             use=usage(2000, 150))),
            ok(response_body([function_call("list_captures", {}, next(ids))], use=usage(2500, 90))),
            ok(response_body([function_call("view_image", {"bundle": "input", "shot_id": "full", "collection": COL},
                                            next(ids))], use=usage(2600, 80, cached=1024))),
            ok(response_body([message("critique: the arch silhouette is flat"),
                              function_call("replace_text", {"path": PACK, "old_text": "[9, 8, 6, 2, 65]]},",
                                            "new_text": "[9, 8, 6, 2, 65], [10, 9, 2, 1, 54]]},"}, next(ids))],
                             use=usage(3600, 200, reasoning=64))),
            ok(response_body([function_call("run_validator", {"collection": COL, "kind": "validate"}, next(ids)),
                              function_call("run_validator", {"collection": COL, "kind": "render_write"}, next(ids)),
                              function_call("run_validator", {"collection": COL, "kind": "render_check"}, next(ids))],
                             use=usage(3700, 100))),
            ok(response_body([report_call(outcome="improved", visual_evidence_used=True,
                                          edits_applied=["added a verdigris seam accent"])], use=usage(3800, 300))),
        ]
        stub = StubApi(models=good_models())
        stub.queue = queue
        with stub:
            ov = api_overrides(self.env, stub, task={"capture_bundle": str(self.env.bundle)})
            result = self.env.run(ov, env={"OPENAI_API_KEY": KEY})
            rec = self.verify(result)
            posts = stub.response_posts()
            self.assertEqual((rec["status"]["final"], result.exit_code), ("success", 0))
            self.assertEqual(len(posts), 6)
            self.assertEqual(rec["usage"]["api_responses"], 6)
            self.assertFalse(rec["run"]["model_calls_simulated"])
            self.assertEqual(rec["model"]["api_endpoint"], "loopback-test")
            self.assertTrue(rec["credit_gate"]["passed"])
            self.assertEqual(rec["credit_gate"]["facts"]["rate_limit_headers"], {"x-ratelimit-limit-requests": "500"})
            # request contract: stateless, explicit, bounded, key only in the header
            first = posts[0]["body"]
            self.assertEqual((first["model"], first["store"], first["truncation"], first["max_output_tokens"]),
                             (MODEL, False, "disabled", 4000))
            self.assertEqual(first["reasoning"], {"effort": "low"})
            self.assertEqual(first["include"], ["reasoning.encrypted_content"])
            self.assertTrue(all(t["type"] == "function" and t["strict"] for t in first["tools"]))
            self.assertIn("submit_report", [t["name"] for t in first["tools"]])
            self.assertTrue(first["instructions"].startswith("instructions_version: atlas-agent-instructions/1"))
            for post in posts:
                self.assertNotIn(KEY, json.dumps(post["body"]))
                self.assertEqual({k.lower(): v for k, v in post["headers"].items()}["authorization"], f"Bearer {KEY}")
            # tool results flow back as function_call_output items
            outputs = [i for i in posts[1]["body"]["input"] if i.get("type") == "function_call_output"]
            self.assertEqual(len(outputs), 2)
            self.assertEqual(json.loads(outputs[1]["output"])["exit_code"], 0)
            # the image is attached as a real PNG data URL in the following request, then ages out
            def images(post):
                return [p for i in post["body"]["input"] if isinstance(i.get("content"), list)
                        for p in i["content"] if p.get("type") == "input_image"]
            self.assertEqual(len(images(posts[2])), 0)
            attached = images(posts[3])
            self.assertEqual(len(attached), 1)
            png = base64.b64decode(attached[0]["image_url"].split(",", 1)[1])
            self.assertEqual(attached[0]["detail"], "high")
            self.assertEqual(rec["images"][0]["sha256"], __import__("hashlib").sha256(png).hexdigest())
            self.assertEqual(len(images(posts[5])), 0, "image must be dropped from context after the resend window")
            # accounting: reported usage x rates, distinct from the reserved worst case
            rates = rec["cost"]["rates"]
            expected = sum(((c["input_tokens"] - c["cached_input_tokens"]) * rates["input_usd_per_1m"]
                            + c["cached_input_tokens"] * rates["cached_input_usd_per_1m"]
                            + c["output_tokens"] * rates["output_usd_per_1m"]) / 1e6 for c in rec["calls"])
            self.assertAlmostEqual(rec["cost"]["computed_from_reported_usage_usd"], expected, places=7)
            self.assertAlmostEqual(rec["cost"]["committed_usd"], expected, places=7)
            self.assertGreater(rec["cost"]["reserved_worst_case_total_usd"], rec["cost"]["committed_usd"])
            self.assertEqual(rec["usage"]["cached_input_tokens"], 1024)
            self.assertEqual(rec["usage"]["reasoning_tokens"], 64)
            self.assertFalse(rec["cost"]["simulated"])
            self.assertEqual(rec["cost"]["billing_reconciliation"], "not-performed")
            self.assertLess(rec["cost"]["committed_usd"], rec["cost"]["authorised_ceiling_usd"])
            self.assertEqual(rec["model"]["observed"], ["gpt-5.4-mini-2026-01-01"])
            self.assertEqual(rec["final_report"]["outcome"], "improved")
            self.assertFalse(rec["visual_cycle"]["claimed"], "fixture evidence must never claim a visual cycle")
            self.assertEqual(rec["artifacts"]["patch"]["files"], [PACK, f"docs/world-design/{COL}/preview.svg"])

    def test_rate_limit_retries_are_bounded_and_honour_retry_after(self):
        sleeps: list = []
        queue = [error(429, "rate_limit_exceeded", "slow down", {"Retry-After": "3"}),
                 error(429, "rate_limit_exceeded", "slow down"), ok(response_body([report_call()]))]
        stub, result, rec = self.live(queue, sleeps=sleeps)
        self.assertEqual((result.exit_code, rec["status"]["reason_code"]), (0, "completed"))
        self.assertEqual(len(stub.response_posts()), 3)
        self.assertEqual(len(sleeps), 2)
        self.assertGreaterEqual(sleeps[0], 3.0)
        self.assertGreaterEqual(sleeps[1], 1.5)
        self.assertEqual(rec["calls"][0]["retries"], 2)
        self.assertEqual([e["kind"] for e in rec["calls"][0]["retry_events"]], ["rate_limited"] * 2)
        self.assertEqual(rec["usage"]["api_attempts"], 3)
        self.assertEqual(rec["usage"]["api_responses"], 1)
        self.assertEqual(rec["cost"]["ambiguous_charge_assumed_usd"], 0.0, "429s are provably uncharged")

    def test_rate_limit_exhaustion_is_an_unmistakable_failure(self):
        sleeps: list = []
        stub, result, rec = self.live([], default=error(429, "rate_limit_exceeded", "slow down"), sleeps=sleeps,
                                      overrides=None)
        self.assertEqual((rec["status"]["final"], result.exit_code, rec["status"]["reason_code"]),
                         ("failure", 5, "rate_limit_retries_exhausted"))
        self.assertEqual(len(stub.response_posts()), 4)  # 1 + max_retries(3), never unbounded
        self.assertEqual(len(sleeps), 3)
        self.assertEqual(sleeps, sorted(sleeps), "exponential backoff must not shrink")

    def test_server_errors_are_retried_and_counted_as_possibly_charged(self):
        queue = [error(500, "server_error", "boom"), error(503, "overloaded", "busy", {"Retry-After": "1"}),
                 ok(response_body([report_call()]))]
        stub, result, rec = self.live(queue, sleeps=[])
        self.assertEqual(result.exit_code, 0)
        self.assertGreater(rec["cost"]["ambiguous_charge_assumed_usd"], 0)
        self.assertGreater(rec["cost"]["committed_usd"], rec["cost"]["computed_from_reported_usage_usd"])
        self.assertEqual([e["possibly_charged"] for e in rec["calls"][0]["retry_events"]], [True, True])

    def test_exhausted_credit_or_spend_limit_does_not_retry(self):
        sleeps: list = []
        stub, result, rec = self.live([error(429, "insufficient_quota", "You exceeded your current quota")],
                                      sleeps=sleeps)
        self.assertEqual((result.exit_code, rec["status"]["reason_code"]), (5, "credit_exhausted"))
        self.assertEqual((len(stub.response_posts()), sleeps), (1, []))
        stub, result, rec = self.live([error(429, "rate_limit_exceeded", "Billing hard limit has been reached")],
                                      sleeps=sleeps)
        self.assertEqual(rec["status"]["reason_code"], "credit_exhausted")

    def test_authentication_and_bad_request_fail_without_retry(self):
        stub, result, rec = self.live([error(401, "invalid_api_key", "bad key")], sleeps=[])
        self.assertEqual((result.exit_code, rec["status"]["reason_code"], len(stub.response_posts())),
                         (5, "api_authentication", 1))
        stub, result, rec = self.live([error(400, "invalid_request_error", "nope")], sleeps=[])
        self.assertEqual((rec["status"]["reason_code"], len(stub.response_posts())), ("api_request_rejected", 1))

    def test_per_run_budget_refuses_the_next_call(self):
        queue = [ok(response_body([function_call("list_files", {"prefix": ""}, "c1")], use=usage(3000, 4000))),
                 ok(response_body([report_call()]))]
        stub = StubApi(models=good_models())
        stub.queue = queue
        with stub:
            ov = api_overrides(self.env, stub, spend={"max_usd_per_call": 0.03, "max_usd_per_run": 0.04,
                                                      "authorised_ceiling_usd": 0.04})
            result = self.env.run(ov, env={"OPENAI_API_KEY": KEY})
            rec = self.verify(result)
            self.assertEqual((rec["status"]["final"], result.exit_code, rec["status"]["reason_code"]),
                             ("stopped", 4, "per_run_cost_ceiling"))
            self.assertEqual(len(stub.response_posts()), 1)
            self.assertLess(rec["cost"]["remaining_allowance_usd"], 0.04)

    def test_api_anomalies_fail_closed(self):
        cases = {
            "model_substituted": ok(response_body([report_call()], model="gpt-4o-2024-08-06")),
            "reservation_exceeded": ok(response_body([report_call()], use=usage(9_000_000, 10))),
            "response_incomplete": ok(response_body([], status="incomplete",
                                                    incomplete={"reason": "max_output_tokens"})),
        }
        for reason, step in cases.items():
            stub, result, rec = self.live([step], sleeps=[])
            self.assertEqual(rec["status"]["reason_code"], reason)
            self.assertNotEqual(result.exit_code, 0)
        body = response_body([report_call()])
        del body["usage"]
        stub, result, rec = self.live([ok(body)], sleeps=[])
        self.assertEqual(rec["status"]["reason_code"], "usage_missing")
        self.assertGreater(rec["cost"]["ambiguous_charge_assumed_usd"], 0)

    def test_reasoning_items_are_replayed_statelessly_in_order(self):
        reasoning = {"type": "reasoning", "id": "rs_1", "summary": [], "encrypted_content": "ENC-BLOB-123"}
        queue = [ok(response_body([reasoning, function_call("list_files", {"prefix": ""}, "c1")])),
                 ok(response_body([report_call()]))]
        stub, result, rec = self.live(queue, sleeps=[])
        self.assertEqual(result.exit_code, 0)
        second = stub.response_posts()[1]["body"]
        self.assertFalse(second["store"])
        kinds = [i.get("type") or i.get("role") for i in second["input"]]
        self.assertEqual(kinds, ["user", "reasoning", "function_call", "function_call_output"])
        replayed = second["input"][1]
        self.assertEqual((replayed["id"], replayed["encrypted_content"]), ("rs_1", "ENC-BLOB-123"))
        self.assertNotIn("parsed_arguments", second["input"][2])

    def test_model_that_never_reports_is_stopped(self):
        stub, result, rec = self.live([ok(response_body([message("I think it is fine.")]))] * 2, sleeps=[])
        self.assertEqual((rec["status"]["final"], rec["status"]["reason_code"]), ("stopped", "no_report_submitted"))
        self.assertEqual(len(stub.response_posts()), 2)

    def test_hostile_model_tool_calls_stop_the_run_without_escaping(self):
        evil = {"path": "../../etc/passwd", "start_line": 1, "max_lines": 5}
        queue = [ok(response_body([function_call("read_file", evil, "c1")])),
                 ok(response_body([function_call("replace_text", {"path": "/etc/hosts", "old_text": "a",
                                                                  "new_text": "b"}, "c2")]))]
        stub, result, rec = self.live(queue, sleeps=[])
        self.assertEqual((rec["status"]["final"], result.exit_code, rec["status"]["reason_code"]),
                         ("failure", 6, "absolute_path"))
        self.assertEqual(rec["usage"]["sandbox_violations"], 2)
        self.assertEqual(git(self.env.repo, "status", "--porcelain"), "")
        junk = [ok(response_body([function_call("replace_text", "{not json", f"c{i}")])) for i in range(6)]
        stub, result, rec = self.live(junk, sleeps=[])
        self.assertEqual((rec["status"]["final"], rec["status"]["reason_code"]), ("stopped", "max_malformed_tool_calls"))

    def test_secrets_never_reach_receipt_logs_or_artifacts(self):
        (self.env.repo / "docs/world-design" / COL / "README.md").write_text(f"leaked {KEY} here\n", encoding="utf-8")
        git(self.env.repo, "commit", "-qam", "readme with a planted key")
        queue = [ok(response_body([message(f"my key is {KEY}"),
                                   function_call("read_file", {"path": f"docs/world-design/{COL}/README.md",
                                                               "start_line": 1, "max_lines": 5}, "c1")])),
                 ok(response_body([report_call(summary=f"done; key {KEY}")]))]
        stub, result, rec = self.live(queue, sleeps=[])
        self.assertEqual(result.exit_code, 0)
        for path in result.receipt_path.parent.rglob("*"):
            if path.is_file():
                self.assertNotIn(KEY, path.read_text(encoding="utf-8", errors="replace"), msg=path.name)
        self.assertIn("[REDACTED]", rec["final_report"]["summary"])
        followup = stub.response_posts()[1]["body"]["input"]
        tool_outputs = [i["output"] for i in followup if i.get("type") == "function_call_output"]
        self.assertTrue(tool_outputs)
        self.assertNotIn(KEY, "".join(tool_outputs), "a planted key must not be sent back to the model")


FAKE_LAUNCHER = """import json, sys
from pathlib import Path
sys.path.insert(0, {tools!r})
from atlas_agent.fixtures.make_capture_bundle import make_bundle
a = sys.argv
out = Path(a[a.index('--output-dir') + 1]); pack = Path(a[a.index('--pack') + 1])
out.mkdir(parents=True); make_bundle(pack, out)
print('WORLD_ART_CAPTURE_RESULT ' + json.dumps({{'status': 'completed', 'bundle': str(out)}}))
"""


class RendererIntegrationTests(RunCase):
    """The #498 launcher contract, exercised with a contract double (NOT Godot)."""

    def test_render_compare_and_no_false_visual_claim(self):
        launcher = self.env.root / captures.LAUNCHER_NAME
        launcher.write_text(FAKE_LAUNCHER.format(tools=str(Path(__file__).resolve().parents[1])), encoding="utf-8")
        godot = self.env.root / "Godot_fake.exe"
        godot.write_text("stand-in", encoding="utf-8")
        result = self.env.run(self.env.overrides(task={
            "capture_bundle": str(self.env.bundle), "capture_launcher": str(launcher), "godot": str(godot),
            "dry_run_plan": str(self.env.plan)}))
        rec = self.verify(result)
        self.assertEqual(result.exit_code, 0, rec["status"])
        self.assertEqual([a["status"] for a in rec["captures"]["render_attempts"]], ["completed"])
        self.assertTrue(rec["captures"]["rendered_bundle"]["verified"])
        comparison = rec["captures"]["comparison"]
        self.assertTrue(comparison["comparable"])
        self.assertTrue(comparison["visual_change_observed"], "the edit must change the rendered pixels")
        self.assertEqual(comparison["evidence_classes"], ["fixture", "fixture"])
        self.assertFalse(rec["visual_cycle"]["claimed"])
        self.assertIn("not both godot-capture", rec["visual_cycle"]["reason"])

    def test_unavailable_renderer_is_reported_not_faked(self):
        godot = self.env.root / "Godot_fake.exe"
        godot.write_text("stand-in", encoding="utf-8")
        bogus = self.env.root / captures.LAUNCHER_NAME
        bogus.write_text("import sys\nsys.exit(7)\n", encoding="utf-8")
        result = self.env.run(self.env.overrides(task={
            "capture_bundle": str(self.env.bundle), "capture_launcher": str(bogus), "godot": str(godot),
            "dry_run_plan": str(self.env.plan)}))
        rec = self.verify(result)
        self.assertEqual(rec["captures"]["render_attempts"][0]["reason"], "no_display")
        self.assertIsNone(rec["captures"]["rendered_bundle"])
        self.assertFalse(rec["visual_cycle"]["claimed"])


class VisualCycleLogicTests(unittest.TestCase):
    def cycle(self, comparison, edited=True, bundle=True, mode="live"):
        from types import SimpleNamespace
        rec = {"run": {"mode": mode}}
        runner._visual_cycle(rec, SimpleNamespace(input_bundle="b" if bundle else None, comparison=comparison), edited)
        return rec["visual_cycle"]

    def test_claim_requires_godot_both_sides_equal_framing_and_a_real_change(self):
        good = {"comparable": True, "godot_to_godot": True, "visual_change_observed": True,
                "evidence_classes": ["godot-capture", "godot-capture"]}
        self.assertTrue(self.cycle(good)["claimed"])
        self.assertFalse(self.cycle(good, mode="dry-run")["claimed"], "a scripted dry run never claims a cycle")
        for mutation, edited, bundle in (({"godot_to_godot": False}, True, True), ({"comparable": False}, True, True),
                                         ({"visual_change_observed": False}, True, True), ({}, False, True),
                                         ({}, True, False)):
            self.assertFalse(self.cycle({**good, **mutation}, edited, bundle)["claimed"], msg=str(mutation))
        self.assertFalse(self.cycle(None)["claimed"])


@needs_sdk
class CreditCheckCliTests(RunCase):
    def test_credit_check_reports_without_any_charged_request(self):
        import contextlib
        import io
        from unittest import mock
        from atlas_agent import cli
        attest = self.env.root / "attest.json"
        for label, payload, expected in (("good", attestation(checked_utc=dt.datetime.now(dt.timezone.utc).strftime(
                "%Y-%m-%dT%H:%M:%SZ"), expires_utc=(dt.date.today() + dt.timedelta(days=60)).isoformat()), 0),
                                         ("none", None, 3)):
            with StubApi(models=good_models()) as stub:
                config = self.env.root / f"{label}.json"
                config.write_text(json.dumps({"schema": "cybersand.atlas-agent.config/1", "model": MODEL,
                                              "api": {"base_url": stub.base_url},
                                              "task": {"collection": COL, "atlas_root": str(self.env.repo)},
                                              "spend": {"authorised_ceiling_usd": 0.25, "authorisation_ref": "ref"},
                                              "pricing_file": str(self.env.root / "pricing.json")}), encoding="utf-8")
                table = json.loads((Path(__file__).resolve().parent / "pricing.json").read_text(encoding="utf-8"))
                table["retrieved_utc"] = dt.date.today().isoformat()
                (self.env.root / "pricing.json").write_text(json.dumps(table), encoding="utf-8")
                args = ["credit-check", "--config", str(config)]
                if payload is not None:
                    attest.write_text(json.dumps(payload), encoding="utf-8")
                    args += ["--credit-attestation-file", str(attest)]
                buffer = io.StringIO()
                with mock.patch.dict(os.environ, {"OPENAI_API_KEY": KEY}), contextlib.redirect_stdout(buffer):
                    code = cli.main(args)
                self.assertEqual(code, expected, buffer.getvalue())
                report = json.loads(buffer.getvalue())["gate"]
                self.assertEqual(report["passed"], expected == 0)
                self.assertEqual(stub.response_posts(), [])
                self.assertNotIn(KEY, buffer.getvalue())


class CliTests(RunCase):
    def cli(self, *args, env=None):
        full_env = {k: v for k, v in os.environ.items() if k != "OPENAI_API_KEY"}
        full_env.update(env or {})
        return subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / "atlas_agent_runner.py"), *args],
                              capture_output=True, text=True, env=full_env, timeout=300)

    def test_cli_contract_exit_codes_and_result_line(self):
        out = self.env.out()
        done = self.cli("run", "--atlas-root", str(self.env.repo), "--collection", COL, "--output-dir", str(out),
                        "--capture-bundle", str(self.env.bundle), "--dry-run-plan", str(self.env.plan))
        self.assertEqual(done.returncode, 0, done.stderr)
        last = done.stdout.strip().splitlines()[-1]
        self.assertTrue(last.startswith("ATLAS_AGENT_RESULT "))
        info = json.loads(last.split(" ", 1)[1])
        self.assertEqual((info["status"], info["simulated"], info["mode"]), ("success", True, "dry-run"))
        verified = self.cli("verify-receipt", str(out / "receipt.json"))
        self.assertEqual(verified.returncode, 0, verified.stdout)
        tampered = json.loads((out / "receipt.json").read_text(encoding="utf-8"))
        tampered["usage"]["input_tokens"] = 5
        (out / "receipt.json").write_text(json.dumps(tampered), encoding="utf-8")
        self.assertEqual(self.cli("verify-receipt", str(out / "receipt.json")).returncode, 2)
        done = self.cli("run", "--atlas-root", str(self.env.repo), "--collection", COL, "--output-dir", str(out))
        self.assertEqual((done.returncode, "output_not_empty" in done.stderr), (2, True))

    def test_cli_live_without_key_is_refused_with_exit_3(self):
        out = self.env.out()
        done = self.cli("run", "--mode", "live", "--model", MODEL, "--atlas-root", str(self.env.repo),
                        "--collection", COL, "--output-dir", str(out), "--authorised-ceiling-usd", "0.25",
                        "--authorisation-ref", "ref")
        self.assertEqual(done.returncode, 3)
        rec = json.loads((out / "receipt.json").read_text(encoding="utf-8"))
        self.assertEqual(rec["status"]["reason_code"], "credentials_missing")
        self.assertEqual(rec["usage"]["api_attempts"], 0)
        no_model = self.cli("run", "--mode", "live", "--atlas-root", str(self.env.repo), "--collection", COL,
                            "--output-dir", str(self.env.out()))
        self.assertEqual(no_model.returncode, 2)

    def test_cli_publish_creates_new_branch_and_refuses_after_competing_write(self):
        out = self.env.out()
        done = self.cli("run", "--atlas-root", str(self.env.repo), "--collection", COL, "--output-dir", str(out),
                        "--expected-source-sha", self.env.head, "--dry-run-plan", str(self.env.plan))
        self.assertEqual(done.returncode, 0, done.stderr)
        published = self.cli("publish", "--receipt", str(out / "receipt.json"), "--repo", str(self.env.repo),
                             "--branch", "atlas-agent/demo-1")
        self.assertEqual(published.returncode, 0, published.stderr)
        self.assertEqual(git(self.env.repo, "rev-parse", "main"), self.env.head)
        self.assertIn(PACK, git(self.env.repo, "diff", "--name-only", "main", "atlas-agent/demo-1"))
        git(self.env.repo, "checkout", "-q", "main")
        (self.env.repo / "docs/world-design/README.md").write_text("competing worker\n", encoding="utf-8")
        git(self.env.repo, "commit", "-qam", "competing worker")
        refused = self.cli("publish", "--receipt", str(out / "receipt.json"), "--repo", str(self.env.repo),
                           "--branch", "atlas-agent/demo-2")
        self.assertEqual(refused.returncode, 8)
        self.assertIn("upstream_head_changed", refused.stderr)
        self.assertEqual(git(self.env.repo, "branch", "--list", "atlas-agent/demo-2"), "")

    def test_fixture_receipts_and_failed_runs_are_not_publishable(self):
        out = self.env.out()
        done = self.cli("run", "--fixture", "--collection", "mini-vault", "--output-dir", str(out),
                        "--dry-run-plan", str(PLAN))
        self.assertEqual(done.returncode, 0, done.stderr)
        refused = self.cli("publish", "--receipt", str(out / "receipt.json"), "--repo", str(self.env.repo),
                           "--branch", "atlas-agent/x")
        self.assertEqual(refused.returncode, 8)
        self.assertIn("fixture_not_publishable", refused.stderr)


if __name__ == "__main__":
    unittest.main()
