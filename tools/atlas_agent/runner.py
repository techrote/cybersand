"""Bounded Responses API agent loop with reserve-before-call budgeting and receipts.

Phases: preflight -> gate (live only) -> loop -> finalise. A receipt is written on
every path, including refusals and crashes.
"""
from __future__ import annotations

import base64
import datetime as dt
import json
import os
import secrets
import shutil
import tempfile
import time
from pathlib import Path
from typing import Callable

from . import atlas, captures, credit_gate, gitops, pricing, receipt as receipt_mod
from .budget import Budget
from .client import ApiClient, make_sdk_client, sdk_version, usage_of
from .config import load_config
from .dryrun import DryRunBackend, load_plan
from .errors import (EXIT_OK, STATUS_FAILURE, STATUS_SUCCESS, AgentError, ApiFailure, ConfigError, LimitReached,
                     SandboxViolation, SourceChanged, ValidationFailed)
from .procs import resolve_executables
from .sandbox import PathPolicy, is_inside, sha256_bytes, sha256_file
from .tools import ToolExecutor, tool_definitions, tools_sha256

PACKAGE = Path(__file__).resolve().parent
INSTRUCTIONS = PACKAGE / "instructions" / "atlas-agent-instructions.md"
DEFAULT_LAUNCHER = PACKAGE.parents[1] / "tools" / captures.LAUNCHER_NAME


class RunResult:
    def __init__(self, exit_code: int, receipt: dict, receipt_path: Path | None):
        self.exit_code, self.receipt, self.receipt_path = exit_code, receipt, receipt_path


def _utc(now: dt.datetime) -> str:
    return now.strftime("%Y-%m-%dT%H:%M:%SZ")


def _item_dict(item) -> dict:
    if isinstance(item, dict):
        return item
    dump = item.model_dump(exclude_none=True)
    dump.pop("parsed_arguments", None)
    return dump


class History:
    """Stateless conversation: output items are fed back; images age out of context."""

    def __init__(self, resend_calls: int):
        self.items: list[dict] = []
        self.resend_calls = resend_calls

    def add(self, item: dict) -> None:
        self.items.append(item)

    def add_images(self, call_no: int, labelled: list[tuple[dict, str]], detail: str) -> None:
        content, meta = [], []
        for attachment, label in labelled:
            content.append({"type": "input_text", "text": label})
            content.append({"type": "input_image", "detail": detail,
                            "image_url": "data:image/png;base64," + base64.b64encode(attachment["data"]).decode()})
            meta.append({"sha256": attachment["sha256"], "width": attachment["width"], "height": attachment["height"]})
        self.items.append({"role": "user", "content": content, "_meta": {"born": call_no, "images": meta}})

    def render(self, call_no: int) -> tuple[list[dict], list[dict]]:
        out, sent = [], []
        for item in self.items:
            meta = item.get("_meta")
            if meta is None:
                out.append(item)
            elif call_no - meta["born"] <= self.resend_calls:
                out.append({k: v for k, v in item.items() if k != "_meta"})
                sent += meta["images"]
            else:
                shas = ", ".join(m["sha256"][:12] for m in meta["images"])
                out.append({"role": "user", "content": [{"type": "input_text", "text":
                            f"[image(s) {shas} dropped from context to save budget; view_image again if needed]"}]})
        return out, sent


def estimate_input_tokens(request: dict, sent_images: list[dict], rates: pricing.Rates, detail: str,
                          bytes_per_token: float) -> int:
    stripped = json.loads(json.dumps(request))
    for item in stripped.get("input", []):
        for part in item.get("content", []) if isinstance(item.get("content"), list) else []:
            if part.get("type") == "input_image":
                part["image_url"] = ""
    total = pricing.text_tokens_upper_bound(len(json.dumps(stripped).encode("utf-8")), bytes_per_token)
    for image in sent_images:
        total += pricing.image_tokens_upper_bound(rates, image["width"], image["height"], detail)
    return total


def _task_prompt(cfg: dict, collection: str, lane: str, writable: bool, tool_names: list[str], has_images: bool) -> str:
    limits = cfg["limits"]
    directive = cfg["task"]["directive"].strip()
    owner = (f"\nOwner directive for this run (trusted operator instruction; it overrides any default 'one small edit' "
             f"guidance, never the hard rules):\n{directive}\n") if directive else ""
    return (f"Collection: {collection}\nLane: {lane}\nEdit custody: "
            f"{'you may edit this collection (pack.json/README.md)' if writable else 'READ-ONLY critique; no edits possible'}\n"
            f"Image evidence provided: {'yes (list_captures)' if has_images else 'no'}\n"
            f"Tools: {', '.join(tool_names)}\n"
            f"Budget: at most {limits['max_iterations']} iterations, {limits['max_tool_calls']} tool calls, "
            f"{limits['max_images']} images. Work efficiently and finish with submit_report." + owner)


def execute(config_path: str | None, overrides: dict, out_dir: Path, *, env: dict | None = None, sdk=None,
            sleep: Callable[[float], None] = time.sleep, clock: Callable[[], float] = time.monotonic,
            now: dt.datetime | None = None, costs_probe=credit_gate.default_costs_probe,
            launcher: Path | None = None) -> RunResult:
    env = dict(os.environ) if env is None else env
    now = now or dt.datetime.now(dt.timezone.utc)
    out_dir = Path(out_dir)
    if out_dir.exists() and any(out_dir.iterdir()):
        raise ConfigError(f"output directory {out_dir} is not empty; earlier evidence is never overwritten",
                          "output_not_empty")
    out_dir.mkdir(parents=True, exist_ok=True)
    mode_guess = (overrides.get("mode") or "dry-run")
    collection_guess = (overrides.get("task") or {}).get("collection") or "unknown"
    rec = receipt_mod.skeleton(f"{now.strftime('%Y%m%dT%H%M%SZ')}-{secrets.token_hex(4)}", mode_guess, _utc(now),
                               collection_guess)
    redactor = receipt_mod.Redactor([env.get("OPENAI_API_KEY", ""), env.get("OPENAI_ADMIN_KEY", "")])
    started = clock()
    ctx: dict = {"phase": "preflight", "workspace": None, "executor": None, "budget": None, "calls": [],
                 "tool_log": [], "transcript": [], "image_sends": 0, "report": None, "history": None}
    error: AgentError | None = None
    try:
        cfg = load_config(config_path, overrides)
        redactor = receipt_mod.Redactor([env.get(cfg["api"]["key_env"], ""), env.get(cfg["spend"]["costs_key_env"], "")])
        _run(cfg, rec, out_dir, ctx, env, sdk, sleep, clock, now, costs_probe, launcher, redactor)
        ctx["phase"] = "done"
        rec["status"].update({"final": STATUS_SUCCESS, "exit_code": EXIT_OK, "reason_code": "completed",
                              "reason": "report submitted, validations passed, limits respected"})
    except AgentError as exc:
        error = exc
    except Exception as exc:  # noqa: BLE001 - a runner defect must still produce a receipt
        error = AgentError(f"{type(exc).__name__}: {exc}", "internal_error")
    if error is not None:
        rec["status"].update({"final": error.status, "exit_code": error.exit_code, "reason_code": error.reason_code,
                              "reason": redactor.text(error.message)[:1000]})
    rec["status"]["phase"] = ctx["phase"]
    path = _finalise(rec, out_dir, ctx, redactor, clock() - started, clock, now)
    ws = ctx.get("workspace")
    if ws:
        shutil.rmtree(ws, ignore_errors=True)
    return RunResult(rec["status"]["exit_code"], rec, path)


def _run(cfg, rec, out_dir, ctx, env, sdk, sleep, clock, now, costs_probe, launcher, redactor) -> None:
    live = cfg["mode"] == "live"
    task, limits, spend, api = cfg["task"], cfg["limits"], cfg["spend"], cfg["api"]
    collection = task["collection"]
    table_path = Path(cfg["pricing_file"]) if cfg["pricing_file"] else None
    table = pricing.load_table(table_path)
    rec["policy"]["pricing_sha256"] = pricing.table_sha256(table_path)
    rates = pricing.rates_for(cfg["model"], table, now.date(), enforce_age=live)
    if api["reasoning_effort"] is not None and not rates.supports_reasoning:
        raise ConfigError(f"{cfg['model']} does not support reasoning effort; set api.reasoning_effort to null",
                          "reasoning_unsupported")
    rec["run"]["mode"], rec["run"]["openai_sdk"] = cfg["mode"], sdk_version()
    rec["run"]["model_calls_simulated"] = not live
    runner_identity = gitops.repo_identity(PACKAGE)
    rec["run"].update({"runner_git_head": runner_identity["repository_head"],
                       "runner_tree_dirty": runner_identity["dirty"]})
    rec["model"].update({"requested": cfg["model"], "reasoning_effort": api["reasoning_effort"],
                         "max_output_tokens_per_call": limits["max_output_tokens_per_call"],
                         "image_detail": api["image_detail"],
                         "api_endpoint": "none" if not live else ("openai-default" if not api["base_url"]
                                                                  else "loopback-test")})
    rec["limits"] = {"limits": limits, "spend": {k: v for k, v in spend.items() if k != "credit_attestation"}}
    rec["cost"]["rates"] = rates.public()
    rec["cost"].update({"per_call_ceiling_usd": spend["max_usd_per_call"], "per_run_ceiling_usd": spend["max_usd_per_run"],
                        "authorised_ceiling_usd": spend["authorised_ceiling_usd"] if live else 0.0})

    # ---- source identity -------------------------------------------------------
    fixture = task["fixture"]
    source_root = Path(task["atlas_root"] or (PACKAGE / "fixtures" / "atlas-mini" if fixture else ""))
    if not str(source_root) or not source_root.is_dir():
        raise ConfigError("task.atlas_root must point at an Atlas source checkout (or use task.fixture)", "atlas_root_missing")
    source_root = source_root.resolve()
    if is_inside(out_dir, source_root):
        raise ConfigError("the output directory must not be inside the read-only Atlas source", "unsafe_output_dir")
    identity = gitops.repo_identity(source_root)
    rec["source"].update({"repository_head": identity["repository_head"], "source_dirty": identity["dirty"],
                          "expected_source_sha": task["expected_source_sha"], "fixture": fixture})
    gitops.check_expected_sha(task["expected_source_sha"], identity["repository_head"])
    lane, writable = atlas.resolve_lane(collection, task["lane"], fixture)
    writable = writable and not task["critique_only"]
    rec["source"].update({"lane": lane, "lane_writable": writable})

    # ---- disposable workspace + policy ---------------------------------------
    work_root = Path(tempfile.mkdtemp(prefix="atlas-agent-ws-"))
    ctx["workspace"] = work_root
    built = atlas.build_workspace(source_root, collection, task["read_extra_collections"], work_root)
    rec["source"].update({"files": built["files"], "source_manifest_sha256": built["manifest_sha256"]})
    policy = PathPolicy(work_root, atlas.read_globs(collection, task["read_extra_collections"]),
                        atlas.write_globs(collection, writable))
    generated = atlas.generated_globs(collection, writable)
    rec["policy"].update({"read_globs": policy.read_globs, "write_globs": policy.write_globs,
                          "generated_globs": generated})
    instructions = INSTRUCTIONS.read_text(encoding="utf-8")
    directive = task["directive"].strip()
    rec["policy"]["task_directive"] = ({"text": directive, "sha256": sha256_bytes(directive.encode("utf-8"))}
                                       if directive else None)
    rec["policy"].update({"instructions_version": instructions.splitlines()[0].split(":", 1)[1].strip(),
                          "instructions_sha256": sha256_file(INSTRUCTIONS), "tool_schema_sha256": tools_sha256()})

    # ---- capture evidence -----------------------------------------------------
    bundle = Path(task["capture_bundle"]) if task["capture_bundle"] else None
    if bundle is not None:
        summary = captures.summarize_bundle(bundle, "input")
        rec["captures"]["input_bundle"] = {k: v for k, v in summary.items() if k != "problems"} | \
            {"problems": summary["problems"]}
        if not summary["verified"]:
            raise ConfigError("input capture bundle failed verification: " + "; ".join(summary["problems"][:3]),
                              "capture_bundle_invalid")
    renderer = launcher or (Path(task["capture_launcher"]) if task["capture_launcher"] else
                            (DEFAULT_LAUNCHER if DEFAULT_LAUNCHER.is_file() and task["godot"] else None))
    if renderer is not None and not task["godot"]:
        renderer = None
    executor = ToolExecutor(cfg, work_root, policy, collection, writable, task["read_extra_collections"], redactor,
                            resolve_executables(), bundle, renderer, out_dir)
    ctx["executor"] = executor
    tool_names = executor.tool_names()
    rec["policy"]["tools_advertised"] = tool_names

    # ---- gate (live only) -----------------------------------------------------
    budget = Budget(limits, spend, rates, live, clock)
    ctx["budget"] = budget
    client: ApiClient | None = None
    if live:
        ctx["phase"] = "gate"
        report, client = gate_report(cfg, env, table, now, sdk, sleep, costs_probe, identity["dirty"])
        rec["credit_gate"] = {k: report[k] for k in ("performed", "passed", "checks", "headroom_basis", "facts")}
        credit_gate.enforce(report)
    ctx["phase"] = "loop"

    # ---- backend ---------------------------------------------------------------
    plan = load_plan(task["dry_run_plan"]) if not live else None
    backend = client if live else DryRunBackend(collection, plan, bundle is not None, renderer is not None, writable)
    history = History(int(limits["image_resend_calls"]))
    ctx["history"] = history
    history.add({"role": "user", "content": [{"type": "input_text", "text": _task_prompt(
        cfg, collection, lane, writable, tool_names, bundle is not None)}]})
    tool_defs = tool_definitions(tool_names)
    nudges = 0
    call_no = 0
    tool_no = 0
    while True:
        budget.start_iteration()
        call_no += 1
        input_items, sent = history.render(call_no)
        request = {"model": cfg["model"], "instructions": instructions, "input": input_items, "tools": tool_defs,
                   "tool_choice": "auto", "parallel_tool_calls": True,
                   "max_output_tokens": int(limits["max_output_tokens_per_call"]), "store": False,
                   "truncation": "disabled"}
        if api["reasoning_effort"] is not None:
            request["reasoning"] = {"effort": api["reasoning_effort"]}
            request["include"] = ["reasoning.encrypted_content"]
        upper = estimate_input_tokens(request, sent, rates, api["image_detail"],
                                      float(limits["token_estimate_bytes_per_token"]))
        result = backend.respond(budget, request, upper, request["max_output_tokens"]) if not live else \
            client.respond(budget, request, upper, request["max_output_tokens"])
        response = result["response"]
        usage = usage_of(response)
        if usage is None:
            budget.mark_ambiguous(result["reservation"])
            raise ApiFailure("response carried no usage; cost cannot be reconciled", "usage_missing")
        reconciled = budget.commit(result["reservation"], **usage)
        for image in sent:
            ctx["image_sends"] += 1
            if image["sha256"] in executor.images:
                executor.images[image["sha256"]]["sent_in_calls"].append(call_no)
        ctx["calls"].append({"n": call_no, "kind": "simulated" if not live else "responses.create",
                             "response_id": getattr(response, "id", None), "status": getattr(response, "status", None),
                             "model": getattr(response, "model", None), "request_id": result.get("request_id"),
                             "retries": result["retries"], "retry_events": result["events"],
                             "input_tokens_estimated_upper": upper, "reserved_worst_case_usd": round(
                                 result["reservation"].usd, 8), "input_tokens": usage["input_tokens"],
                             "cached_input_tokens": usage["cached_tokens"], "output_tokens": usage["output_tokens"],
                             "reasoning_tokens": usage["reasoning_tokens"],
                             "computed_from_reported_usage_usd": round(reconciled["computed_usd"], 8),
                             "images_in_request": len(sent), "duration_ms": result["duration_ms"]})
        observed = getattr(response, "model", None)
        if observed and observed not in rec["model"]["observed"]:
            rec["model"]["observed"].append(observed)
        if live and observed and not (observed == cfg["model"] or observed.startswith(cfg["model"] + "-")):
            raise ApiFailure(f"API served model {observed!r} instead of the requested {cfg['model']!r}; "
                             "no hidden model substitution", "model_substituted")
        if reconciled["exceeded_reservation"]:
            raise ApiFailure("reported usage exceeded the reserved worst case; stopping fail-closed",
                             "reservation_exceeded")
        if getattr(response, "status", "completed") == "incomplete":
            raise LimitReached("the response was cut off by max_output_tokens", "response_incomplete")
        items = [_item_dict(i) for i in response.output]
        for item in items:
            history.add(item)
        text = " ".join(part.get("text", "") for i in items if i.get("type") == "message"
                        for part in i.get("content", []) if part.get("type") == "output_text")
        calls = [i for i in items if i.get("type") == "function_call"]
        ctx["transcript"].append({"call": call_no, "assistant_text": redactor.text(text)[:2000],
                                  "tool_calls": [{"name": c.get("name"), "arguments_sha256": sha256_bytes(
                                      str(c.get("arguments")).encode())} for c in calls]})
        if not calls:
            if ctx["report"] is None:
                if nudges >= 1:
                    raise LimitReached("the model finished without calling submit_report", "no_report_submitted")
                nudges += 1
                history.add({"role": "user", "content": [{"type": "input_text", "text":
                             "You must finish by calling submit_report with your structured report."}]})
                continue
        if len(calls) > int(limits["max_tool_calls_per_response"]):
            raise LimitReached(f"{len(calls)} tool calls in one response exceeds max_tool_calls_per_response",
                               "max_tool_calls_per_response")
        attachments: list[tuple[dict, str]] = []
        for call in calls:
            tool_no += 1
            outcome = executor.execute(call.get("name", ""), call.get("arguments", ""), tool_no)
            ctx["tool_log"].append({"n": tool_no, "name": str(call.get("name"))[:60],
                                    "arguments": redactor.text(str(call.get("arguments")))[:2000],
                                    "ok": outcome.ok, "error_code": outcome.error_code, "output": outcome.text[:4000]})
            history.add({"type": "function_call_output", "call_id": call["call_id"], "output": outcome.text})
            for attachment in outcome.attachments:
                info = executor.images[attachment["sha256"]]
                attachments.append((attachment, f"Image {attachment['sha256'][:12]} = {info['bundle']}/"
                                                f"{info['collection']}/{info['shot_id']} "
                                                f"(evidence_class={info['evidence_class']}, "
                                                f"{info['width']}x{info['height']})"))
            if outcome.report is not None:
                ctx["report"] = outcome.report
                break
        if ctx["report"] is not None:
            break
        if attachments:
            history.add_images(call_no, attachments, api["image_detail"])
    ctx["phase"] = "finalise"

    # ---- finalise: source identity, patch, final validation --------------------
    after = gitops.repo_identity(source_root)
    rec["source"]["head_after_run"] = after["repository_head"]
    fresh = {rel: sha256_file(source_root / rel) for rel in built["files"] if (source_root / rel).is_file()}
    unchanged = after["repository_head"] == identity["repository_head"] and \
        all(fresh.get(rel) == meta["sha256"] for rel, meta in built["files"].items())
    rec["source"]["source_unchanged_after_run"] = unchanged
    if not unchanged:
        raise SourceChanged("the Atlas source (HEAD or file hashes) changed while the run executed; "
                            "the patch is not safe to publish", "source_changed_during_run")
    patch_text = _build_patch(source_root, work_root, built["files"], policy, generated)
    if patch_text:
        patch_path = out_dir / "patch.diff"
        patch_path.write_text(patch_text, encoding="utf-8", newline="\n")
        targets = gitops.check_patch_scope(patch_text, policy.write_globs + generated)
        rec["artifacts"]["patch"] = {"path": "patch.diff", "sha256": sha256_file(patch_path), "files": targets}
        for kind in ("validate", "render_check"):
            try:
                final = atlas.run_script(work_root, collection, kind, float(limits["max_tool_seconds"]),
                                         int(limits["max_tool_output_bytes"]) // 2)
            except ValidationFailed as exc:
                if kind == "render_check" and exc.reason_code == "render_check_unsupported":
                    continue  # this collection's render script has no --check mode: recorded by omission
                raise
            executor.validation.append({"n": len(executor.validation) + 1, "collection": collection, "kind": kind,
                                        "script": final["script"], "script_sha256": final["script_sha256"],
                                        "argv": final["argv_public"], "exit_code": final["exit_code"],
                                        "passed": final["passed"], "timed_out": final["timed_out"],
                                        "duration_seconds": final["duration_seconds"], "runner_final_check": True,
                                        "stdout_tail": redactor.text(final["stdout"][-600:]),
                                        "stderr_tail": redactor.text(final["stderr"][-600:])})
            if not final["passed"]:
                raise ValidationFailed(f"the patched collection fails its own {kind} check; patch kept for "
                                       "diagnosis only", "final_validation_failed")
    report = ctx["report"]
    if report and report["outcome"] == "blocked":
        raise LimitReached("the agent reported it is blocked: " + report["summary"][:300], "agent_reported_blocked")
    _visual_cycle(rec, executor, bool(patch_text))


def gate_report(cfg: dict, env: dict, table: dict, now: dt.datetime, sdk, sleep, costs_probe,
                source_dirty: bool | None) -> tuple[dict, ApiClient | None]:
    """Evaluate the live gate. The SDK client is only built after the key check passes."""
    api, limits = cfg["api"], cfg["limits"]
    holder: dict = {}

    def probe(model: str) -> dict:
        holder["client"] = ApiClient(sdk or make_sdk_client(env[api["key_env"]], api["base_url"],
                                                             api["timeout_seconds"]), limits, sleep)
        return holder["client"].probe_model(model)

    base = api["base_url"] or "https://api.openai.com/v1"
    report = credit_gate.evaluate(cfg, env, table, now, probe, costs_probe, source_dirty, base)
    return report, holder.get("client")


def _build_patch(source_root: Path, work_root: Path, original: dict, policy: PathPolicy,
                 generated: list[str]) -> str:
    """Unified diff of every changed file. New/deleted files and unassigned changes are violations."""
    now_files = atlas.snapshot(work_root)
    for rel in sorted(now_files):
        if rel not in original:
            raise SandboxViolation(f"unexpected new file in the workspace: {rel}", "unexpected_new_file")
    patches = []
    for rel, meta in sorted(original.items()):
        if rel not in now_files:
            raise SandboxViolation(f"workspace file disappeared: {rel}", "unexpected_deletion")
        if now_files[rel] == meta["sha256"]:
            continue
        if rel not in generated:
            policy.check_write(rel)  # a changed file must have been assigned to this lane/collection
        patches.append(gitops.unified_patch(rel, (source_root / rel).read_bytes(), (work_root / rel).read_bytes()))
    return "".join(patches)


def _visual_cycle(rec: dict, executor: ToolExecutor, edited: bool) -> None:
    comparison = executor.comparison
    if rec["run"]["mode"] != "live":
        reason = "dry-run: no model critiqued the images, so no improvement cycle is claimed"
    elif executor.input_bundle is None:
        reason = "no input capture bundle was supplied"
    elif not edited:
        reason = "no source edit was applied"
    elif comparison is None:
        reason = "no after-capture was rendered and compared (renderer unavailable or not invoked)"
    elif not comparison["godot_to_godot"]:
        reason = f"evidence classes {comparison['evidence_classes']} are not both godot-capture (fixtures are not engine output)"
    elif not comparison["comparable"]:
        reason = "before/after captures use different framing or failed verification"
    elif not comparison["visual_change_observed"]:
        reason = "captures are equivalent but no pack and pixel change was observed"
    else:
        rec["visual_cycle"] = {"claimed": True, "reason": "Godot before/after captured with equivalent framing; "
                                                         "pack and PNG changed; patched pack re-validated"}
        return
    rec["visual_cycle"] = {"claimed": False, "reason": reason}


def _finalise(rec: dict, out_dir: Path, ctx: dict, redactor: receipt_mod.Redactor, duration: float, clock,
              now: dt.datetime) -> Path:
    budget: Budget | None = ctx["budget"]
    executor: ToolExecutor | None = ctx["executor"]
    live = rec["run"]["mode"] == "live"
    if budget is not None:
        snap = budget.snapshot()
        rec["usage"].update({"api_attempts": snap["attempts"], "api_responses": snap["responses"],
                             "iterations": snap["iterations"], "input_tokens": snap["input_tokens"],
                             "cached_input_tokens": snap["cached_input_tokens"], "output_tokens": snap["output_tokens"],
                             "reasoning_tokens": snap["reasoning_tokens"],
                             "retries": sum(c["retries"] for c in ctx["calls"])})
        rec["cost"].update({k: snap[k] for k in ("reserved_worst_case_total_usd", "peak_reservation_usd",
                                                "computed_from_reported_usage_usd", "ambiguous_charge_assumed_usd",
                                                "committed_usd", "remaining_allowance_usd", "reservation_overruns")})
        rec["cost"]["simulated"] = not live
    if executor is not None:
        rec["usage"].update({"tool_calls": executor.tool_calls, "malformed_tool_calls": executor.malformed,
                             "sandbox_violations": executor.violations, "images_loaded": len(executor.images),
                             "image_sends": ctx["image_sends"], "image_bytes": executor.image_bytes,
                             "tool_seconds": round(executor.tool_seconds, 3)})
        rec["tools"] = [{"n": r["n"], **{k: v for k, v in r.items() if k != "n"}} for r in executor.records]
        rec["validation"] = executor.validation
        rec["edits"] = executor.edits
        rec["images"] = list(executor.images.values())
        rec["captures"]["render_attempts"] = executor.render_attempts
        rec["captures"]["comparison"] = executor.comparison
        if executor.rendered_bundle is not None and "rendered" in executor.bundle_summaries:
            rec["captures"]["rendered_bundle"] = executor.bundle_summaries["rendered"]
    rec["calls"] = ctx["calls"]
    rec["final_report"] = ctx["report"]
    for name, rows in (("tool-log.jsonl", ctx["tool_log"]), ("transcript.jsonl", ctx["transcript"])):
        target = out_dir / name
        target.write_text("".join(json.dumps(redactor.obj(r), ensure_ascii=False) + "\n" for r in rows),
                          encoding="utf-8", newline="\n")
        rec["artifacts"]["tool_log" if name.startswith("tool") else "transcript"] = {
            "path": name, "sha256": sha256_file(target), "entries": len(rows)}
    rec["run"]["finished_utc"] = _utc(dt.datetime.now(dt.timezone.utc))
    rec["run"]["duration_seconds"] = round(duration, 3)
    clean = redactor.obj(rec)
    rec.clear()
    rec.update(clean)
    receipt_mod.seal(rec)
    from .schema import load_schema, validate
    problems = validate(rec, load_schema("receipt.schema.json"))
    if problems:
        rec["status"].update({"final": STATUS_FAILURE, "exit_code": 9, "reason_code": "receipt_schema_violation",
                              "reason": "; ".join(problems[:4])})
        receipt_mod.seal(rec)
    path = out_dir / "receipt.json"
    text = receipt_mod.canonical(rec)
    if redactor.contains_secret(text):  # last line of defence: never write a credential-shaped receipt
        rec["status"].update({"final": STATUS_FAILURE, "exit_code": 9, "reason_code": "secret_in_receipt",
                              "reason": "receipt contained credential-shaped content and was withheld"})
        rec["final_report"] = None
        text = receipt_mod.canonical(receipt_mod.seal(rec))
    path.write_text(text, encoding="utf-8", newline="\n")
    return path
