"""Conservative, explicit CPU math recipe for independent hosted continuations.

Establish environment controls before importing Torch or any library that may
initialize its thread pools. This reduces CPU dispatch variability; the separate
runner comparison remains the qualification gate, without a bitwise guarantee.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import platform
import sys

PROFILE = "portable-cpu-fp32-v1"
ENVIRONMENT = {
    "ATEN_CPU_CAPABILITY": "default",
    "MKL_CBWR": "COMPATIBLE",
    "OMP_NUM_THREADS": "1",
    "MKL_NUM_THREADS": "1",
    "OMP_DYNAMIC": "FALSE",
    "MKL_DYNAMIC": "FALSE",
}


def prepare_environment(threads: int = 1) -> None:
    """Reject conflicting/late initialization instead of pretending it took effect."""
    if threads != 1:
        raise ValueError(PROFILE + " requires exactly one CPU thread")
    if "torch" in sys.modules:
        raise RuntimeError("CPU numerical profile must be established before importing Torch")
    conflicts = [key for key, value in ENVIRONMENT.items()
                 if key in os.environ and os.environ[key] != value]
    if conflicts:
        raise ValueError("Conflicting CPU numerical environment: " + ", ".join(conflicts))
    os.environ.update(ENVIRONMENT)


def cpu_identity() -> dict:
    """Diagnostic identity only: physical hosts are allowed to differ on resume."""
    fields = {}
    path = Path("/proc/cpuinfo")
    if path.is_file():
        for line in path.read_text(encoding="utf-8").split("\n\n", 1)[0].splitlines():
            key, separator, value = line.partition(":")
            if separator and key.strip() in {"vendor_id", "model name", "cpu family", "model", "stepping", "flags"}:
                fields[key.strip()] = value.strip()
    return {"platform": platform.platform(), "machine": platform.machine(),
            "logical_cpu_count": os.cpu_count(), "cpu": fields}


def configure_cpu(threads: int = 1) -> tuple[dict, dict]:
    """Return an exact-resume recipe and a separate physical-runtime receipt."""
    prepare_environment(threads)
    import torch

    if not torch.backends.mkl.is_available() or torch.version.cuda is not None:
        raise ValueError(PROFILE + " requires the pinned CPU-only Torch build with MKL")
    torch.set_num_threads(1)
    torch.set_num_interop_threads(1)
    torch.use_deterministic_algorithms(True)
    torch.backends.mkldnn.enabled = False
    torch.set_float32_matmul_precision("highest")
    effective = {
        "environment": {key: os.environ[key] for key in ENVIRONMENT},
        "aten_cpu_capability": torch.backends.cpu.get_cpu_capability(),
        "intraop_threads": torch.get_num_threads(),
        "interop_threads": torch.get_num_interop_threads(),
        "mkl_available": torch.backends.mkl.is_available(),
        "mkldnn_enabled": torch.backends.mkldnn.enabled,
        "float32_matmul_precision": torch.get_float32_matmul_precision(),
        "cpu_autocast_enabled": torch.is_autocast_enabled("cpu"),
        "default_dtype": str(torch.get_default_dtype()),
        "default_device": str(torch.get_default_device()),
        "deterministic_algorithms": torch.are_deterministic_algorithms_enabled(),
        "deterministic_warn_only": torch.is_deterministic_algorithms_warn_only_enabled(),
    }
    expected = {
        "environment": ENVIRONMENT, "aten_cpu_capability": "DEFAULT",
        "intraop_threads": 1, "interop_threads": 1, "mkl_available": True,
        "mkldnn_enabled": False, "float32_matmul_precision": "highest",
        "cpu_autocast_enabled": False, "default_dtype": "torch.float32",
        "default_device": "cpu", "deterministic_algorithms": True,
        "deterministic_warn_only": False,
    }
    if effective != expected:
        raise ValueError("Effective CPU math controls differ from " + PROFILE)
    build = torch.__config__.show()
    recipe = {"profile": PROFILE, "effective": effective,
              "torch_version": str(torch.__version__), "torch_git_version": torch.version.git_version,
              "torch_build_sha256": hashlib.sha256(build.encode()).hexdigest(),
              "numerics_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    runtime = {"identity": cpu_identity(), "torch_build": build,
               "torch_parallel_info": torch.__config__.parallel_info()}
    return recipe, runtime
