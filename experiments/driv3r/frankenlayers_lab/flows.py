"""Small layer skeletons extrapolated from source-qualified #626 eight-layer hounds.

These are *hypotheses*, not claimed working models. All four keep the core
attention ballast indices 4/18 or 4/20 present in the successful 8-step flows.
Real backend guard in patch_lab.py checks model metadata to reject flows that
fail to exercise both full and sliding attention kinds.
"""
from __future__ import annotations

LAB_FLOWS: dict[str, tuple[int, ...]] = {
    "skele6": (0, 1, 4, 9, 18, 23),
    "aero6":  (0, 2, 4, 10, 20, 23),
    "skele4": (0, 4, 18, 23),
    "aero4":  (0, 4, 20, 23),
}

def validate_flows(flows: dict[str, tuple[int, ...]] = LAB_FLOWS) -> None:
    if len(flows) != 4:
        raise ValueError("Expected exactly four predeclared experimental flows")
    if {k: len(v) for k, v in flows.items()} != {
        "skele6": 6, "aero6": 6, "skele4": 4, "aero4": 4
    }:
        raise ValueError("Unexpected layer-execution counts")
    for name, layers in flows.items():
        if not all(isinstance(i, int) and 0 <= i < 24 for i in layers):
            raise ValueError(f"{name}: invalid layer index")
        if len(set(layers)) != len(layers) or tuple(sorted(layers)) != layers:
            raise ValueError(f"{name}: first-pass sparse skeletons must be unique and ordered")
        if layers[0] != 0 or layers[-1] != 23:
            raise ValueError(f"{name}: preserve first/last layer in first-pass skeletons")

validate_flows()
