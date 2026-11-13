"""Custody and completed-output checks for supervised local SLM evaluation.

No model imports, training, network access or final-split access. Heavy evaluation
must share the training supervisor's run-parent file lock and durable role lease.
"""
from __future__ import annotations

import hashlib
import importlib.metadata
import json
from pathlib import Path
import platform
import re
import sys

from job_guard import canonical, digest, options

ALLOWED = frozenset({
    "--model", "--adapter", "--dev", "--admission", "--corpus-manifest",
    "--compiler", "--output", "--eval-count", "--suite", "--threads",
    "--max-new-tokens", "--max-length", "--device", "--trust-remote-code",
})
REQUIRED = frozenset({"--model", "--dev", "--admission", "--corpus-manifest", "--compiler", "--output"})
INPUTS = ("--dev", "--admission", "--corpus-manifest", "--compiler")
PACKAGES = ("torch", "transformers", "peft", "accelerate", "numpy", "safetensors", "filelock")


def evaluation_fingerprint(argv: list[str], worker: Path) -> tuple[str, dict]:
    """Bind one heavy attempt to exact model/adapter/corpus/template/code bytes."""
    opts = options(argv)
    if missing := REQUIRED - opts.keys():
        raise ValueError("Missing evaluation arguments: " + ", ".join(sorted(missing)))
    if extra := opts.keys() - ALLOWED:
        raise ValueError("Unknown evaluation arguments: " + ", ".join(sorted(extra)))
    for key in (*INPUTS, "--model", "--adapter", "--output"):
        if key in opts and not Path(str(opts[key])).is_absolute():
            raise ValueError("Private evaluation path must be absolute: " + key)
    for key in ("--eval-count", "--threads", "--max-new-tokens", "--max-length"):
        if key in opts and (not str(opts[key]).isdigit() or int(str(opts[key])) < 1):
            raise ValueError("Invalid positive evaluation value: " + key)
    if opts.get("--suite", "dev") not in ("dev", "keywords"):
        raise ValueError("Unsupported evaluation suite")

    model = Path(str(opts["--model"])).resolve(strict=True)
    if not model.is_dir():
        raise ValueError("Pinned model snapshot must be a directory")
    files = {}
    for key in INPUTS:
        path = Path(str(opts[key])).resolve(strict=True)
        if not path.is_file():
            raise ValueError("Evaluation input is not a file: " + key)
        files[key] = {"path": str(path), "sha256": digest(path)}

    receipt = model / "download_receipt.json"
    if not receipt.is_file():
        receipt = model.parent / "download_receipt.json"
    downloaded = json.loads(receipt.read_text(encoding="utf-8"))
    if not re.fullmatch(r"[0-9a-f]{40}", downloaded.get("resolved_revision", "")):
        raise ValueError("Model revision must be the exact resolved commit")
    if not downloaded.get("model_id") or not isinstance(downloaded.get("files"), dict):
        raise ValueError("Pinned model receipt is incomplete")
    files["model/download_receipt"] = {"path": str(receipt), "sha256": digest(receipt)}
    adapter_model_files = {}
    for path in sorted(model.rglob("*")):
        if not path.is_file() or ".cache" in path.parts or path == receipt:
            continue
        relative = str(path.relative_to(model))
        hash_value = digest(path)
        if downloaded["files"].get(relative, {}).get("sha256") != hash_value:
            raise ValueError("Pinned model file checksum differs from receipt: " + relative)
        files["model/" + relative] = {"sha256": hash_value}
        if path.suffix in (".safetensors", ".json", ".jinja", ".py"):
            adapter_model_files[relative] = hash_value
    if set(downloaded["files"]) != {k.removeprefix("model/") for k in files if k.startswith("model/") and k != "model/download_receipt"}:
        raise ValueError("Model snapshot and pinned receipt file inventory differ")

    if "--adapter" in opts:
        adapter = Path(str(opts["--adapter"])).resolve(strict=True)
        for filename in ("adapter_model.safetensors", "adapter_config.json", "inference_contract.json"):
            if not (adapter / filename).is_file():
                raise ValueError("Adapter missing required file: " + filename)
        contract = json.loads((adapter / "inference_contract.json").read_text(encoding="utf-8"))
        for key, expected in (("model_id", downloaded["model_id"]),
                              ("revision", downloaded["resolved_revision"]),
                              ("compiler_sha256", files["--compiler"]["sha256"]),
                              ("model_files", adapter_model_files)):
            if contract.get(key) != expected:
                raise ValueError("Adapter and model/compiler contract mismatch: " + key)
        for path in sorted(adapter.rglob("*")):
            if path.is_file():
                files["adapter/" + str(path.relative_to(adapter))] = {"sha256": digest(path)}

    source = worker.parent
    for path in (worker, source / "evaluation_guard.py", source / "job_guard.py",
                 source / "train_lora.py", source / "system_prompt.txt"):
        if not path.is_file():
            raise ValueError("Missing evaluation source contract: " + str(path))
        files["source/" + path.name] = {"sha256": digest(path)}
    packages = {}
    for package in PACKAGES:
        try:
            packages[package] = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:
            packages[package] = "not installed"
    payload = {
        "kind": "evaluation", "arguments": {k: v for k, v in sorted(opts.items()) if k != "--output"},
        "files": files,
        "model_identity": {"id": downloaded["model_id"], "revision": downloaded["resolved_revision"],
                           "subfolder": downloaded.get("subfolder"), "profile": downloaded.get("profile")},
        "environment": {"python": sys.version.split()[0], "platform": platform.platform(), "packages": packages},
        "worker": str(worker.resolve(strict=True)),
    }
    return hashlib.sha256(canonical(payload).encode("utf-8")).hexdigest(), payload



def raw_record_consistent(record: dict, max_new_tokens: int) -> bool:
    """Independently check saved raw text and EOS/semantic claims, never repair it.

    Compiler execution and actual native mutation are still separate gates.
    """
    from train_lora import strict_json

    flags = ("json_valid", "program_valid", "first_pass_accepted",
             "theme_field_correct", "primary_motif_correct",
             "motif_layout_exact", "exact_target", "eos_emitted",
             "eos_terminated")
    if any(type(record.get(flag, False)) is not bool for flag in flags):
        return False
    if (not isinstance(record.get("completion"), str)
            or not isinstance(record.get("expected_completion"), str)
            or type(record.get("output_tokens")) is not int
            or not 0 <= record["output_tokens"] <= max_new_tokens
            or record["eos_terminated"] and not record["eos_emitted"]
            or record["eos_terminated"] and record["output_tokens"] == 0):
        return False
    try:
        value = strict_json(record["completion"])
        parsed = True
    except (ValueError, TypeError):
        value, parsed = None, False
    if record["json_valid"] != parsed:
        return False
    try:
        expected = strict_json(record["expected_completion"])
    except (ValueError, TypeError):
        return False
    if record["exact_target"] != (parsed and value == expected):
        return False
    theme_matches = parsed and isinstance(value, dict) and value.get("theme") == record.get("theme")
    if record.get("theme_field_correct", False) != theme_matches:
        return False
    valid = record["program_valid"]
    if valid:
        if (not parsed or not isinstance(value, dict)
                or record.get("program") != value
                or type(record.get("compiled_operations")) is not int
                or record["compiled_operations"] <= 0):
            return False
        try:
            predicted_layers, target_layers = value["layers"], expected["layers"]
            motif_matches = predicted_layers[0]["motif"] == target_layers[0]["motif"]
            structure_matches = (
                [(layer["motif"], layer["layout"]) for layer in predicted_layers]
                == [(layer["motif"], layer["layout"]) for layer in target_layers]
            )
        except (KeyError, TypeError, IndexError):
            return False
    else:
        if "program" in record or "compiled_operations" in record:
            return False
        motif_matches = structure_matches = False
    if (record.get("primary_motif_correct", False) != motif_matches
            or record.get("motif_layout_exact", False) != structure_matches):
        return False
    return record["first_pass_accepted"] == (
        valid and record["eos_terminated"] and record["output_tokens"] > 0
    )


def verified_evaluation(output: Path, argv: list[str]) -> dict | None:
    """Distinguish complete strict raw evaluation from partial untrusted output.

    Does not repair predictions or consider repaired/native/visual success.
    """
    output = Path(output)
    paths = {name: output / name for name in ("run_config.json", "predictions.json", "summary.json")}
    if any(not path.is_file() for path in paths.values()):
        return None
    try:
        config = json.loads(paths["run_config.json"].read_text(encoding="utf-8"))
        predictions = json.loads(paths["predictions.json"].read_text(encoding="utf-8"))
        summary = json.loads(paths["summary.json"].read_text(encoding="utf-8"))
        metrics = summary["metrics"]
        records = predictions["records"]
        opts = options(argv)
        if (summary["config"] != config or predictions["summary"] != metrics
                or not isinstance(records, list) or not records):
            return None
        if config["suite"] != opts.get("--suite", "dev") or config["training_executed"] is not False:
            return None
        receipt_path = Path(str(opts["--model"])) / "download_receipt.json"
        if not receipt_path.is_file():
            receipt_path = Path(str(opts["--model"])).parent / "download_receipt.json"
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        expected = {
            "model_id": receipt["model_id"], "revision": receipt["resolved_revision"],
            "model_profile": receipt.get("profile"), "model_subfolder": receipt.get("subfolder"),
            "compiler_sha256": digest(Path(str(opts["--compiler"]))),
            "dev_sha256": digest(Path(str(opts["--dev"]))),
            "admission_sha256": digest(Path(str(opts["--admission"]))),
            "adapter_sha256": (digest(Path(str(opts["--adapter"])) / "adapter_model.safetensors")
                               if "--adapter" in opts else None),
            "max_new_tokens": int(str(opts.get("--max-new-tokens", "256"))),
            "decoding": "greedy, unconstrained, no repair",
        }
        if any(config.get(key) != value for key, value in expected.items()):
            return None
        if metrics["count"] != len(records) or len({r["id"] for r in records}) != len(records):
            return None
        target = int(str(opts.get("--eval-count", "24")))
        if config["suite"] == "dev":
            dev_rows = sum(1 for line in Path(str(opts["--dev"])).read_text(encoding="utf-8").splitlines() if line.strip())
            target = min(target, dev_rows)
        else:
            target = min(target, 12)
        if len(records) != target:
            return None
        if not all(raw_record_consistent(record, int(str(opts.get("--max-new-tokens", "256")))) for record in records):
            return None
        for key in ("json_valid", "program_valid", "first_pass_accepted", "theme_field_correct",
                    "primary_motif_correct", "motif_layout_exact", "exact_target"):
            if metrics[key] != sum(bool(r.get(key, False)) for r in records):
                return None
        return {"observed_requests": len(records), "raw_predictions_sha256": digest(paths["predictions.json"]),
                "summary_sha256": digest(paths["summary.json"]),
                "raw_first_pass_accepted": metrics["first_pass_accepted"],
                "native_execution": False, "visual_acceptance": False}
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        return None
