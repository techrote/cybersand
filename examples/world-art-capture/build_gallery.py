#!/usr/bin/env python3
"""Generate an offline 15-scene / 120-feature gallery from verified *real Godot* PNGs.

The gallery never re-renders art or modifies the source. It is an index into
source-matched, independently verified PNG evidence. Invalid or incomplete
bundles are refused rather than displayed as accepted artwork.
"""
from __future__ import annotations

import argparse
from html import escape
import os
from pathlib import Path
import sys
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import world_art_capture_support as support  # noqa: E402


def build_gallery(bundle: Path, output: Path | None = None) -> tuple[Path, int]:
    bundle = bundle.expanduser().resolve()
    batch, problems = support.verify_bundle(bundle)
    if problems or batch.get("status") != "completed":
        raise ValueError("refusing unverified/incomplete capture bundle: " + "; ".join(problems[:8]))
    destination = (output or bundle / "gallery" / "index.html").expanduser().resolve()
    if destination.exists():
        raise ValueError("gallery already exists; use a fresh output path: " + str(destination))
    cards: list[str] = []
    for job in batch["jobs"]:
        collection = str(job.get("collection", "unknown"))
        for shot in job.get("shots", []):
            raw_path = str(shot.get("file", ""))
            resolved = (bundle / raw_path).resolve()
            if not resolved.is_relative_to(bundle) or not resolved.is_file() or resolved.suffix.lower() != ".png":
                raise ValueError("gallery image is outside verified bundle or is missing: " + raw_path)
            url = quote(Path(os.path.relpath(resolved, destination.parent)).as_posix(), safe="/")
            label = f"{collection} / {shot.get('id', shot.get('kind', 'shot'))}"
            dimension = f"{shot.get('width', '?')}×{shot.get('height', '?')}"
            digest = str(shot.get("png_sha256", ""))
            cards.append(
                '<figure><a href="' + escape(url, quote=True) + '">'
                '<img loading="lazy" decoding="async" alt="' + escape(label, quote=True)
                + '" src="' + escape(url, quote=True) + '"></a>'
                '<figcaption><strong>' + escape(label) + '</strong>'
                '<span>' + escape(dimension) + '</span>'
                '<small>PNG SHA-256 ' + escape(digest[:20]) + '…</small></figcaption></figure>'
            )
    if not cards:
        raise ValueError("the verified capture bundle does not contain any images")
    revision = str(batch.get("art_source", {}).get("revision") or "unversioned external art source")
    renderer = str(batch.get("engine", {}).get("display", {}).get("rendering_driver") or "unspecified")
    html = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CyberSand World Art — source-matched capture gallery</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}
body{margin:0;background:#09131d;color:#e2edf5;font:14px/1.5 system-ui,sans-serif}
header{padding:22px max(22px,4vw);border-bottom:1px solid #385061}
h1{font-size:1.4rem;margin:0 0 4px}p{color:#aec2cd;margin:4px 0}
main{padding:24px max(20px,3vw);display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px}
figure{margin:0;border:1px solid #304351;border-radius:8px;overflow:hidden;background:#121f2d}
figure img{display:block;width:100%;height:210px;object-fit:contain;background:#071019}
figcaption{padding:12px;display:flex;flex-direction:column;gap:2px}
figcaption span{color:#a5bac8}small{font-size:11px;color:#819aac}
</style></head><body><header><h1>CyberSand · World Art Gallery</h1>
<p>Source-matched Godot RG8 material-palette frames. Synthetic material conditions — no physics or native playable-World claim.</p>
<p>Art revision: REVISION · Driver: DRIVER · PNGs: COUNT. Open an image for full resolution.</p>
</header><main>CARDS</main></body></html>
"""
    html = (html.replace("REVISION", escape(revision))
            .replace("DRIVER", escape(renderer))
            .replace("COUNT", str(len(cards)))
            .replace("CARDS", "\n".join(cards)))
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive create; no earlier gallery is overwritten on repeated commands.
    with destination.open("x", encoding="utf-8") as handle:
        handle.write(html)
    return destination, len(cards)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--output", type=Path, help="fresh index.html path (defaults to BUNDLE/gallery/index.html)")
    args = parser.parse_args()
    try:
        output, count = build_gallery(args.bundle, args.output)
    except (ValueError, OSError, support.CaptureError) as error:
        print("WORLD_ART_GALLERY_ERROR " + str(error), file=sys.stderr)
        return 1
    print(f"WORLD_ART_GALLERY_OK path={output} images={count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
