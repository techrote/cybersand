"""Official OpenAI Python SDK wrapper: one place that talks to the Responses API.

The SDK's own retries are disabled (``max_retries=0``); this module owns a bounded
retry loop so that *every* attempt is reserved against the budget first. Error
classes decide whether a reservation is released (provably not charged) or kept as
possibly-charged (timeouts, 5xx, dropped connections).
"""
from __future__ import annotations

import random
import time
from typing import Callable

from .budget import Budget
from .errors import ApiFailure, GateRefused, LimitReached

_QUOTA_WORDS = ("quota", "billing", "spend limit", "hard limit", "credit", "balance")
_QUOTA_CODES = ("insufficient_quota", "billing_hard_limit_reached", "billing_not_active")


def sdk_version() -> str | None:
    try:
        import openai
        return getattr(openai, "__version__", None)
    except ImportError:
        return None


def make_sdk_client(api_key: str, base_url: str | None, timeout: float):
    try:
        from openai import OpenAI
    except ImportError:
        raise GateRefused("the official 'openai' Python package is not installed "
                          "(pip install -r tools/atlas_agent/requirements.txt)", "sdk_missing") from None
    kwargs = {"api_key": api_key, "max_retries": 0, "timeout": timeout}
    if base_url:
        kwargs["base_url"] = base_url
    return OpenAI(**kwargs)


def _error_text(exc) -> tuple[str, str]:
    body = getattr(exc, "body", None)
    code = ""
    if isinstance(body, dict):
        inner = body.get("error", body)
        if isinstance(inner, dict):
            code = str(inner.get("code") or inner.get("type") or "")
    return code, str(getattr(exc, "message", exc))[:300]


class ApiClient:
    def __init__(self, sdk, limits: dict, sleep: Callable[[float], None] = time.sleep,
                 rng: random.Random | None = None):
        self.sdk, self.limits, self.sleep = sdk, limits, sleep
        self.rng = rng or random.Random(0xA71A5)
        self.rate_limit_headers: dict[str, str] = {}

    # uncharged capability probe used by the live gate
    def probe_model(self, model: str) -> dict:
        import openai
        try:
            raw = self.sdk.models.with_raw_response.retrieve(model)
            return {"status": 200, "headers": dict(raw.headers)}
        except openai.NotFoundError:
            return {"status": 404, "headers": {}}
        except openai.PermissionDeniedError:
            return {"status": 403, "headers": {}}
        except openai.AuthenticationError:
            return {"status": 401, "headers": {}}

    def backoff_delay(self, attempt: int, retry_after: float | None) -> float:
        base, cap = float(self.limits["backoff_base_seconds"]), float(self.limits["backoff_max_seconds"])
        delay = min(cap, base * (2 ** attempt))
        delay *= 1 + self.rng.uniform(-0.2, 0.2)
        if retry_after is not None:
            delay = max(delay, min(retry_after, cap))
        return max(0.0, min(delay, cap))

    def respond(self, budget: Budget, request: dict, input_tokens_ub: int, max_output_tokens: int) -> dict:
        """One logical call with bounded retries. Returns response + accounting."""
        import openai
        events: list[dict] = []
        retries = int(self.limits["max_retries"])
        for attempt in range(retries + 1):
            reservation = budget.reserve(input_tokens_ub, max_output_tokens)  # may raise LimitReached
            started = time.monotonic()
            failure, retry_after, charged = None, None, False
            try:
                raw = self.sdk.responses.with_raw_response.create(**request)
                response = raw.parse()
                headers = {k.lower(): v for k, v in dict(raw.headers).items()}
                self.rate_limit_headers = {k: v for k, v in headers.items() if k.startswith("x-ratelimit-")}
                return {"response": response, "reservation": reservation, "retries": attempt, "events": events,
                        "duration_ms": int((time.monotonic() - started) * 1000), "request_id": headers.get("x-request-id")}
            except openai.RateLimitError as exc:
                code, message = _error_text(exc)
                budget.release(reservation)
                if code in _QUOTA_CODES or any(w in message.lower() for w in _QUOTA_WORDS):
                    raise ApiFailure(f"provider reports exhausted credit/spend limit ({code or 'rate-limit-error'}); "
                                     "stopping instead of retrying", "credit_exhausted") from None
                failure, retry_after = "rate_limited", _retry_after(exc)
            except (openai.APITimeoutError, openai.APIConnectionError):
                budget.mark_ambiguous(reservation)
                failure, charged = "timeout_or_connection", True
            except openai.InternalServerError as exc:
                budget.mark_ambiguous(reservation)
                failure, retry_after, charged = f"server_error_{exc.status_code}", _retry_after(exc), True
            except openai.APIStatusError as exc:
                code, message = _error_text(exc)
                if exc.status_code == 408:
                    budget.mark_ambiguous(reservation)
                    failure, charged = "request_timeout_408", True
                else:
                    budget.release(reservation)
                    reason = "api_authentication" if exc.status_code in (401, 403) else "api_request_rejected"
                    raise ApiFailure(f"API rejected the request (HTTP {exc.status_code} {code}): {message}",
                                     reason) from None
            except openai.OpenAIError as exc:
                budget.mark_ambiguous(reservation)
                raise ApiFailure(f"unexpected SDK error {type(exc).__name__}", "api_unexpected_response") from None
            events.append({"attempt": attempt + 1, "kind": failure, "possibly_charged": charged})
            if attempt >= retries:
                raise ApiFailure(f"API still failing after {retries} bounded retries ({failure})",
                                 "api_retries_exhausted" if failure != "rate_limited" else "rate_limit_retries_exhausted")
            delay = self.backoff_delay(attempt, retry_after)
            if budget.elapsed() + delay >= float(budget.limits["max_run_seconds"]):
                raise LimitReached("no time left for another retry within max_run_seconds", "max_run_seconds")
            events[-1]["delay_seconds"] = round(delay, 3)
            self.sleep(delay)
        raise ApiFailure("retry loop ended unexpectedly", "api_failure")  # pragma: no cover


def _retry_after(exc) -> float | None:
    try:
        value = exc.response.headers.get("retry-after")
        return float(value) if value is not None else None
    except (AttributeError, ValueError):
        return None


def usage_of(response) -> dict | None:
    usage = getattr(response, "usage", None)
    if usage is None:
        return None
    details = getattr(usage, "input_tokens_details", None)
    out_details = getattr(usage, "output_tokens_details", None)
    return {"input_tokens": int(usage.input_tokens or 0),
            "cached_tokens": int(getattr(details, "cached_tokens", 0) or 0),
            "output_tokens": int(usage.output_tokens or 0),
            "reasoning_tokens": int(getattr(out_details, "reasoning_tokens", 0) or 0)}
