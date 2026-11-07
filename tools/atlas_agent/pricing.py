"""Model rates and conservative worst-case token/cost estimates.

Honesty rules: the API reports token *counts*, never dollars, so every "cost" the
runner can produce is rate x tokens. A reservation is a worst-case estimate made
before a call; the computed cost is derived from the usage the API reported after
it. Neither is a bill. Unknown models, stale rates or unknown image rules raise
:class:`PricingUnavailable` so charged execution fails closed.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path

from .errors import GateRefused

DEFAULT_PRICING = Path(__file__).resolve().parent / "pricing.json"


class PricingUnavailable(GateRefused):
    reason_code = "pricing_unverifiable"


@dataclass(frozen=True)
class Rates:
    model: str
    input: float
    cached_input: float
    output: float
    per_tokens: int
    supports_reasoning: bool
    image: dict
    source_url: str
    retrieved_utc: str

    def cost(self, input_tokens: int, cached_tokens: int, output_tokens: int) -> float:
        cached = min(max(cached_tokens, 0), max(input_tokens, 0))
        fresh = max(input_tokens, 0) - cached
        total = fresh * self.input + cached * self.cached_input + max(output_tokens, 0) * self.output
        return total / self.per_tokens

    def worst_case_cost(self, input_tokens: int, output_tokens: int) -> float:
        """Every input token at the uncached rate (cached is never dearer)."""
        return self.cost(input_tokens, 0, output_tokens)

    def public(self) -> dict:
        return {"model": self.model, "input_usd_per_1m": self.input, "cached_input_usd_per_1m": self.cached_input,
                "output_usd_per_1m": self.output, "source_url": self.source_url,
                "retrieved_utc": self.retrieved_utc}


def load_table(path: Path | None = None) -> dict:
    return json.loads((path or DEFAULT_PRICING).read_text(encoding="utf-8"))


def table_sha256(path: Path | None = None) -> str:
    return hashlib.sha256((path or DEFAULT_PRICING).read_bytes()).hexdigest()


def rates_for(model: str, table: dict, today: dt.date | None = None, enforce_age: bool = True) -> Rates:
    entry = table.get("models", {}).get(model)
    if entry is None:
        raise PricingUnavailable(f"model {model!r} has no published rate in the pricing table; "
                                 "no hidden model substitution or guessed rates", "model_not_priced")
    if enforce_age:
        today = today or dt.datetime.now(dt.timezone.utc).date()
        try:
            retrieved = dt.date.fromisoformat(table["retrieved_utc"])
        except (KeyError, ValueError):
            raise PricingUnavailable("pricing table has no valid retrieved_utc date", "pricing_stale") from None
        age = (today - retrieved).days
        if age > int(table.get("max_age_days", 0)) or age < 0:
            raise PricingUnavailable(f"pricing table is {age} days old (limit {table.get('max_age_days')}); "
                                     "re-verify the published rates and update pricing.json", "pricing_stale")
    return Rates(model=model, input=float(entry["input"]), cached_input=float(entry["cached_input"]),
                 output=float(entry["output"]), per_tokens=int(table["tokens_per_unit"]),
                 supports_reasoning=bool(entry.get("supports_reasoning", False)), image=dict(entry["image"]),
                 source_url=table["source_url"], retrieved_utc=table["retrieved_utc"])


def image_tokens_upper_bound(rates: Rates, width: int, height: int, detail: str) -> int:
    """Worst-case input tokens one image may cost, from the published sizing rules."""
    rule = rates.image
    if rule.get("method") == "patch":
        size = int(rule["patch_size"])
        patches = math.ceil(width / size) * math.ceil(height / size)
        budget = rule.get("patch_budget", {}).get(detail)
        if budget is None:
            raise PricingUnavailable(f"no patch budget known for detail {detail!r}", "image_pricing_unknown")
        # Over budget images are scaled down to fit it, so the budget is the ceiling.
        return math.ceil(min(patches, int(budget)) * float(rule["multiplier"]))
    if rule.get("method") == "tile":
        base, tile = int(rule["base_tokens"]), int(rule["tile_tokens"])
        if detail == "low":
            return base
        # Fit 2048x2048, then shortest side 768, then 512px tiles: <= 2x2 tiles after
        # scaling a square; allow the full 2048-long-side case (4 x 3) as the ceiling.
        return base + tile * 12
    raise PricingUnavailable("model has no recognised image pricing rule", "image_pricing_unknown")


def text_tokens_upper_bound(text_bytes: int, bytes_per_token: float) -> int:
    """Deliberately pessimistic: assume ``bytes_per_token`` UTF-8 bytes per token."""
    return int(math.ceil(text_bytes / max(bytes_per_token, 0.5))) + 16


def utc_today() -> dt.date:
    return dt.datetime.now(dt.timezone.utc).date()
