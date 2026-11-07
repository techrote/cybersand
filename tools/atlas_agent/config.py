"""Run configuration: defaults, deep merge, schema validation, cross-field rules."""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path
from urllib.parse import urlparse

from .errors import ConfigError
from .schema import load_schema, validate

CONFIG_SCHEMA_ID = "cybersand.atlas-agent.config/1"
DEFAULT_MODEL = "gpt-5.4-mini"

DEFAULTS: dict = {
    "schema": CONFIG_SCHEMA_ID,
    "mode": "dry-run",
    "model": "",
    "pricing_file": None,
    "api": {
        "key_env": "OPENAI_API_KEY",
        "base_url": None,
        "timeout_seconds": 120,
        "reasoning_effort": "low",
        "image_detail": "high",
    },
    "limits": {
        "max_iterations": 8,
        "max_api_calls": 10,
        "max_retries": 3,
        "backoff_base_seconds": 1.0,
        "backoff_max_seconds": 30.0,
        "max_run_seconds": 900,
        "max_output_tokens_per_call": 4000,
        "max_input_tokens_per_call": 60000,
        "max_total_input_tokens": 200000,
        "max_total_output_tokens": 20000,
        "token_estimate_bytes_per_token": 2.0,
        "max_tool_calls": 40,
        "max_tool_calls_per_response": 4,
        "max_tool_seconds": 120,
        "max_total_tool_seconds": 600,
        "max_tool_output_bytes": 20000,
        "max_malformed_tool_calls": 3,
        "max_sandbox_violations": 2,
        "max_images": 4,
        "max_image_bytes": 3_000_000,
        "max_total_image_bytes": 8_000_000,
        "max_image_edge_pixels": 2048,
        "image_resend_calls": 2,
        "max_read_bytes": 65536,
        "max_edit_bytes": 20000,
        "max_files_edited": 3,
    },
    "spend": {
        "max_usd_per_call": 0.05,
        "max_usd_per_run": 0.25,
        "authorised_ceiling_usd": 0.0,
        "authorisation_ref": "",
        "require_costs_crosscheck": False,
        "costs_key_env": "OPENAI_ADMIN_KEY",
        "expected_project": None,
        "credit_expiry_margin_hours": 24,
        "attestation_max_age_hours": 72,
        "credit_attestation": None,
    },
    "task": {
        "collection": "",
        "lane": None,
        "fixture": False,
        "atlas_root": None,
        "expected_source_sha": None,
        "allow_dirty_source": False,
        "critique_only": False,
        "capture_bundle": None,
        "capture_launcher": None,
        "godot": None,
        "read_extra_collections": [],
        "dry_run_plan": None,
    },
}

_SHA = re.compile(r"^[0-9a-f]{40}$")


def deep_merge(base: dict, override: dict) -> dict:
    merged = copy.deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict) and key != "credit_attestation":
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = copy.deepcopy(value)
    return merged


def validate_base_url(url: str | None) -> None:
    """The API key may only be sent to the OpenAI endpoint or a loopback test server."""
    if url is None:
        return
    parsed = urlparse(url)
    loopback = parsed.hostname in ("127.0.0.1", "localhost", "::1")
    if parsed.scheme == "https" and parsed.hostname == "api.openai.com":
        return
    if parsed.scheme == "http" and loopback:
        return
    raise ConfigError("api.base_url must be https://api.openai.com or a loopback http test server; "
                      "the API key is never sent elsewhere", "unsafe_base_url")


def load_config(path: str | Path | None, overrides: dict | None = None) -> dict:
    """Merge defaults <- file <- overrides, then validate. Raises ConfigError."""
    merged = copy.deepcopy(DEFAULTS)
    if path:
        try:
            loaded = json.loads(Path(path).read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            raise ConfigError(f"cannot read configuration {path}: {exc}", "config_unreadable") from None
        if not isinstance(loaded, dict):
            raise ConfigError("configuration must be a JSON object", "config_unreadable")
        merged = deep_merge(merged, loaded)
    if overrides:
        merged = deep_merge(merged, overrides)
    return check_config(merged)


def check_config(cfg: dict) -> dict:
    problems = validate(cfg, load_schema("config.schema.json"))
    if problems:
        raise ConfigError("invalid configuration: " + "; ".join(problems[:8]), "config_schema_violation")
    validate_base_url(cfg["api"]["base_url"])
    limits, spend, task = cfg["limits"], cfg["spend"], cfg["task"]
    if cfg["mode"] == "live" and not cfg["model"]:
        raise ConfigError("live mode requires an explicit model (no default, no fallback)", "model_not_selected")
    if not cfg["model"]:
        cfg["model"] = DEFAULT_MODEL  # dry-run only: used to price the simulated usage
    if spend["max_usd_per_call"] > spend["max_usd_per_run"]:
        raise ConfigError("spend.max_usd_per_call exceeds spend.max_usd_per_run", "inconsistent_spend_limits")
    if limits["backoff_base_seconds"] > limits["backoff_max_seconds"]:
        raise ConfigError("limits.backoff_base_seconds exceeds backoff_max_seconds", "inconsistent_backoff")
    if limits["max_image_bytes"] > limits["max_total_image_bytes"]:
        raise ConfigError("limits.max_image_bytes exceeds max_total_image_bytes", "inconsistent_image_limits")
    if limits["max_tool_seconds"] > limits["max_total_tool_seconds"]:
        raise ConfigError("limits.max_tool_seconds exceeds max_total_tool_seconds", "inconsistent_tool_limits")
    if not task["collection"]:
        raise ConfigError("task.collection is required", "collection_required")
    sha = task["expected_source_sha"]
    if sha is not None and not _SHA.fullmatch(sha):
        raise ConfigError("task.expected_source_sha must be a full 40-hex lowercase Git SHA", "invalid_source_sha")
    return cfg
