"""Fail-closed gate in front of any charged (live) execution.

What can and cannot be verified is stated plainly in every receipt:

* Verifiable with the API key (uncharged call): the key works, the selected model is
  retrievable by that key/project, the project header matches ``expected_project``.
* Verifiable with an organization *admin* key (optional): spend since the attestation
  via the Costs API, giving a measured headroom. This cross-check is not available
  from the normal key.
* NOT verifiable programmatically: the active credit-grant balance and expiry, and
  whether auto-recharge is on. No documented API-key endpoint exposes them, so the
  owner must supply a dated attestation read from the billing dashboard. Without a
  fresh, sufficient, unexpired attestation and an explicit spending authorisation the
  runner refuses to make a single charged request.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable

from .errors import GateRefused
from .pricing import PricingUnavailable, Rates, rates_for

_FIRST_FAIL_CODES = {
    "api_key_present": "credentials_missing",
    "spend_authorised": "spend_not_authorised",
    "pricing_known": "pricing_unverifiable",
    "credit_attestation": "credit_unverified",
    "credit_not_expired": "credit_expired",
    "credit_sufficient": "credit_insufficient",
    "auto_recharge_disabled": "auto_recharge_not_disabled",
    "model_attested_eligible": "model_eligibility_unattested",
    "source_clean": "source_dirty",
    "model_retrievable": "model_not_eligible",
    "project_matches": "project_mismatch",
    "costs_crosscheck": "headroom_unverifiable",
}


def _parse_time(value: str) -> dt.datetime:
    if len(value) == 10:
        return dt.datetime.fromisoformat(value).replace(tzinfo=dt.timezone.utc)
    return dt.datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)


def _hash_id(value: str | None) -> str | None:
    return hashlib.sha256(value.encode()).hexdigest()[:12] if value else None


def default_costs_probe(base_url: str, admin_key: str, start_epoch: int, project: str | None,
                        timeout: float = 30) -> float:
    """Sum USD amounts from the organization Costs API since ``start_epoch``. Raises on any problem."""
    query = {"start_time": str(start_epoch), "bucket_width": "1d", "limit": "31"}
    if project:
        query["project_ids"] = project
    request = urllib.request.Request(f"{base_url.rstrip('/')}/organization/costs?{urllib.parse.urlencode(query)}",
                                     headers={"Authorization": f"Bearer {admin_key}"})
    with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310 - host validated in config
        body = json.loads(response.read().decode("utf-8"))
    total = 0.0
    for bucket in body["data"]:
        for result in bucket.get("results", []):
            amount = result["amount"]
            if amount.get("currency", "usd").lower() != "usd":
                raise ValueError("non-USD cost row")
            total += float(amount["value"])
    if body.get("has_more"):
        raise ValueError("costs response is paginated beyond the first page")
    return total


def evaluate(cfg: dict, env: dict, table: dict, now: dt.datetime, model_probe: Callable[[str], dict] | None,
             costs_probe: Callable[..., float] | None, source_dirty: bool | None, base_url: str) -> dict:
    """Return {passed, checks, facts, headroom_basis}; never raises for a failed check."""
    spend, api, model = cfg["spend"], cfg["api"], cfg["model"]
    checks: list[dict] = []
    facts: dict = {"credit_balance_programmatically_verifiable": False,
                   "note": "grant balance/expiry/auto-recharge cannot be read via a supported API-key endpoint; "
                           "the owner attestation is the only source for them"}

    def check(name: str, ok: bool, detail: str) -> bool:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})
        return bool(ok)

    key = env.get(api["key_env"], "")
    key_ok = check("api_key_present", len(key) >= 20 and not re.search(r"\s", key),
                   f"environment variable {api['key_env']} " + ("is set" if key else "is not set"))
    ceiling, per_run = float(spend["authorised_ceiling_usd"]), float(spend["max_usd_per_run"])
    check("spend_authorised", ceiling >= per_run > 0 and bool(spend["authorisation_ref"].strip()),
          f"authorised ceiling ${ceiling:.2f} vs per-run limit ${per_run:.2f}; authorisation reference "
          + ("present" if spend["authorisation_ref"].strip() else "missing"))
    rates: Rates | None = None
    try:
        rates = rates_for(model, table, now.date())
        check("pricing_known", True, f"rates for {model} retrieved {rates.retrieved_utc}")
    except PricingUnavailable as exc:
        check("pricing_known", False, exc.message)
    check("source_clean", source_dirty is False or cfg["task"]["allow_dirty_source"],
          "source checkout is clean" if source_dirty is False else "source checkout is dirty or not a Git checkout")

    att = spend["credit_attestation"]
    headroom_basis, remaining = None, 0.0
    if not check("credit_attestation", att is not None, "owner credit attestation " +
                 ("supplied" if att else "missing: grants cannot be verified automatically")):
        for name in ("credit_not_expired", "credit_sufficient", "auto_recharge_disabled", "model_attested_eligible"):
            check(name, False, "no attestation")
    else:
        checked = _parse_time(att["checked_utc"])
        age_h = (now - checked).total_seconds() / 3600
        fresh = -0.1 <= age_h <= float(spend["attestation_max_age_hours"])
        expiry = _parse_time(att["expires_utc"])
        margin = dt.timedelta(hours=float(spend["credit_expiry_margin_hours"]))
        check("credit_not_expired", fresh and expiry > now + margin,
              f"attestation age {age_h:.1f}h (max {spend['attestation_max_age_hours']}h); "
              f"expires {att['expires_utc']} (required margin {spend['credit_expiry_margin_hours']}h)")
        remaining = float(att["remaining_usd"])
        check("credit_sufficient", att["api_only"] and remaining >= per_run,
              f"attested remaining ${remaining:.2f} vs per-run limit ${per_run:.2f}; "
              + ("grant attested to cover API usage" if att["api_only"] else "grant not attested for API usage"))
        check("auto_recharge_disabled", att["auto_recharge_disabled"], "auto-recharge "
              + ("attested disabled" if att["auto_recharge_disabled"] else "not attested disabled"))
        eligible = att.get("eligible_models") or []
        check("model_attested_eligible", model in eligible or "*" in eligible,
              f"{model} " + ("is" if (model in eligible or "*" in eligible) else "is not") + " in the attested eligible list")
        headroom_basis = "owner-attestation-only"

    admin_key = env.get(spend["costs_key_env"], "")
    if admin_key and att is not None and costs_probe is not None:
        try:
            spent = costs_probe(base_url, admin_key, int(_parse_time(att["checked_utc"]).timestamp()),
                                spend.get("expected_project"))
            headroom = remaining - spent
            check("costs_crosscheck", headroom >= per_run, f"Costs API spend since attestation ${spent:.4f}; "
                  f"measured headroom ${headroom:.2f} vs per-run limit ${per_run:.2f}")
            headroom_basis = "attestation-minus-costs-api"
            facts["costs_api_spend_since_attestation_usd"] = round(spent, 6)
        except Exception as exc:  # noqa: BLE001 - any failure must close the gate
            check("costs_crosscheck", False, f"Costs API cross-check failed: {type(exc).__name__}")
    elif spend["require_costs_crosscheck"]:
        check("costs_crosscheck", False, "cross-check required but no admin key available")

    if key_ok and model_probe is not None and all(c["ok"] for c in checks):
        try:
            probe = model_probe(model)
            check("model_retrievable", probe["status"] == 200,
                  f"models.retrieve({model}) returned HTTP {probe['status']}")
            headers = {k.lower(): v for k, v in probe.get("headers", {}).items()}
            project = headers.get("openai-project")
            facts["organization_id_sha256_12"] = _hash_id(headers.get("openai-organization"))
            facts["project_id_sha256_12"] = _hash_id(project)
            facts["rate_limit_headers"] = {k: headers[k] for k in headers if k.startswith("x-ratelimit-")}
            if spend.get("expected_project"):
                check("project_matches", project == spend["expected_project"],
                      "API project header " + ("matches" if project == spend["expected_project"] else "differs from")
                      + " the expected project")
        except Exception as exc:  # noqa: BLE001
            check("model_retrievable", False, f"model probe failed: {type(exc).__name__}")
    elif key_ok and model_probe is not None:
        check("model_retrievable", False, "skipped: an earlier gate check failed")

    facts["headroom_basis"] = headroom_basis
    return {"performed": True, "passed": all(c["ok"] for c in checks), "checks": checks, "facts": facts,
            "headroom_basis": headroom_basis, "rates": rates}


def enforce(report: dict) -> None:
    if report["passed"]:
        return
    failed = [c for c in report["checks"] if not c["ok"]]
    first = failed[0]
    raise GateRefused("charged execution refused: " + "; ".join(f"{c['name']}: {c['detail']}" for c in failed[:4]),
                      _FIRST_FAIL_CODES.get(first["name"], "live_gate_refused"))
