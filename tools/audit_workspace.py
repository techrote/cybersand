#!/usr/bin/env python3
"""Record differences from the acquired source snapshot, without changing it."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source"
provenance = json.loads((ROOT / "SOURCE-PROVENANCE.json").read_text())
changes = []
pointers = []
native_files = 0
native_unchanged = 0
for entry in provenance["files"]:
    path = SOURCE / entry["path"]
    digest = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
    if digest != entry["sha256"]:
        changes.append({"path": entry["path"], "original_sha256": entry["sha256"], "current_sha256": digest})
    if path.is_file() and path.stat().st_size < 1024 and path.read_bytes().startswith(b"version https://git-lfs.github.com/spec/v1"):
        pointers.append(entry["path"])
    if entry["path"].startswith("native/"):
        native_files += 1
        native_unchanged += digest == entry["sha256"]
result = {"base_commit": provenance["commit"], "original_files": len(provenance["files"]), "changes": changes,
          "remaining_lfs_pointers": pointers, "native_files": native_files, "native_files_unchanged": native_unchanged}
(ROOT / "validation/source-audit.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
raise SystemExit(0 if native_files == native_unchanged else 1)
