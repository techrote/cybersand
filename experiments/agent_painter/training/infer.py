#!/usr/bin/env python3
"""One raw model proposal, strict EOS/JSON, host-owned compilation; no native writes."""
from __future__ import annotations

import argparse
from pathlib import Path
import time

from common import (ROOT, canonical, compiler_module, profile, sha256_file, strict_completion,
                    strict_json, verify_checkpoint, write_json)
from train import load_base
from numerics import configure_cpu
from lane_adapters import adapter_identity, encode_prompt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--width", type=int, default=96)
    parser.add_argument("--height", type=int, default=96)
    parser.add_argument("--material", type=int, default=58)
    parser.add_argument("--max-new-tokens", type=int, default=1024)
    parser.add_argument("--threads", type=int, default=1, help="must match the checkpoint's portable CPU math profile")
    args = parser.parse_args()
    if not 0 <= args.seed <= 2**32 - 1 or not 96 <= args.width <= 512 or not 96 <= args.height <= 512:
        parser.error("host seed/focus exceeds compiler bounds")
    if args.threads != 1 or not 1 <= args.max_new_tokens <= 2048 or not 1 <= len(args.prompt.encode()) <= 4096:
        parser.error("bounded prompt/token/CPU contract refused")
    if args.output.exists():
        raise ValueError("refusing to overwrite inference evidence")
    checkpoint = verify_checkpoint(args.checkpoint)
    config = checkpoint["config"]
    selected = profile(config["profile"], require_supported=True)
    compiler_path = ROOT / "compiler.py"
    if config["compiler_sha256"] != sha256_file(compiler_path) or config["model"] != selected:
        raise ValueError("adapter/compiler/model identity mismatch")
    if config.get("adapter_contract") != adapter_identity(selected):
        raise ValueError("model adapter/framing implementation differs from checkpoint")
    numerics, numerical_runtime = configure_cpu(args.threads)
    if config.get("numerics") != numerics:
        raise ValueError("inference numerical recipe differs from checkpoint")
    import torch
    from peft import PeftModel
    started = time.monotonic()
    base, tokenizer = load_base(args.model, selected)
    model = PeftModel.from_pretrained(base, args.checkpoint / "adapter", is_trainable=False, local_files_only=True)
    model.eval()
    ids = encode_prompt(tokenizer, args.prompt, config["system"], selected)
    if len(ids) + args.max_new_tokens > selected["max_sequence_tokens"]:
        raise ValueError("prompt plus generation budget exceeds lane context; no truncation")
    inputs = torch.tensor([ids], dtype=torch.long)
    with torch.inference_mode():
        generated = model.generate(input_ids=inputs, attention_mask=torch.ones_like(inputs),
                                   max_new_tokens=args.max_new_tokens, do_sample=False,
                                   eos_token_id=tokenizer.eos_token_id, pad_token_id=tokenizer.pad_token_id,
                                   use_cache=True)[0, len(ids):].tolist()
    compiler = compiler_module()
    verdict = strict_completion(tokenizer, generated, compiler.validate_program)
    accepted = verdict["first_pass_accepted"]
    compiled = None
    if accepted:
        try:
            compiled = compiler.compile_program(strict_json(verdict["raw_text"]), seed=args.seed,
                                                 focus=(0, 0, args.width, args.height), material=args.material,
                                                 allowed_materials=(args.material,))
        except ValueError as error:
            accepted = False
            verdict["compile_failure"] = str(error)
    args.output.mkdir(parents=True)
    (args.output / "completion.txt").write_text(verdict["raw_text"], encoding="utf-8")
    write_json(args.output / "raw-output.json", verdict)
    write_json(args.output / "art_batch.json", compiled["operations"] if accepted else [])
    if accepted:
        write_json(args.output / "compiled.json", compiled)
    receipt = {"schema_version": 1, "accepted": accepted, "eos_emitted": tokenizer.eos_token_id in generated,
               "eos_terminated": verdict["eos_terminated"], "prompt": args.prompt,
               "model_id": selected["model_id"], "model_revision": selected["revision"],
               "adapter_sha256": sha256_file(args.checkpoint / "adapter" / "adapter_model.safetensors"),
               "compiler_sha256": sha256_file(compiler_path), "seed": args.seed,
               "width": args.width, "height": args.height, "material": args.material,
               "completion_sha256": sha256_file(args.output / "completion.txt"),
               "operations_sha256": compiled["operations_sha256"] if accepted else None,
               "input_tokens": len(ids), "output_tokens": len(generated),
               "seconds": time.monotonic() - started, "decoding": "greedy first pass; no repair/retry/fallback",
               "numerics": numerics, "numerical_runtime": numerical_runtime,
               "native_execution": False, "visual_quality_claim": False}
    write_json(args.output / "receipt.json", receipt)
    print(canonical(receipt), flush=True)


if __name__ == "__main__":
    main()
