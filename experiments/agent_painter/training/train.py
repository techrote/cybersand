#!/usr/bin/env python3
"""Bounded genuine CPU LoRA optimization on newly native-admitted TRAIN rows.

The initial proof supports SmolLM2-135M-Instruct only. Other frozen lane profiles
are explicit preflight handoffs; this code never substitutes a generic loader.
Checkpoint mechanics adapt frozen PR #567 and NeuroRunner TRAIN-001; inputs and
outputs have new identities and never alter the historical model or data.
"""
from __future__ import annotations

import argparse
import importlib.metadata
import os
from pathlib import Path
import platform
import random
import signal
import subprocess
import sys
import time

from common import (ROOT, canonical, digest_json, encode_row, load_training_corpus,
                    profile, read_json, sha256_file, verify_checkpoint, verify_file, write_json)
from numerics import configure_cpu

STOP = False
SYSTEM = "Return only one valid CyberSand painter program JSON object. Follow the requested structure. Do not set host seeds, material permissions or focus."
PACKAGES = ("torch", "transformers", "peft", "accelerate", "numpy", "safetensors", "huggingface-hub", "tokenizers")


def request_stop(_signal, _frame):
    global STOP
    STOP = True


def exact_equal(left, right):
    import torch
    if isinstance(left, torch.Tensor):
        return isinstance(right, torch.Tensor) and torch.equal(left, right)
    if isinstance(left, dict):
        return isinstance(right, dict) and left.keys() == right.keys() and all(exact_equal(left[key], right[key]) for key in left)
    if isinstance(left, (tuple, list)):
        return type(left) is type(right) and len(left) == len(right) and all(exact_equal(a, b) for a, b in zip(left, right))
    return left == right


def fingerprint(model, trainable):
    import hashlib
    import torch
    digest = hashlib.sha256()
    for name, parameter in sorted(model.named_parameters()):
        if parameter.requires_grad != trainable:
            continue
        digest.update(name.encode())
        digest.update(str(tuple(parameter.shape)).encode())
        digest.update(parameter.detach().cpu().contiguous().view(torch.uint8).numpy().tobytes())
    return digest.hexdigest()


def source_sha():
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()


def verify_model(directory, selected):
    directory = Path(directory)
    receipt = read_json(directory / "download_receipt.json")
    if receipt.get("model_id") != selected["model_id"] or receipt.get("revision") != selected["revision"] or receipt.get("trust_remote_code") is not False:
        raise ValueError("model snapshot receipt differs from exact lane")
    files = {p.relative_to(directory).as_posix() for p in directory.rglob("*")
             if p.is_file() and ".cache" not in p.parts and p.name != "download_receipt.json"}
    if files != set(receipt["files"]):
        raise ValueError("model snapshot file inventory mismatch")
    for name, item in receipt["files"].items():
        path = verify_file(directory, name, item["sha256"])
        if path.stat().st_size != item["bytes"]:
            raise ValueError("model snapshot file size mismatch")
    for name, expected in selected["required_hashes"].items():
        if receipt["files"].get(name, {}).get("sha256") != expected:
            raise ValueError("model byte identity differs from reviewed pin")
    return receipt


def load_base(directory, selected):
    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer
    verify_model(directory, selected)
    tokenizer = AutoTokenizer.from_pretrained(directory, local_files_only=True, trust_remote_code=False)
    if not tokenizer.chat_template or type(tokenizer.eos_token_id) is not int:
        raise ValueError("Smol lane requires its upstream chat template and actual EOS")
    if tokenizer.pad_token_id is None:
        tokenizer.pad_token = tokenizer.eos_token
    base = AutoModelForCausalLM.from_pretrained(directory, local_files_only=True, trust_remote_code=False,
                                               dtype=torch.float32, attn_implementation="eager")
    if base.config.model_type != selected["model_type"] or type(base).__name__ != selected["architecture"]:
        raise ValueError("loaded model architecture differs from reviewed lane")
    base.to("cpu")
    base.config.use_cache = False
    targets = {name.rsplit(".", 1)[-1] for name, module in base.named_modules() if isinstance(module, torch.nn.Linear)}
    if not set(selected["lora_targets"]).issubset(targets):
        raise ValueError("required LoRA module whitelist is not present")
    return base, tokenizer


def state_for(optimizer, scheduler, step, cursor, config, frozen_sha, history):
    import torch
    return {"optimizer": optimizer.state_dict(), "scheduler": scheduler.state_dict(),
            "global_step": step, "sample_cursor": cursor, "python_rng": random.getstate(),
            "torch_rng": torch.get_rng_state(), "config": config, "frozen_base_sha256": frozen_sha, "history": history}


def save_checkpoint(output, model, tokenizer, state, numerical_runtime):
    import torch
    from peft import get_peft_model_state_dict
    from safetensors.torch import load_file

    destination = output / f"checkpoint-{state['global_step']:06d}"
    temporary = output / f".checkpoint-{state['global_step']:06d}.writing"
    if destination.exists() or temporary.exists():
        raise ValueError("refusing to overwrite an existing checkpoint")
    temporary.mkdir()
    model.save_pretrained(temporary / "adapter", safe_serialization=True)
    tokenizer.save_pretrained(temporary / "adapter")
    torch.save(state, temporary / "training_state.pt")
    receipt = {key: state[key] for key in ("global_step", "sample_cursor", "config", "frozen_base_sha256", "history")}
    receipt["training_state_format"] = "torch.load(weights_only=True); tensors and primitive state only"
    receipt["numerical_runtime"] = numerical_runtime
    write_json(temporary / "receipt.json", receipt)
    inventory = {path.relative_to(temporary).as_posix(): {"sha256": sha256_file(path), "bytes": path.stat().st_size}
                 for path in sorted(temporary.rglob("*")) if path.is_file()}
    write_json(temporary / "inventory.json", inventory)
    verify_checkpoint(temporary)
    loaded = torch.load(temporary / "training_state.pt", map_location="cpu", weights_only=True)
    if not exact_equal(state, loaded):
        raise ValueError("serialized optimizer/scheduler/RNG/sampler readback differs")
    stored_adapter = load_file(str(temporary / "adapter" / "adapter_model.safetensors"))
    expected_adapter = {name: tensor.detach().cpu() for name, tensor in get_peft_model_state_dict(model).items()}
    if not exact_equal(expected_adapter, stored_adapter):
        raise ValueError("serialized adapter tensor readback differs")
    os.replace(temporary, destination)
    return destination


def sampler(rows, seed):
    """Stable balanced interleaving; all seed variants retain their sample IDs."""
    import hashlib
    buckets = {}
    for index, row in enumerate(rows):
        buckets.setdefault(row["family"], []).append(index)
    for indexes in buckets.values():
        indexes.sort(key=lambda index: hashlib.sha256(f"{seed}:{rows[index]['id']}".encode()).digest())
    return [buckets[family][i] for i in range(max(map(len, buckets.values())))
            for family in sorted(buckets) if i < len(buckets[family])]


def train(args):
    if not 1 <= args.steps <= 10000 or not 60 <= args.max_seconds <= 18000 or args.threads != 1:
        raise ValueError("steps/deadline/CPU thread budget out of bounds")
    if not 1 <= args.checkpoint_every <= args.steps:
        raise ValueError("checkpoint interval out of bounds")
    selected = profile(args.profile, require_supported=True)
    if not 1 <= args.max_length <= selected["max_sequence_tokens"]:
        raise ValueError("sequence budget exceeds model-specific allowance")
    os.environ["TOKENIZERS_PARALLELISM"] = "false"
    numerics, numerical_runtime = configure_cpu(args.threads)
    import torch
    from peft import LoraConfig, PeftModel, get_peft_model
    random.seed(args.seed)
    torch.manual_seed(args.seed)
    rows, admission = load_training_corpus(args.corpus)
    args.output.mkdir(parents=True, exist_ok=False)
    args._output_owned = True
    write_json(args.output / "lease.json", {"pid": os.getpid(), "source_sha": source_sha(), "started_unix": time.time(), "profile": args.profile})
    started = time.monotonic()
    base, tokenizer = load_base(args.model, selected)
    encoded = [encode_row(tokenizer, row, SYSTEM, args.max_length) for row in rows]
    order = sampler(rows, args.seed)
    packages = {name: importlib.metadata.version(name) for name in PACKAGES}
    config = {"schema_version": 1, "profile": args.profile, "model": selected,
              "model_files": read_json(args.model / "download_receipt.json")["files"],
              "source_sha": source_sha(), "native_source_sha": admission["source_sha"],
              "corpus_manifest_sha256": sha256_file(args.corpus / "admitted-corpus.json"),
              "train_sha256": admission["split_files"]["TRAIN"]["sha256"],
              "compiler_sha256": admission["compiler_sha256"],
              "trainer_sha256": sha256_file(__file__), "contract_sha256": sha256_file(Path(__file__).with_name("common.py")),
              "numerics": numerics,
              "packages": packages, "python": platform.python_version(), "device": "cpu", "dtype": "float32",
              "threads": args.threads, "seed": args.seed, "max_length": args.max_length,
              "rank": 8, "alpha": 16, "dropout": 0.05, "learning_rate": 0.0005,
              "system": SYSTEM, "system_sha256": digest_json(SYSTEM),
              "chat_template_sha256": digest_json(tokenizer.chat_template),
              "sample_order": [rows[index]["id"] for index in order],
              "native_execution_by_trainer": False, "final_targets_opened": False}
    state = None
    if args.resume:
        previous_receipt = verify_checkpoint(args.resume)
        previous_config = previous_receipt["config"]
        # Paths and job IDs intentionally excluded; independent VMs have new paths.
        if config != previous_config:
            changed = [key for key in config if config[key] != previous_config.get(key)]
            raise ValueError("resume identity mismatch: " + ", ".join(changed))
        state = torch.load(args.resume / "training_state.pt", map_location="cpu", weights_only=True)
        if state["global_step"] >= args.steps:
            raise ValueError("resume target must advance the saved optimizer step")
        model = PeftModel.from_pretrained(base, args.resume / "adapter", is_trainable=True, local_files_only=True)
    else:
        model = get_peft_model(base, LoraConfig(task_type="CAUSAL_LM", r=config["rank"], lora_alpha=config["alpha"],
                                               lora_dropout=config["dropout"], bias="none", target_modules=selected["lora_targets"]))
    trainable = [parameter for parameter in model.parameters() if parameter.requires_grad]
    if not trainable or any("lora_" not in name for name, parameter in model.named_parameters() if parameter.requires_grad):
        raise ValueError("only declared LoRA parameters may train")
    optimizer = torch.optim.AdamW(trainable, lr=config["learning_rate"], betas=(0.9, 0.95), weight_decay=0.01)
    scheduler = torch.optim.lr_scheduler.LambdaLR(optimizer, lambda _step: 1.0)
    frozen_before = fingerprint(model, False)
    adapter_before = fingerprint(model, True)
    step, cursor, history = 0, 0, []
    resumed = None
    if state:
        if state["config"] != config or state["frozen_base_sha256"] != frozen_before:
            raise ValueError("resumed full state/base identity mismatch")
        optimizer.load_state_dict(state["optimizer"])
        scheduler.load_state_dict(state["scheduler"])
        random.setstate(state["python_rng"])
        torch.set_rng_state(state["torch_rng"])
        step, cursor, history = state["global_step"], state["sample_cursor"], state["history"]
        restored = state_for(optimizer, scheduler, step, cursor, config, frozen_before, history)
        if not exact_equal(state, restored):
            raise ValueError("restored optimizer/scheduler/RNG/sampler differ before continuation")
        resumed = {"from_step": step, "sample_cursor": cursor, "inventory_sha256": sha256_file(args.resume / "inventory.json"),
                   "restored_all_state_exactly": True}
    write_json(args.output / "preflight.json", {"config": config, "train_rows": len(rows),
               "numerical_runtime": numerical_runtime,
               "max_sequence_tokens": max(len(item["input_ids"]) for item in encoded),
               "trainable_parameters": sum(p.numel() for p in trainable),
               "all_parameters": sum(p.numel() for p in model.parameters()), "resume": resumed,
               "mask_checks": [{"id": item["id"], "prompt_tokens": item["boundary"], "loss_tokens": item["target_tokens"],
                                "supervised_eos": tokenizer.eos_token_id in item["input_ids"][item["boundary"]:]} for item in encoded]})
    training_started = time.monotonic()
    starting_step = step
    last_saved = -1
    model.train()
    while step < args.steps and not STOP and time.monotonic() - started < args.max_seconds - 30:
        item = encoded[order[cursor % len(order)]]
        step_start = time.monotonic()
        optimizer.zero_grad(set_to_none=True)
        ids = torch.tensor([item["input_ids"]], dtype=torch.long)
        labels = torch.tensor([item["labels"]], dtype=torch.long)
        loss = model(input_ids=ids, attention_mask=torch.ones_like(ids), labels=labels, use_cache=False).loss
        if not torch.isfinite(loss).item():
            raise ValueError("non-finite training loss")
        loss.backward()
        gradients = [p.grad for p in trainable if p.grad is not None]
        if not gradients or not all(torch.isfinite(gradient).all().item() for gradient in gradients) or not any(torch.count_nonzero(gradient).item() for gradient in gradients):
            raise ValueError("missing, zero or non-finite LoRA gradients")
        grad_norm = torch.nn.utils.clip_grad_norm_(trainable, 1.0).item()
        optimizer.step()
        scheduler.step()
        step += 1
        cursor += 1
        event = {"global_step": step, "sample_cursor": cursor, "sample_id": item["id"], "loss": loss.item(),
                 "gradient_norm": grad_norm, "sequence_tokens": len(item["input_ids"]), "loss_tokens": item["target_tokens"],
                 "prompt_bytes": item["prompt_bytes"], "completion_bytes": item["completion_bytes"],
                 "seconds": time.monotonic() - step_start}
        history.append(event)
        print(canonical({"event": "optimizer-step", **event}), flush=True)
        with (args.output / "progress.jsonl").open("a", encoding="utf-8") as stream:
            stream.write(canonical(event) + "\n")
        if step % args.checkpoint_every == 0:
            checkpoint = save_checkpoint(args.output, model, tokenizer, state_for(optimizer, scheduler, step, cursor, config, frozen_before, history), numerical_runtime)
            last_saved = step
    if step == starting_step:
        raise ValueError("no optimizer step completed; not a training proof")
    if step != last_saved:
        checkpoint = save_checkpoint(args.output, model, tokenizer, state_for(optimizer, scheduler, step, cursor, config, frozen_before, history), numerical_runtime)
    frozen_after = fingerprint(model, False)
    adapter_after = fingerprint(model, True)
    if frozen_after != frozen_before or adapter_after == adapter_before:
        raise ValueError("frozen base changed or adapter did not update")
    import resource
    measured = history[starting_step:]
    completed = step == args.steps
    summary = {"schema_version": 1, "status": "completed" if completed else "stopped-checkpoint-saved",
               "actual_training": True, "global_step": step, "optimizer_steps_this_job": step - starting_step,
               "sample_cursor": cursor, "sample_ids_this_job": [event["sample_id"] for event in measured],
               "loss_tokens_this_job": sum(event["loss_tokens"] for event in measured),
               "sequence_tokens_this_job": sum(event["sequence_tokens"] for event in measured),
               "bytes_this_job": sum(event["prompt_bytes"] + event["completion_bytes"] for event in measured),
               "first_loss": measured[0]["loss"], "last_loss": measured[-1]["loss"],
               "training_seconds": time.monotonic() - training_started, "wall_seconds": time.monotonic() - started,
               "cpu_seconds": time.process_time(), "peak_rss_kib": int(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss),
               "adapter_before_sha256": adapter_before, "adapter_after_sha256": adapter_after,
               "adapter_changed": True, "frozen_base_unchanged": True, "frozen_base_sha256": frozen_after,
               "checkpoint": checkpoint.name, "checkpoint_readback_exact": True,
               "checkpoint_bytes": sum(path.stat().st_size for path in checkpoint.rglob("*") if path.is_file()),
               "checkpoint_inventory_sha256": sha256_file(checkpoint / "inventory.json"),
               "resume": resumed, "config": config, "native_execution": False, "model_quality_claim": False,
               "numerical_runtime": numerical_runtime,
               "runner": {"os": platform.platform(), "machine": platform.machine(), "cpu_count": os.cpu_count(),
                          "github_run_id": os.environ.get("GITHUB_RUN_ID"), "github_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT")}}
    write_json(args.output / "summary.json", summary)
    print(canonical({"event": "training-finished", "step": step, "completed": completed, "actual_training": True}), flush=True)
    return 0 if completed else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", default="smol")
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--resume", type=Path)
    parser.add_argument("--steps", type=int, default=2, help="total global step target including resumed steps")
    parser.add_argument("--max-seconds", type=int, default=1200)
    parser.add_argument("--max-length", type=int, default=2048)
    parser.add_argument("--threads", type=int, default=1, help="portable-cpu-fp32-v1 requires one thread")
    parser.add_argument("--seed", type=int, default=568)
    parser.add_argument("--checkpoint-every", type=int, default=1)
    args = parser.parse_args()
    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)
    try:
        return train(args)
    except Exception as error:
        if getattr(args, "_output_owned", False):
            write_json(args.output / "failure.json", {"status": "FAILED", "error": str(error), "type": type(error).__name__})
        raise


if __name__ == "__main__":
    sys.exit(main())
