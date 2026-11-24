"""Authority boundary for repository retrieval; historical search is explicit.

This protects the repository evaluator/ingestion path, not external indexes.
External importers must use the same selection and chunk envelopes and rebuild
older caches. Source prose, including an old 'Approved' status, is never authority.
"""
import json
from pathlib import Path
import re

POLICY_VERSION = "historical-isolation-v1"
HISTORICAL_AUTHORITY = "historical-non-authoritative"
HISTORICAL_PREFIXES = ("docs/history", "docs/audits")


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
    declared = (metadata or {}).get("authority")
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
    is_history = historical_path(path, root) or tagged
    if is_history != historical:
        mode = "historical" if historical else "default"
        raise ValueError(f"Authority boundary: {path.relative_to(root)} is not a {mode} document")
    return HISTORICAL_AUTHORITY if is_history else "current-documentation"
