"""Reproducible offline heading-chunk/BM25 development evaluation, stdlib only.

This measures a fixed lexical baseline, not embedding retrieval or answer truth.
Expected-fact answer sufficiency is separately reviewed and never inferred from
keyword matches. Corpus paths and hashes plus complete top-k contexts are saved.
"""
from __future__ import annotations
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re

try:
    from .retrieval_policy import POLICY_VERSION, HISTORICAL_AUTHORITY, require_authority
except ImportError:  # direct CLI execution
    from retrieval_policy import POLICY_VERSION, HISTORICAL_AUTHORITY, require_authority

STOP = set("a an and are as at be been but by can do does for from had has have how i if in into is it its may me my no not of on or our should so that the their them there these they this those to too was we were what when where which who why will with would you your".split())
FOCUSED = {"architecture", "systems", "operations", "reference", "decisions", "research"}

def tokens(value: str) -> list[str]:
    return [t for t in re.findall(r"[a-z0-9]+", value.lower()) if t not in STOP]

def metadata_and_body(text: str) -> tuple[dict, str]:
    metadata = {}
    if text.startswith("---\n"):
        header, body = text[4:].split("\n---", 1)
        for line in header.splitlines():
            if ":" in line and not line.startswith(" "):
                key, value = line.split(":", 1)
                metadata[key] = value.strip()
        return metadata, body.strip()
    return metadata, text

def selected_paths(root: Path, historical: bool = False) -> list[Path]:
    root = root.resolve()
    docs = root / "docs"
    manifest = docs / ("history/engineering/retrieval-corpus.json" if historical else "reference/retrieval-corpus.json")
    if manifest.exists():
        entries = json.loads(manifest.read_text(encoding="utf-8-sig"))["documents"]
        paths = [(docs / (entry if isinstance(entry, str) else entry["path"])).resolve() for entry in entries]
        if any(not p.is_relative_to(root) for p in paths):
            raise ValueError("Retrieval corpus documents must stay inside the source repository")
        if len(set(paths)) != len(paths):
            raise ValueError("Retrieval corpus has duplicate resolved paths")
        missing = [str(p) for p in paths if not p.is_file()]
        if missing:
            raise ValueError("Missing corpus documents: " + ", ".join(missing))
        for path in paths:
            meta, _ = metadata_and_body(path.read_text(encoding="utf-8-sig"))
            require_authority(path, root, historical=historical, metadata=meta)
        return sorted(paths, key=lambda p: p.relative_to(root).as_posix())
    if historical:
        raise ValueError("Explicit historical corpus manifest is required")
    paths = [p for p in docs.rglob("*.md")
             if p.relative_to(docs).parts[0] in FOCUSED
             or p.relative_to(docs).as_posix() == "README.md"]
    paths.extend(p for p in (root / "README.md", root / "AGENTS.md") if p.exists())
    for path in paths:
        meta, _ = metadata_and_body(path.read_text(encoding="utf-8-sig"))
        require_authority(path, root, historical=False, metadata=meta)
    return sorted(paths, key=lambda p: p.relative_to(root).as_posix())

def split_section(text: str, max_words: int) -> list[str]:
    # A hard cap also handles long lists/tables; no dependence on model tokens.
    words = text.split()
    return [" ".join(words[start:start+max_words]) for start in range(0, len(words), max_words)]

def chunk_document(path: Path, root: Path, max_words: int, historical: bool = False) -> list[dict]:
    path, root = path.resolve(), root.resolve()
    text = path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    meta, body = metadata_and_body(text)
    authority = require_authority(path, root, historical=historical, metadata=meta)
    title = meta.get("title", next((line[2:] for line in body.splitlines() if line.startswith("# ")), path.stem))
    envelope = "\n".join(f"{key}: {meta[key]}" for key in ("document-kind", "status", "scope", "canonical-for", "last-reviewed") if key in meta)
    if historical:
        envelope = (f"authority: {HISTORICAL_AUTHORITY}\nretrieval-mode: explicit-history-only\n"
                    "status: Historical evidence; NOT current instructions or implementation approval\n"
                    f"source-status: {meta.get('status', 'unlabelled')} (historical source label only)\n"
                    f"scope: {meta.get('scope', 'Historical engineering evidence')}\n"
                    f"last-reviewed: {meta.get('last-reviewed', 'unknown')}")
    else:
        envelope = f"authority: {authority}\n" + envelope
    sections = []
    headings = []
    lines = []
    in_fence = False
    def flush():
        if lines:
            sections.append((" > ".join(headings), "\n".join(lines)))
            lines.clear()
    for line in body.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        match = None if in_fence else re.match(r"^(#{1,6})\s+(.+)$", line)
        if match:
            flush()
            level = len(match[1])
            headings = headings[:level-1]
            headings.append(match[2])
        else:
            lines.append(line)
    flush()
    relative = path.relative_to(root / "docs").as_posix() if path.is_relative_to(root / "docs") else "../" + path.name
    result = []
    for heading, text in sections:
        for part, chunk in enumerate(split_section(text, max_words), 1):
            rendered = f"Document: {title}\nPath: {relative}\n{envelope}\nSection: {heading}\n{chunk}"
            result.append({"path": relative, "title": title, "heading": heading, "part": part, "authority": authority, "retrieval_policy": POLICY_VERSION, "text": rendered})
    return result

def evaluate(root: Path, queries: Path, output: Path, k: int, max_words: int, historical: bool = False):
    if k < 1 or max_words < 1:
        raise ValueError("k and max-words must be positive")
    paths = selected_paths(root, historical)
    manifest_path = root / "docs" / ("history/engineering/retrieval-corpus.json" if historical else "reference/retrieval-corpus.json")
    chunks = [c for p in paths for c in chunk_document(p, root, max_words, historical)]
    if not chunks:
        raise ValueError("Retrieval corpus contains no nonempty text chunks")
    counts = [Counter(tokens(c["text"])) for c in chunks]
    lengths = [sum(c.values()) for c in counts]
    mean = sum(lengths) / len(lengths)
    df = Counter(t for c in counts for t in c)
    n = len(chunks)
    fixture = json.loads(queries.read_text(encoding="utf-8-sig"))
    rows = []
    for question in fixture["questions"]:
        words = sorted(set(tokens(question["query"])))
        scores = []
        for index, count in enumerate(counts):
            score = 0.0
            for word in words:
                freq = count[word]
                if freq:
                    idf = math.log(1 + (n-df[word]+0.5)/(df[word]+0.5))
                    score += idf * freq * 2.2 / (freq + 1.2 * (0.25 + 0.75*lengths[index]/mean))
            scores.append((score, index))
        ranked = sorted(scores, key=lambda x: (-x[0], chunks[x[1]]["path"], chunks[x[1]]["heading"], chunks[x[1]]["part"]))[:k]
        hits = [{"rank": i+1, "score": round(score, 6), **chunks[index]} for i, (score, index) in enumerate(ranked)]
        rank = next((h["rank"] for h in hits if h["path"] in question["canonical"]), None)
        rows.append({**question, "canonical_rank": rank, "hits": hits})
    summary = {
        "questions": len(rows), "canonical_hit_at_1": sum(r["canonical_rank"] == 1 for r in rows),
        "canonical_hit_at_k": sum(r["canonical_rank"] is not None for r in rows),
        "mrr_at_k": round(sum(1/r["canonical_rank"] if r["canonical_rank"] else 0 for r in rows)/len(rows), 4),
        "answer_sufficiency": "Requires separate human/model source review. Canonical hits are not answer correctness."
    }
    report = {
        "retrieval_policy": POLICY_VERSION,
        "authority": HISTORICAL_AUTHORITY if historical else "current-documentation",
        "historical_opt_in": historical,
        "link_expansion": False,
        "cache_policy": "No persistent cache is read; external caches require rebuild with this policy and per-chunk authority.",
        "created_utc": datetime.now(timezone.utc).isoformat(), "corpus_root": str(root),
        "method": {"name":"heading-chunk BM25 lexical development baseline", "k":k,"maximum_body_words":max_words,"overlap_words":0,"k1":1.2,"b":0.75,"metadata":"title, path, document-kind, status, scope, canonical-for, last-reviewed, heading path on every chunk when present","query_expansion":False,"stemming":False,"reranker":False,"embeddings":False,"corpus_policy":("explicit isolated historical manifest required; every chunk is historical non-authoritative" if historical else "explicit current manifest if present; otherwise focused directories plus navigation README/AGENTS; historical paths and tagged copies rejected")},
        "fixture_sha256": hashlib.sha256(queries.read_bytes()).hexdigest(),
        "evaluator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "corpus_manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest() if manifest_path.is_file() else None,
        "corpus_manifest": manifest_path.relative_to(root).as_posix(),
        "authority_policy_sha256": hashlib.sha256((Path(__file__).parent / "retrieval_policy.py").read_bytes()).hexdigest(),
        "corpus": [{"path":p.relative_to(root).as_posix(),"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),"bytes":p.stat().st_size} for p in paths],
        "document_count":len(paths),"chunk_count":n,"summary":summary,"results":rows
    }
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
    md = ["# Retrieval contexts for independent answer review", "", "Source-backed expected facts and the complete top-five contexts follow. A canonical route hit alone is not an answer pass.", ""]
    for row in rows:
        md += [f"## {row['id']}: {row['query']}", "", f"Canonical rank: {row['canonical_rank']}", "", "Expected facts:", ""]
        md.extend(f"- {fact}" for fact in row["facts"])
        for hit in row["hits"]:
            md += ["",f"### Rank {hit['rank']}: {hit['path']} — {hit['heading']}","",hit["text"],""]
    output.with_suffix(".contexts.md").write_text("\n".join(md), encoding="utf-8")
    print(json.dumps({"documents":len(paths),"chunks":n,**summary},indent=2))
    for row in rows:
        print(row["id"], "rank="+str(row["canonical_rank"]), row["hits"][0]["path"], "::", row["hits"][0]["heading"])

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2], help="Source repository root, or a pre-rewrite source snapshot")
    parser.add_argument("--queries", type=Path, default=Path(__file__).resolve().parents[2] / "docs/reference/retrieval-questions.json")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--k",type=int,default=5)
    parser.add_argument("--max-words",type=int,default=420)
    parser.add_argument("--historical", action="store_true", help="Explicitly select the isolated historical corpus; never mixes current answers")
    args = parser.parse_args()
    evaluate(args.root.resolve(),args.queries.resolve(),args.output.resolve(),args.k,args.max_words,args.historical)
