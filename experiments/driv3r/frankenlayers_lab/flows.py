"""Immutable first-wave carcasses plus two second-wave alternative 4-layer tails.

The previous four names/flows MUST NOT change: their exact-model receipts are
attached to GitHub Actions run 43790709596. New modes use new names.
"""
from __future__ import annotations

WAVE1_FLOWS: dict[str, tuple[int, ...]] = {
    "skele6": (0, 1, 4, 9, 18, 23),
    "aero6": (0, 2, 4, 10, 20, 23),
    "skele4": (0, 4, 18, 23),
    "aero4": (0, 4, 20, 23),  # failed runtime guard; preserved intentionally
}
# Attempt alternate final blocks while retaining 0,4,18 ballast that booted in
# SKELE4. These flows are NOT claimed functional until source-built inference.
WAVE2_FLOWS: dict[str, tuple[int, ...]] = {
    "tailspin4": (0, 4, 18, 20),
    "needle4": (0, 4, 18, 22),
}
LAB_FLOWS: dict[str, tuple[int, ...]] = {**WAVE1_FLOWS, **WAVE2_FLOWS}
EXPECTED_LENGTHS = {
    "skele6": 6, "aero6": 6, "skele4": 4, "aero4": 4,
    "tailspin4": 4, "needle4": 4,
}

def validate_flows(flows: dict[str, tuple[int, ...]] = LAB_FLOWS) -> None:
    if set(flows) != set(EXPECTED_LENGTHS):
        raise ValueError("Unexpected lab flow names; immutable wave identities")
    if {name: len(layers) for name, layers in flows.items()} != EXPECTED_LENGTHS:
        raise ValueError("Unexpected executed-layer count")
    for name, layers in flows.items():
        if not all(type(i) is int and 0 <= i < 24 for i in layers):
            raise ValueError(f"{name}: invalid layer index")
        if len(set(layers)) != len(layers) or tuple(sorted(layers)) != layers:
            raise ValueError(f"{name}: nonunique/nonordered first-pass skeleton")
        if layers[0] != 0:
            raise ValueError(f"{name}: initial layer changed")
        if name in WAVE1_FLOWS:
            if layers != WAVE1_FLOWS[name]:
                raise ValueError(f"{name}: immutable wave-1 flow changed")
        elif layers != WAVE2_FLOWS[name]:
            raise ValueError(f"{name}: frozen wave-2 flow changed")

validate_flows()
