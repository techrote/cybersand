#!/usr/bin/env python3
"""Fetch the immutable, already executed R Windows assembly for supplemental use."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import urllib.request

sys.dont_write_bytecode = True
RUN = "44690026779"
ORCHESTRATION = "f69b68a88401b28b3fe688c3d070162ebcd090c5"
ARTIFACT = "14607763901"
ARTIFACT_NAME = "gentek80-final-package-assembly-44690026779"
ARTIFACT_SHA = "3497155bcf9513ce6090c3330d332aa12cacf4fb84289ad4c4f210f377ba1680"
ARTIFACT_BYTES = 92330616
PACKAGE_NAME = "CyberSand-Gentek80-Windows-bf1bd8c8e6f1.zip"
PACKAGE_SHA = "1ecfef2bca82e73200cc686ce225f8e60a5bccd49a9853cc12f66863d11e06f1"
PACKAGE_BYTES = 92410079
ASSEMBLY_SHA = "5d8fcd406a60f7da88262bf7b26d267038f6fe6dd5ed769dab1801f7c27c8a42"
HELPERS = {
    "retained_runtime_admission.py": "baa42413bbebdeae031dfcf41f73b127b5bc1ff982b0c997d35dd3d34fc6971b",
    "fetch_qualified_artifact.py": "423120b4c4ed75b799da6ba46ebeb2c3628b780d87193b12d69156feae211a48",
    "package_retained_gentek80.py": "735a620b3b02aa0c3578a9e7d7125489519fad36819eb4a0fccc9921c840a63f",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_metadata(metadata: dict, run: dict) -> None:
    require(str(metadata.get("id")) == ARTIFACT and metadata.get("name") == ARTIFACT_NAME and
            metadata.get("expired") is False and metadata.get("digest") == "sha256:" + ARTIFACT_SHA and
            metadata.get("size_in_bytes") == ARTIFACT_BYTES and
            str(metadata.get("workflow_run", {}).get("id")) == RUN and
            metadata["workflow_run"].get("head_sha") == ORCHESTRATION,
            "Immutable original assembly artifact identity differs")
    require(str(run.get("id")) == RUN and str(run.get("run_attempt")) == "1" and
            run.get("head_sha") == ORCHESTRATION and run.get("head_branch") == "ci/gentek80-final-admission" and
            run.get("event") == "push" and run.get("status") == "completed" and run.get("conclusion") == "success",
            "Original final assembly/execution run is not the completed successful R run")


def load_helpers(directory: Path):
    for name, expected in HELPERS.items():
        path = directory / name
        require(path.is_file() and not path.is_symlink() and sha(path) == expected,
                "Reviewed original download helper changed: " + name)
    loaded = []
    for name in ("retained_runtime_admission", "package_retained_gentek80", "fetch_qualified_artifact"):
        spec = importlib.util.spec_from_file_location(name, directory / (name + ".py"))
        require(spec is not None and spec.loader is not None, "Cannot load original download helper")
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
        loaded.append(module)
    return loaded[1:]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--harness", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args()
    package, fetch = load_helpers(args.harness.resolve())
    metadata = fetch.api("/repos/techrote/cybersand/actions/artifacts/" + ARTIFACT)
    run = fetch.api("/repos/techrote/cybersand/actions/runs/" + RUN)
    validate_metadata(metadata, run)
    destination = args.destination.resolve()
    archive = destination.with_suffix(".original-artifact.zip")
    require(not destination.exists() and not archive.exists(), "Assembly download destinations must be new")
    archive.parent.mkdir(parents=True, exist_ok=True)
    location = fetch.api("/repos/techrote/cybersand/actions/artifacts/" + ARTIFACT + "/zip", redirect=True)
    try:
        # The reviewed API helper sends authorization only to api.github.com.
        # This fresh signed-URL request has no token and is never logged.
        with urllib.request.urlopen(location, timeout=120) as incoming, archive.open("wb") as outgoing:
            shutil.copyfileobj(incoming, outgoing)
    except Exception:
        raise RuntimeError("Original assembly download failed; no token or signed URL retained") from None
    require(archive.stat().st_size == ARTIFACT_BYTES, "Original assembly archive size differs")
    package.extract_pristine(archive, destination, ARTIFACT_SHA)
    require({str(path.relative_to(destination)).replace("\\", "/") for path in destination.rglob("*") if path.is_file()} ==
            {PACKAGE_NAME, PACKAGE_NAME + ".sha256", "assembly.json"},
            "Original assembly has an unexpected member inventory")
    require(sha(destination / PACKAGE_NAME) == PACKAGE_SHA and
            (destination / PACKAGE_NAME).stat().st_size == PACKAGE_BYTES and
            sha(destination / "assembly.json") == ASSEMBLY_SHA,
            "Original Windows ZIP or assembly receipt differs")
    require((destination / (PACKAGE_NAME + ".sha256")).read_bytes() ==
            (PACKAGE_SHA + "  " + PACKAGE_NAME + "\r\n").encode("utf-8"),
            "Original Windows ZIP checksum file differs")
    package.write_json(destination.with_suffix(".download-receipt.json"), {
        "schema": "gentek80-exact-final-assembly-download-v1", "status": "passed",
        "metadata": metadata, "original_run": {key: run.get(key) for key in
            ("id", "run_attempt", "head_sha", "head_branch", "event", "status", "conclusion", "html_url")},
        "archive_sha256": ARTIFACT_SHA, "archive_bytes": ARTIFACT_BYTES,
        "package_sha256": PACKAGE_SHA, "package_bytes": PACKAGE_BYTES,
        "assembly_receipt_sha256": ASSEMBLY_SHA, "original_helpers_sha256": HELPERS,
        "fetch_helper_sha256": sha(Path(__file__)), "destination": str(destination)})
    print(json.dumps({"artifact_id": ARTIFACT, "archive_sha256": ARTIFACT_SHA,
                      "package_sha256": PACKAGE_SHA, "status": "passed"}))


if __name__ == "__main__":
    main()
