#!/usr/bin/env python3
"""Reproduce the bounded documentation closure retrieval evidence, stdlib only.

Run from the delivered checkout. Revision projections contain exact Git bytes for
Markdown, fixed question fixtures and the two evaluator helpers; they deliberately
omit runtimes/images. Current runs additionally exercise missing-manifest discovery
and direct ingestion. This is not an embedding or production answer benchmark.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

SUITES = {
    "frozen": "docs/reference/retrieval-questions.json",
    "challenges": "docs/reference/retrieval-challenges.json",
    "renaissance": "docs/reference/retrieval-questions-docs-renaissance-v1.json",
    "owner-intent": "docs/reference/owner-intent-retrieval-questions.json",
    "historical": "docs/history/engineering/retrieval-questions.json",
}
HELPERS = ["tools/docs/retrieval_eval.py", "tools/docs/retrieval_policy.py"]
BASELINE = "00cdb02f103265b6dc5224c68283e9a0c8cb449f"
RECOVERY = "ddd7c88fd97d8b85056dd7910896ec3a897ecb87"


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def projection(root, target, revision=None):
    rows = []
    if revision:
        records = git(root, "ls-tree", "-r", "-z", revision).split(b"\0")
        files = {}
        for record in records:
            if not record:
                continue
            meta, path = record.split(b"\t", 1)
            mode, kind, blob = meta.decode().split()
            if kind == "blob":
                files[path.decode()] = blob
        candidates = [p for p in files if p in HELPERS or p in {"README.md", "AGENTS.md", "docs/MATERIAL_LAB.md"}
                      or (p.startswith("docs/") and p.endswith(".md") and not p.startswith("docs/audits/"))
                      or p in SUITES.values() or p in {"docs/reference/retrieval-corpus.json", "docs/history/engineering/retrieval-corpus.json"}]
        for relative in sorted(candidates):
            data = git(root, "cat-file", "blob", files[relative])
            path = target / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            rows.append({"path": relative, "git_blob": files[relative], "sha256": digest(path), "bytes": len(data)})
    else:
        candidates = [p for p in root.joinpath("docs").rglob("*.md") if not p.is_relative_to(root / "docs/audits")]
        candidates += [root/p for p in HELPERS + list(SUITES.values()) + ["README.md", "AGENTS.md", "docs/reference/retrieval-corpus.json", "docs/history/engineering/retrieval-corpus.json"]]
        for source in sorted(set(candidates)):
            relative = source.relative_to(root).as_posix()
            target_path = target / relative
            target_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target_path)
            rows.append({"path": relative, "sha256": digest(source), "bytes": source.stat().st_size})
    return rows


def execute(command, cwd, *, timeout=120):
    start = time.monotonic()
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    return {"created_utc": datetime.now(timezone.utc).isoformat(), "command": [str(x) for x in command],
            "working_directory": str(cwd), "exit_code": result.returncode, "elapsed_seconds": round(time.monotonic()-start, 3),
            "stdout": result.stdout, "stderr": result.stderr}


def evaluate(sourcedir, queryroot, output, suites):
    receipts = []
    for name in suites:
        queries = queryroot / SUITES[name]
        outfile = output / (name + ".json")
        command = [sys.executable, str(sourcedir/HELPERS[0]), "--root", str(sourcedir), "--queries", str(queries), "--output", str(outfile)]
        if name == "historical":
            command.append("--historical")
        receipt = execute(command, sourcedir)
        receipt.update({"suite": name, "fixture_sha256": digest(queries), "evaluator_sha256": digest(sourcedir/HELPERS[0]), "policy_sha256": digest(sourcedir/HELPERS[1])})
        if outfile.is_file():
            result = json.loads(outfile.read_text())
            receipt.update({"result_sha256": digest(outfile), "contexts_sha256": digest(outfile.with_suffix(".contexts.md")), "summary": result["summary"], "documents": result["document_count"], "chunks": result["chunk_count"]})
        receipts.append(receipt)
        print(name, receipt["exit_code"], receipt.get("summary"), flush=True)
        if receipt["exit_code"]:
            save(output/"execution-receipts.json", receipts)
            raise RuntimeError(receipt["stderr"])
    save(output/"execution-receipts.json", receipts)
    return receipts


def direct_ingestion(sourcedir):
    sys.path.insert(0, str(sourcedir / "tools/docs"))
    spec = importlib.util.spec_from_file_location("closure_retrieval", sourcedir / HELPERS[0])
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    current = module.selected_paths(sourcedir)
    history = module.selected_paths(sourcedir, historical=True)
    admitted = []
    rejected = []
    for path in current:
        chunks = module.chunk_document(path, sourcedir, 420)
        meta, _ = module.metadata_and_body(path.read_text(encoding="utf-8-sig"))
        declared = meta.get("authority", "current-documentation").strip("\"'")
        assert chunks and all(c["authority"] == declared for c in chunks)
        assert all("authority: " + declared in c["text"] for c in chunks)
        admitted.append({"path": path.relative_to(sourcedir).as_posix(), "sha256": digest(path), "chunks": len(chunks), "authority": declared})
    candidates = [p for p in (sourcedir/"docs").rglob("*.md")
                  if p.relative_to(sourcedir/"docs").parts[0] in module.FOCUSED
                  or p.relative_to(sourcedir/"docs").as_posix() in {"README.md", "MATERIAL_LAB.md"}]
    candidates += [sourcedir/"README.md", sourcedir/"AGENTS.md"]
    for path in sorted(set(candidates)-set(current)):
        try:
            module.chunk_document(path, sourcedir, 420)
        except ValueError as exc:
            rejected.append({"path": path.relative_to(sourcedir).as_posix(), "sha256": digest(path), "reason": str(exc)})
        else:
            raise AssertionError("Unselected document admitted directly: " + str(path))
    historical = []
    for path in history:
        try:
            module.chunk_document(path, sourcedir, 420)
        except ValueError as exc:
            reason = str(exc)
        else:
            raise AssertionError("Historical document admitted in default mode")
        chunks = module.chunk_document(path, sourcedir, 420, historical=True)
        assert all(c["authority"] == "historical-non-authoritative" and "NOT current instructions" in c["text"] for c in chunks)
        historical.append({"path": path.relative_to(sourcedir).as_posix(), "sha256": digest(path), "chunks": len(chunks), "default_refusal": reason})
    return {"status": "passed", "current_direct_documents": admitted, "default_direct_refusals": rejected, "explicit_historical_documents": historical,
            "current_chunk_authority_preserved": True, "historical_envelope_every_chunk": True, "link_expansion": False}


def run(root, output, stage):
    output.mkdir(parents=True, exist_ok=True)
    revision = {"baseline": BASELINE, "recovery": RECOVERY}.get(stage)
    with tempfile.TemporaryDirectory(prefix="docs-closure-" + stage + "-") as temporary:
        source = Path(temporary) / "source"
        source.mkdir()
        rows = projection(root, source, revision)
        save(output/"source-projection.json", {"authority": "historical-non-authoritative", "kind": "exact Git blob projection" if revision else "immutable working-document projection", "source_revision": revision,
             "checkout_head": git(root, "rev-parse", "HEAD").decode().strip(), "source_tree": git(root, "rev-parse", revision+"^{tree}").decode().strip() if revision else None,
             "projection_scope": "Markdown outside audits, selected question fixtures and evaluator/policy helpers; no runtime or image reconstruction", "files": rows, "runner_sha256": digest(__file__)})
        evaluate(source, root, output, SUITES)
        if stage == "candidate":
            save(output/"direct-ingestion.json", direct_ingestion(source))
        if stage in {"baseline", "candidate"}:
            (source/"docs/reference/retrieval-corpus.json").unlink()
            fallback = output/"fallback"
            fallback.mkdir(exist_ok=True)
            evaluate(source, root, fallback, [x for x in SUITES if x != "historical"])
            comparison = []
            for name in SUITES:
                if name == "historical":
                    continue
                manifest = json.loads((output/(name+".json")).read_text())
                fallback_result = json.loads((fallback/(name+".json")).read_text())
                comparison.append({"suite": name, "corpus_equal": manifest["corpus"] == fallback_result["corpus"], "ranked_contexts_equal": manifest["results"] == fallback_result["results"],
                                   "manifest_summary": manifest["summary"], "fallback_summary": fallback_result["summary"],
                                   "extra_paths": sorted({r["path"] for r in fallback_result["corpus"]}-{r["path"] for r in manifest["corpus"]}),
                                   "missing_paths": sorted({r["path"] for r in manifest["corpus"]}-{r["path"] for r in fallback_result["corpus"]})})
            save(output/"manifest-fallback-comparison.json", comparison)
        if stage == "candidate":
            changed = [r["path"] for r in rows if digest(root/r["path"]) != r["sha256"]]
            save(output/"working-corpus-stability.json", {"changed_during_projection_and_run": changed, "stable": not changed})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--stage", choices=["baseline", "recovery", "candidate", "all"], default="all")
    args = parser.parse_args()
    root, output = args.root.resolve(), args.output.resolve()
    for stage in (["baseline", "recovery", "candidate"] if args.stage == "all" else [args.stage]):
        run(root, output/stage, stage)


if __name__ == "__main__":
    main()
