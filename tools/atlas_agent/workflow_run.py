#!/usr/bin/env python3
"""GitHub Actions entry for the Atlas agent runner.

Workflow inputs arrive ONLY as environment variables (never interpolated into a shell
line). Each is validated here against a strict pattern, a runner configuration is built,
the runner is called in-process, and a step summary is written. Rejected inputs still
leave ``input-rejected.json`` so the uploaded artifact explains the failure.

  python3 tools/atlas_agent/workflow_run.py [--validate-only]
"""
from __future__ import annotations

import json
import os
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from atlas_agent import cli, receipt as receipt_mod  # noqa: E402
from atlas_agent.errors import EXIT_USAGE, ConfigError  # noqa: E402
from atlas_agent.fixtures.make_capture_bundle import make_bundle  # noqa: E402

PACKAGE = Path(__file__).resolve().parent
SHA = re.compile(r"^[0-9a-f]{40}$")
NAME = re.compile(r"^[A-Za-z0-9._-]{1,80}$")
MODEL = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$")
NUMBER = re.compile(r"^\d{1,3}(\.\d{1,4})?$")


def _reject(out: Path, message: str) -> int:
    out.mkdir(parents=True, exist_ok=True)
    (out / "input-rejected.json").write_text(json.dumps({"rejected": True, "reason": message}, indent=2) + "\n",
                                             encoding="utf-8", newline="\n")
    print(f"::error title=Atlas agent input rejected::{message}")
    return EXIT_USAGE


def parse_inputs(env: dict) -> dict:
    """Validate raw workflow inputs; raises ConfigError with a precise message."""
    def get(name: str, default: str = "") -> str:
        return (env.get(name) or default).strip()

    values = {
        "source": get("IN_SOURCE", "fixture"), "collection": get("IN_COLLECTION", "mini-vault"),
        "lane": get("IN_LANE", "auto"), "expected_sha": get("IN_ATLAS_SHA"), "mode": get("IN_MODE", "dry-run"),
        "model": get("IN_MODEL"), "max_usd": get("IN_MAX_USD_RUN", "0.25"),
        "ceiling": get("IN_AUTH_CEILING", "0"), "auth_ref": get("IN_AUTH_REF"), "attest": get("IN_ATTEST_JSON"),
        "iterations": get("IN_MAX_ITER", "8"), "artifact": get("IN_ARTIFACT_NAME", "atlas-agent-receipt"),
        "godot": get("IN_GODOT"),
    }
    if values["source"] not in ("fixture", "atlas-ref"):
        raise ConfigError("source must be 'fixture' or 'atlas-ref'")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,62}", values["collection"]):
        raise ConfigError("collection must be a lowercase slug")
    if values["source"] == "fixture" and values["collection"] != "mini-vault":
        raise ConfigError("the bundled fixture only provides the 'mini-vault' collection")
    if values["lane"] not in ("auto", "terrain-art", "ruin-detail", "art-curation"):
        raise ConfigError("lane must be auto, terrain-art, ruin-detail or art-curation")
    if values["expected_sha"] and not SHA.fullmatch(values["expected_sha"]):
        raise ConfigError("expected_source_sha must be 40 lowercase hex characters (or empty)")
    if values["mode"] not in ("dry-run", "live"):
        raise ConfigError("mode must be dry-run or live")
    if (values["mode"] == "live" and env.get("GITHUB_ACTIONS") == "true"
            and env.get("GITHUB_EVENT_NAME") != "workflow_dispatch"):
        raise ConfigError("charged execution requires a manual workflow_dispatch event")
    if values["model"] and not MODEL.fullmatch(values["model"]):
        raise ConfigError("model contains invalid characters")
    for key in ("max_usd", "ceiling"):
        if not NUMBER.fullmatch(values[key]) or float(values[key]) > 25:
            raise ConfigError(f"{key} must be a plain decimal number no greater than 25")
    if not re.fullmatch(r"\d{1,2}", values["iterations"]) or not 1 <= int(values["iterations"]) <= 30:
        raise ConfigError("max_iterations must be an integer 1..30")
    if not NAME.fullmatch(values["artifact"]):
        raise ConfigError("artifact_name must match [A-Za-z0-9._-]{1,80}")
    if len(values["auth_ref"]) > 300 or "\n" in values["auth_ref"]:
        raise ConfigError("authorisation_ref must be one line of at most 300 characters")
    if values["mode"] == "live":
        if not values["model"]:
            raise ConfigError("live mode requires an explicit model")
        if values["source"] == "atlas-ref" and not values["expected_sha"]:
            raise ConfigError("live mode against the Atlas source requires expected_source_sha")
    if values["attest"]:
        if len(values["attest"]) > 4000:
            raise ConfigError("credit_attestation_json is too long")
        try:
            parsed = json.loads(values["attest"])
        except ValueError as exc:
            raise ConfigError(f"credit_attestation_json is not valid JSON: {exc}") from None
        if not isinstance(parsed, dict):
            raise ConfigError("credit_attestation_json must be a JSON object")
        values["attest"] = parsed
    return values


def build_argv(values: dict, env: dict, out: Path, temp: Path) -> list[str]:
    workspace = Path(env.get("GITHUB_WORKSPACE", ".")).resolve()
    argv = ["run", "--output-dir", str(out), "--collection", values["collection"], "--mode", values["mode"],
            "--max-iterations", values["iterations"], "--max-usd-per-run", values["max_usd"]]
    if values["model"]:
        argv += ["--model", values["model"]]
    if values["lane"] != "auto":
        argv += ["--lane", values["lane"]]
    if values["expected_sha"]:
        argv += ["--expected-source-sha", values["expected_sha"]]
    if values["mode"] == "live":
        argv += ["--authorised-ceiling-usd", values["ceiling"]]
        if values["auth_ref"]:
            argv += ["--authorisation-ref", values["auth_ref"]]
        if values["attest"]:
            attestation = temp / "credit-attestation.json"
            attestation.write_text(json.dumps(values["attest"]), encoding="utf-8")
            argv += ["--credit-attestation-file", str(attestation)]
    if values["source"] == "fixture":
        argv += ["--fixture"]
        if values["mode"] == "dry-run":
            argv += ["--dry-run-plan", str(PACKAGE / "fixtures" / "mini-vault-plan.json")]
        bundle_dir = temp / "fixture-capture-bundle"
        make_bundle(PACKAGE / "fixtures" / "atlas-mini" / "docs" / "world-design" / "mini-vault", _fresh(bundle_dir))
        argv += ["--capture-bundle", str(bundle_dir)]
    else:
        argv += ["--atlas-root", str(workspace / "atlas-source")]
        external = workspace / "capture-bundle"
        if external.is_dir():
            argv += ["--capture-bundle", str(external)]
    if values["godot"]:
        argv += ["--godot", values["godot"]]
    return argv


def _fresh(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def write_summary(out: Path, exit_code: int, env: dict) -> None:
    target = env.get("GITHUB_STEP_SUMMARY")
    receipt_path = out / "receipt.json"
    lines = ["## Atlas agent runner", ""]
    if not receipt_path.is_file():
        lines.append(f"No receipt was produced (exit {exit_code}); see `input-rejected.json` or the job log.")
    else:
        rec = json.loads(receipt_path.read_text(encoding="utf-8"))
        problems = receipt_mod.verify_receipt(receipt_path)
        status, cost, usage = rec["status"], rec["cost"], rec["usage"]
        lines += [
            "| Field | Value |", "|---|---|",
            f"| Result | **{status['final']}** (exit {exit_code}, `{status['reason_code']}`) |",
            f"| Mode | {rec['run']['mode']}{' (model calls simulated, no API traffic)' if rec['run']['model_calls_simulated'] else ''} |",
            f"| Collection / lane | {rec['source']['collection']} / {rec['source']['lane']} |",
            f"| Source HEAD | `{rec['source']['repository_head']}` |",
            f"| API responses / attempts | {usage['api_responses']} / {usage['api_attempts']} |",
            f"| Tokens in / cached / out | {usage['input_tokens']} / {usage['cached_input_tokens']} / {usage['output_tokens']} |",
            f"| Computed from reported usage (USD) | {cost['computed_from_reported_usage_usd']}"
            f"{' (simulated)' if cost['simulated'] else ''} |",
            f"| Reserved worst case, total (USD) | {cost['reserved_worst_case_total_usd']} |",
            f"| Remaining allowance (USD) | {cost['remaining_allowance_usd']} |",
            f"| Visual improvement cycle claimed | {rec['visual_cycle']['claimed']} - {rec['visual_cycle']['reason']} |",
            f"| Receipt SHA-256 | `{rec['receipt_sha256']}` |",
            f"| Receipt verification | {'valid' if not problems else 'INVALID: ' + '; '.join(problems)} |",
        ]
        failed = [c for c in rec["credit_gate"]["checks"] if not c["ok"]]
        if failed:
            lines += ["", "**Refused by the live gate:**"] + [f"- `{c['name']}`: {c['detail']}" for c in failed]
        if status["final"] != "success":
            lines += ["", f"> {status['reason']}"]
        lines += ["", "_Estimated (reserved) and computed costs are token counts times published rates, not a bill. "
                      "GitHub Actions compute is billed separately from API usage._"]
    text = "\n".join(lines) + "\n"
    print(text)
    if target:
        with open(target, "a", encoding="utf-8") as handle:
            handle.write(text)


def main(argv: list[str] | None = None, env: dict | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    env = dict(os.environ) if env is None else env
    temp = Path(env.get("RUNNER_TEMP") or tempfile.gettempdir())
    out = Path(env.get("ATLAS_AGENT_OUT") or temp / "atlas-agent-out")
    try:
        values = parse_inputs(env)
    except ConfigError as exc:
        return _reject(out, exc.message)
    if "--validate-only" in argv:
        print("inputs valid")
        return 0
    try:
        run_args = build_argv(values, env, out, temp)
    except Exception as exc:  # noqa: BLE001
        return _reject(out, f"could not prepare the run: {type(exc).__name__}: {exc}")
    code = cli.main(run_args)
    write_summary(out, code, env)
    if "GITHUB_OUTPUT" in env:
        with open(env["GITHUB_OUTPUT"], "a", encoding="utf-8") as handle:
            handle.write(f"exit_code={code}\n")
    if code != 0:
        print(f"::error title=Atlas agent run did not succeed::exit {code}; see the step summary and receipt")
    return code


if __name__ == "__main__":
    sys.exit(main())
