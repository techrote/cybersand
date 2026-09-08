#!/usr/bin/env python3
"""Check current documentation structure without altering historical release hashes.

Standard-library only. This checks metadata, canonical ownership, corpus routes,
relative Markdown links/anchors and retrieval-fixture references. It does not
verify source semantics, runtime evidence, external URLs or retrieval quality.
"""
from __future__ import annotations
import argparse
from collections import Counter
from datetime import date
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
STATUSES = {"Current", "Approved", "Approved design", "Planned", "Deferred", "Rejected", "Ambiguous"}
KINDS = {"contract", "design", "decision", "guide", "runbook", "reference", "evidence", "navigation", "research"}
REQUIRED = {"title", "status", "scope", "last-reviewed", "document-kind", "canonical-for", "related-documents"}
FOCUSED = {"architecture", "systems", "operations", "reference", "decisions", "research"}
NAVIGATION = (
    "docs/README.md", "docs/reference/retrieval-index.md", "README.md", "AGENTS.md",
    "CONTRIBUTING.md", "third_party/README.md", "godot/native_extension/README.md",
    ".github/pull_request_template.md",
)

def metadata(text: str) -> dict:
    """Read the deliberately restricted scalar/inline-list metadata convention."""
    text = text.replace("\r\n", "\n")
    if not text.startswith("---\n") or "\n---" not in text[4:]:
        return {}
    header = text[4:].split("\n---", 1)[0]
    result = {}
    key = None
    for line in header.splitlines():
        if re.match(r"^[a-z][a-z0-9-]*:", line):
            key, value = line.split(":", 1)
            value = value.strip()
            if value.startswith("[") and value.endswith("]"):
                result[key] = [v.strip().strip("\"'") for v in value[1:-1].split(",") if v.strip()]
            elif value:
                result[key] = value.strip("\"'")
            else:
                result[key] = []
        elif key and re.match(r"^\s+-\s+", line) and isinstance(result[key], list):
            result[key].append(re.sub(r"^\s+-\s+", "", line).strip().strip("\"'"))
    return result

def visible_markdown(text: str) -> str:
    return re.sub(r"^\s*(```|~~~).*?^\s*\1\s*$", "", text, flags=re.M | re.S)

def anchors(text: str) -> set[str]:
    text = visible_markdown(text)
    result = set(re.findall(r'<a\s+(?:[^>]*?\s)?(?:id|name)=[\"\']([^\"\']+)', text))
    occurrences = Counter()
    for heading in re.findall(r"^#{1,6}\s+(.+?)(?:\s+#+)?\s*$", text, re.M):
        heading = re.sub(r"\[([^]]+)\]\([^)]+\)", r"\1", heading)
        heading = re.sub(r"<[^>]+>", "", heading)
        slug = re.sub(r"[^\w\- ]", "", heading.lower()).replace(" ", "-")
        count = occurrences[slug]
        occurrences[slug] += 1
        result.add(slug + (f"-{count}" if count else ""))
    return result

def document_paths(manifest: dict, field: str) -> list[str]:
    result = []
    for entry in manifest.get(field, []):
        result.append(entry if isinstance(entry, str) else entry["path"])
    return result

def check(root: Path) -> dict:
    docs = root / "docs"
    errors, warnings = [], []
    manifest_path = docs / "reference/retrieval-corpus.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        selected = document_paths(manifest, "documents")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        return {"status":"failed", "errors":[f"Cannot read corpus manifest: {exc}"], "warnings":[]}
    if not selected:
        errors.append("Retrieval corpus documents must not be empty")
    duplicate = [p for p, count in Counter(selected).items() if count > 1]
    errors.extend(f"Duplicate corpus document: {p}" for p in duplicate)
    owners = {}
    texts = {}
    paths = []
    for relative in selected:
        path = (docs / relative).resolve()
        if not path.is_relative_to(root) or path.suffix.lower() != ".md":
            errors.append(f"Corpus path must be a Markdown file inside the source repository: {relative}")
            continue
        if not path.is_file():
            errors.append(f"Missing corpus document: {relative}")
            continue
        if path.relative_to(root).as_posix() in NAVIGATION:
            errors.append(f"Navigation must be listed separately from default retrieval documents: {relative}")
        if path.is_relative_to(docs / "audits"):
            errors.append(f"Historical audit must stay outside default retrieval documents: {relative}")
        paths.append(path)
        text = path.read_text(encoding="utf-8-sig")
        texts[path] = text
        # Repository README/AGENTS are explicit navigation exceptions.
        if path.parent == root and path.name in {"README.md", "AGENTS.md"}:
            continue
        meta = metadata(text)
        if meta.get("document-kind") == "navigation":
            errors.append(f"Navigation page cannot be a default answer document: {relative}")
        for field in sorted(REQUIRED - meta.keys()):
            errors.append(f"{relative}: missing frontmatter {field}")
        if meta.get("status") not in STATUSES:
            errors.append(f"{relative}: unsupported status {meta.get('status')!r}")
        if meta.get("document-kind") not in KINDS:
            errors.append(f"{relative}: unsupported document-kind {meta.get('document-kind')!r}")
        try:
            date.fromisoformat(str(meta.get("last-reviewed", "")))
        except ValueError:
            errors.append(f"{relative}: last-reviewed must be YYYY-MM-DD")
        for field in ("canonical-for", "related-documents"):
            if not isinstance(meta.get(field), list):
                errors.append(f"{relative}: {field} must be an inline or simple block list")
        for claim in meta.get("canonical-for", []) if isinstance(meta.get("canonical-for"), list) else []:
            if claim in owners:
                errors.append(f"Canonical claim {claim!r} has multiple owners: {owners[claim]} and {relative}")
            owners[claim] = relative
        for related in meta.get("related-documents", []) if isinstance(meta.get("related-documents"), list) else []:
            target = related.split("#", 1)[0]
            if target and not (path.parent / target).exists():
                errors.append(f"{relative}: missing related-documents target {related}")
    excluded = set(document_paths(manifest, "excluded"))
    navigation = document_paths(manifest, "navigation")
    known_navigation = {"README.md", "reference/retrieval-index.md"}
    for path in docs.rglob("*.md"):
        relative = path.relative_to(docs).as_posix()
        if relative.split("/")[0] in FOCUSED and relative not in selected and relative not in excluded and relative not in navigation and relative not in known_navigation:
            errors.append(f"Focused document has no corpus or explicit excluded entry: {relative}")
    # Navigation is checked for links without becoming default answer material.
    link_paths = list(paths)
    for relative in navigation:
        path = (docs / relative).resolve()
        if not path.is_relative_to(root) or path.suffix.lower() != ".md":
            errors.append(f"Navigation path must be a Markdown file inside the source repository: {relative}")
        elif not path.is_file():
            errors.append(f"Missing navigation document: {relative}")
        elif path not in link_paths:
            link_paths.append(path)
    for relative in NAVIGATION:
        path = root / relative
        if path.is_file() and path not in link_paths:
            link_paths.append(path)
    for path in link_paths:
        texts.setdefault(path, path.read_text(encoding="utf-8-sig"))
    # Past audit contents remain immutable and outside link enforcement.
    link_count = 0
    anchor_count = 0
    for path in link_paths:
        relative = path.relative_to(root).as_posix()
        text = visible_markdown(texts[path])
        for match in re.finditer(r"\[[^\]]*\]\((<[^>]+>|[^)]+)\)", text):
            raw = match[1].strip()
            target = raw[1:raw.find(">")].strip() if raw.startswith("<") else re.split(r'\s+[\"\']', raw, 1)[0]
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("//"):
                continue
            url = urlsplit(target)
            resolved = (path.parent / unquote(url.path)).resolve() if url.path else path
            link_count += 1
            if not resolved.exists():
                errors.append(f"{relative}: broken link {target}")
                continue
            if url.fragment and resolved.suffix.lower() == ".md":
                anchor_count += 1
                other = texts.setdefault(resolved, resolved.read_text(encoding="utf-8-sig"))
                if unquote(url.fragment) not in anchors(other):
                    errors.append(f"{relative}: missing heading anchor {target}")
    fixture_path = docs / "reference/retrieval-questions.json"
    question_count = 0
    try:
        fixture = json.loads(fixture_path.read_text(encoding="utf-8-sig"))
        seen = set()
        for question in fixture["questions"]:
            question_count += 1
            qid = question["id"]
            if qid in seen:
                errors.append(f"Duplicate retrieval question ID: {qid}")
            seen.add(qid)
            if not question.get("facts") or not question.get("query"):
                errors.append(f"{qid}: retrieval fixture requires a query and expected facts")
            if not any(c in selected for c in question.get("canonical", [])):
                errors.append(f"{qid}: no canonical route exists in the retrieval corpus")
            for source in question.get("sources", []):
                source_path = source.split("::", 1)[0]
                if not (docs / source_path).exists():
                    errors.append(f"{qid}: missing expected-fact source {source_path}")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(f"Cannot validate retrieval questions: {exc}")
    return {"status":"failed" if errors else "passed", "documents":len(paths), "navigation_link_documents":len(link_paths)-len(paths), "canonical_claims":len(owners), "local_links":link_count, "heading_anchors":anchor_count, "questions":question_count, "errors":errors,"warnings":warnings,
            "limitations":["Does not verify source semantics or runtime claims", "Does not fetch external URLs", "Does not rewrite or reattest historical audits", "Retrieval quality requires the separate lexical evaluation and expected-fact review"]}

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    result = check(args.root.resolve())
    rendered = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
    if args.json:
        args.json.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if result["status"] == "passed" else 1

if __name__ == "__main__":
    sys.exit(main())
