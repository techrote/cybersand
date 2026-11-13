#!/usr/bin/env python3
"""Evaluate a pinned base or adapter without optimizer work or final-split access."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path

from infer import load_compiler
from train_lora import choose_device_dtype, encode_corpus, evaluate, read_rows, sha256_file, validate_admission, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--adapter", type=Path)
    parser.add_argument("--dev", type=Path, required=True)
    parser.add_argument("--admission", type=Path, required=True)
    parser.add_argument("--corpus-manifest", type=Path, required=True)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--eval-count", type=int, default=24)
    parser.add_argument("--suite", choices=("dev", "keywords"), default="dev")
    parser.add_argument("--threads", type=int, default=3)
    parser.add_argument("--max-new-tokens", type=int, default=256)
    parser.add_argument("--max-length", type=int, default=1024)
    parser.add_argument("--device", default="auto")
    parser.add_argument("--trust-remote-code", action="store_true")
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError("Evaluation output already exists")
    rows = read_rows(args.dev, "dev")
    validate_admission(args.admission, {"dev": args.dev}, {"dev": rows}, args.compiler, args.corpus_manifest)
    system = Path(__file__).with_name("system_prompt.txt").read_text().strip()
    receipt_path = args.model / "download_receipt.json"
    if not receipt_path.is_file():
        receipt_path = args.model.parent / "download_receipt.json"
    downloaded = json.loads(receipt_path.read_text())
    model_files = {str(p.relative_to(args.model)): sha256_file(p) for p in sorted(args.model.rglob("*")) if p.is_file() and p.suffix in (".safetensors", ".json", ".jinja", ".py") and ".cache" not in p.parts and p.name != "download_receipt.json"}
    for filename, digest in model_files.items():
        if downloaded["files"].get(filename, {}).get("sha256") != digest:
            raise ValueError("Exact-revision model custody failed: " + filename)
    if args.adapter:
        contract = json.loads((args.adapter / "inference_contract.json").read_text())
        for key, expected in (("model_id", downloaded["model_id"]), ("revision", downloaded["resolved_revision"]), ("model_files", model_files), ("compiler_sha256", sha256_file(args.compiler))):
            if contract[key] != expected:
                raise ValueError("Adapter contract mismatch: " + key)
        system = contract["system"]
    if args.suite == "keywords":
        compiler = load_compiler(args.compiler)
        rows = [{"id": "keyword-" + theme, "prompt": theme, "theme": theme, "group_id": "keyword-sanity:" + theme, "split": "training-keyword-sanity", "seed": 17, "completion": json.dumps(compiler.make_program(theme), sort_keys=True, separators=(",", ":"))} for theme in compiler.THEMES]
    os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer
    torch.set_num_threads(args.threads)
    torch.set_num_interop_threads(1)
    device, dtype = choose_device_dtype(args.device)
    tokenizer = AutoTokenizer.from_pretrained(args.model, local_files_only=True, trust_remote_code=args.trust_remote_code)
    if tokenizer.pad_token_id is None:
        tokenizer.pad_token = tokenizer.eos_token
    template_hash = hashlib.sha256(str(tokenizer.chat_template).encode()).hexdigest()
    if args.adapter and template_hash != contract["chat_template_sha256"]:
        raise ValueError("Adapter tokenizer template changed")
    encode_corpus(tokenizer, rows, system, args.max_length)
    model = AutoModelForCausalLM.from_pretrained(args.model, local_files_only=True, trust_remote_code=args.trust_remote_code, dtype=dtype, attn_implementation="eager").to(device)
    if args.adapter:
        from peft import PeftModel
        model = PeftModel.from_pretrained(model, args.adapter, is_trainable=False)
    args.output.mkdir(parents=True)
    config = {"model_id": downloaded["model_id"], "revision": downloaded["resolved_revision"], "model_profile": downloaded["profile"], "model_subfolder": downloaded["subfolder"], "model_files": model_files, "compiler_sha256": sha256_file(args.compiler), "dev_sha256": sha256_file(args.dev), "admission_sha256": sha256_file(args.admission), "chat_template_sha256": template_hash, "system": system, "system_sha256": hashlib.sha256(system.encode()).hexdigest(), "suite": args.suite, "max_new_tokens": args.max_new_tokens, "decoding": "greedy, unconstrained, no repair", "training_executed": False, "adapter_sha256": sha256_file(args.adapter / "adapter_model.safetensors") if args.adapter else None, "device": str(device), "dtype": str(dtype)}
    write_json(args.output / "run_config.json", config)
    summary = evaluate(model, tokenizer, rows, system, device, args.max_new_tokens, args.eval_count, args.output / "predictions.json", args.compiler)
    write_json(args.output / "summary.json", {"config": config, "metrics": summary})
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
