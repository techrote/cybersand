"""Authority boundary for repository retrieval; historical search is explicit.

This protects the repository evaluator/ingestion path, not external indexes.
External importers must use the same selection and chunk envelopes and rebuild
older caches. Source prose, including an old 'Approved' status, is never authority.
"""
import json
from pathlib import Path
import re

POLICY_VERSION = "historical-isolation-v4"
HISTORICAL_AUTHORITY = "historical-non-authoritative"
HISTORICAL_PREFIXES = ("docs/history", "docs/audits")
FOCUSED = {"architecture", "systems", "operations", "reference", "decisions", "research", "tools"}
DOCUMENT_KINDS = {"contract", "design", "decision", "guide", "runbook", "reference", "evidence", "navigation", "research"}
NAVIGATION = (
    "docs/README.md", "docs/reference/retrieval-index.md", "README.md", "AGENTS.md",
    "CONTRIBUTING.md", "third_party/README.md", "godot/native_extension/README.md",
    ".github/pull_request_template.md",
)


def retrieval_selection(metadata: dict | None = None) -> str:
    """Read selection separately from authority using the flat metadata grammar.

    ``explicit-only`` preserves deliberately excluded execution/research packets
    when the main manifest is unavailable. It grants no authority and does not
    turn a current-path document into a historical one.
    """
    declared = (metadata or {}).get("retrieval", "default")
    if not isinstance(declared, str):
        raise ValueError("Unsupported retrieval selection scalar")
    declared = declared.strip()
    if len(declared) >= 2 and declared[0] == declared[-1] and declared[0] in "\"'":
        declared = declared[1:-1]
    if declared not in {"default", "explicit-only"}:
        raise ValueError("Unsupported retrieval selection scalar")
    return declared


def default_selection_allowed(path: Path, root: Path, metadata: dict | None = None) -> bool:
    """Call after require_authority; never use selection to hide bad authority."""
    metadata = source_frontmatter(path)
    selection = retrieval_selection(metadata)
    relative = path.resolve().relative_to(root.resolve()).as_posix()
    kind = (metadata or {}).get("document-kind")
    if kind is not None:
        if not isinstance(kind, str):
            raise ValueError("Unsupported document-kind scalar")
        kind = kind.strip()
        if len(kind) >= 2 and kind[0] == kind[-1] and kind[0] in "\"'":
            kind = kind[1:-1]
        if kind not in DOCUMENT_KINDS:
            raise ValueError("Unsupported document-kind scalar")
    return (selection != "explicit-only" and relative not in NAVIGATION
            and scalar((metadata or {}).get("status", "Current")) != "Draft"
            and kind not in {"navigation", "evidence", "research"})


def frontmatter_field(line: str) -> tuple[str, str] | None:
    """Read a field in the documented flat metadata subset, or fail closed.

    Both documentation validation and retrieval must recognize the same keys.
    Quoted keys, whitespace before ':' and indented fields must not hide an
    authority declaration. Indented simple-list entries belong to their parent.
    This deliberately does not implement arbitrary YAML keys, anchors or tags.
    """
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return None
    if line[:1].isspace() and stripped.startswith("- "):
        return None
    if ":" not in stripped:
        raise ValueError("Unsupported frontmatter field syntax")
    key, value = stripped.split(":", 1)
    key = key.strip()
    if key.startswith('"'):
        try:
            key = json.loads(key)
        except (ValueError, TypeError) as exc:
            raise ValueError("Unsupported frontmatter key syntax") from exc
    elif key.startswith("'") and key.endswith("'"):
        key = key[1:-1].replace("''", "'")
    if not isinstance(key, str) or not re.fullmatch(r"[a-z][a-z0-9-]*", key):
        raise ValueError("Unsupported frontmatter key syntax")
    return key, value.strip()


def source_frontmatter(path: Path) -> dict[str, str]:
    """Validate exact source metadata independently of a caller's parsed copy.

    Legacy unlabelled documents remain readable by the frozen evaluator. The
    supported agent adapter additionally requires complete current metadata.
    Every declared field, however, must be unambiguous in all ingestion paths.
    """
    text = path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    if not text.startswith("---\n"):
        return {}
    lines = text.splitlines()
    try:
        end = lines.index("---", 1)
    except ValueError as exc:
        raise ValueError("Unterminated frontmatter") from exc
    result = {}
    for line in lines[1:end]:
        field = frontmatter_field(line)
        if field is None:
            continue
        key, value = field
        if key in result:
            raise ValueError("Duplicate frontmatter " + key)
        result[key] = value
    return result


def scalar(value):
    if not isinstance(value, str):
        raise ValueError("Unsupported authority/status metadata scalar")
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1]
    return value


def historical_path(path: Path, root: Path) -> bool:
    """Resolve aliases/symlinks before deciding which authority class applies."""
    relative = path.resolve().relative_to(root.resolve()).as_posix()
    return any(relative == prefix or relative.startswith(prefix + "/")
               for prefix in HISTORICAL_PREFIXES)


def require_authority(path: Path, root: Path, *, historical: bool,
                      metadata: dict | None = None) -> str:
    """Reject crossing between default answers and the opt-in archive."""
    root, path = root.resolve(), path.resolve()
    if not path.is_relative_to(root):
        raise ValueError("Retrieval documents must stay inside the source repository")
    actual = source_frontmatter(path)
    # A stale/forged metadata argument cannot relabel a changed source. Check
    # the authority-bearing scalar fields; lists have different parser forms.
    for key in ("authority", "retrieval", "document-kind", "status"):
        supplied = (metadata or {}).get(key)
        if supplied is not None and (key not in actual or scalar(supplied) != scalar(actual[key])):
            raise ValueError("Source metadata mismatch: " + key)
    declared = actual.get("authority")
    if declared is not None:
        # The repository's small frontmatter reader retains scalar quotes.
        # Recognize its supported spellings; unfamiliar syntax must not silently
        # turn an explicitly tagged historical source into ordinary context.
        if not isinstance(declared, str):
            raise ValueError("Unsupported retrieval authority scalar")
        declared = declared.strip()
        if len(declared) >= 2 and declared[0] == declared[-1] and declared[0] in "\"'":
            declared = declared[1:-1]
        if declared not in {HISTORICAL_AUTHORITY, "current-documentation", "owner-confirmed-intent"}:
            raise ValueError("Unsupported retrieval authority scalar")
    tagged = declared == HISTORICAL_AUTHORITY
    status = scalar(actual["status"]) if "status" in actual else None
    obsolete_status = status in {"Historical", "Superseded", "Obsolete", "Archived"}
    if not historical and status is not None and status not in {"Current", "Approved", "Approved design", "Planned", "Deferred", "Rejected", "Ambiguous", "Draft"} and not obsolete_status:
        raise ValueError("Unsupported current-document status")
    is_history = historical_path(path, root) or tagged or obsolete_status
    if is_history != historical:
        mode = "historical" if historical else "default"
        raise ValueError(f"Authority boundary: {path.relative_to(root)} is not a {mode} document")
    # Intent remains an admitted current source, but its chunk envelope must not
    # silently relabel approved direction as implementation documentation.
    return HISTORICAL_AUTHORITY if is_history else (declared or "current-documentation")
