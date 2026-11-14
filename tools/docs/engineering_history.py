"""Validate the #571 capture and regenerate its human-readable views (stdlib).

This tool does not contact GitHub, change ticket state, infer owner approval or
run experiments. JSON records are the maintained facts; Markdown views derive
from them. Narrative family analyses remain separately authored evidence.
"""
from __future__ import annotations
import argparse
from collections import Counter
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
AUTHORITY = "historical-non-authoritative"


def load(root: Path):
    archive = root / "docs/history/engineering"
    return archive, json.loads((archive / "coverage.json").read_text(encoding="utf-8")), json.loads((archive / "findings.json").read_text(encoding="utf-8"))


def validate(root: Path, *, check_links: bool = True) -> dict:
    archive, coverage, register = load(root)
    errors = []
    expected = set(coverage["scope"]["baseline_open_ids"]) | set(coverage["scope"]["intake_delta_ids"])
    items = coverage["items"]
    numbers = [r["number"] for r in items]
    for n, count in Counter(numbers).items():
        if count != 1:
            errors.append(f"Duplicate item #{n}")
    expected_all = expected | set(coverage["scope"]["closed_reference_ids"])
    if set(numbers) != expected_all:
        errors.append("Ledger differs from the complete frozen intake universe")
    assessed = {r["number"] for r in items if r["scope_role"] != "closed-reference"}
    if assessed != expected:
        errors.append(f"Scope mismatch: missing={sorted(expected-assessed)}, extra={sorted(assessed-expected)}")
    findings = register["findings"]
    ids = [r["id"] for r in findings]
    if len(ids) != len(set(ids)):
        errors.append("Duplicate finding IDs")
    for container in (coverage, register):
        if container.get("authority") != AUTHORITY:
            errors.append("Historical container lost its authority envelope")
    for row in items:
        number = row["number"]
        if row.get("authority") != AUTHORITY:
            errors.append(f"#{number}: authority envelope missing")
        if row.get("retirement_state") != "not-authorised":
            errors.append(f"#{number}: M1 cannot authorise retirement")
        if row["scope_role"] == "closed-reference":
            continue
        for field in ("family", "coverage_depth", "assessment_state", "confidence", "summary",
                      "ticket_fate", "idea_fate", "code_fate", "evidence_fate", "sources", "limitations"):
            if not row.get(field):
                errors.append(f"#{number}: missing {field}")
        if not row["coverage_depth"].startswith(("D2", "D3", "D4")):
            errors.append(f"#{number}: title/metadata review is insufficient for an in-scope assessment")
        for finding in row.get("findings", []):
            if finding not in ids:
                errors.append(f"#{number}: unknown finding {finding}")
        destination = archive / row["transfer"]["destination"]
        if not destination.is_file():
            errors.append(f"#{number}: missing transfer destination {destination}")
    for finding in findings:
        if finding.get("authority") != AUTHORITY:
            errors.append(f"{finding['id']}: authority envelope missing")
        for field in ("claim", "rationale", "scope", "source_urls", "validity", "transfer"):
            if not finding.get(field):
                errors.append(f"{finding['id']}: missing {field}")
        if finding["type"] not in {"doctrine", "salvage", "negative", "opportunity"}:
            errors.append(f"{finding['id']}: unknown finding type")
        if finding["type"] == "doctrine" and finding["validity"] not in {"still valid", "superseded", "contradicted", "partially valid", "unverified"}:
            errors.append(f"{finding['id']}: unknown doctrine validity")
        if any(not str(url).startswith("https://") for url in finding["source_urls"]):
            errors.append(f"{finding['id']}: non-HTTPS source reference")
        if not (archive / finding["transfer"]["destination"]).is_file():
            errors.append(f"{finding['id']}: missing destination")
    for path in archive.rglob("*.md"):
        text = path.read_text(encoding="utf-8")
        if not text.startswith("---\n") or f"authority: {AUTHORITY}\n" not in text.split("\n---", 1)[0] + "\n":
            errors.append(f"{path.relative_to(archive)}: missing historical document envelope")
        for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("//"):
                continue
            raw_path = unquote(urlsplit(target).path)
            if check_links and raw_path and not (path.parent / raw_path).exists():
                errors.append(f"{path.relative_to(archive)}: missing local link {target}")
    return {"status": "failed" if errors else "passed", "scope_items": len(expected),
            "ledger_items": len(items), "closed_reference_items": len(items)-len(expected),
            "findings": len(findings), "protected_scope_items": sum(bool(r.get("protected")) for r in items if r["number"] in expected),
            "errors": errors,
            "limits": ["Structural/source-link checks do not prove semantic correctness or owner acceptance",
                       "Historical closure and merge remain separately unauthorised"]}


def envelope(title: str) -> str:
    return ("---\n" + f"title: {title}\nstatus: Historical\ndocument-kind: evidence\n"
            + f"authority: {AUTHORITY}\nretrieval: explicit-history-only\n"
            + "scope: Generated historical engineering view; no current instructions or execution permission\n"
            + "last-reviewed: 2026-11-14\n---\n\n" + f"# {title}\n\n"
            + "**Historical, non-authoritative.** Generated from the maintained JSON records; "
            + "do not edit this view independently. Source statements retain their original scope.\n\n")


def escape(value) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def generated(root: Path) -> dict[str, str]:
    archive, coverage, register = load(root)
    items = [r for r in coverage["items"] if r["scope_role"] != "closed-reference"]
    outputs = {}
    text = envelope("Individual coverage and four-asset dispositions")
    text += ("Every baseline open item and intake delta has its own row. The complete four fates, "
             "confidence, limitations, exact PR identities and sources live in [coverage.json](../coverage.json). "
             "Closed records are indexed there separately; indexing is not an exhaustive adjudication.\n\n")
    for family in sorted({r["family"] for r in items}):
        rows = sorted((r for r in items if r["family"] == family), key=lambda r:r["number"])
        text += f"## {family}\n\n| Item | Depth / protection | Assessment and ticket disposition |\n|---|---|---|\n"
        for row in rows:
            depth = row["coverage_depth"] + ("; PROTECTED" if row.get("protected") else "")
            text += f"| [#{row['number']}]({row['url']}) — {escape(row['title'])} | {escape(depth)} | {escape(row['summary'])} **Ticket:** {escape(row['ticket_fate'])} |\n"
        text += "\n"
    outputs["views/coverage.md"] = text
    for name, title, types in (
        ("salvage", "Technical salvage and negative knowledge", {"salvage", "negative"}),
        ("doctrine", "Historical doctrine and constraints", {"doctrine"}),
        ("opportunities", "Surviving opportunities for later reconciliation", {"opportunity"}),
    ):
        text = envelope(title)
        text += "Canonical successor issues have not been created. These findings are inputs for discussion, not approved implementation briefs.\n\n"
        for row in register["findings"]:
            if row["type"] not in types:
                continue
            text += f"## {row['id']} — {row['type']}\n\n{row['claim']}\n\n"
            text += f"**Rationale:** {row['rationale']}\n\n**Scope / validity:** {row['scope']} — {row['validity']}\n\n"
            if row.get("validity_detail"):
                text += f"**Validity qualification:** {row['validity_detail']}\n\n"
            text += f"**Transfer:** [{row['transfer']['destination']}](../{row['transfer']['destination']}); {row['transfer']['verification']}.\n\n"
            text += "**Sources:** " + " · ".join(f"[source {i+1}]({u})" for i,u in enumerate(row["source_urls"])) + "\n\n"
        outputs[f"views/{name}.md"] = text
    return {name: text.rstrip() + "\n" for name, text in outputs.items()}


def check(root: Path) -> dict:
    """Structural and generated-view gate used by normal documentation CI."""
    result = validate(root)
    if result["errors"]:
        return result
    archive = root / "docs/history/engineering"
    for relative, text in generated(root).items():
        path = archive / relative
        if not path.exists() or path.read_text(encoding="utf-8") != text:
            result["errors"].append(f"Generated view is stale: {relative}")
    result["status"] = "failed" if result["errors"] else "passed"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "render", "check"))
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    result = validate(args.root, check_links=args.command != "render")
    if result["errors"]:
        print(json.dumps(result, indent=2)); return 1
    if args.command in {"render", "check"}:
        archive = args.root / "docs/history/engineering"
        for relative, text in generated(args.root).items():
            path = archive / relative
            if args.command == "render":
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            elif not path.exists() or path.read_text(encoding="utf-8") != text:
                result["errors"].append(f"Generated view is stale: {relative}")
        result["status"] = "failed" if result["errors"] else "passed"
    if args.command == "render":
        result = validate(args.root)
    print(json.dumps(result, indent=2))
    return bool(result["errors"])


if __name__ == "__main__":
    raise SystemExit(main())
