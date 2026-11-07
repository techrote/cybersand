"""Reserve-before-call spend/limit ledger.

Flow per request attempt: ``reserve`` (worst case, may refuse) -> call ->
``commit`` (reconcile with reported usage) | ``release`` (provably not charged) |
``mark_ambiguous`` (outcome unknown: the reservation stays counted as spent).
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Callable

from .errors import LimitReached
from .pricing import Rates


@dataclass
class Reservation:
    attempt: int
    input_tokens: int
    output_tokens: int
    usd: float
    state: str = "open"  # open | committed | released | ambiguous


@dataclass
class Budget:
    limits: dict
    spend: dict
    rates: Rates
    live: bool
    clock: Callable[[], float] = time.monotonic
    started: float = field(default=0.0)
    attempts: int = 0
    responses: int = 0
    iterations: int = 0
    committed_usd: float = 0.0  # reconciled computed cost + ambiguous reservations
    computed_usd: float = 0.0  # reconciled from reported usage only
    ambiguous_usd: float = 0.0
    peak_reservation_usd: float = 0.0
    reserved_total_usd: float = 0.0
    input_tokens: int = 0
    cached_tokens: int = 0
    output_tokens: int = 0
    reasoning_tokens: int = 0
    overruns: int = 0

    def __post_init__(self) -> None:
        self.started = self.clock()

    # ------------------------------------------------------------------ ceilings
    def run_allowance_usd(self) -> float:
        ceiling = float(self.spend["max_usd_per_run"])
        if self.live:
            ceiling = min(ceiling, float(self.spend["authorised_ceiling_usd"]))
        return ceiling

    def remaining_usd(self) -> float:
        return max(0.0, self.run_allowance_usd() - self.committed_usd)

    def elapsed(self) -> float:
        return self.clock() - self.started

    def check_deadline(self) -> None:
        if self.elapsed() >= float(self.limits["max_run_seconds"]):
            raise LimitReached(f"run exceeded max_run_seconds={self.limits['max_run_seconds']}", "max_run_seconds")

    def start_iteration(self) -> None:
        if self.iterations >= int(self.limits["max_iterations"]):
            raise LimitReached(f"reached max_iterations={self.limits['max_iterations']}", "max_iterations")
        self.iterations += 1

    # --------------------------------------------------------------- reservations
    def reserve(self, input_tokens_ub: int, max_output_tokens: int) -> Reservation:
        self.check_deadline()
        lim = self.limits
        if self.attempts >= int(lim["max_api_calls"]):
            raise LimitReached(f"reached max_api_calls={lim['max_api_calls']}", "max_api_calls")
        if input_tokens_ub > int(lim["max_input_tokens_per_call"]):
            raise LimitReached(f"estimated input {input_tokens_ub} tokens exceeds max_input_tokens_per_call="
                               f"{lim['max_input_tokens_per_call']}", "max_input_tokens_per_call")
        if self.input_tokens + input_tokens_ub > int(lim["max_total_input_tokens"]):
            raise LimitReached("max_total_input_tokens would be exceeded", "max_total_input_tokens")
        if self.output_tokens + max_output_tokens > int(lim["max_total_output_tokens"]):
            raise LimitReached("max_total_output_tokens would be exceeded", "max_total_output_tokens")
        usd = self.rates.worst_case_cost(input_tokens_ub, max_output_tokens)
        if usd > float(self.spend["max_usd_per_call"]):
            raise LimitReached(f"worst-case ${usd:.4f} exceeds max_usd_per_call=${self.spend['max_usd_per_call']}",
                               "per_call_cost_ceiling")
        if self.committed_usd + usd > float(self.spend["max_usd_per_run"]):
            raise LimitReached(f"worst-case ${usd:.4f} would exceed max_usd_per_run=${self.spend['max_usd_per_run']} "
                               f"(already ${self.committed_usd:.4f})", "per_run_cost_ceiling")
        if self.live and self.committed_usd + usd > float(self.spend["authorised_ceiling_usd"]):
            raise LimitReached("worst-case spend would exceed the explicitly authorised ceiling "
                               f"${self.spend['authorised_ceiling_usd']}", "authorised_spend_exhausted")
        self.attempts += 1
        self.reserved_total_usd += usd
        self.peak_reservation_usd = max(self.peak_reservation_usd, usd)
        return Reservation(self.attempts, input_tokens_ub, max_output_tokens, usd)

    def commit(self, res: Reservation, input_tokens: int, cached_tokens: int, output_tokens: int,
               reasoning_tokens: int = 0) -> dict:
        res.state = "committed"
        usd = self.rates.cost(input_tokens, cached_tokens, output_tokens)
        self.responses += 1
        self.computed_usd += usd
        self.committed_usd += usd
        self.input_tokens += input_tokens
        self.cached_tokens += min(cached_tokens, input_tokens)
        self.output_tokens += output_tokens
        self.reasoning_tokens += reasoning_tokens
        exceeded = input_tokens > res.input_tokens or output_tokens > res.output_tokens or usd > res.usd + 1e-12
        if exceeded:
            self.overruns += 1
        return {"computed_usd": usd, "exceeded_reservation": exceeded}

    def release(self, res: Reservation) -> None:
        res.state = "released"  # e.g. a 429/4xx the provider rejected before running the model

    def mark_ambiguous(self, res: Reservation) -> None:
        """Timeout / 5xx / dropped connection: assume the worst-case charge happened."""
        res.state = "ambiguous"
        self.ambiguous_usd += res.usd
        self.committed_usd += res.usd
        self.input_tokens += res.input_tokens
        self.output_tokens += res.output_tokens

    def snapshot(self) -> dict:
        return {
            "attempts": self.attempts, "responses": self.responses, "iterations": self.iterations,
            "input_tokens": self.input_tokens, "cached_input_tokens": self.cached_tokens,
            "output_tokens": self.output_tokens, "reasoning_tokens": self.reasoning_tokens,
            "reserved_worst_case_total_usd": round(self.reserved_total_usd, 8),
            "peak_reservation_usd": round(self.peak_reservation_usd, 8),
            "computed_from_reported_usage_usd": round(self.computed_usd, 8),
            "ambiguous_charge_assumed_usd": round(self.ambiguous_usd, 8),
            "committed_usd": round(self.committed_usd, 8),
            "remaining_allowance_usd": round(self.remaining_usd(), 8),
            "reservation_overruns": self.overruns,
            "elapsed_seconds": round(self.elapsed(), 3),
        }
