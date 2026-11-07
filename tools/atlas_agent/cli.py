"""Command line: run | credit-check | verify-receipt | publish."""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path

from . import atlas, credit_gate, gitops, pricing, receipt as receipt_mod, runner
from .config import load_config
from .errors import EXIT_OK, EXIT_USAGE, AgentError, ConfigError, SourceChanged


def _overrides(args: argparse.Namespace) -> dict:
    task, limits, spend, api = {}, {}, {}, {}

    def put(target: dict, key: str, value) -> None:
        if value is not None:
            target[key] = value

    for key in ("collection", "lane", "atlas_root", "expected_source_sha", "capture_bundle", "capture_launcher", "godot",
                "dry_run_plan"):
        put(task, key, getattr(args, key, None))
    if getattr(args, "fixture", False):
        task["fixture"] = True
    if getattr(args, "critique_only", False):
        task["critique_only"] = True
    if getattr(args, "allow_dirty_source", False):
        task["allow_dirty_source"] = True
    if getattr(args, "read_extra_collection", None):
        task["read_extra_collections"] = list(args.read_extra_collection)
    put(limits, "max_iterations", getattr(args, "max_iterations", None))
    put(limits, "max_api_calls", getattr(args, "max_api_calls", None))
    put(spend, "max_usd_per_run", getattr(args, "max_usd_per_run", None))
    put(spend, "max_usd_per_call", getattr(args, "max_usd_per_call", None))
    put(spend, "authorised_ceiling_usd", getattr(args, "authorised_ceiling_usd", None))
    put(spend, "authorisation_ref", getattr(args, "authorisation_ref", None))
    put(spend, "expected_project", getattr(args, "expected_project", None))
    if getattr(args, "credit_attestation_file", None):
        try:
            spend["credit_attestation"] = json.loads(Path(args.credit_attestation_file).read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            raise ConfigError(f"cannot read credit attestation file: {exc}", "attestation_unreadable") from None
    put(api, "reasoning_effort", getattr(args, "reasoning_effort", None))
    if getattr(args, "no_reasoning", False):
        api["reasoning_effort"] = None
    put(api, "image_detail", getattr(args, "image_detail", None))
    out: dict = {}
    put(out, "mode", getattr(args, "mode", None))
    put(out, "model", getattr(args, "model", None))
    for name, section in (("task", task), ("limits", limits), ("spend", spend), ("api", api)):
        if section:
            out[name] = section
    return out


def _add_common(p: argparse.ArgumentParser) -> None:
    p.add_argument("--config", help="JSON configuration (cybersand.atlas-agent.config/1)")
    p.add_argument("--mode", choices=("dry-run", "live"))
    p.add_argument("--model", help="explicit model id (required for live; no fallback)")
    p.add_argument("--collection")
    p.add_argument("--lane", choices=("terrain-art", "ruin-detail", "art-curation"))
    p.add_argument("--fixture", action="store_true", help="use the bundled synthetic atlas-mini fixture")
    p.add_argument("--atlas-root", dest="atlas_root", help="checkout containing docs/world-design (read-only)")
    p.add_argument("--expected-source-sha", dest="expected_source_sha")
    p.add_argument("--allow-dirty-source", action="store_true", dest="allow_dirty_source")
    p.add_argument("--critique-only", action="store_true", dest="critique_only")
    p.add_argument("--read-extra-collection", action="append", dest="read_extra_collection")
    p.add_argument("--capture-bundle", dest="capture_bundle")
    p.add_argument("--capture-launcher", dest="capture_launcher")
    p.add_argument("--godot")
    p.add_argument("--max-usd-per-run", type=float, dest="max_usd_per_run")
    p.add_argument("--max-usd-per-call", type=float, dest="max_usd_per_call")
    p.add_argument("--authorised-ceiling-usd", type=float, dest="authorised_ceiling_usd")
    p.add_argument("--authorisation-ref", dest="authorisation_ref")
    p.add_argument("--expected-project", dest="expected_project")
    p.add_argument("--credit-attestation-file", dest="credit_attestation_file")
    p.add_argument("--reasoning-effort", dest="reasoning_effort", choices=("none", "minimal", "low", "medium", "high"))
    p.add_argument("--no-reasoning", action="store_true", dest="no_reasoning")
    p.add_argument("--image-detail", dest="image_detail", choices=("low", "high", "auto"))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="atlas_agent_runner", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    run = sub.add_parser("run", help="execute one bounded run and write a receipt")
    _add_common(run)
    run.add_argument("--output-dir", required=True, dest="output_dir")
    run.add_argument("--max-iterations", type=int, dest="max_iterations")
    run.add_argument("--max-api-calls", type=int, dest="max_api_calls")
    run.add_argument("--dry-run-plan", dest="dry_run_plan")
    check = sub.add_parser("credit-check", help="evaluate the live gate only (no charged request)")
    _add_common(check)
    verify = sub.add_parser("verify-receipt", help="verify schema, seal and absence of credentials")
    verify.add_argument("receipt")
    publish = sub.add_parser("publish", help="commit a receipt's patch to a NEW atlas-agent/* branch (compare-and-swap)")
    publish.add_argument("--receipt", required=True)
    publish.add_argument("--repo", required=True, help="checkout of the Atlas repository")
    publish.add_argument("--branch", required=True)
    publish.add_argument("--base-ref", default="HEAD", dest="base_ref")
    publish.add_argument("--remote")
    publish.add_argument("--push", action="store_true", help="push the new branch (never forced)")
    return parser


def _emit_result(result: runner.RunResult) -> None:
    rec = result.receipt
    print("ATLAS_AGENT_RESULT " + json.dumps({
        "status": rec["status"]["final"], "exit_code": result.exit_code, "reason_code": rec["status"]["reason_code"],
        "reason": rec["status"]["reason"][:300], "mode": rec["run"]["mode"], "receipt": str(result.receipt_path),
        "receipt_sha256": rec["receipt_sha256"], "committed_usd": rec["cost"]["committed_usd"],
        "simulated": rec["cost"]["simulated"], "api_responses": rec["usage"]["api_responses"]}), flush=True)


def cmd_run(args: argparse.Namespace) -> int:
    result = runner.execute(args.config, _overrides(args), Path(args.output_dir))
    _emit_result(result)
    return result.exit_code


def cmd_credit_check(args: argparse.Namespace) -> int:
    overrides = _overrides(args)
    overrides["mode"] = "live"
    cfg = load_config(args.config, overrides)
    now = dt.datetime.now(dt.timezone.utc)
    table_path = Path(cfg["pricing_file"]) if cfg["pricing_file"] else None
    table = pricing.load_table(table_path)
    root = cfg["task"]["atlas_root"] or ""
    identity = gitops.repo_identity(Path(root)) if root and Path(root).is_dir() else {"dirty": None}
    report, _ = runner.gate_report(cfg, dict(os.environ), table, now, None, __import__("time").sleep,
                                   credit_gate.default_costs_probe, identity["dirty"])
    report.pop("rates", None)
    print(json.dumps({"gate": {k: report[k] for k in ("passed", "checks", "headroom_basis", "facts")}}, indent=2))
    return EXIT_OK if report["passed"] else 3


def cmd_verify(args: argparse.Namespace) -> int:
    problems = receipt_mod.verify_receipt(Path(args.receipt))
    print(json.dumps({"receipt": args.receipt, "valid": not problems, "problems": problems}, indent=2))
    return EXIT_OK if not problems else EXIT_USAGE


def cmd_publish(args: argparse.Namespace) -> int:
    receipt_path = Path(args.receipt)
    problems = receipt_mod.verify_receipt(receipt_path)
    if problems:
        raise SourceChanged("receipt failed verification: " + "; ".join(problems[:3]), "receipt_invalid")
    rec = json.loads(receipt_path.read_text(encoding="utf-8"))
    if rec["status"]["final"] != "success" or not rec["artifacts"]["patch"]:
        raise SourceChanged("only a successful receipt with a patch can be published", "nothing_to_publish")
    if rec["source"]["fixture"]:
        raise SourceChanged("fixture runs are not publishable", "fixture_not_publishable")
    lane, writable = atlas.resolve_lane(rec["source"]["collection"], rec["source"]["lane"], False)
    if not writable:
        raise SourceChanged("the receipt's lane does not own this collection", "lane_ownership_violation")
    patch = receipt_path.parent / rec["artifacts"]["patch"]["path"]
    if not patch.is_file() or receipt_mod.hashlib.sha256(patch.read_bytes()).hexdigest() != rec["artifacts"]["patch"]["sha256"]:
        raise SourceChanged("patch bytes differ from the receipt", "patch_hash_mismatch")
    result = gitops.publish_patch(Path(args.repo), patch, rec["source"]["repository_head"], args.branch,
                                  atlas.patch_globs(rec["source"]["collection"], True), args.remote, args.base_ref,
                                  args.push)
    print("ATLAS_AGENT_PUBLISH " + json.dumps(result))
    return EXIT_OK


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    handlers = {"run": cmd_run, "credit-check": cmd_credit_check, "verify-receipt": cmd_verify, "publish": cmd_publish}
    try:
        return handlers[args.command](args)
    except AgentError as exc:
        print(f"ATLAS_AGENT_ERROR {exc.reason_code}: {exc.message}", file=sys.stderr)
        return exc.exit_code


if __name__ == "__main__":
    sys.exit(main())
