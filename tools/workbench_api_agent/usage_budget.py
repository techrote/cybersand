"""Request/token/time ledger for explicitly authorized, unpriced desktop models.

Unknown prices are not zero prices: this ledger makes no USD ceiling claim.
"""
from __future__ import annotations
from dataclasses import dataclass
import math
import time
from atlas_agent.errors import LimitReached


@dataclass
class UsageReservation:
    attempt: int
    input_tokens: int
    output_tokens: int
    usd: None = None
    state: str = 'open'


def conservative_image_tokens(width: int, height: int) -> int:
    """Generic conservative image estimate, not a provider-verified tariff.

    Use the existing generic 32px/2.46 patch estimate with actual dimensions.
    Actual reported usage still enforces configured limits. This estimate is
    neither a tariff nor a guaranteed bound for an arbitrary chosen model.
    """
    if type(width) is not int or type(height) is not int or width < 1 or height < 1:
        raise ValueError('image dimensions must be positive integers')
    return math.ceil(min(((width + 31) // 32) * ((height + 31) // 32), 30000) * 2.46)


class UsageBudget:
    rates = None
    live = True

    def __init__(self, limits: dict, clock=time.monotonic):
        self.limits = limits
        self.clock = clock
        self.started = clock()
        self.attempts = self.responses = self.iterations = self.rate_limited = 0
        self.input_tokens = self.cached_tokens = self.output_tokens = self.reasoning_tokens = 0
        self.overruns = self.ambiguous_attempts = 0
        self._pending_input = self._pending_output = 0

    def elapsed(self): return self.clock() - self.started
    def run_allowance_usd(self): return None
    def remaining_usd(self): return None

    def check_deadline(self):
        if self.elapsed() >= self.limits['max_run_seconds']:
            raise LimitReached('run deadline reached', 'max_run_seconds')

    def start_iteration(self):
        self.check_deadline()
        if self.iterations >= self.limits['max_model_calls']:
            raise LimitReached('model iteration limit reached', 'max_iterations')
        self.iterations += 1

    def reserve(self, input_tokens_ub, max_output_tokens):
        self.check_deadline()
        lim = self.limits
        if self.attempts >= lim['max_model_calls'] + lim['max_total_retries']:
            raise LimitReached('API request limit reached', 'max_api_calls')
        for value in (input_tokens_ub, max_output_tokens):
            if type(value) is not int or value < 0:
                raise ValueError('token reservation must be a nonnegative integer')
        if input_tokens_ub > lim['max_input_tokens_per_call']:
            raise LimitReached('estimated input exceeds configured per-call limit', 'max_input_tokens_per_call')
        if max_output_tokens > lim['max_output_tokens']:
            raise LimitReached('output reservation exceeds configured limit', 'max_output_tokens')
        if self.input_tokens + self._pending_input + input_tokens_ub > lim['max_total_input_tokens']:
            raise LimitReached('total input limit would be exceeded', 'max_total_input_tokens')
        if self.output_tokens + self._pending_output + max_output_tokens > lim['max_total_output_tokens']:
            raise LimitReached('total output limit would be exceeded', 'max_total_output_tokens')
        self.attempts += 1
        self._pending_input += input_tokens_ub
        self._pending_output += max_output_tokens
        return UsageReservation(self.attempts, input_tokens_ub, max_output_tokens)

    def _close(self, res, state):
        if res.state != 'open': raise ValueError('reservation already settled')
        res.state = state
        self._pending_input -= res.input_tokens
        self._pending_output -= res.output_tokens

    def commit(self, res, input_tokens, cached_tokens, output_tokens, reasoning_tokens=0):
        if any(type(v) is not int or v < 0 for v in (input_tokens, cached_tokens, output_tokens, reasoning_tokens)):
            raise ValueError('reported token usage must be nonnegative integers')
        self._close(res, 'committed')
        self.responses += 1
        self.input_tokens += input_tokens
        self.cached_tokens += min(cached_tokens, input_tokens)
        self.output_tokens += output_tokens
        self.reasoning_tokens += reasoning_tokens
        exceeded = input_tokens > res.input_tokens or output_tokens > res.output_tokens
        if exceeded: self.overruns += 1
        # Input is heuristic for an unpriced model. The output ceiling, however,
        # is the exact per-request value sent to the provider and remains hard.
        if output_tokens > res.output_tokens:
            raise LimitReached('reported output exceeds effective request cap', 'max_output_tokens')
        for value, key in ((input_tokens, 'max_input_tokens_per_call'), (output_tokens, 'max_output_tokens'),
                (self.input_tokens, 'max_total_input_tokens'), (self.output_tokens, 'max_total_output_tokens')):
            if value > self.limits[key]:
                raise LimitReached('reported usage exceeds configured token limit', key)
        return {'computed_usd': None, 'exceeded_reservation': exceeded}

    def release(self, res, rate_limited=False):
        self._close(res, 'released')
        if rate_limited: self.rate_limited += 1

    def mark_ambiguous(self, res):
        self._close(res, 'ambiguous')
        self.ambiguous_attempts += 1
        self.input_tokens += res.input_tokens
        self.output_tokens += res.output_tokens

    def snapshot(self):
        return {'attempts': self.attempts, 'rate_limited_attempts': self.rate_limited,
            'responses': self.responses, 'iterations': self.iterations,
            'input_tokens': self.input_tokens, 'cached_input_tokens': self.cached_tokens,
            'output_tokens': self.output_tokens, 'reasoning_tokens': self.reasoning_tokens,
            'reserved_worst_case_total_usd': None, 'peak_reservation_usd': None,
            'computed_from_reported_usage_usd': None, 'ambiguous_charge_assumed_usd': None,
            'committed_usd': None, 'remaining_allowance_usd': None,
            'cost_status': 'unknown_unpriced_model', 'cash_ceiling_enforced': False,
            'image_token_estimate': 'generic_32px_patch_2.46; not_model_verified',
            'token_accounting': 'reported_usage_plus_reserved_unknown_attempts',
            'ambiguous_attempts': self.ambiguous_attempts, 'reservation_overruns': self.overruns,
            'elapsed_seconds': round(self.elapsed(), 3)}
