"""Exact-source structural cost census for B2 prototype, not a timing benchmark.

Run from research/solver-certificates/invalidation/: python3 scan_floor.py
Refuses to analyse modified B2 source/evidence without explicit requalification.
"""
from __future__ import annotations

import ast
import hashlib
import json
from pathlib import Path

MODEL_BLOB = "30606f77cf353bf552383f224a80afe880da92a5"
EVIDENCE_BLOB = "6333dc07c07dcec15db12ab3f077e3a188727b06"


def git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\x00" + data).hexdigest()


def require_source_shape(source: str) -> None:
    tree = ast.parse(source)
    classes = [n for n in tree.body if isinstance(n, ast.ClassDef)]
    def method(owner: str, name: str) -> ast.FunctionDef:
        cls = next(c for c in classes if c.name == owner)
        return next(f for f in cls.body if isinstance(f, ast.FunctionDef) and f.name == name)
    def calls(node: ast.AST) -> set[str]:
        return {ast.unparse(n) for n in ast.walk(node) if isinstance(n, ast.Call)}
    copy_calls = calls(method("State", "copy"))
    step_calls = calls(method("Cached", "step"))
    baseline = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "full_step")
    required = {
        "State.copy() copies every cell": "self.cells.copy()" in copy_calls,
        "Cached.step() takes full snapshot": "s.copy()" in step_calls,
        "Cached.step() copies full output": "old.cells.copy()" in step_calls,
        "Cached.step() compares every cell": "enumerate(zip(old.cells, output))" in step_calls,
        "full_step() takes same snapshot": "s.copy()" in calls(baseline),
    }
    failures = [label for label, valid in required.items() if not valid]
    if failures:
        raise ValueError("source-shape changed: " + "; ".join(failures))


def census(source: bytes, evidence: bytes) -> list[dict]:
    if git_blob(source) != MODEL_BLOB or git_blob(evidence) != EVIDENCE_BLOB:
        raise ValueError("source/evidence blob changed: do not reuse historical totals")
    require_source_shape(source.decode("utf-8"))
    doc = json.loads(evidence)
    assert doc["source_main"] == "d4b18e7f06839b35c8f6a66195206da0f33c5fa3"
    out = []
    for row in doc["profiles"]:
        n = row["full_calls"]
        assert row["ticks"] == 64 and n == 24 * 16 * 64
        assert n == row["incremental_calls"] + row["skipped_calls"]
        assert row["abstract_work_units"] == row["incremental_calls"] + row["probe_calls"] + row["halo_sites"]
        out.append({
            "profile": row["profile"], "logical_shards": row["logical_shards"],
            "full_rule_calls": n, "cached_rule_calls": row["incremental_calls"],
            "proof_rule_calls": row["probe_calls"],
            "common_snapshot_cell_copies": n,
            "additional_cached_output_cell_copies": n,
            "additional_cached_pair_comparisons": n,
            "extra_cached_linear_traversals": 2 * n,
            "total_cached_linear_traversals": 3 * n,
            "reported_abstract_work_units_exclude_traversals": row["abstract_work_units"],
        })
    assert {x["profile"] for x in out} == {"quiet", "mixed", "dense", "churn"}
    assert len(out) == 8
    return out


def _selftest() -> None:
    example = """class State:
 def copy(self):
  return State(self.cells.copy())
class Cached:
 def step(self):
  old = s.copy()
  output = old.cells.copy()
  changed = {i for i, (a,b) in enumerate(zip(old.cells, output)) if a != b}
def full_step(s):
 old = s.copy()
"""
    require_source_shape(example)
    try:
        require_source_shape(example.replace("zip(old.cells, output)", "zip([], [])"))
    except ValueError:
        pass
    else:
        raise AssertionError("missing linear diff failed to invalidate audit")
    print("structural selftest PASS (not the published model)")


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--selftest":
        _selftest()
    else:
        root = Path(__file__).resolve().parent
        result = census((root / "model.py").read_bytes(), (root / "evidence.json").read_bytes())
        print(json.dumps(result, indent=2, sort_keys=True))
