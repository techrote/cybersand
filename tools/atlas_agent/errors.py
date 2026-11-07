"""Exit codes, run statuses and the error hierarchy of the Atlas API agent runner.

Every refusal or failure carries a stable ``reason_code`` that is copied into the
receipt, so #500-style automation can branch on it without parsing prose.
"""
from __future__ import annotations

EXIT_OK = 0
EXIT_USAGE = 2  # invalid or unsafe configuration / arguments
EXIT_GATE = 3  # live (charged) execution refused: credentials/credit/budget not verifiable
EXIT_LIMIT = 4  # a configured limit stopped the run before it finished
EXIT_API = 5  # the API failed (auth, rate limit after bounded retries, malformed response)
EXIT_SANDBOX = 6  # the model or caller tried to cross a filesystem/executable boundary
EXIT_VALIDATION = 7  # a required source validation did not pass
EXIT_SOURCE = 8  # source identity wrong/changed, or publication refused (competing write)
EXIT_INTERNAL = 9  # unexpected runner defect

STATUS_SUCCESS = "success"
STATUS_FAILURE = "failure"
STATUS_STOPPED = "stopped"


class AgentError(Exception):
    """Base class: ``status``/``exit_code``/``reason_code`` become the receipt verdict."""

    exit_code = EXIT_INTERNAL
    status = STATUS_FAILURE
    reason_code = "internal_error"

    def __init__(self, message: str, reason_code: str | None = None):
        super().__init__(message)
        self.message = message
        if reason_code:
            self.reason_code = reason_code


class ConfigError(AgentError):
    exit_code = EXIT_USAGE
    reason_code = "invalid_configuration"


class GateRefused(AgentError):
    exit_code = EXIT_GATE
    reason_code = "live_gate_refused"


class LimitReached(AgentError):
    """A configured ceiling was reached: the run stops cleanly (status ``stopped``)."""

    exit_code = EXIT_LIMIT
    status = STATUS_STOPPED
    reason_code = "limit_reached"


class ApiFailure(AgentError):
    exit_code = EXIT_API
    reason_code = "api_failure"


class SandboxViolation(AgentError):
    exit_code = EXIT_SANDBOX
    reason_code = "sandbox_violation"


class ValidationFailed(AgentError):
    exit_code = EXIT_VALIDATION
    reason_code = "validation_failed"


class SourceChanged(AgentError):
    exit_code = EXIT_SOURCE
    reason_code = "source_identity_rejected"


class ToolError(Exception):
    """A recoverable, model-visible tool failure (bad arguments, no match, ...)."""

    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message
