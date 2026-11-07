"""Pure-Python helpers for the unattended world-art capture mode.

Used by tools/world_art_preview_launcher.py --capture. Nothing here renders: all
pixels come from the Godot runner (godot/tools/world_art_capture.gd). These helpers
validate arguments, identify the art source, guard it against mutation, scan Godot
logs, validate PNG evidence independently of Godot and verify/compare bundles.
Standard library only.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import zlib

SCHEMA_BATCH = "cybersand.world_art_capture.batch-manifest/1"
SCHEMA_JOB = "cybersand.world_art_capture.job-manifest/1"
SCHEMA_REQUEST = "cybersand.world_art_capture.request/1"

EXIT_OK = 0
EXIT_USAGE = 2  # invalid arguments / unreadable input / unsafe output location
EXIT_ENGINE = 3  # Godot executable missing or unusable
EXIT_RENDER = 4  # Godot failed, timed out, logged a shader/script error or a job failed
EXIT_EVIDENCE = 5  # PNG/manifest evidence missing, inconsistent or invalid
EXIT_SOURCE_CHANGED = 6  # the read-only art source was modified during capture
EXIT_NO_DISPLAY = 7  # no graphical display (headless / no X11)

# Mirrors COLLECTION_ORDER in godot/tools/world_art_preview.gd (tested for equality).
COLLECTION_ORDER = (
    "lumen-fault", "chalkbone-coast", "carved-ice-choir", "ashroot-nursery",
    "emberglass-fumaroles", "silt-clockworks", "signal-orchard", "dust-meridian",
    "cathedral-of-capacitors", "mirror-marsh", "drowned-observatory",
    "ironroot-necropolis", "tectonic-archive", "coral-telegraph", "fallow-carnival",
)
MAX_SIDE = 16384
MAX_PIXELS = 50_000_000
ZOOM_MIN = 0.03
ZOOM_MAX = 32.0
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
# Godot diagnostics that mean the render cannot be trusted even if the process exits 0.
LOG_ERROR_PATTERN = re.compile(
    r"SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error|Shader compilation failed|"
    r"Error loading extension|Failed to compile|"
    r"Unable to create DisplayServer|Could not initialize display|"
    r"Can't connect to X11|Failed to create (?:the )?window|OpenGL .* (?:not supported|failed)",
    re.IGNORECASE)


class CaptureError(Exception):
    """A failure with a stable exit code and an actionable message."""

    def __init__(self, code: int, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


# ------------------------------------------------------------------ primitives

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_json(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def seal_manifest(manifest: dict) -> dict:
    """Bind the manifest to its own content: manifest_sha256 covers everything else."""
    body = {key: value for key, value in manifest.items() if key != "manifest_sha256"}
    manifest["manifest_sha256"] = sha256_bytes(canonical_json(body))
    return manifest


def manifest_is_sealed(manifest: dict) -> bool:
    body = {key: value for key, value in manifest.items() if key != "manifest_sha256"}
    return manifest.get("manifest_sha256") == sha256_bytes(canonical_json(body))


def is_inside(child: Path, parent: Path) -> bool:
    a = os.path.normcase(os.path.realpath(child))
    b = os.path.normcase(os.path.realpath(parent))
    return a == b or a.startswith(b.rstrip("\\/") + os.sep)


# -------------------------------------------------------------- argument parsing

def _numbers(text: str, count: int, label: str, integer: bool) -> list:
    parts = [piece for piece in re.split(r"[,x:\s]+", text.strip()) if piece != ""]
    if len(parts) != count:
        raise CaptureError(EXIT_USAGE, f"{label} needs {count} numbers, got {text!r}")
    try:
        values = [int(p) if integer else float(p) for p in parts]
    except ValueError:
        raise CaptureError(EXIT_USAGE, f"{label} must be {'integers' if integer else 'numbers'}: {text!r}") from None
    if not all(math.isfinite(v) for v in values):
        raise CaptureError(EXIT_USAGE, f"{label} must be finite: {text!r}")
    return values


def parse_resolution(text: str) -> list[int]:
    width, height = _numbers(text, 2, "--resolution (WIDTHxHEIGHT)", True)
    if not (1 <= width <= MAX_SIDE and 1 <= height <= MAX_SIDE) or width * height > MAX_PIXELS:
        raise CaptureError(EXIT_USAGE, f"--resolution {text!r} must be 1..{MAX_SIDE} per side and at most {MAX_PIXELS} pixels")
    return [width, height]


def parse_rect(text: str, label: str, integer: bool) -> list:
    rect = _numbers(text, 4, f"{label} (X,Y,WIDTH,HEIGHT)", integer)
    if rect[2] <= 0 or rect[3] <= 0:
        raise CaptureError(EXIT_USAGE, f"{label} width and height must be positive: {text!r}")
    return rect


def parse_point(text: str) -> list[float]:
    return _numbers(text, 2, "--center (X,Y in native cells)", False)


def check_zoom(value: float, label: str) -> float:
    if not (ZOOM_MIN <= value <= ZOOM_MAX):
        raise CaptureError(EXIT_USAGE, f"{label} {value} must be within {ZOOM_MIN}..{ZOOM_MAX} pixels per native cell")
    return value


def build_shots(args) -> list[dict]:
    """Translate CLI options into the shot plan understood by world_art_capture.gd."""
    feature_requested = bool(args.feature) or args.all_features or args.all_variants
    if args.shots is None:
        kinds = [] if feature_requested else ["full", "viewport", "detail"]
    elif args.shots.strip().lower() == "none":
        kinds = []
    else:
        kinds = [k.strip().lower() for k in args.shots.split(",") if k.strip()]
    unknown = [k for k in kinds if k not in ("full", "viewport", "detail")]
    if unknown:
        raise CaptureError(EXIT_USAGE, f"--shots has unknown kind(s) {unknown}; use full, viewport, detail or none")
    if len(set(kinds)) != len(kinds):
        raise CaptureError(EXIT_USAGE, "--shots lists a kind twice")
    resolution = parse_resolution(args.resolution)
    if args.scale < 1 or args.scale > 8:
        raise CaptureError(EXIT_USAGE, "--scale must be 1..8")
    if args.feature_scale < 1 or args.feature_scale > 8:
        raise CaptureError(EXIT_USAGE, "--feature-scale must be 1..8")
    framing: dict = {"mode": args.framing}
    if args.view is not None:
        if args.zoom is not None or args.center is not None:
            raise CaptureError(EXIT_USAGE, "--view cannot be combined with --zoom/--center")
        framing = {"mode": "view", "view": parse_rect(args.view, "--view", False)}
    elif args.zoom is not None or args.center is not None:
        if args.zoom is None:
            raise CaptureError(EXIT_USAGE, "--center requires --zoom")
        framing = {"mode": "zoom", "zoom": check_zoom(args.zoom, "--zoom"),
                   "center": parse_point(args.center) if args.center is not None else None}
    crop = parse_rect(args.crop, "--crop", True) if args.crop is not None else None
    detail_zoom = check_zoom(args.detail_zoom, "--detail-zoom") if args.detail_zoom is not None else None
    shots: list[dict] = []
    for kind in kinds:
        if kind == "full":
            shots.append({"kind": "full", "scale": args.scale})
        elif kind == "viewport":
            shots.append({"kind": "viewport", "resolution": resolution, "framing": framing})
        else:
            shots.append({"kind": "detail", "resolution": resolution, "crop": crop, "zoom": detail_zoom})
    for spec in args.feature or []:
        feature, _, variant = spec.partition(":")
        if not feature:
            raise CaptureError(EXIT_USAGE, f"--feature expects ID or ID:VARIANT, got {spec!r}")
        shots.append({"kind": "feature", "feature": feature, "variant": variant,
                      "scale": args.feature_scale})
    if args.all_features or args.all_variants:
        shots.append({"kind": "features", "all_variants": args.all_variants,
                      "scale": args.feature_scale})
    if not shots:
        raise CaptureError(EXIT_USAGE, "nothing to capture: --shots none without --feature/--all-features")
    if not (args.time >= 0 and math.isfinite(args.time)):
        raise CaptureError(EXIT_USAGE, "--time must be a finite number of seconds >= 0")
    return shots


# -------------------------------------------------------------------- inputs

def discover_collections(art_root: Path, names: list[str] | None) -> list[Path]:
    if not art_root.is_dir():
        raise CaptureError(EXIT_USAGE, f"--art-root is not a directory: {art_root}")
    present = {child.name for child in art_root.iterdir() if (child / "pack.json").is_file()}
    ordered = [n for n in COLLECTION_ORDER if n in present] + sorted(present - set(COLLECTION_ORDER))
    if names:
        missing = [n for n in names if n not in present]
        if missing:
            raise CaptureError(EXIT_USAGE, f"collection(s) {missing} have no pack.json under {art_root}; available: {ordered}")
        ordered = names
    if not ordered:
        raise CaptureError(EXIT_USAGE, f"no collection/pack.json found under {art_root}")
    return [art_root / name / "pack.json" for name in ordered]


def resolve_pack(path_text: str) -> Path:
    path = Path(os.path.expandvars(os.path.expanduser(path_text)))
    if path.is_dir():
        path = path / "pack.json"
    if not path.is_file():
        raise CaptureError(EXIT_USAGE, f"pack not found: {path} (give a pack.json or a collection directory containing one)")
    if path.stat().st_size == 0:
        raise CaptureError(EXIT_USAGE, f"pack is empty: {path}")
    return path.resolve()


def _git(path: Path, *args: str) -> str | None:
    try:
        result = subprocess.run(["git", "-C", str(path), *args], capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout.strip() if result.returncode == 0 else None


def git_identity(directory: Path) -> dict:
    """Identify the checkout that holds the art (HEAD is read, never written)."""
    top = _git(directory, "rev-parse", "--show-toplevel")
    if not top:
        return {"git": False, "revision": None, "dirty": None, "toplevel": None}
    head = _git(directory, "rev-parse", "HEAD")
    status = _git(directory, "status", "--porcelain=v1", "--untracked-files=normal")
    return {"git": True, "revision": head, "dirty": bool(status), "toplevel": top,
            "dirty_entries": status.splitlines()[:20] if status else [],
            "branch": _git(directory, "rev-parse", "--abbrev-ref", "HEAD")}


def pack_git_blob(pack: Path, toplevel: str | None) -> dict:
    if not toplevel:
        return {"blob": None, "matches_head": None}
    blob = _git(pack.parent, "hash-object", str(pack))
    try:
        relative = pack.relative_to(Path(toplevel).resolve()).as_posix()
    except ValueError:
        return {"blob": blob, "matches_head": None}
    committed = _git(pack.parent, "rev-parse", f"HEAD:{relative}")
    return {"blob": blob, "repo_path": relative, "matches_head": bool(blob and blob == committed)}


def describe_art_source(packs: list[Path], art_root: Path | None, claimed: str | None) -> dict:
    anchor = art_root if art_root is not None else packs[0].parent
    identity = git_identity(anchor)
    detected = identity["revision"]
    if claimed and detected and claimed.lower() != detected.lower() and not detected.lower().startswith(claimed.lower()):
        raise CaptureError(EXIT_USAGE, f"--design-revision {claimed} does not match the art checkout HEAD {detected}; "
                           "omit the flag to record the checkout's real revision")
    if detected:
        revision, origin = detected, "git-head"
    elif claimed:
        revision, origin = claimed, "caller-supplied (not a git checkout; unverified)"
    else:
        revision, origin = "unverified external design source", "unverified"
    return {"root": str(art_root) if art_root else None, "revision": revision, "revision_source": origin,
            "git": identity["git"], "branch": identity.get("branch"), "dirty": identity["dirty"],
            "dirty_entries": identity.get("dirty_entries", []), "toplevel": identity["toplevel"]}


def snapshot_tree(directory: Path) -> dict[str, str]:
    """Hash every file below a guarded source directory (art is small: packs + notes)."""
    snapshot: dict[str, str] = {}
    for root, dirs, files in os.walk(directory):
        dirs[:] = [d for d in dirs if d != ".git"]
        for name in files:
            full = Path(root) / name
            try:
                snapshot[full.relative_to(directory).as_posix()] = sha256_file(full)
            except OSError as exc:
                snapshot[full.relative_to(directory).as_posix()] = f"unreadable:{exc.errno}"
    return snapshot


def guard_directories(packs: list[Path], art_root: Path | None) -> list[Path]:
    guards: list[Path] = [art_root.resolve()] if art_root is not None else []
    for pack in packs:
        if not any(is_inside(pack, g) for g in guards):
            guards.append(pack.parent)
    return guards


def diff_snapshots(before: dict[str, dict[str, str]], after: dict[str, dict[str, str]]) -> list[str]:
    problems: list[str] = []
    for directory, old in before.items():
        new = after.get(directory, {})
        for name in sorted(set(old) | set(new)):
            if old.get(name) != new.get(name):
                kind = "added" if name not in old else "removed" if name not in new else "modified"
                problems.append(f"{kind}: {directory}/{name}")
    return problems


# ---------------------------------------------------------------- log scanning

def scan_log(text: str) -> list[str]:
    return [line.strip() for line in text.splitlines() if LOG_ERROR_PATTERN.search(line)][:25]


# ---------------------------------------------------------------- PNG evidence

def inspect_png(path: Path) -> dict:
    """Validate a PNG file independently of Godot; raises ValueError when invalid."""
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("not a PNG (bad signature)")
    position = len(PNG_SIGNATURE)
    header = None
    compressed = bytearray()
    ended = False
    while position < len(data):
        if position + 12 > len(data):
            raise ValueError("truncated PNG chunk header")
        length, kind = struct.unpack(">I4s", data[position:position + 8])
        end = position + 8 + length
        if end + 4 > len(data):
            raise ValueError("truncated PNG chunk")
        chunk = data[position + 8:end]
        (crc,) = struct.unpack(">I", data[end:end + 4])
        if zlib.crc32(kind + chunk) & 0xFFFFFFFF != crc:
            raise ValueError(f"PNG chunk {kind!r} CRC mismatch")
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            compressed += chunk
        elif kind == b"IEND":
            ended = True
            break
        position = end + 4
    if header is None or not ended or not compressed:
        raise ValueError("PNG lacks IHDR/IDAT/IEND")
    width, height, depth, colour, _, _, interlace = header
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(colour)
    if channels is None or interlace != 0 or depth != 8:
        raise ValueError(f"unsupported PNG layout (colour type {colour}, depth {depth}, interlace {interlace})")
    raw = zlib.decompress(bytes(compressed))
    expected = height * (1 + width * channels)
    if len(raw) != expected:
        raise ValueError(f"PNG pixel stream is {len(raw)} bytes, expected {expected}")
    stride = max(1, len(raw) // 1_000_000)
    diversity = len(set(raw[::stride]))
    return {"width": width, "height": height, "colour_type": colour, "bit_depth": depth,
            "bytes": len(data), "sha256": sha256_bytes(data), "raw_byte_diversity": diversity}


# --------------------------------------------------------- bundle verify/compare

def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise CaptureError(EXIT_EVIDENCE, f"cannot read {path}: {exc}") from None
    if not isinstance(value, dict):
        raise CaptureError(EXIT_EVIDENCE, f"{path} is not a JSON object")
    return value


def verify_job(job_dir: Path, manifest: dict, expected_art: dict | None, expected_viewer: dict | None,
               recheck_packs: bool, allow_blank: bool = False) -> list[str]:
    problems: list[str] = []
    tag = job_dir.name
    if manifest.get("schema") != SCHEMA_JOB:
        problems.append(f"{tag}: wrong job manifest schema")
    if manifest.get("status") != "complete":
        problems.append(f"{tag}: status is {manifest.get('status')!r}: {manifest.get('error')}")
    if expected_art is not None and manifest.get("art_source") != expected_art:
        problems.append(f"{tag}: art_source identity differs from the batch manifest")
    if expected_viewer is not None and manifest.get("viewer") != expected_viewer:
        problems.append(f"{tag}: viewer identity differs from the batch manifest")
    pack = manifest.get("input_pack", {})
    if recheck_packs:
        pack_path = Path(pack.get("path", ""))
        if pack_path.is_file():
            if sha256_file(pack_path) != pack.get("sha256"):
                problems.append(f"{tag}: pack bytes no longer match the recorded SHA-256 (source edited since capture)")
    if pack.get("sha256") != manifest.get("job", {}).get("pack_sha256_expected"):
        problems.append(f"{tag}: rendered pack SHA-256 differs from the independently hashed pack")
    shots = manifest.get("shots", [])
    if not shots:
        problems.append(f"{tag}: no shots recorded")
    listed = set()
    for shot in shots:
        name = shot.get("file", "")
        listed.add(name)
        if shot.get("status") != "complete":
            problems.append(f"{tag}/{name}: shot status {shot.get('status')!r}")
            continue
        path = job_dir / name
        if not path.is_file():
            problems.append(f"{tag}/{name}: PNG missing")
            continue
        try:
            png = inspect_png(path)
        except (ValueError, zlib.error) as exc:
            problems.append(f"{tag}/{name}: invalid PNG: {exc}")
            continue
        if (png["width"], png["height"]) != (shot.get("width"), shot.get("height")):
            problems.append(f"{tag}/{name}: PNG is {png['width']}x{png['height']}, manifest says {shot.get('width')}x{shot.get('height')}")
        if png["sha256"] != shot.get("png_sha256"):
            problems.append(f"{tag}/{name}: PNG SHA-256 differs from the manifest")
        if not allow_blank and (not shot.get("stats", {}).get("nonblank", False) or png["raw_byte_diversity"] < 4):
            problems.append(f"{tag}/{name}: image is blank (diversity {png['raw_byte_diversity']})")
        if shot.get("kind") in ("full", "feature"):
            native = shot.get("source", {})
            scale = shot.get("camera", {}).get("scale")
            if scale and (png["width"], png["height"]) != (native.get("native_width", 0) * scale, native.get("native_height", 0) * scale):
                problems.append(f"{tag}/{name}: full export is not native size x {scale}")
    stray = sorted(p.name for p in job_dir.glob("*.png") if p.name not in listed)
    if stray:
        problems.append(f"{tag}: PNG(s) not in the manifest: {stray}")
    return problems


def verify_bundle(bundle: Path, recheck_packs: bool = True) -> tuple[dict, list[str]]:
    """Re-verify a retained capture bundle: schema, seals, hashes, PNGs, identities."""
    path = bundle / "batch-manifest.json"
    if not path.is_file():
        raise CaptureError(EXIT_EVIDENCE, f"{path} not found; this directory is not a completed capture bundle")
    batch = read_json(path)
    problems: list[str] = []
    if batch.get("schema") != SCHEMA_BATCH:
        problems.append("wrong batch manifest schema")
    if not manifest_is_sealed(batch):
        problems.append("batch manifest_sha256 does not match its content (edited after capture)")
    if batch.get("status") != "completed":
        problems.append(f"batch status is {batch.get('status')!r}")
    for entry in batch.get("jobs", []):
        manifest_path = bundle / entry.get("manifest", "")
        if not manifest_path.is_file():
            problems.append(f"{entry.get('id')}: job manifest missing")
            continue
        if sha256_file(manifest_path) != entry.get("manifest_sha256"):
            problems.append(f"{entry.get('id')}: job manifest bytes differ from the batch record")
        problems += verify_job(manifest_path.parent, read_json(manifest_path), batch.get("art_source"),
                               batch.get("viewer"), recheck_packs, bool(batch.get("allow_blank", False)))
    if not batch.get("jobs"):
        problems.append("no jobs recorded")
    return batch, problems


def _shot_key(job: dict, shot: dict) -> tuple[str, str]:
    return job["collection"], shot["id"]


def compare_bundles(before: Path, after: Path) -> dict:
    """Report, per collection/shot, whether two bundles used equivalent framing and what changed."""
    batch_a, problems_a = verify_bundle(before, recheck_packs=False)
    batch_b, problems_b = verify_bundle(after, recheck_packs=False)
    report: dict = {"before_problems": problems_a, "after_problems": problems_b, "shots": [],
                    "presentation_equivalent": batch_a.get("presentation") == batch_b.get("presentation")}

    def shots_of(batch: dict, root: Path) -> dict:
        found = {}
        for entry in batch.get("jobs", []):
            manifest = read_json(root / entry["manifest"])
            for shot in manifest.get("shots", []):
                found[(manifest["job"]["collection"], shot["id"])] = (manifest, shot)
        return found

    left, right = shots_of(batch_a, before), shots_of(batch_b, after)
    for key in sorted(set(left) | set(right)):
        row: dict = {"collection": key[0], "shot": key[1]}
        if key not in left or key not in right:
            row["comparable"] = False
            row["note"] = "present in only one bundle"
        else:
            (ma, sa), (mb, sb) = left[key], right[key]
            camera_a, camera_b = sa.get("camera", {}), sb.get("camera", {})
            equivalent = camera_a == camera_b and (sa.get("width"), sa.get("height")) == (sb.get("width"), sb.get("height"))
            row.update({
                "comparable": equivalent,
                "framing_equivalent": equivalent,
                "pack_changed": ma["input_pack"]["sha256"] != mb["input_pack"]["sha256"],
                "rg8_changed": sa["source"]["rg8_sha256"] != sb["source"]["rg8_sha256"],
                "png_changed": sa["png_sha256"] != sb["png_sha256"],
                "before_png": str(before / ma["job"]["id"] / sa["file"]),
                "after_png": str(after / mb["job"]["id"] / sb["file"]),
            })
            if not equivalent:
                row["note"] = "camera/resolution differ; recapture 'after' with the same framing options"
        report["shots"].append(row)
    report["comparable"] = bool(report["shots"]) and all(r["comparable"] for r in report["shots"]) \
        and report["presentation_equivalent"] and not problems_a and not problems_b
    return report
