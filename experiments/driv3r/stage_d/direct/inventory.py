"""Fail-closed inventory for D-1A's offline unittest discovery.

Source inventory is not a substitute for test execution: it establishes that
all expected test modules/methods were available to discovery at one clean
source revision. No held-out policies, native actions or model calls occur.
"""
from __future__ import annotations

import ast
from pathlib import Path

VERSION = "d1a-source-test-inventory/4"
LANE = "experiments/driv3r/stage_d/direct"
# Floors fixed against the independently inspected, 130-method source at
# f969338fe4ece101c283a2a304764cdae662645c, plus this scoped repair.
# New modules require an explicit inventory version/update; extra methods in
# existing modules are counted and must also be discovered and executed.
REQUIRED_METHODS = {
    "test_band_horizon.py": 14,
    "test_budget_oracle.py": 11,
    "test_horizon.py": 7,
    "test_inventory.py": 7,
    "test_line_character.py": 8,
    "test_macro_oracle.py": 7,
    "test_m1_preflight.py": 20,
    "test_offline.py": 15,
    "test_paired.py": 16,
    "test_qualification.py": 10,
    "test_recovery.py": 8,
    "test_target_sweep.py": 6,
    "test_trajectory.py": 9,
    "test_visualize.py": 10,
    "test_wall_progress.py": 9,
}


class TestInventoryError(ValueError):
    """Source tests were removed, hidden or rendered undiscoverable."""


def audit_test_inventory(root: Path) -> dict:
    """Count Python test methods in every expected lane-owned module.

    The enclosing source fence verifies that this tree is Git-clean and pinned
    to the accepted M1 ancestor. Static counts are compared to actual unittest
    discovery *after* execution, so neither missing modules nor under-discovery
    can masquerade as a complete green suite.
    """
    directory = Path(root) / LANE
    found = {path.name: path for path in directory.glob("test_*.py")}
    if set(found) != set(REQUIRED_METHODS):
        raise TestInventoryError(
            "D-1A test module inventory differs from the recorded source: "
            f"missing={sorted(set(REQUIRED_METHODS)-set(found))}, "
            f"unknown={sorted(set(found)-set(REQUIRED_METHODS))}")
    counts: dict[str, int] = {}
    for name, file in sorted(found.items()):
        if file.is_symlink() or not file.is_file():
            raise TestInventoryError(f"Test module is not a regular source file: {name}")
        try:
            tree = ast.parse(file.read_text(encoding="utf-8"), filename=name)
        except (OSError, SyntaxError, UnicodeError) as exc:
            raise TestInventoryError(f"Test module cannot be parsed: {name}") from exc
        count = sum(
            1 for cls in tree.body if isinstance(cls, ast.ClassDef)
            for method in cls.body
            if isinstance(method, (ast.FunctionDef, ast.AsyncFunctionDef))
            and method.name.startswith("test_")
        )
        if count < REQUIRED_METHODS[name]:
            raise TestInventoryError(
                f"Test module {name} lost source methods: {count} "
                f"is below recorded floor {REQUIRED_METHODS[name]}")
        counts[name] = count
    return {"version": VERSION, "method_count": sum(counts.values()),
            "module_method_counts": counts}
