#!/usr/bin/env python3
"""Auditable derivation boundary for the separately registered renderer oracle.

This validates a committed source file. It does not execute generated code,
patch a function in memory, or alter any receipt or trace.
"""
from __future__ import annotations

import hashlib
from pathlib import Path


FROZEN_V3_SHA256 = "896126129f035e4ed39f776d6514f562ff0e6815d6ba1132d8f2a685982a3be2"
HEADER = '''#!/usr/bin/env python3
"""Registered Safe/Separate renderer oracle derived from the frozen c90 V3.

The caller must explicitly supply the expected actual render owner. This is a
separate registration/schema, not a modification of historical V3 acceptance.
Every native, terrain, real callback, body, input, Water, material and framebuffer
predicate is otherwise byte-identical to frozen V3. Executable provenance is
independently enforced by run_renderer_comparison before invocation.
"""
'''


def expected_renderer_reducer(frozen: bytes) -> bytes:
    if hashlib.sha256(frozen).hexdigest() != FROZEN_V3_SHA256:
        raise ValueError("Frozen V3 reducer bytes changed")
    text = frozen.decode("utf-8")
    text = text[text.index("from __future__ import annotations"):text.index("\ndef main():")].rstrip() + "\n"
    changes = {
        "def reduce_receipt(path, campaign, project=None, engine=None, arm_letter=None):":
            "def reduce_receipt(path, campaign, project=None, engine=None, arm_letter=None, *, expected_render_thread):",
        'need(data["render_thread"]["runtime"] == data["render_thread"]["requested"] == "safe", "V3 requires the registered Safe rendering owner")':
            'need(expected_render_thread in ("safe", "separate") and data["render_thread"]["runtime"] == data["render_thread"]["requested"] == expected_render_thread, "Actual rendering owner differs from explicit renderer-isolation registration")',
        '"analysis_schema":"pubpres-playability-analysis-v3"':
            '"analysis_schema":"pubpres-final-registered-renderer-analysis-v1"',
    }
    for original, replacement in changes.items():
        if text.count(original) != 1:
            raise ValueError("Renderer derivation no longer has one exact contract boundary")
        text = text.replace(original, replacement)
    return (HEADER + text).encode("utf-8")


def verify_renderer_reducer(root: Path) -> dict:
    frozen = root / "tools/pubpres_playability/results_same_frame.py"
    actual = root / "tools/pubpres_final/results_registered_renderer.py"
    if actual.read_bytes() != expected_renderer_reducer(frozen.read_bytes()):
        raise ValueError("Registered renderer oracle changed a predicate outside its explicit render-owner scope")
    return {"frozen_v3_sha256": FROZEN_V3_SHA256,
            "registered_renderer_sha256": hashlib.sha256(actual.read_bytes()).hexdigest(),
            "acceptance_change": "Explicit expected Safe or Separate actual owner; every other V3 predicate unchanged.",
            "other_changes": "New explanatory docstring and analysis schema; predecessor command-line entry point omitted."}
