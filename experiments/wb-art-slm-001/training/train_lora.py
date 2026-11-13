#!/usr/bin/env python3
"""Bounded, completion-only LoRA training for the WB-ART-SLM-001 experiment.

Artifacts belong outside the source repository. The input is model-neutral JSONL
with id, prompt, completion, group_id, theme and split. No target is truncated.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib.metadata
import json
import math
import os
from pathlib import Path
import random
import re
import shutil
import signal
import sys
import time

from curriculum import POLICIES, epoch_indices

TARGET_SUFFIXES = ["q_proj", "k_proj", "v_proj", "o_proj", "in_proj", "out_proj", "w1", "w2", "w3", "gate_proj", "up_proj", "down_proj"]
STOP_REQUESTED = False


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


def strict_json(text):
    def unique_keys(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError("duplicate JSON field: " + key)
            value[key] = item
        return value

    def reject_constant(value):
        raise ValueError("non-finite JSON constant: " + value)

    return json.loads(text, object_pairs_hook=unique_keys, parse_constant=reject_constant)


def decode_generation(tokenizer, tokens):
    # Only remove the actual stopping EOS. Preserve any other emitted special
    # tokens so they cause a strict parse failure rather than a hidden repair.
    content = tokens[:-1] if tokens and tokens[-1] == tokenizer.eos_token_id else tokens
    return tokenizer.decode(content, skip_special_tokens=False)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temp, path)


def verify_checkpoint(path):
    path = Path(path)
    inventory = json.loads((path / "inventory.json").read_text())
    expected = {str(p.relative_to(path)) for p in path.rglob("*") if p.is_file() and p != path / "inventory.json"}
    if set(inventory) != expected:
        raise ValueError("Checkpoint file inventory differs from saved receipt")
    required = {"adapter/adapter_model.safetensors", "adapter/adapter_config.json", "adapter/inference_contract.json", "training_state.pt", "receipt.json"}
    if not required <= inventory.keys():
        raise ValueError("Checkpoint lacks required full-resume artifacts")
    for relative, evidence in inventory.items():
        file = path / relative
        if file.stat().st_size != evidence["bytes"] or sha256_file(file) != evidence["sha256"]:
            raise ValueError("Checkpoint custody mismatch: " + relative)


def read_rows(path, split):
    result = []
    for line_number, line in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        row = json.loads(line)
        for key in ("id", "prompt", "completion", "group_id", "theme", "split"):
            if key not in row:
                raise ValueError(f"{path}:{line_number}: missing {key}")
        if not isinstance(row["prompt"], str) or not isinstance(row["completion"], str):
            raise ValueError("prompt and completion must be text")
        if row["split"] != split:
            raise ValueError(f"{path}:{line_number}: expected split {split}")
        if row.get("native_qualified") is not True:
            raise ValueError(f"{row['id']}: native admission is required")
        receipt = row.get("native_receipt", {})
        if (receipt.get("success") is not True
                or not row.get("native_case_id")
                or receipt.get("id") != row.get("native_case_id")
                or not re.fullmatch(r"[a-f0-9]{64}", row.get("operations_sha256", ""))
                or receipt.get("operations_sha256") != row.get("operations_sha256")
                or receipt.get("outside_focus_violations") != 0
                or type(receipt.get("acknowledged_cells")) is not int
                or receipt.get("acknowledged_cells", 0) <= 0
                or not re.fullmatch(r"[a-f0-9]{64}", receipt.get("image_sha256", ""))
                or not re.fullmatch(r"[a-f0-9]{64}", receipt.get("readback_sha256", ""))
                or row.get("visual_review") not in ("case-inspected", "template-group-pilot-admitted")):
            raise ValueError(f"{row['id']}: incomplete native receipt or review admission")
        value = strict_json(row["completion"])
        if hashlib.sha256(canonical(value).encode()).hexdigest() != row.get("program_sha256"):
            raise ValueError(f"{row['id']}: completion differs from admitted program")
        result.append(row)
    if not result or len({x["id"] for x in result}) != len(result):
        raise ValueError("empty corpus or duplicate ids")
    return result


def validate_admission(admission_path, paths, rows_by_split, compiler_path, manifest_path):
    admission = json.loads(Path(admission_path).read_text())
    if admission.get("state") not in ("partial-native-pilot", "native-qualified-bootstrap"):
        raise ValueError("Corpus is not admitted for training")
    for split, path in paths.items():
        if admission.get("file_sha256", {}).get(split) != sha256_file(path):
            raise ValueError(f"Admitted {split} file hash mismatch")
        if admission.get("split_counts", {}).get(split) != len(rows_by_split[split]):
            raise ValueError(f"Admitted {split} count mismatch")
        for row in rows_by_split[split]:
            if row.get("native_runtime") != admission.get("runtime"):
                raise ValueError(f"{row['id']}: native runtime provenance mismatch")
    for field in ("receipts_sha256", "review_sha256"):
        if not re.fullmatch(r"[a-f0-9]{64}", admission.get(field, "")):
            raise ValueError("Missing admission evidence hash: " + field)
    manifest = json.loads(Path(manifest_path).read_text())
    if admission.get("corpus_manifest_sha256") != sha256_file(manifest_path):
        raise ValueError("Corpus manifest differs from admission evidence")
    if admission.get("compiler_sha256") != sha256_file(compiler_path):
        raise ValueError("Admission compiler identity mismatch")
    if sha256_file(compiler_path) != manifest.get("compiler_sha256"):
        raise ValueError("Compiler differs from the corpus admission manifest")
    return admission


def balanced_rows(rows, limit):
    """Deterministic round-robin over themes; never select an ordered prefix."""
    buckets = {}
    for row in rows:
        buckets.setdefault(row["theme"], []).append(row)
    for values in buckets.values():
        values.sort(key=lambda r: hashlib.sha256(r["id"].encode()).hexdigest())
    chosen = []
    for index in range(max(map(len, buckets.values()), default=0)):
        for theme in sorted(buckets):
            if index < len(buckets[theme]) and len(chosen) < limit:
                chosen.append(buckets[theme][index])
    return chosen


def split_guard(train, dev):
    overlap = {r["group_id"] for r in train} & {r["group_id"] for r in dev}
    if overlap:
        raise ValueError(f"train/dev family overlap: {sorted(overlap)[:5]}")
    overlap_ids = {r["id"] for r in train} & {r["id"] for r in dev}
    if overlap_ids:
        raise ValueError("train/dev id overlap")


def messages_for(row, system):
    return ([{"role": "system", "content": system}] if system else []) + [{"role": "user", "content": row["prompt"]}]


def encode_row(tokenizer, row, system, max_length):
    messages = messages_for(row, system)
    prefix = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True, enable_thinking=False)
    full = tokenizer.apply_chat_template(messages + [{"role": "assistant", "content": row["completion"]}], tokenize=False, add_generation_prompt=False, enable_thinking=False)
    if not full.startswith(prefix):
        raise ValueError(f"{row['id']}: chat template prefix is not stable")
    input_ids = tokenizer.encode(full, add_special_tokens=False)
    prefix_ids = tokenizer.encode(prefix, add_special_tokens=False)
    boundary = 0
    for left, right in zip(input_ids, prefix_ids):
        if left != right:
            break
        boundary += 1
    # A BPE token can span the final prompt newline and the first answer byte.
    # Supervise that boundary token; do not accidentally mask the first JSON byte.
    if len(prefix_ids) - boundary > 2:
        raise ValueError(f"{row['id']}: unstable token prefix boundary")
    if len(input_ids) > max_length:
        raise ValueError(f"{row['id']}: {len(input_ids)} tokens exceeds {max_length}; target will NOT be truncated")
    labels = [-100] * boundary + input_ids[boundary:]
    if boundary == len(input_ids) or tokenizer.eos_token_id not in input_ids[boundary:]:
        raise ValueError(f"{row['id']}: no completion or supervised EOS")
    return {"input_ids": input_ids, "labels": labels, "prefix_ids": prefix_ids, "boundary": boundary, "id": row["id"], "target_tokens": len(input_ids) - boundary}


def encode_corpus(tokenizer, rows, system, max_length):
    return [encode_row(tokenizer, r, system, max_length) for r in rows]


def fingerprint_frozen(model):
    """Hash every frozen parameter byte (not just a sample)."""
    import torch
    h = hashlib.sha256()
    for name, parameter in sorted(model.named_parameters()):
        if parameter.requires_grad:
            continue
        h.update(name.encode())
        h.update(str(tuple(parameter.shape)).encode())
        h.update(parameter.detach().cpu().contiguous().view(torch.uint8).numpy().tobytes())
    return h.hexdigest()


def finite_gradients(model):
    import torch
    grads = [p.grad for p in model.parameters() if p.requires_grad and p.grad is not None]
    return bool(grads) and all(torch.isfinite(g).all().item() for g in grads)


def choose_device_dtype(device_name):
    import torch
    if device_name == "auto":
        device_name = "cuda" if torch.cuda.is_available() else "cpu"
    device = torch.device(device_name)
    # CPU uses FP32 deliberately. CUDA capability is checked, never assumed.
    dtype = torch.float32
    if device.type == "cuda":
        dtype = torch.bfloat16 if torch.cuda.is_bf16_supported(including_emulation=False) else torch.float16
    return device, dtype


def evaluate(model, tokenizer, rows, system, device, max_new_tokens, limit, output_path, compiler_path=None):
    import torch
    compiler = None
    if compiler_path:
        import importlib.util
        spec = importlib.util.spec_from_file_location("wb_pattern_evaluator_compiler", compiler_path)
        compiler = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = compiler
        spec.loader.exec_module(compiler)
    outputs = []
    was_training = model.training
    model.eval()
    for row in balanced_rows(rows, limit):
        prefix = tokenizer.apply_chat_template(messages_for(row, system), tokenize=False, add_generation_prompt=True, enable_thinking=False)
        inputs = tokenizer(prefix, return_tensors="pt", add_special_tokens=False).to(device)
        t0 = time.monotonic()
        with torch.no_grad():
            result = model.generate(**inputs, do_sample=False, max_new_tokens=max_new_tokens, pad_token_id=tokenizer.pad_token_id, eos_token_id=tokenizer.eos_token_id, use_cache=True)
        tokens = result[0, inputs["input_ids"].shape[-1]:].tolist()
        text = decode_generation(tokenizer, tokens)
        record = {"id": row["id"], "theme": row["theme"], "group_id": row["group_id"], "prompt": row["prompt"], "completion": text, "expected_completion": row["completion"], "seed": int(row.get("seed", 0)), "output_tokens": len(tokens), "elapsed_seconds": time.monotonic() - t0, "eos_emitted": tokenizer.eos_token_id in tokens, "json_valid": False, "program_valid": False, "exact_target": False}
        try:
            value = strict_json(text)
            record["json_valid"] = True
            record["exact_target"] = value == json.loads(row["completion"])
            record["theme_field_correct"] = isinstance(value, dict) and value.get("theme") == row["theme"]
            if compiler:
                compiler.validate_program(value)
                operations = compiler.compile_program(value, 96, 96, seed=int(row.get("seed", 0)))
                record["program_valid"] = True
                record["compiled_operations"] = len(operations)
                record["program"] = value
                expected = strict_json(row["completion"])
                record["primary_motif_correct"] = value["layers"][0]["motif"] == expected["layers"][0]["motif"]
                record["motif_layout_exact"] = [(l["motif"], l["layout"]) for l in value["layers"]] == [(l["motif"], l["layout"]) for l in expected["layers"]]
        except Exception as exc:
            record["error"] = f"{type(exc).__name__}: {str(exc)[:240]}"
        record["first_pass_accepted"] = record["program_valid"] and bool(tokens) and tokens[-1] == tokenizer.eos_token_id
        if record["program_valid"] and not record["first_pass_accepted"]:
            record["error"] = "Unterminated generation: stopping EOS not emitted"
        outputs.append(record)
        print(canonical({"event": "eval", "id": row["id"], "json_valid": record["json_valid"], "program_valid": record["program_valid"], "seconds": record["elapsed_seconds"]}), flush=True)
        write_json(output_path, {"records": outputs})
    if was_training:
        model.train()
    summary = {"count": len(outputs), "json_valid": sum(r["json_valid"] for r in outputs), "program_valid": sum(r["program_valid"] for r in outputs), "first_pass_accepted": sum(r["first_pass_accepted"] for r in outputs), "theme_field_correct": sum(r.get("theme_field_correct", False) for r in outputs), "primary_motif_correct": sum(r.get("primary_motif_correct", False) for r in outputs), "motif_layout_exact": sum(r.get("motif_layout_exact", False) for r in outputs), "exact_target": sum(r["exact_target"] for r in outputs), "output_tokens": sum(r["output_tokens"] for r in outputs), "seconds": sum(r["elapsed_seconds"] for r in outputs), "theme_counts": {t: sum(r["theme"] == t for r in outputs) for t in sorted({r["theme"] for r in outputs})}, "selection": "sha256-id within theme, sorted-theme round robin", "native_execution": "NOT EXECUTED BY TRAINER", "visual_theme_assessment": "NOT PERFORMED BY TRAINER; theme field and motif checks are symbolic only", "decoding": "greedy, unconstrained, no repair"}
    write_json(output_path, {"summary": summary, "records": outputs})
    return summary


def save_checkpoint(model, tokenizer, optimizer, scheduler, scaler, output, step, cursor, config, frozen_hash, history, start_time):
    import numpy as np
    import torch
    output = Path(output)
    checkpoint = output / f"checkpoint-{step:06d}"
    temporary = output / f".checkpoint-{step:06d}.writing"
    if temporary.exists():
        shutil.rmtree(temporary)
    temporary.mkdir(parents=True)
    model.save_pretrained(temporary / "adapter", safe_serialization=True)
    tokenizer.save_pretrained(temporary / "adapter")
    write_json(temporary / "adapter" / "inference_contract.json", {k: config[k] for k in ("model_id", "revision", "system", "system_sha256", "chat_template_sha256", "max_new_tokens", "max_length", "trust_remote_code", "model_files", "compiler_sha256", "admission_sha256")})
    for license_path in Path(config["model"]).glob("LICENSE*"):
        if license_path.is_file():
            shutil.copy2(license_path, temporary / "adapter" / ("BASE_MODEL_" + license_path.name))
    state = {"optimizer": optimizer.state_dict(), "scheduler": scheduler.state_dict(), "scaler": scaler.state_dict(), "global_step": step, "sample_cursor": cursor, "python_rng": random.getstate(), "numpy_rng": np.random.get_state(), "torch_rng": torch.get_rng_state(), "cuda_rng": torch.cuda.get_rng_state_all() if torch.cuda.is_available() else None, "config": config, "frozen_base_sha256": frozen_hash, "history": history, "elapsed_seconds": time.monotonic() - start_time}
    torch.save(state, temporary / "training_state.pt")
    write_json(temporary / "receipt.json", {k: state[k] for k in ["global_step", "sample_cursor", "config", "frozen_base_sha256", "history", "elapsed_seconds"]})
    inventory = {str(p.relative_to(temporary)): {"sha256": sha256_file(p), "bytes": p.stat().st_size} for p in sorted(temporary.rglob("*")) if p.is_file()}
    write_json(temporary / "inventory.json", inventory)
    if checkpoint.exists():
        raise FileExistsError(f"Refusing to overwrite checkpoint: {checkpoint}")
    os.replace(temporary, checkpoint)
    write_json(output / "latest_checkpoint.json", {"path": str(checkpoint), "global_step": step, "sample_cursor": cursor})
    return checkpoint


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--train", required=True)
    parser.add_argument("--dev", required=True)
    parser.add_argument("--admission", required=True, help="Native admission JSON with exact train/dev file hashes")
    parser.add_argument("--corpus-manifest", required=True)
    parser.add_argument("--model", required=True, help="Pinned local model snapshot directory")
    parser.add_argument("--model-id", required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--resume")
    parser.add_argument("--system-file")
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--trust-remote-code", action="store_true", help="Execute only the explicitly pinned local model's custom architecture code")
    parser.add_argument("--steps", type=int, default=25, help="Total global optimizer steps, including resumed steps")
    parser.add_argument("--max-seconds", type=int, default=1800)
    parser.add_argument("--max-length", type=int, default=1024)
    parser.add_argument("--max-new-tokens", type=int, default=384)
    parser.add_argument("--accumulation", type=int, default=1)
    parser.add_argument("--rank", type=int, default=16)
    parser.add_argument("--alpha", type=int, default=32)
    parser.add_argument("--dropout", type=float, default=0.05)
    parser.add_argument("--learning-rate", type=float, default=0.0005)
    parser.add_argument("--seed", type=int, default=731)
    parser.add_argument("--curriculum", choices=POLICIES, default="shuffled-v1", help="Versioned train-only sampler; new policies require a fresh candidate checkpoint")
    parser.add_argument("--threads", type=int, default=3)
    parser.add_argument("--device", default="auto")
    parser.add_argument("--eval-count", type=int, default=24)
    parser.add_argument("--skip-baseline", action="store_true")
    parser.add_argument("--skip-final-eval", action="store_true")
    parser.add_argument("--preflight-only", action="store_true")
    parser.add_argument("--checkpoint-every", type=int, default=25)
    parser.add_argument("--gradient-checkpointing", action="store_true")
    args = parser.parse_args()
    if args.steps < 1 or args.accumulation < 1 or args.threads < 1:
        parser.error("steps, accumulation and threads must be positive")

    os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
    os.environ.setdefault("CUBLAS_WORKSPACE_CONFIG", ":4096:8")
    import numpy as np
    import torch
    import peft
    from peft import LoraConfig, PeftModel, get_peft_model
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from filelock import FileLock

    torch.set_num_threads(args.threads)
    torch.set_num_interop_threads(1)
    torch.use_deterministic_algorithms(True)
    torch.backends.cuda.matmul.allow_tf32 = False
    torch.backends.cudnn.allow_tf32 = False
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    device, dtype = choose_device_dtype(args.device)
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    lock = FileLock(str(output.parent / "wb-art-slm-training.lock"), timeout=0)
    with lock:
        if args.resume:
            verify_checkpoint(args.resume)
            receipt = json.loads((Path(args.resume) / "receipt.json").read_text(encoding="utf-8"))
            previous_curriculum = receipt["config"].get("curriculum", "shuffled-v1")
            if args.curriculum != previous_curriculum:
                raise ValueError(
                    f"Resume curriculum mismatch before loading the model: "
                    f"{previous_curriculum} != {args.curriculum}"
                )
        write_json(output / "job.json", {"pid": os.getpid(), "started_at_unix": time.time(), "device": str(device), "state": "running"})
        train_rows, dev_rows = read_rows(args.train, "train"), read_rows(args.dev, "dev")
        admission = validate_admission(args.admission, {"train": args.train, "dev": args.dev}, {"train": train_rows, "dev": dev_rows}, args.compiler, args.corpus_manifest)
        split_guard(train_rows, dev_rows)
        system_file = Path(args.system_file) if args.system_file else Path(__file__).with_name("system_prompt.txt")
        system = system_file.read_text().strip()
        tokenizer = AutoTokenizer.from_pretrained(args.model, local_files_only=True, trust_remote_code=args.trust_remote_code)
        if tokenizer.pad_token_id is None:
            tokenizer.pad_token = tokenizer.eos_token
        # Validate a changed curriculum before allocating base model memory.
        epoch_indices(train_rows, args.seed, 0, args.curriculum)
        encoded = encode_corpus(tokenizer, train_rows, system, args.max_length)
        encode_corpus(tokenizer, dev_rows, system, args.max_length)
        packages = {p: importlib.metadata.version(p) for p in ["torch", "transformers", "peft", "accelerate", "numpy", "safetensors"]}
        config = vars(args).copy()
        # New sampler experiments pin both the replay schedule and trainer code.
        # Historical shuffled-v1 checkpoints predate these explicit fields.
        config["sampler_sha256"] = sha256_file(Path(__file__).with_name("curriculum.py")) if args.curriculum != "shuffled-v1" else None
        config["trainer_sha256"] = sha256_file(__file__) if args.curriculum != "shuffled-v1" else None
        model_files = {str(p.relative_to(args.model)): sha256_file(p) for p in sorted(Path(args.model).rglob("*")) if p.is_file() and p.suffix in (".safetensors", ".json", ".jinja", ".py") and ".cache" not in p.parts and p.name != "download_receipt.json"}
        download_receipt_path = Path(args.model) / "download_receipt.json"
        if not download_receipt_path.is_file():
            download_receipt_path = Path(args.model).parent / "download_receipt.json"
        downloaded = json.loads(download_receipt_path.read_text())
        if downloaded["model_id"] != args.model_id or downloaded["resolved_revision"] != args.revision:
            raise ValueError("Local model download receipt differs from requested identity")
        for filename, digest in model_files.items():
            if downloaded["files"].get(filename, {}).get("sha256") != digest:
                raise ValueError("Local model differs from exact-revision download: " + filename)
        config["model_subfolder"] = downloaded["subfolder"]
        config["model_profile"] = downloaded["profile"]
        config.update({"packages": packages, "dtype": str(dtype), "resolved_device": str(device), "cuda_devices": [torch.cuda.get_device_name(i) for i in range(torch.cuda.device_count())], "deterministic_algorithms": True, "tf32": False, "train_sha256": sha256_file(args.train), "dev_sha256": sha256_file(args.dev), "admission_sha256": sha256_file(args.admission), "admission_state": admission["state"], "corpus_manifest_sha256": sha256_file(args.corpus_manifest), "compiler_sha256": sha256_file(args.compiler), "system": system, "system_sha256": hashlib.sha256(system.encode()).hexdigest(), "model_files": model_files, "chat_template_sha256": hashlib.sha256(str(tokenizer.chat_template).encode()).hexdigest(), "training_examples": len(encoded), "dev_examples": len(dev_rows), "maximum_sequence_tokens": max(len(e["input_ids"]) for e in encoded), "maximum_completion_tokens": max(e["target_tokens"] for e in encoded), "non_thinking_template": True, "native_execution_by_trainer": False})
        masks = [{"id": e["id"], "input_tokens": len(e["input_ids"]), "supervised_tokens": e["target_tokens"], "supervised_text": tokenizer.decode(e["input_ids"][e["boundary"]:], skip_special_tokens=False), "last_token": e["input_ids"][-1], "eos_supervised": tokenizer.eos_token_id in e["input_ids"][e["boundary"]:]} for e in encoded[:4]]
        write_json(output / "preflight.json", {"config": config, "mask_examples": masks, "split_guard_passed": True})
        print(canonical({"event": "preflight", "examples": len(encoded), "max_tokens": config["maximum_sequence_tokens"], "max_target_tokens": config["maximum_completion_tokens"], "device": str(device), "dtype": str(dtype)}), flush=True)
        if args.preflight_only:
            write_json(output / "job.json", {"pid": os.getpid(), "state": "preflight_complete", "training_executed": False})
            return
        t0 = time.monotonic()
        base = AutoModelForCausalLM.from_pretrained(args.model, local_files_only=True, trust_remote_code=args.trust_remote_code, dtype=dtype, attn_implementation="eager").to(device)
        available = {name.rsplit(".", 1)[-1] for name, module in base.named_modules() if isinstance(module, torch.nn.Linear)}
        targets = [name for name in TARGET_SUFFIXES if name in available]
        if not targets:
            raise ValueError("No recognized linear LoRA targets in the actual model")
        config["lora_target_modules"] = targets
        if args.resume:
            model = PeftModel.from_pretrained(base, Path(args.resume) / "adapter", is_trainable=True)
        else:
            model = get_peft_model(base, LoraConfig(r=args.rank, lora_alpha=args.alpha, lora_dropout=args.dropout, target_modules=targets, task_type="CAUSAL_LM", bias="none"))
        model.peft_config["default"].base_model_name_or_path = args.model_id
        model.peft_config["default"].revision = args.revision
        for parameter in model.parameters():
            if parameter.requires_grad:
                parameter.data = parameter.data.float()
        unexpected_trainable = [name for name, parameter in model.named_parameters() if parameter.requires_grad and ".lora_" not in name]
        if unexpected_trainable:
            raise ValueError("Non-LoRA parameter is trainable: " + repr(unexpected_trainable[:5]))
        if args.gradient_checkpointing:
            model.gradient_checkpointing_enable()
            model.enable_input_require_grads()
        model.config.use_cache = False
        trainable = [p for p in model.parameters() if p.requires_grad]
        config["trainable_parameters"] = sum(p.numel() for p in trainable)
        config["total_parameters"] = sum(p.numel() for p in model.parameters())
        frozen_hash = fingerprint_frozen(model)
        optimizer = torch.optim.AdamW(trainable, lr=args.learning_rate, weight_decay=0.0)
        scheduler = torch.optim.lr_scheduler.LambdaLR(optimizer, lambda step: 1.0)
        scaler = torch.amp.GradScaler("cuda", enabled=device.type == "cuda" and dtype == torch.float16)
        step, cursor, history = 0, 0, []
        if args.resume:
            state = torch.load(Path(args.resume) / "training_state.pt", map_location="cpu", weights_only=False)
            for key in ["model_id", "revision", "train_sha256", "dev_sha256", "admission_sha256", "system_sha256", "chat_template_sha256", "model_files", "compiler_sha256", "rank", "alpha", "dropout", "learning_rate", "accumulation", "seed", "packages", "dtype", "resolved_device", "cuda_devices", "threads", "gradient_checkpointing", "deterministic_algorithms", "tf32", "curriculum", "sampler_sha256", "trainer_sha256"]:
                # Historical shuffled-v1 receipts predate the explicit field.
                previous = state["config"].get(key, "shuffled-v1" if key == "curriculum" else None)
                if config[key] != previous:
                    raise ValueError(f"Resume identity mismatch: {key}")
            if state["frozen_base_sha256"] != frozen_hash:
                raise ValueError("Frozen base bytes differ on resume")
            optimizer.load_state_dict(state["optimizer"])
            scheduler.load_state_dict(state["scheduler"])
            scaler.load_state_dict(state["scaler"])
            random.setstate(state["python_rng"])
            np.random.set_state(state["numpy_rng"])
            torch.set_rng_state(state["torch_rng"])
            if state["cuda_rng"] and torch.cuda.is_available():
                torch.cuda.set_rng_state_all(state["cuda_rng"])
            step, cursor, history = state["global_step"], state["sample_cursor"], state["history"]
            if args.steps <= step:
                raise ValueError(f"Resume requires a larger total step target than saved step {step}")
            config["resumed_from_step"] = step
            print(canonical({"event": "resumed", "step": step, "cursor": cursor}), flush=True)
        write_json(output / "run_config.json", config)
        if not args.skip_baseline and not args.resume:
            with model.disable_adapter():
                evaluate(model, tokenizer, dev_rows, system, device, args.max_new_tokens, args.eval_count, output / "baseline.json", args.compiler)
        model.train()
        epoch_order, epoch_number = [], None
        last_checkpoint_step = -1
        train_started = time.monotonic()
        while step < args.steps and not STOP_REQUESTED:
            if time.monotonic() - train_started >= max(1, args.max_seconds - 30):
                break
            optimizer.zero_grad(set_to_none=True)
            loss_sum, tokens_sum, target_tokens_sum = 0.0, 0, 0
            step_started = time.monotonic()
            for _ in range(args.accumulation):
                epoch = cursor // len(encoded)
                if epoch_number != epoch:
                    epoch_order = epoch_indices(train_rows, args.seed, epoch, args.curriculum)
                    epoch_number = epoch
                item = encoded[epoch_order[cursor % len(encoded)]]
                inputs = torch.tensor([item["input_ids"]], dtype=torch.long, device=device)
                labels = torch.tensor([item["labels"]], dtype=torch.long, device=device)
                with torch.autocast(device_type=device.type, dtype=dtype, enabled=device.type == "cuda"):
                    result = model(input_ids=inputs, attention_mask=torch.ones_like(inputs), labels=labels, use_cache=False)
                    loss = result.loss / args.accumulation
                if not torch.isfinite(loss).item():
                    raise FloatingPointError(f"Non-finite loss at step {step}")
                scaler.scale(loss).backward()
                loss_sum += loss.item()
                tokens_sum += len(item["input_ids"])
                target_tokens_sum += item["target_tokens"]
                cursor += 1
            scaler.unscale_(optimizer)
            if not finite_gradients(model):
                raise FloatingPointError("Missing or non-finite adapter gradients")
            grad_norm = torch.nn.utils.clip_grad_norm_(trainable, 1.0).item()
            scaler.step(optimizer)
            scaler.update()
            scheduler.step()
            step += 1
            event = {"global_step": step, "sample_cursor": cursor, "loss": loss_sum, "grad_norm": grad_norm, "processed_input_tokens": tokens_sum, "supervised_target_tokens": target_tokens_sum, "seconds": time.monotonic() - step_started}
            history.append(event)
            print(canonical({"event": "train", **event}), flush=True)
            with (output / "progress.jsonl").open("a") as f:
                f.write(canonical(event) + "\n")
            write_json(output / "job.json", {"pid": os.getpid(), "state": "running", "global_step": step, "heartbeat_unix": time.time()})
            if step % args.checkpoint_every == 0:
                save_checkpoint(model, tokenizer, optimizer, scheduler, scaler, output, step, cursor, config, frozen_hash, history, t0)
                last_checkpoint_step = step
        if last_checkpoint_step != step:
            checkpoint = save_checkpoint(model, tokenizer, optimizer, scheduler, scaler, output, step, cursor, config, frozen_hash, history, t0)
        else:
            checkpoint = output / f"checkpoint-{step:06d}"
        frozen_after = fingerprint_frozen(model)
        if frozen_hash != frozen_after:
            raise AssertionError("Frozen base weights changed")
        final_eval = None
        if not args.skip_final_eval:
            final_eval = evaluate(model, tokenizer, dev_rows, system, device, args.max_new_tokens, args.eval_count, output / "after.json", args.compiler)
        import resource
        summary = {"status": "training_executed", "global_step": step, "sample_cursor": cursor, "checkpoint": str(checkpoint), "frozen_base_unchanged": True, "frozen_base_sha256": frozen_hash, "trainable_parameters": config["trainable_parameters"], "total_parameters": config["total_parameters"], "processed_input_tokens": sum(e["processed_input_tokens"] for e in history), "supervised_target_tokens": sum(e["supervised_target_tokens"] for e in history), "training_step_seconds": sum(e["seconds"] for e in history), "wall_seconds_this_process": time.monotonic() - t0, "peak_rss_kib": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss, "final_eval": final_eval, "native_evaluation": "Requires separately executed native gallery/readback; this trainer does not claim it", "config": config}
        write_json(output / "summary.json", summary)
        write_json(output / "job.json", {"pid": os.getpid(), "state": "completed", "global_step": step, "completed_at_unix": time.time()})
        print(canonical({"event": "complete", "step": step, "checkpoint": str(checkpoint), "seconds": summary["wall_seconds_this_process"]}), flush=True)


def request_stop(signum, frame):
    global STOP_REQUESTED
    STOP_REQUESTED = True


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)
    main()
