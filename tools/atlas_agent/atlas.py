"""Atlas ownership lanes, disposable workspace construction and pack inspection.

The runner never edits the source checkout. It copies the assigned collection (and
the support files its validators read) into a disposable workspace, lets the agent
edit only assigned files there, and exports a patch.
"""
from __future__ import annotations

import hashlib
import json
import re
import shutil
from pathlib import Path

from .errors import ConfigError, SandboxViolation, ToolError, ValidationFailed
from .procs import resolve_executables, run_allowlisted
from .sandbox import PathPolicy, is_link, sha256_file

WORLD_DESIGN = "docs/world-design"

# Source: docs/world-design/QUALITY_BAR.md "Hourly cooperative custody" (art PR #454,
# head c4aab63e at the time of writing). Collections 001-005 / 006-010 / 011-015.
LANES: dict[str, list[str]] = {
    "terrain-art": ["lumen-fault", "chalkbone-coast", "carved-ice-choir", "ashroot-nursery", "emberglass-fumaroles"],
    "ruin-detail": ["silt-clockworks", "signal-orchard", "dust-meridian", "cathedral-of-capacitors", "mirror-marsh"],
    "art-curation": ["drowned-observatory", "ironroot-necropolis", "tectonic-archive", "coral-telegraph",
                     "fallow-carnival"],
}
FIXTURE_LANES: dict[str, list[str]] = {"terrain-art": ["mini-vault"], "ruin-detail": [], "art-curation": []}

SUPPORT_FILES = ("native/include/cybersand/material.hpp", "materials/catalogue/catalogue.json")
INSTRUCTION_FILES = (f"{WORLD_DESIGN}/QUALITY_BAR.md", f"{WORLD_DESIGN}/README.md")
EDITABLE = ("pack.json", "README.md")  # preview.svg is regenerated only by the collection's own script
MAX_FILE_COPY = 6_000_000
MAX_TREE_COPY = 40_000_000


def lanes(fixture: bool) -> dict[str, list[str]]:
    return FIXTURE_LANES if fixture else LANES


def lane_of(collection: str, fixture: bool) -> str | None:
    for lane, members in lanes(fixture).items():
        if collection in members:
            return lane
    return None


def resolve_lane(collection: str, requested: str | None, fixture: bool) -> tuple[str, bool]:
    """Return (lane, writable). A lane may write only collections it owns; any other
    collection is read-only critique for that lane."""
    owner = lane_of(collection, fixture)
    if owner is None:
        raise ConfigError(f"collection {collection!r} is not part of the Atlas ownership table", "unknown_collection")
    if requested is None:
        return owner, True
    return requested, requested == owner


def write_globs(collection: str, writable: bool) -> list[str]:
    if not writable:
        return []
    return [f"{WORLD_DESIGN}/{collection}/{name}" for name in EDITABLE]


def generated_globs(collection: str, writable: bool) -> list[str]:
    """Files only the collection's own render script may regenerate (never edited by the model)."""
    return [f"{WORLD_DESIGN}/{collection}/preview.svg"] if writable else []


def patch_globs(collection: str, writable: bool) -> list[str]:
    return write_globs(collection, writable) + generated_globs(collection, writable)


def read_globs(collection: str, extras: list[str]) -> list[str]:
    globs = [f"{WORLD_DESIGN}/{collection}/**", *INSTRUCTION_FILES, *SUPPORT_FILES]
    for extra in extras:
        globs += [f"{WORLD_DESIGN}/{extra}/pack.json", f"{WORLD_DESIGN}/{extra}/README.md"]
    return globs


def _copy_one(source: Path, target: Path, rel: str, manifest: dict, totals: dict) -> None:
    if is_link(source):
        raise SandboxViolation(f"symlink in the Atlas source rejected: {rel}", "symlink_escape")
    size = source.stat().st_size
    if size > MAX_FILE_COPY:
        raise ConfigError(f"source file {rel} is {size} bytes (limit {MAX_FILE_COPY})", "source_file_too_large")
    totals["bytes"] += size
    if totals["bytes"] > MAX_TREE_COPY:
        raise ConfigError("Atlas source selection exceeds the workspace copy limit", "source_tree_too_large")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    manifest[rel] = {"sha256": sha256_file(target), "bytes": size}


def build_workspace(source_root: Path, collection: str, extras: list[str], work_root: Path) -> dict:
    """Copy only the approved read set; returns {files: {rel: {sha256, bytes}}, manifest_sha256}."""
    source_root = Path(source_root)
    collection_dir = source_root / WORLD_DESIGN / collection
    if not (collection_dir / "pack.json").is_file():
        raise ConfigError(f"{WORLD_DESIGN}/{collection}/pack.json not found under {source_root}", "pack_not_found")
    manifest: dict[str, dict] = {}
    totals = {"bytes": 0}
    for path in sorted(collection_dir.rglob("*")):
        if path.is_dir() and not is_link(path):
            continue
        rel = path.relative_to(source_root).as_posix()
        if "node_modules" in rel.split("/"):
            continue
        _copy_one(path, work_root / rel, rel, manifest, totals)
    for rel in INSTRUCTION_FILES:
        if (source_root / rel).is_file():
            _copy_one(source_root / rel, work_root / rel, rel, manifest, totals)
    pack = json.loads((collection_dir / "pack.json").read_text(encoding="utf-8"))
    pinned = [v for v in (pack.get("source") or {}).values() if isinstance(v, str)]
    for rel in dict.fromkeys([*SUPPORT_FILES, *pinned]):
        try:
            PathPolicy.normalise(rel)
        except SandboxViolation:
            continue
        candidate = source_root / rel
        if candidate.is_file() and rel not in manifest and not candidate.is_symlink():
            _copy_one(candidate, work_root / rel, rel, manifest, totals)
    for extra in extras:
        for name in ("pack.json", "README.md"):
            rel = f"{WORLD_DESIGN}/{extra}/{name}"
            if (source_root / rel).is_file():
                _copy_one(source_root / rel, work_root / rel, rel, manifest, totals)
    digest = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()
    return {"files": manifest, "manifest_sha256": digest, "total_bytes": totals["bytes"]}


def snapshot(root: Path) -> dict[str, str]:
    return {p.relative_to(root).as_posix(): sha256_file(p) for p in sorted(root.rglob("*")) if p.is_file()}


# ----------------------------------------------------------------------- inspection

def inspect_pack(work_root: Path, collection: str) -> dict:
    """Compact, model-sized summary of a pack: metadata, palette, features, scenes."""
    path = work_root / WORLD_DESIGN / collection / "pack.json"
    pack = json.loads(path.read_text(encoding="utf-8"))
    palette = [{"id": m.get("id"), "name": m.get("name"), "rgba": m.get("rgba"), "movable": m.get("movable")}
               for m in pack.get("palette", [])]
    features = []
    for f in pack.get("features", []):
        features.append({"id": f.get("id"), "title": f.get("title"), "size": f.get("size"), "status": f.get("status"),
                         "role": f.get("role"), "anchor": f.get("anchor"),
                         "rectangle_count": len(f.get("rectangles", [])),
                         "variants": sorted((f.get("variants") or {}).keys()) if isinstance(f.get("variants"), dict)
                         else [v.get("id") for v in f.get("variants", []) if isinstance(v, dict)]})
    scenes = {}
    for key in ("scene", "combined_scene", "alternate_scene"):
        scene = pack.get(key)
        if isinstance(scene, dict):
            scenes[key] = {"size": scene.get("size"), "placements": len(scene.get("placements", [])),
                           "foundation_rectangles": len(scene.get("foundation", scene.get("base", [])) or [])}
    return {"collection": collection, "title": pack.get("title"), "schema_id": pack.get("schema_id"),
            "schema_version": pack.get("schema_version"), "status": pack.get("status"),
            "source": pack.get("source"), "palette": palette, "features": features, "scenes": scenes,
            "pack_sha256": sha256_file(path), "total_rectangles": sum(x["rectangle_count"] for x in features),
            "top_level_keys": sorted(pack.keys())}


# --------------------------------------------------------------------- script access

def find_script(work_root: Path, collection: str, stem: str) -> Path | None:
    base = work_root / WORLD_DESIGN / collection
    for suffix in (".py", ".mjs"):
        candidate = base / f"{stem}{suffix}"
        if candidate.is_file():
            return candidate
    return None


def script_argv(script: Path, kind: str, executables: dict[str, str]) -> list[str]:
    """Fixed argument vectors per documented script kind. The model chooses only the kind."""
    text = script.read_text(encoding="utf-8", errors="replace")
    if script.suffix == ".py":
        argv = [executables["python"], "-I", str(script)]
    else:
        if "node" not in executables:
            raise ValidationFailed("node is required for this collection's scripts but was not found", "node_missing")
        argv = [executables["node"], str(script)]
    positional = ["pack.json", "preview.svg"] if re.search(r"\[\s*,\s*,\s*packPath", text) else []
    if kind == "validate":
        return argv
    if kind == "render_check":
        if "--check" not in text:
            raise ValidationFailed("this collection's render script has no --check mode", "render_check_unsupported")
        return [*argv, *positional, "--check"]
    if kind == "render_write":
        return [*argv, *positional, *(["--write"] if "--write" in text else [])]
    raise ConfigError(f"unknown script kind {kind!r}", "unknown_script_kind")


def run_script(work_root: Path, collection: str, kind: str, timeout: float, max_output: int,
               executables: dict[str, str] | None = None) -> dict:
    executables = executables or resolve_executables()
    stem = "validate_pack" if kind == "validate" else "render_pack"
    script = find_script(work_root, collection, stem)
    if script is None:
        raise ValidationFailed(f"{WORLD_DESIGN}/{collection}/{stem}.(py|mjs) not found", "script_not_found")
    argv = script_argv(script, kind, executables)
    before = snapshot(work_root)
    result = run_allowlisted(argv, script.parent, timeout, max_output, executables)
    after = snapshot(work_root)
    changed = sorted(p for p in set(before) | set(after) if before.get(p) != after.get(p))
    allowed = {f"{WORLD_DESIGN}/{collection}/preview.svg"} if kind == "render_write" else set()
    stray = [p for p in changed if p not in allowed]
    result.update({"kind": kind, "script": script.relative_to(work_root).as_posix(),
                   "script_sha256": sha256_file(script),
                   "argv_public": [Path(argv[0]).name, *[Path(a).relative_to(work_root).as_posix()
                                                         if Path(a).is_absolute() else a for a in argv[1:]]],
                   "passed": result["exit_code"] == 0 and not result["timed_out"], "files_changed": changed})
    if stray:
        raise SandboxViolation(f"script wrote outside its assignment: {stray[:5]}", "process_wrote_outside_assignment")
    return result


# ------------------------------------------------------------------- structured edit

_NUMBER = re.compile(r"-?\d+")


def _array_end(text: str, open_index: int) -> int:
    depth = 0
    for index in range(open_index, len(text)):
        if text[index] == "[":
            depth += 1
        elif text[index] == "]":
            depth -= 1
            if depth == 0:
                return index
    raise ToolError("pack_layout_unsupported", "unbalanced rectangles array")


def add_rectangles(pack_text: str, feature_id: str, rects: list, max_rects: int = 60) -> tuple[str, dict]:
    """Append validated ``[x, y, width, height, material]`` rectangles to one feature, preserving the
    file's own layout (inline or one-number-per-line). The spliced text must parse to exactly the old
    pack plus the new rectangles, otherwise the edit is refused."""
    pack = json.loads(pack_text)
    feature = next((f for f in pack.get("features", []) if f.get("id") == feature_id), None)
    if feature is None:
        raise ToolError("unknown_feature", f"no feature {feature_id!r}; use inspect_pack to list feature ids")
    if not rects or len(rects) > max_rects:
        raise ToolError("bad_rectangles", f"provide 1..{max_rects} rectangles per call")
    palette = {m["id"]: m for m in pack.get("palette", [])}
    width, height = feature["size"]
    for rect in rects:
        if not (isinstance(rect, list) and len(rect) == 5 and all(type(v) is int for v in rect)):
            raise ToolError("bad_rectangles", f"each rectangle must be [x, y, width, height, material_id]: {rect!r}")
        x, y, w, h, material = rect
        if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > width or y + h > height:
            raise ToolError("rectangle_out_of_bounds",
                            f"{rect} lies outside the {width}x{height} feature (half-open bounds)")
        if material not in palette:
            raise ToolError("unknown_material", f"material {material} is not in the pack palette")
        if feature.get("status") == "static" and palette[material].get("movable"):
            raise ToolError("movable_in_static", f"material {material} is movable but the feature is static")
    top = re.search(r'\n  "features":\s*\[', pack_text)
    start = top.end() if top else pack_text.index('"features"')
    ident = re.compile(r'"id":\s*"' + re.escape(feature_id) + '"').search(pack_text, start)
    key = re.compile(r'"rectangles":\s*\[').search(pack_text, ident.end()) if ident else None
    if key is None:
        raise ToolError("pack_layout_unsupported", "could not locate the feature's rectangles array")
    close = _array_end(pack_text, key.end() - 1)
    inner = pack_text[key.end():close]
    blocks = list(re.finditer(r"\[[^\[\]]*\]", inner))
    if not blocks:
        raise ToolError("pack_layout_unsupported", "feature has no existing rectangle to copy the layout from")
    last = blocks[-1]
    separator = inner[blocks[-2].end():last.start()] if len(blocks) > 1 else ", "
    at = key.end() + last.end()
    pieces = []
    for rect in rects:
        values = iter(str(v) for v in rect)
        pieces.append(separator + _NUMBER.sub(lambda _m: next(values), last.group(0)))
    new_text = pack_text[:at] + "".join(pieces) + pack_text[at:]
    expected = json.loads(pack_text)
    next(f for f in expected["features"] if f["id"] == feature_id)["rectangles"].extend(rects)
    if json.loads(new_text) != expected:
        raise ToolError("pack_layout_unsupported", "the spliced pack did not parse to the expected content; refused")
    return new_text, {"feature_id": feature_id, "rectangles_added": len(rects),
                      "bytes_added": len(new_text) - len(pack_text)}


def remove_rectangles(pack_text: str, feature_id: str, rects: list, max_rects: int = 60) -> tuple[str, dict]:
    """Remove the last exact match of each rectangle from one feature, preserving layout. The spliced
    text must parse to exactly the old pack minus those entries; a feature keeps at least one rectangle."""
    pack = json.loads(pack_text)
    feature = next((f for f in pack.get("features", []) if f.get("id") == feature_id), None)
    if feature is None:
        raise ToolError("unknown_feature", f"no feature {feature_id!r}; use inspect_pack to list feature ids")
    if not rects or len(rects) > max_rects:
        raise ToolError("bad_rectangles", f"provide 1..{max_rects} rectangles per call")
    existing = [list(r) for r in feature["rectangles"]]
    positions, taken = [], set()
    for rect in rects:
        if not (isinstance(rect, list) and len(rect) == 5 and all(type(v) is int for v in rect)):
            raise ToolError("bad_rectangles", f"each rectangle must be [x, y, width, height, material_id]: {rect!r}")
        index = next((i for i in range(len(existing) - 1, -1, -1) if existing[i] == rect and i not in taken), None)
        if index is None:
            raise ToolError("rectangle_not_found", f"{rect} is not in feature {feature_id!r} (or was already listed)")
        taken.add(index)
        positions.append(index)
    if len(existing) - len(taken) < 1:
        raise ToolError("feature_would_be_empty", "a feature must keep at least one rectangle")
    top = re.search(r'\n  "features":\s*\[', pack_text)
    start = top.end() if top else pack_text.index('"features"')
    ident = re.compile(r'"id":\s*"' + re.escape(feature_id) + '"').search(pack_text, start)
    key = re.compile(r'"rectangles":\s*\[').search(pack_text, ident.end()) if ident else None
    if key is None:
        raise ToolError("pack_layout_unsupported", "could not locate the feature's rectangles array")
    close = _array_end(pack_text, key.end() - 1)
    inner = pack_text[key.end():close]
    blocks = list(re.finditer(r"\[[^\[\]]*\]", inner))
    if len(blocks) != len(existing):
        raise ToolError("pack_layout_unsupported", "rectangle layout did not match the parsed array")
    # rebuild the array from the kept entries using the file's own first separator
    separator = inner[blocks[0].end():blocks[1].start()] if len(blocks) > 1 else ", "
    kept = [blocks[i].group(0) for i in range(len(blocks)) if i not in taken]
    new_inner = inner[:blocks[0].start()] + separator.join(kept) + inner[blocks[-1].end():]
    new_text = pack_text[:key.end()] + new_inner + pack_text[close:]
    expected = json.loads(pack_text)
    target = next(f for f in expected["features"] if f["id"] == feature_id)
    target["rectangles"] = [r for i, r in enumerate(target["rectangles"]) if i not in taken]
    try:
        reparsed = json.loads(new_text)
    except ValueError:
        raise ToolError("pack_layout_unsupported", "the spliced pack did not parse; refused") from None
    if reparsed != expected:
        raise ToolError("pack_layout_unsupported", "the spliced pack did not parse to the expected content; refused")
    return new_text, {"feature_id": feature_id, "rectangles_removed": len(taken),
                      "bytes_added": len(new_text) - len(pack_text)}
