"""Standalone #19 reference arithmetic/configuration; NOT a runtime engine policy.

Python 3.10+, standard library only. No dependency on the game or global state.
The half-up formula matches issue #17's registered rational quantization.
"""
from __future__ import annotations
import argparse
from dataclasses import asdict, dataclass
from fractions import Fraction
import hashlib
import json
from typing import Any, Mapping


def integer(value: Any, lo: int, hi: int, name: str) -> int:
    if type(value) is not int or not lo <= value <= hi:
        raise ValueError(f"{name} must be an integer in [{lo}, {hi}]")
    return value


def quantize(n: int, d: int, maximum: int) -> int:
    """Q(n/d), exact nearest, halfway upward; reject invalid rational input."""
    if any(type(v) is not int for v in (n, d, maximum)):
        raise ValueError("quantize requires integer arguments")
    if d <= 0 or maximum < 1 or not 0 <= n <= d:
        raise ValueError("require 0 <= n <= d, d > 0, maximum > 0")
    return (2 * n * maximum + d) // (2 * d)


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True,
                      allow_nan=False)


def digest(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("ascii")).hexdigest()


def strict_json(text: str) -> dict[str, Any]:
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for k, v in items:
            if k in result:
                raise ValueError(f"duplicate JSON key: {k}")
            result[k] = v
        return result
    def bad_constant(value: str) -> None:
        raise ValueError(f"non-finite JSON number: {value}")
    result = json.loads(text, object_pairs_hook=pairs, parse_constant=bad_constant)
    if not isinstance(result, dict):
        raise ValueError("profile must be an object")
    return result


@dataclass(frozen=True)
class WaterPolicy:
    schema: int = 1
    mass_bits: int = 8
    coherence_ticks: int = 12
    rest_policy: str = "normalized"

    def __post_init__(self) -> None:
        integer(self.schema, 1, 1, "schema")
        integer(self.mass_bits, 3, 8, "mass_bits")
        integer(self.coherence_ticks, 0, 12, "coherence_ticks")
        if self.rest_policy not in ("normalized", "literal_one"):
            raise ValueError("rest_policy must be normalized or literal_one")

    @property
    def maximum(self) -> int:
        return (1 << self.mass_bits) - 1

    @property
    def film(self) -> int:
        return quantize(48, 255, self.maximum)

    @property
    def tolerance(self) -> int:
        return 1 if self.rest_policy == "literal_one" else quantize(1, 255, self.maximum)

    def record(self) -> dict[str, Any]:
        return asdict(self)

    def identity(self) -> str:
        return digest(self.record())

    @classmethod
    def from_mapping(cls, value: Mapping[str, Any]) -> WaterPolicy:
        if not isinstance(value, Mapping):
            raise ValueError("policy must be a mapping")
        unknown = set(value) - {"schema", "mass_bits", "coherence_ticks", "rest_policy"}
        if unknown:
            raise ValueError(f"unknown policy fields: {sorted(unknown)}")
        return cls(**value)

    @classmethod
    def from_json(cls, text: str) -> WaterPolicy:
        return cls.from_mapping(strict_json(text))

    @classmethod
    def from_cli(cls, argv: list[str]) -> WaterPolicy:
        parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
        parser.add_argument("--water-mass-bits", type=int, default=8)
        parser.add_argument("--water-coherence", type=int, default=12)
        parser.add_argument("--water-rest", choices=("normalized", "literal_one"), default="normalized")
        args = parser.parse_args(argv)
        return cls(mass_bits=args.water_mass_bits, coherence_ticks=args.water_coherence,
                   rest_policy=args.water_rest)


@dataclass(frozen=True)
class PresentationPolicy:
    """Separate identity prevents render hot-switches changing semantic hashes."""
    schema: int = 1
    fill_levels: int = 4
    interface_mode: str = "oriented"
    quantizer: str = "positive_nearest"

    def __post_init__(self) -> None:
        integer(self.schema, 1, 1, "schema")
        integer(self.fill_levels, 4, 4, "fill_levels")
        if self.interface_mode not in ("reference", "gravity", "oriented"):
            raise ValueError("unknown interface_mode")
        if self.quantizer not in ("nearest", "positive_nearest", "ceiling"):
            raise ValueError("unknown quantizer")

    def identity(self) -> str:
        return digest(asdict(self))


def lateral_pair(a: int, b: int, policy: WaterPolicy) -> tuple[int, int, int]:
    """Local unscaled positive-difference request, NOT the complete Water kernel.

    Omits viscosity, adhesion, gravity, update epochs, scheduler and interactions.
    """
    maximum = policy.maximum
    integer(a, 0, maximum, "source")
    integer(b, 0, maximum, "destination")
    difference = a - b
    request = 3 * difference // 4 if difference > policy.tolerance else 0
    moved = min(request, a, maximum - b)
    return a - moved, b + moved, moved


def visible_level(mass: int, maximum: int, method: str) -> Fraction:
    integer(maximum, 1, 1023, "maximum")
    integer(mass, 0, maximum, "mass")
    if method not in ("nearest", "positive_nearest", "ceiling"):
        raise ValueError("unknown coverage quantizer")
    if mass == 0:
        return Fraction(0)
    if method == "ceiling":
        level = (4 * mass + maximum - 1) // maximum
    else:
        level = quantize(mass, maximum, 4)
        if method == "positive_nearest":
            level = max(1, level)
    return Fraction(level, 4)


def projected_condition(mass: int, policy: WaterPolicy) -> int:
    """Proposed Water-only display byte; never write it back to cell authority."""
    integer(mass, 0, policy.maximum, "mass")
    return quantize(mass, policy.maximum, 255)
