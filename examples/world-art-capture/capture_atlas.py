#!/usr/bin/env python3
"""Minimal external-worker contract for unattended world-art capture (#498).

An agent or CI job needs only this: call the launcher, check the exit code, read the
JSON result and manifest, look at the returned PNG paths. No Godot project knowledge.

  python3 examples/world-art-capture/capture_atlas.py --godot godot \
      --art-root /abs/art-source/docs/world-design --collection lumen-fault \
      --output-dir /abs/captures/before

  # after editing a writable pack copy, recapture with the SAME framing and compare:
  python3 examples/world-art-capture/capture_atlas.py --godot godot --pack /abs/work/lumen-fault \
      --output-dir /abs/captures/after --compare-with /abs/captures/before
Prints one JSON object (status, images, hashes, art revision) and exits with the launcher's code.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

LAUNCHER = Path(__file__).resolve().parents[2] / "tools" / "world_art_preview_launcher.py"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--compare-with", help="earlier capture bundle to compare against (same framing options)")
    args, passthrough = parser.parse_known_args()
    command = [sys.executable, str(LAUNCHER), "--capture", "--output-dir", args.output_dir, *passthrough]
    done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
    result = None
    for line in done.stdout.splitlines():
        if line.startswith("WORLD_ART_CAPTURE_RESULT "):
            result = json.loads(line.split(" ", 1)[1])
    report: dict = {"exit_code": done.returncode, "status": "failed", "errors": done.stderr.strip().splitlines()[-5:]}
    if result:
        manifest = json.loads(Path(result["batch_manifest"]).read_text(encoding="utf-8"))
        report.update({"status": result["status"], "bundle": result["bundle"], "batch_manifest": result["batch_manifest"],
                       "manifest_sha256": result["manifest_sha256"], "failures": result["failures"],
                       "art_revision": manifest["art_source"]["revision"],
                       "renderer": manifest["engine"]["display"].get("rendering_driver"),
                       "jobs": [{"collection": job["collection"], "pack_sha256": job["pack_sha256"],
                                 "images": [str(Path(result["bundle"]) / shot["file"]) for shot in job["shots"]]}
                                for job in manifest["jobs"]]})
    if done.returncode == 0 and args.compare_with:
        compared = subprocess.run([sys.executable, str(LAUNCHER), "--compare-bundles", args.compare_with, args.output_dir],
                                  capture_output=True, text=True, encoding="utf-8")
        report["comparison"] = json.loads(compared.stdout) if compared.stdout.strip() else {"error": compared.stderr}
        report["exit_code"] = compared.returncode
    print(json.dumps(report, indent=2))
    return report["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
