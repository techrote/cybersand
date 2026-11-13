#!/usr/bin/env python3
"""Compare uninterrupted and fresh-process-resumed continuation checkpoints."""
from __future__ import annotations

import argparse
from pathlib import Path
import torch
import numpy as np
from safetensors.torch import load_file

from train_lora import sha256_file, write_json


def equal(left, right):
    if isinstance(left, torch.Tensor):
        return isinstance(right, torch.Tensor) and torch.equal(left, right)
    if isinstance(left, np.ndarray):
        return isinstance(right, np.ndarray) and np.array_equal(left, right)
    if isinstance(left, dict):
        return isinstance(right, dict) and left.keys() == right.keys() and all(equal(left[k], right[k]) for k in left)
    if isinstance(left, (tuple, list)):
        return type(left) is type(right) and len(left) == len(right) and all(equal(a, b) for a, b in zip(left, right))
    return left == right


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uninterrupted", type=Path, required=True)
    parser.add_argument("--resumed", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    a = torch.load(args.uninterrupted / "training_state.pt", map_location="cpu", weights_only=False)
    b = torch.load(args.resumed / "training_state.pt", map_location="cpu", weights_only=False)
    checks = {key: equal(a[key], b[key]) for key in ("optimizer", "scheduler", "scaler", "global_step", "sample_cursor", "python_rng", "numpy_rng", "torch_rng", "cuda_rng", "frozen_base_sha256")}
    checks["adapter_tensors"] = equal(load_file(args.uninterrupted / "adapter" / "adapter_model.safetensors"), load_file(args.resumed / "adapter" / "adapter_model.safetensors"))
    checks["last_loss"] = a["history"][-1]["loss"] == b["history"][-1]["loss"]
    checks["last_gradient_norm"] = a["history"][-1]["grad_norm"] == b["history"][-1]["grad_norm"]
    report = {"passed": all(checks.values()), "checks": checks, "uninterrupted_checkpoint": str(args.uninterrupted), "resumed_checkpoint": str(args.resumed), "global_step": a["global_step"], "uninterrupted_adapter_sha256": sha256_file(args.uninterrupted / "adapter" / "adapter_model.safetensors"), "resumed_adapter_sha256": sha256_file(args.resumed / "adapter" / "adapter_model.safetensors"), "scope": "Exact equality for this tested checkpoint continuation in the pinned runtime; not a cross-hardware guarantee"}
    write_json(args.output, report)
    print(report)
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
