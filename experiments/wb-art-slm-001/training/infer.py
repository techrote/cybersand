#!/usr/bin/env python3
"""Generate one actual model program and save a bounded Art batch; never execute it.

Rejected output is retained for diagnosis. No keyword fallback, JSON repair,
tool execution, or simulation of native acknowledgement occurs here.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import time

from train_lora import choose_device_dtype, decode_generation, messages_for, sha256_file, strict_json, write_json


def load_compiler(path):
    spec = importlib.util.spec_from_file_location("wb_strict_inference_compiler", path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True, help="Pinned local base snapshot")
    parser.add_argument("--adapter", type=Path, required=True)
    parser.add_argument("--compiler", type=Path, default=Path(__file__).resolve().parents[1] / "controls" / "pattern_compiler.py")
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=17, help="Host geometry seed; never inserted into model output")
    parser.add_argument("--width", type=int, default=96)
    parser.add_argument("--height", type=int, default=96)
    parser.add_argument("--material", type=int, default=58)
    parser.add_argument("--max-shapes", type=int, default=2048)
    parser.add_argument("--max-estimated-cells", type=int, default=131072)
    parser.add_argument("--threads", type=int, default=3)
    parser.add_argument("--device", default="auto")
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError("Refusing to overwrite prior inference evidence: " + str(args.output))
    contract = json.loads((args.adapter / "inference_contract.json").read_text())
    config = json.loads((args.adapter / "adapter_config.json").read_text())
    if config["base_model_name_or_path"] != contract["model_id"] or config["revision"] != contract["revision"]:
        raise ValueError("Adapter base identity differs from inference contract")
    if sha256_file(args.compiler) != contract["compiler_sha256"]:
        raise ValueError("Compiler hash differs from training contract")
    for relative, digest in contract["model_files"].items():
        if sha256_file(args.model / relative) != digest:
            raise ValueError("Pinned model file changed: " + relative)
    os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
    import torch
    from transformers import AutoTokenizer, AutoModelForCausalLM
    from peft import PeftModel
    torch.set_num_threads(args.threads)
    torch.set_num_interop_threads(1)
    device, dtype = choose_device_dtype(args.device)
    tokenizer = AutoTokenizer.from_pretrained(args.model, local_files_only=True, trust_remote_code=contract["trust_remote_code"])
    if hashlib.sha256(str(tokenizer.chat_template).encode()).hexdigest() != contract["chat_template_sha256"]:
        raise ValueError("Tokenizer chat template changed")
    if tokenizer.pad_token_id is None:
        tokenizer.pad_token = tokenizer.eos_token
    prefix = tokenizer.apply_chat_template(messages_for({"prompt": args.prompt}, contract["system"]), tokenize=False, add_generation_prompt=True, enable_thinking=False)
    inputs = tokenizer(prefix, return_tensors="pt", add_special_tokens=False).to(device)
    if inputs["input_ids"].shape[-1] + contract["max_new_tokens"] > contract["max_length"]:
        raise ValueError("Request exceeds the trained input/output token budget")
    base = AutoModelForCausalLM.from_pretrained(args.model, local_files_only=True, trust_remote_code=contract["trust_remote_code"], dtype=dtype, attn_implementation="eager").to(device)
    model = PeftModel.from_pretrained(base, args.adapter, is_trainable=False).eval()
    started = time.monotonic()
    with torch.inference_mode():
        prediction = model.generate(**inputs, max_new_tokens=contract["max_new_tokens"], do_sample=False, use_cache=True, eos_token_id=tokenizer.eos_token_id, pad_token_id=tokenizer.pad_token_id)
    tokens = prediction[0, inputs["input_ids"].shape[-1]:].tolist()
    raw = decode_generation(tokenizer, tokens)
    args.output.mkdir(parents=True)
    (args.output / "raw_completion.txt").write_text(raw)
    receipt = {"prompt": args.prompt, "model_id": contract["model_id"], "revision": contract["revision"], "adapter_sha256": sha256_file(args.adapter / "adapter_model.safetensors"), "adapter_config_sha256": sha256_file(args.adapter / "adapter_config.json"), "inference_contract_sha256": sha256_file(args.adapter / "inference_contract.json"), "compiler_sha256": contract["compiler_sha256"], "seed": args.seed, "width": args.width, "height": args.height, "material": args.material, "output_tokens": len(tokens), "eos_emitted": tokenizer.eos_token_id in tokens, "generation_seconds": time.monotonic() - started, "decoding": "greedy, unconstrained, no repair", "native_execution": False}
    try:
        if not tokens or tokens[-1] != tokenizer.eos_token_id:
            raise ValueError("Unterminated generation: stopping EOS not emitted")
        program = strict_json(raw)
        compiler = load_compiler(args.compiler)
        compiler.validate_program(program)
        report = compiler.compile_with_report(program, args.width, args.height, args.seed, material=args.material, max_shapes=args.max_shapes, max_estimated_cells=args.max_estimated_cells)
        write_json(args.output / "program.json", program)
        write_json(args.output / "art_batch.json", report["operations"])
        write_json(args.output / "compile_report.json", report)
        receipt.update({"accepted": True, "operations": len(report["operations"]), "program_sha256": report["program_sha256"], "art_batch_sha256": sha256_file(args.output / "art_batch.json")})
    except (ValueError, TypeError, KeyError) as exc:
        receipt.update({"accepted": False, "rejection": f"{type(exc).__name__}: {exc}"})
        write_json(args.output / "receipt.json", receipt)
        print(json.dumps(receipt, indent=2))
        raise SystemExit(2)
    write_json(args.output / "receipt.json", receipt)
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
