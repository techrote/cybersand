"""Filesystem custody enforced in code: allowed read/write globs, no traversal,
no symlinks/junctions, no hard-linked write targets, atomic bounded writes.

All model-supplied paths are untrusted strings. They are normalised and rejected
before any filesystem access, then every component is checked with ``lstat`` and the
final real path must stay inside the disposable workspace root.
"""
from __future__ import annotations

import hashlib
import os
import re
import stat
from pathlib import Path

from .errors import SandboxViolation, ToolError

ALWAYS_DENY = (".git/**", "**/.git/**", "**/.env", "**/.env.*", "**/*.pem", "**/*.key", "**/id_rsa*", "**/*.p12")
_REPARSE = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
_WIN_RESERVED = re.compile(r"^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$", re.IGNORECASE)


def glob_to_regex(glob: str) -> re.Pattern:
    out, i = [], 0
    while i < len(glob):
        char = glob[i]
        if glob.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif glob.startswith("**", i):
            out.append(".*")
            i += 2
        elif char == "*":
            out.append("[^/]*")
            i += 1
        elif char == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(char))
            i += 1
    return re.compile("^" + "".join(out) + "$")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def is_link(path: Path) -> bool:
    try:
        info = os.lstat(path)
    except OSError:
        return False
    return stat.S_ISLNK(info.st_mode) or bool(getattr(info, "st_file_attributes", 0) & _REPARSE)


def is_inside(child: Path, parent: Path) -> bool:
    a = os.path.normcase(os.path.realpath(child))
    b = os.path.normcase(os.path.realpath(parent))
    return a == b or a.startswith(b.rstrip("\\/") + os.sep)


class PathPolicy:
    """Read/write custody over one workspace root."""

    def __init__(self, root: Path, read: list[str], write: list[str]):
        self.root = Path(root)
        self.read_globs = list(read)
        self.write_globs = list(write)
        self._read = [glob_to_regex(g) for g in self.read_globs]
        self._write = [glob_to_regex(g) for g in self.write_globs]
        self._deny = [glob_to_regex(g) for g in ALWAYS_DENY]

    # ------------------------------------------------------------ normalisation
    @staticmethod
    def normalise(rel: object) -> str:
        if not isinstance(rel, str) or not rel:
            raise SandboxViolation("path must be a non-empty string", "invalid_path")
        if len(rel) > 300 or "\x00" in rel:
            raise SandboxViolation("path too long or contains NUL", "invalid_path")
        if "\\" in rel:
            raise SandboxViolation("backslashes are not allowed in paths", "invalid_path")
        if rel.startswith("/") or re.match(r"^[A-Za-z]:", rel) or rel.startswith("~"):
            raise SandboxViolation(f"absolute path rejected: {rel!r}", "absolute_path")
        segments = rel.split("/")
        for segment in segments:
            if segment in ("", ".", ".."):
                raise SandboxViolation(f"path traversal or empty segment rejected: {rel!r}", "path_traversal")
            if ":" in segment or segment.endswith((" ", ".")) or _WIN_RESERVED.match(segment):
                raise SandboxViolation(f"unsafe path segment rejected: {segment!r}", "invalid_path")
        return "/".join(segments)

    def _walk(self, rel: str) -> Path:
        current = self.root
        for segment in rel.split("/"):
            current = current / segment
            if is_link(current):
                raise SandboxViolation(f"symlink/junction in path rejected: {rel!r}", "symlink_escape")
        if not is_inside(current, self.root):
            raise SandboxViolation(f"path resolves outside the workspace: {rel!r}", "path_traversal")
        return current

    def _matches(self, patterns: list[re.Pattern], rel: str) -> bool:
        return any(p.match(rel) for p in patterns)

    # ------------------------------------------------------------------- checks
    def check_read(self, rel: object) -> tuple[str, Path]:
        clean = self.normalise(rel)
        if self._matches(self._deny, clean):
            raise SandboxViolation(f"path is on the deny list: {clean}", "denied_path")
        if not self._matches(self._read, clean):
            raise SandboxViolation(f"read not permitted outside approved paths: {clean}", "read_not_permitted")
        return clean, self._walk(clean)

    def check_write(self, rel: object) -> tuple[str, Path]:
        clean = self.normalise(rel)
        if self._matches(self._deny, clean):
            raise SandboxViolation(f"path is on the deny list: {clean}", "denied_path")
        if not self._matches(self._write, clean):
            raise SandboxViolation(f"write not permitted outside assigned files: {clean}", "write_not_permitted")
        path = self._walk(clean)
        if path.exists() and os.lstat(path).st_nlink > 1:
            raise SandboxViolation(f"hard-linked write target rejected: {clean}", "hardlink_write")
        return clean, path

    def is_writable(self, rel: str) -> bool:
        try:
            self.check_write(rel)
            return True
        except SandboxViolation:
            return False

    def is_readable(self, rel: str) -> bool:
        try:
            self.check_read(rel)
            return True
        except SandboxViolation:
            return False

    # ------------------------------------------------------------------ file ops
    def read_text(self, rel: object, start_line: int, max_lines: int, max_bytes: int) -> dict:
        clean, path = self.check_read(rel)
        if not path.is_file():
            raise ToolError("not_a_file", f"{clean} is not a file")
        size = path.stat().st_size
        if size > 8_000_000:
            raise ToolError("file_too_large", f"{clean} is {size} bytes; refusing to load")
        data = path.read_bytes()
        if b"\x00" in data[:4096]:
            raise ToolError("binary_file", f"{clean} is binary; use the image tool for PNG captures")
        lines = data.decode("utf-8", errors="replace").splitlines()
        start = max(1, int(start_line))
        picked, used = [], 0
        for number in range(start, min(len(lines), start + max(1, int(max_lines)) - 1) + 1):
            text = lines[number - 1]
            if used + len(text.encode("utf-8")) > max_bytes:
                break
            used += len(text.encode("utf-8")) + 1
            picked.append(text)
        end = start + len(picked) - 1
        return {"path": clean, "sha256": sha256_bytes(data), "bytes": size, "total_lines": len(lines),
                "start_line": start, "end_line": end if picked else start - 1,
                "truncated": end < len(lines), "text": "\n".join(picked)}

    def write_bytes(self, rel: object, content: bytes, max_bytes: int) -> dict:
        clean, path = self.check_write(rel)
        if len(content) > max_bytes:
            raise ToolError("write_too_large", f"{len(content)} bytes exceeds the {max_bytes}-byte edit limit")
        if not path.parent.is_dir():
            raise ToolError("parent_missing", f"parent directory of {clean} does not exist")
        before = sha256_file(path) if path.is_file() else None
        temp = path.with_name(f".{path.name}.agent-tmp-{os.getpid()}")
        try:
            temp.write_bytes(content)
            os.replace(temp, path)
        finally:
            if temp.exists():
                temp.unlink()
        return {"path": clean, "before_sha256": before, "after_sha256": sha256_bytes(content), "bytes": len(content)}

    def replace_text(self, rel: object, old: str, new: str, max_edit_bytes: int, max_file_bytes: int) -> dict:
        clean, path = self.check_write(rel)
        if not path.is_file():
            raise ToolError("not_a_file", f"{clean} does not exist; only existing assigned files can be edited")
        if not isinstance(old, str) or not isinstance(new, str) or not old:
            raise ToolError("bad_arguments", "old_text must be a non-empty string and new_text a string")
        if len(old.encode("utf-8")) + len(new.encode("utf-8")) > max_edit_bytes:
            raise ToolError("edit_too_large", f"old+new text exceeds {max_edit_bytes} bytes")
        data = path.read_bytes()
        if len(data) > max_file_bytes:
            raise ToolError("file_too_large", f"{clean} exceeds the {max_file_bytes}-byte editable size")
        text = data.decode("utf-8")
        count = text.count(old)
        if count == 0:
            raise ToolError("no_match", "old_text was not found (it must match exactly, including whitespace)")
        if count > 1:
            raise ToolError("ambiguous_match", f"old_text matches {count} places; include more context")
        updated = text.replace(old, new, 1).encode("utf-8")
        return self.write_bytes(clean, updated, max(len(updated), 1)) | {
            "bytes_removed": len(old.encode("utf-8")), "bytes_added": len(new.encode("utf-8"))}
