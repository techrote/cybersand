#!/usr/bin/env python3
"""Compare genuine uninterrupted and separate-runner checkpoint continuation.

Sampler/RNG/scheduler/config are exact. Float tensors use explicitly reported
FP32 tolerances because GitHub may assign different CPU microarchitectures.
Bitwise equality is reported independently and never promised for other hosts.
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

from common import sha256_file, verify_checkpoint, write_json
from train import exact_equal


def tensors_close(left, right, atol=1e-6, rtol=1e-5):
    import torch
    differences = []

    def visit(a, b):
        if isinstance(a, torch.Tensor):
            if not isinstance(b, torch.Tensor) or a.shape != b.shape or a.dtype != b.dtype:
                return False
            if a.is_floating_point():
                differences.append((a - b).abs().max().item() if a.numel() else 0.0)
                return torch.allclose(a, b, atol=atol, rtol=rtol, equal_nan=False)
            return torch.equal(a, b)
        if isinstance(a, dict):
            return isinstance(b, dict) and a.keys() == b.keys() and all(visit(a[k], b[k]) for k in a)
        if isinstance(a, (list, tuple)):
            return type(a) is type(b) and len(a) == len(b) and all(visit(x, y) for x, y in zip(a, b))
        return a == b

    return visit(left, right), max(differences, default=0.0)


def compare(fresh, resumed, output):
    import torch
    from safetensors.torch import load_file
    verify_checkpoint(fresh)
    verify_checkpoint(resumed)
    a = torch.load(fresh / "training_state.pt", map_location="cpu", weights_only=True)
    b = torch.load(resumed / "training_state.pt", map_location="cpu", weights_only=True)
    exact_keys = ("global_step", "sample_cursor", "config", "scheduler", "python_rng", "torch_rng", "frozen_base_sha256")
    checks = {key: exact_equal(a[key], b[key]) for key in exact_keys}
    checks["sample_history"] = [x["sample_id"] for x in a["history"]] == [x["sample_id"] for x in b["history"]]
    optimizer_close, optimizer_error = tensors_close(a["optimizer"], b["optimizer"])
    checks["optimizer_numerical"] = optimizer_close
    adapter_a = load_file(str(fresh / "adapter" / "adapter_model.safetensors"))
    adapter_b = load_file(str(resumed / "adapter" / "adapter_model.safetensors"))
    adapter_close, adapter_error = tensors_close(adapter_a, adapter_b)
    checks["adapter_numerical"] = adapter_close
    checks["last_loss"] = math.isclose(a["history"][-1]["loss"], b["history"][-1]["loss"], abs_tol=1e-6, rel_tol=1e-5)
    checks["last_gradient_norm"] = math.isclose(a["history"][-1]["gradient_norm"], b["history"][-1]["gradient_norm"], abs_tol=1e-6, rel_tol=1e-5)
    report = {"schema_version": 1, "passed": all(checks.values()), "checks": checks,
              "global_step": a["global_step"], "atol": 1e-6, "rtol": 1e-5,
              "maximum_adapter_absolute_difference": adapter_error, "maximum_optimizer_absolute_difference": optimizer_error,
              "adapter_bitwise_equal": exact_equal(adapter_a, adapter_b),
              "optimizer_bitwise_equal": exact_equal(a["optimizer"], b["optimizer"]),
              "fresh_inventory_sha256": sha256_file(fresh / "inventory.json"),
              "resumed_inventory_sha256": sha256_file(resumed / "inventory.json"),
              "scope": "This executed continuation only; no general cross-hardware bitwise guarantee"}
    write_json(output, report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fresh", type=Path, required=True)
    parser.add_argument("--resumed", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = compare(args.fresh, args.resumed, args.output)
    print(report)
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
