#!/usr/bin/env python3
"""Execute a sealed mixed-scope holdout without changing questions or scoring.

Both methods use their existing APIs. Historical questions are routed explicitly,
never pooled into current context. Raw context output is optional and reproducible
from the retained fixture, source identities, tool bytes and compact passage hashes.
This executes retrieval, not a language model or answer-correctness evaluator.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def metrics(rows):
    ranks = [row["canonical_rank"] for row in rows]
    return {"questions":len(rows), "top1":sum(r == 1 for r in ranks),
            "top3":sum(r is not None and r <= 3 for r in ranks),
            "top5":sum(r is not None and r <= 5 for r in ranks),
            "mrr_at_5":round(sum(1/r if r else 0 for r in ranks)/len(ranks), 4) if ranks else 0.0}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, required=True)
    parser.add_argument("--expected-fixture-sha256", required=True)
    parser.add_argument("--method", choices=("lexical", "reference"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--contexts", action="store_true")
    args = parser.parse_args()
    root, fixture = args.root.resolve(), args.fixture.resolve()
    if sha(fixture) != args.expected_fixture_sha256:
        raise ValueError("Sealed fixture bytes differ from the independently supplied hash")
    questions = json.loads(fixture.read_text(encoding="utf-8"))["questions"]
    if not questions or len({row["id"] for row in questions}) != len(questions):
        raise ValueError("Holdout questions must be nonempty and uniquely identified")
    if any(type(row.get("historical")) is not bool for row in questions):
        raise ValueError("Every question requires an explicit historical scope")
    sys.path.insert(0, str(root / "tools/docs"))
    baseline = importlib.import_module("retrieval_eval")
    reference = importlib.import_module("knowledge_retrieval") if args.method == "reference" else None
    rows, identities = [], []
    started = time.perf_counter()
    with tempfile.TemporaryDirectory(prefix="sealed-holdout-") as temp:
        for history in (False, True):
            selected = [row for row in questions if row["historical"] == history]
            if not selected:
                continue
            q, output = Path(temp) / "questions.json", Path(temp) / "result.json"
            q.write_text(json.dumps({"questions":selected}), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                if reference:
                    reference.evaluate(reference.Retriever(root, historical=history), q, output, 5, True)
                else:
                    baseline.evaluate(root, q, output, 5, 420, history)
            report = json.loads(output.read_text(encoding="utf-8"))
            identities.append({key:value for key,value in report.items() if key not in ("results", "summary")})
            rows.extend(report["results"])
    by_id = {row["id"]:row for row in rows}
    rows = [by_id[q["id"]] for q in questions]
    authority_errors = []
    for row in rows:
        allowed_authorities = ({"historical-non-authoritative"} if row["historical"]
                               else {"current-documentation", "owner-confirmed-intent"})
        for hit in row["hits"]:
            if hit["authority"] not in allowed_authorities:
                authority_errors.append({"id":row["id"], "path":hit["path"], "authority":hit["authority"]})
            hit["context_sha256"] = hashlib.sha256(hit["text"].encode()).hexdigest()
    git = lambda *a: subprocess.check_output(["git", "-C", str(root), *a], text=True).strip()
    result = {"schema":1, "scope":"Actual retrieval; source/context/answer applicability requires separate review",
              "fixture_sha256":sha(fixture), "method":args.method, "source_head":git("rev-parse", "HEAD"),
              "source_tree":git("rev-parse", "HEAD^{tree}"), "runner_sha256":sha(__file__),
              "tracked_dirty_paths":git("diff", "--name-only", "HEAD").splitlines(),
              "evaluator_sha256":sha(baseline.__file__), "policy_sha256":sha(root / "tools/docs/retrieval_policy.py"),
              "reference_sha256":sha(reference.__file__) if reference else None,
              "seconds":time.perf_counter()-started, "metrics":metrics(rows),
              "current_metrics":metrics([r for r in rows if not r["historical"]]),
              "historical_metrics":metrics([r for r in rows if r["historical"]]),
              "authority_errors":authority_errors, "identities":identities, "results":rows}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.contexts:
        args.output.with_suffix(".contexts.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    for row in rows:
        for hit in row["hits"]:
            del hit["text"]
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"method":args.method, "metrics":result["metrics"], "authority_errors":authority_errors}))
    return bool(authority_errors)


if __name__ == "__main__":
    raise SystemExit(main())
