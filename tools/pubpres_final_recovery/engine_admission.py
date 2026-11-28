"""Explicit source/run/provenance admission, with old engine roles kept separate."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]


def load_bounded_payload():
    # Both historical engine packages deliberately retain their old module
    # names. Bind this new reader to its own contract without replacing the
    # original font reader's globals or allowing import-order substitution.
    folder = ROOT / "tools/pubpres_recovery_engine"
    prior = sys.modules.get("engine_contract")
    try:
        spec = importlib.util.spec_from_file_location("engine_contract", folder / "engine_contract.py")
        contract = importlib.util.module_from_spec(spec)
        sys.modules["engine_contract"] = contract
        spec.loader.exec_module(contract)
        spec = importlib.util.spec_from_file_location("recovery_atomic_payload", folder / "payload.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        if prior is None:
            sys.modules.pop("engine_contract", None)
        else:
            sys.modules["engine_contract"] = prior


def add_arguments(parser, required=False):
    parser.add_argument("--engine-payload", type=Path, required=required)
    parser.add_argument("--engine-build-source", required=required)
    parser.add_argument("--engine-build-run", type=int, required=required)
    parser.add_argument("--engine-build-attempt", type=int, required=required)
    parser.add_argument("--engine-proof-sha256", required=required)


def admit(args):
    payload = load_bounded_payload()
    identity = payload.identity_arguments(args)
    payload.need(args.engine_payload is not None and all(value is not None for value in identity.values()),
                 "Supply all independently pinned atomic engine identities")
    root = args.engine_payload.resolve()
    build = payload.verify_payload(root, **identity)
    return root / build["gui_executable"], {"admission": identity, "build": build,
        "scope": "Exact engine source/API/PE/provenance only. Application and actual rendered admission are separate gates."}
