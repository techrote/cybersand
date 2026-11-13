#!/usr/bin/env python3
"""Single-job, durable-lease, bounded whole-process supervisor for WB-ART-SLM.

Run locally only; never schedule model training on GitHub Actions. The parent holds
exactly the same file lock that a direct train_lora.py invocation would acquire.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import signal
import subprocess
import sys
import time
import uuid

from filelock import FileLock

LOCK_NAME = "wb-art-slm-training.lock"
LEASE_NAME = "wb-art-slm-training.role-lease.json"
START_NAME = "guard_start.json"
RESULT_NAME = "guard_result.json"
INPUT_FILES = ("--train", "--dev", "--admission", "--corpus-manifest", "--compiler", "--system-file", "--v5-manifest")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def canonical(obj) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), allow_nan=False)


def atomic_json(path: Path, obj) -> None:
    temporary = path.with_name("." + path.name + "." + uuid.uuid4().hex + ".tmp")
    temporary.write_text(canonical(obj) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def options(argv: list[str]) -> dict[str, str | bool]:
    """Parse option/value pairs and reject ambiguous repeated arguments."""
    values: dict[str, str | bool] = {}
    flags = {"--skip-baseline", "--skip-final-eval", "--preflight-only", "--gradient-checkpointing", "--trust-remote-code"}
    i = 0
    while i < len(argv):
        key = argv[i]
        if not key.startswith("--") or key in values:
            raise ValueError("Unexpected or repeated trainer option: " + key)
        if key in flags:
            values[key] = True
            i += 1
        else:
            if i + 1 >= len(argv) or argv[i + 1].startswith("--"):
                raise ValueError("Trainer option requires value: " + key)
            values[key] = argv[i + 1]
            i += 2
    return values


def build_fingerprint(argv: list[str], worker: Path) -> tuple[str, dict]:
    opts = options(argv)
    required = (*INPUT_FILES[:5], "--model", "--model-id", "--revision", "--output")
    for k in required:
        if k not in opts:
            raise ValueError("Missing trainer argument: " + k)
    for key in (*INPUT_FILES, "--model", "--output", "--resume"):
        if key in opts and not Path(str(opts[key])).is_absolute():
            raise ValueError("Private input/output path must be absolute: " + key)
    model = Path(str(opts["--model"])).resolve(strict=True)
    if not model.is_dir():
        raise ValueError("Model snapshot is not a directory")
    files = {k: {"path": str(Path(str(opts[k])).resolve(strict=True)), "sha256": digest(Path(str(opts[k])))}
             for k in INPUT_FILES if k in opts}
    for path in sorted(model.rglob("*")):
        if path.is_file() and ".cache" not in path.parts and path.name != "download_receipt.json":
            files["model/" + str(path.relative_to(model))] = {"sha256": digest(path)}
    receipt = model / "download_receipt.json"
    if not receipt.is_file():
        receipt = model.parent / "download_receipt.json"
    if not receipt.is_file():
        raise ValueError("Pinned model download_receipt.json missing")
    files["model/download_receipt"] = {"sha256": digest(receipt)}
    downloaded = json.loads(receipt.read_text(encoding="utf-8"))
    if downloaded.get("model_id") != opts["--model-id"] or downloaded.get("resolved_revision") != opts["--revision"]:
        raise ValueError("Pinned model receipt identity differs from training arguments")
    if not isinstance(downloaded.get("files"), dict):
        raise ValueError("Pinned model receipt has no file inventory")
    observed_model = {name.removeprefix("model/") for name in files
                      if name.startswith("model/") and name != "model/download_receipt"}
    if set(downloaded["files"]) != observed_model:
        raise ValueError("Pinned model snapshot and download receipt inventories differ")
    for filename, entry in files.items():
        if filename.startswith("model/") and filename != "model/download_receipt":
            if downloaded["files"].get(filename.removeprefix("model/"), {}).get("sha256") != entry["sha256"]:
                raise ValueError("Pinned model file checksum differs from download receipt: " + filename)
    root = worker.parent
    for p in (worker, root / "job_guard.py", root / "curriculum.py", root / "system_prompt.txt"):
        if p.is_file():
            files["source/" + p.name] = {"sha256": digest(p)}
    if "--resume" in opts:
        resume = Path(str(opts["--resume"])).resolve(strict=True)
        if not (resume / "inventory.json").is_file():
            raise ValueError("Resume inventory missing")
        # Validate *every* full-resume payload before launching a model worker.
        # An inventory hash alone cannot establish optimizer/RNG tensor custody.
        from train_lora import verify_checkpoint
        verify_checkpoint(resume)
        for saved in sorted(resume.rglob("*")):
            if saved.is_file():
                files["resume/" + str(saved.relative_to(resume))] = {
                    "path": str(saved), "sha256": digest(saved)}
    packages = {}
    for name in ("torch", "transformers", "peft", "accelerate", "numpy", "safetensors", "filelock"):
        try:
            packages[name] = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            packages[name] = "not installed"
    environment = {"python": sys.version.split()[0], "platform": platform.platform(), "packages": packages}
    # Keep the fingerprint independent of the private output path, but bind the
    # complete trainer arguments and every input and source hash.
    payload = {"arguments": {k: v for k, v in sorted(opts.items()) if k != "--output"},
               "files": files, "environment": environment, "worker": str(worker.resolve())}
    return hashlib.sha256(canonical(payload).encode()).hexdigest(), payload


def trainer_lock(output: Path):
    """Child bypass is allowed only while its real parent holds the role lease."""
    output = Path(output).resolve()
    token = os.environ.get("WB_ART_SLM_SUPERVISOR_TOKEN")
    if token:
        lease_path = output.parent / LEASE_NAME
        try:
            lease = json.loads(lease_path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            raise ValueError("Supervisor lease is unavailable") from exc
        if (lease.get("token") != token or lease.get("supervisor_pid") != os.getppid()
                or lease.get("output") != str(output)
                or lease.get("child_pid") not in (None, os.getpid())
                or lease.get("state") not in ("starting", "running", "stopping")):
            raise ValueError("Supervisor lease identity does not match the training process")
        return contextlib.nullcontext()
    return FileLock(str(output.parent / LOCK_NAME), timeout=0)


def notify_child(proc: subprocess.Popen, force: bool) -> None:
    if os.name == "nt":
        if proc.poll() is not None:
            return
        if force:
            proc.kill()
        else:
            try:
                proc.send_signal(signal.CTRL_BREAK_EVENT)
            except OSError:
                proc.terminate()
    else:
        # A finished direct child can still have live descendants in its
        # dedicated session. Do not use poll() to skip the group signal.
        try:
            os.killpg(proc.pid, signal.SIGKILL if force else signal.SIGTERM)
        except ProcessLookupError:
            pass


def fence_owned_process_group(proc: subprocess.Popen) -> None:
    """Revoke surviving POSIX descendants before releasing the durable lease.

    Popen.poll()/wait() only cover the direct child, not another process in its
    newly created session. In particular, a parent may exit on SIGTERM while a
    descendant ignores it and continues changing files after a reported Stop.
    This is a final, bounded TERM-to-KILL sweep even if the parent has exited.
    Windows descendant-tree cleanup is *not* established by this POSIX guard.
    """
    if os.name == "nt":
        return
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    time.sleep(0.15)
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def validated_checkpoint(output: Path) -> str | None:
    pointer = output / "latest_checkpoint.json"
    if not pointer.is_file():
        return None
    try:
        from train_lora import verify_checkpoint
        data = json.loads(pointer.read_text(encoding="utf-8"))
        checkpoint = Path(data["path"]).resolve(strict=True)
        if checkpoint.parent != output.resolve():
            raise ValueError("Checkpoint points outside owned output")
        verify_checkpoint(checkpoint)
        return str(checkpoint)
    except (OSError, KeyError, ValueError):
        return None


def run(args, worker_args: list[str]) -> dict:
    parent = args.run_parent.resolve()
    source_root = Path(__file__).resolve().parents[3]
    if (source_root / "AGENTS.md").is_file() and (parent == source_root or source_root in parent.parents):
        raise ValueError("Run parent must be outside the Git source tree")
    if args.wall_seconds > 3300 or args.wall_seconds < 3:
        raise ValueError("Whole-process deadline must be 3..3300 seconds, strictly below an hour")
    if args.save_margin_seconds < 1 or args.save_margin_seconds >= args.wall_seconds:
        raise ValueError("Invalid graceful-save margin")
    worker = args.worker_script.resolve(strict=True)
    is_evaluation = worker.name == "evaluate_model.py"
    opts = options(worker_args)
    if not is_evaluation and "--max-seconds" in opts and int(str(opts["--max-seconds"])) > args.wall_seconds - args.save_margin_seconds:
        raise ValueError("Trainer optimizer timeout must fit before the graceful-save margin")
    if opts.get("--preflight-only"):
        raise ValueError("Preflight is not a training job; run train_lora.py --preflight-only directly")
    output = Path(str(opts.get("--output", ""))).resolve()
    if output.parent != parent or output == parent:
        raise ValueError("Output must be a direct child directory of the shared run parent")
    if not worker.is_file():
        raise ValueError("Worker script missing")
    parent.mkdir(parents=True, exist_ok=True)
    # Same lock protects the trainer's native direct entrypoint and this wrapper.
    with FileLock(str(parent / LOCK_NAME), timeout=0):
        # The OS lock vanishes if a supervisor crashes, but its child may
        # survive. Never replace an unfinished durable lease on that basis.
        # An operator must inspect/stop orphaned workers and reconcile the
        # retained ledger before another local candidate may be launched.
        previous_lease_path = parent / LEASE_NAME
        if previous_lease_path.exists():
            try:
                previous_lease = json.loads(previous_lease_path.read_text(encoding="utf-8"))
            except (OSError, ValueError) as exc:
                raise ValueError("Unparseable durable role lease; manual recovery required") from exc
            terminal = {"completed", "failed", "incomplete", "stopped_early", "deadline_killed"}
            if not isinstance(previous_lease, dict) or previous_lease.get("state") not in terminal:
                raise FileExistsError("Unfinished durable role lease; inspect possible orphaned model worker")
        if is_evaluation:
            from evaluation_guard import evaluation_fingerprint
            fingerprint, inventory = evaluation_fingerprint(worker_args, worker)
        else:
            fingerprint, inventory = build_fingerprint(worker_args, worker)
        for entry in parent.glob("*/" + START_NAME):
            previous = json.loads(entry.read_text(encoding="utf-8"))
            if previous.get("fingerprint") == fingerprint:
                raise FileExistsError("Identical fingerprint already attempted at " + str(entry.parent))
        if output.exists() and any(output.iterdir()):
            raise FileExistsError("Refusing to reuse a nonempty run output: " + str(output))
        output.mkdir(exist_ok=True)
        started = time.monotonic()
        start_unix = time.time()
        token = uuid.uuid4().hex
        claim = {"version": 1, "kind": "evaluation" if is_evaluation else "training",
                 "fingerprint": fingerprint, "inputs": inventory,
                 "started_at_unix": start_unix, "wall_seconds": args.wall_seconds,
                 "save_margin_seconds": args.save_margin_seconds, "output": str(output)}
        atomic_json(output / START_NAME, claim)
        lease = {"version": 1, "kind": "evaluation" if is_evaluation else "training",
                 "token": token, "fingerprint": fingerprint,
                 "supervisor_pid": os.getpid(), "child_pid": None, "output": str(output),
                 "started_at_unix": start_unix, "heartbeat_unix": start_unix, "state": "starting"}
        atomic_json(parent / LEASE_NAME, lease)
        env = dict(os.environ, WB_ART_SLM_SUPERVISOR_TOKEN=token)
        proc = None
        soft_stopped = False
        hard_killed = False
        error = None
        try:
            proc = subprocess.Popen([sys.executable, str(worker), *worker_args], cwd=str(worker.parent), env=env,
                                    start_new_session=os.name != "nt",
                                    creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0)
            lease["child_pid"] = proc.pid
            lease["state"] = "running"
            while proc.poll() is None:
                elapsed = time.monotonic() - started
                if elapsed >= args.wall_seconds and not hard_killed:
                    notify_child(proc, force=True)
                    hard_killed = True
                    lease["state"] = "killing"
                elif (INTERRUPTED or elapsed >= args.wall_seconds - args.save_margin_seconds) and not soft_stopped:
                    notify_child(proc, force=False)
                    soft_stopped = True
                    lease["state"] = "stopping"
                lease["heartbeat_unix"] = time.time()
                atomic_json(parent / LEASE_NAME, lease)
                time.sleep(min(0.5, max(0.01, args.wall_seconds - elapsed)) if not hard_killed else 0.05)
            return_code = proc.returncode
        except BaseException as exc:
            error = repr(exc)
            if proc is not None and proc.poll() is None:
                notify_child(proc, force=True)
                proc.wait(timeout=3)
            return_code = proc.returncode if proc is not None else None
        finally:
            # Do not mark a job terminal (and permit another run) while a
            # same-session descendant can still outlive its direct parent.
            # This fence also runs after a clean parent exit or interrupted
            # supervisor, not only after a whole-process timeout.
            if proc is not None:
                fence_owned_process_group(proc)
        if is_evaluation:
            from evaluation_guard import verified_evaluation
            evidence = verified_evaluation(output, worker_args)
            # A model/adapter/compiler changed during inference is not the
            # preflight-fingerprinted candidate, even if JSON counts happen to fit.
            custody_error = None
            try:
                final_fingerprint, _ = evaluation_fingerprint(worker_args, worker)
                if final_fingerprint != fingerprint:
                    custody_error = "Evaluation input/source fingerprint changed during execution"
            except (OSError, ValueError, KeyError, TypeError) as exc:
                custody_error = "Evaluation custody recheck failed: " + repr(exc)
            if custody_error:
                evidence = None
            status = ("deadline_killed" if hard_killed else "failed" if error or custody_error or return_code != 0
                      else "completed" if evidence else "incomplete")
            result = {"kind": "evaluation", "fingerprint": fingerprint, "status": status,
                      "return_code": return_code, "whole_process_seconds": time.monotonic() - started,
                      "soft_stop_sent": soft_stopped, "hard_kill_sent": hard_killed,
                      "evidence": evidence, "error": error or custody_error, "ended_at_unix": time.time()}
            atomic_json(output / RESULT_NAME, result)
            lease.update({"state": status, "heartbeat_unix": time.time(),
                          "ended_at_unix": time.time(), "result_path": str(output / RESULT_NAME)})
            atomic_json(parent / LEASE_NAME, lease)
            return result
        checkpoint = validated_checkpoint(output)
        summary_path = output / "summary.json"
        if summary_path.is_file():
            try:
                summary = json.loads(summary_path.read_text(encoding="utf-8"))
                completed_steps = summary.get("global_step")
            except (ValueError, OSError):
                completed_steps = None
        else:
            completed_steps = None
        # A valid checkpoint cannot qualify a candidate whose inputs changed
        # while its optimizer was running, even if the child exited cleanly.
        custody_error = None
        try:
            final_fingerprint, _ = build_fingerprint(worker_args, worker)
            if final_fingerprint != fingerprint:
                custody_error = "Training input/source fingerprint changed during execution"
        except (OSError, ValueError, KeyError, TypeError) as exc:
            custody_error = "Training custody recheck failed: " + repr(exc)
        target_steps = int(str(opts.get("--steps", 25)))
        status = ("deadline_killed" if hard_killed else "failed" if error or custody_error or return_code != 0
                  else "completed" if checkpoint and completed_steps == target_steps
                  else "stopped_early" if checkpoint else "incomplete")
        result = {"fingerprint": fingerprint, "status": status, "return_code": return_code,
                  "whole_process_seconds": time.monotonic() - started, "soft_stop_sent": soft_stopped,
                  "hard_kill_sent": hard_killed, "target_steps": target_steps,
                  "observed_steps": completed_steps, "verified_checkpoint": checkpoint,
                  "error": error or custody_error, "ended_at_unix": time.time()}
        atomic_json(output / RESULT_NAME, result)
        lease.update({"state": status, "heartbeat_unix": time.time(), "ended_at_unix": time.time(), "result_path": str(output / RESULT_NAME)})
        atomic_json(parent / LEASE_NAME, lease)
        return result


INTERRUPTED = False


def request_supervisor_stop(signum, frame) -> None:
    global INTERRUPTED
    INTERRUPTED = True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-parent", type=Path, required=True)
    parser.add_argument("--wall-seconds", type=int, default=3300)
    parser.add_argument("--save-margin-seconds", type=int, default=300)
    parser.add_argument("--worker-script", type=Path, default=Path(__file__).with_name("train_lora.py"))
    args, rest = parser.parse_known_args()
    if rest and rest[0] == "--":
        rest = rest[1:]
    signal.signal(signal.SIGINT, request_supervisor_stop)
    signal.signal(signal.SIGTERM, request_supervisor_stop)
    result = run(args, rest)
    print(canonical(result), flush=True)
    return 0 if result["status"] == "completed" else 2


if __name__ == "__main__":
    raise SystemExit(main())
