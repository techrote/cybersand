#!/usr/bin/env python3
"""Compare two complete source-bound Interlaced campaigns from real GCC 13/14.

Retain a JSON result even when an input is missing, malformed or divergent. This
is an admission gate for already-rendered native evidence, not a PNG generator.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess

from compiler_cache import CACHE_SCHEMA, FLAGS, digest
from render_interlaced_viaduct import (ROOT, PARENT, ORIGINAL_SHOWCASE_PARENT, EXPORTER,
                                      GENERATION_SOURCES, campaign, source_boundary)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("Expected an object: " + str(path))
    return value


def compare(gcc13: Path, gcc14: Path, source: dict, *, root: Path = ROOT) -> dict:
    report = {"schema": "gentek80-interlaced-compiler-parity-v1", "status": "fail",
              "recorded_at": datetime.now(timezone.utc).isoformat(),
              "source_commit": source.get("commit"), "source_tree": source.get("tree"),
              "repaired_classic_parent": PARENT, "original_showcase_parent": ORIGINAL_SHOWCASE_PARENT,
              "render_source_inputs_sha256": digest(source.get("inputs", {})),
              "cases_compared": 0, "material_byte_matches": 0, "png_byte_matches": 0,
              "compilers": [], "cases": [], "failures": []}

    def require(condition: bool, message: str) -> None:
        if not condition:
            raise ValueError(message)

    try:
        require(not source.get("uncommitted_source_paths"), "Current render inputs are not committed")
        manifests, layers = [], []
        for major, directory in ((13, gcc13), (14, gcc14)):
            manifest = read(directory / "manifest.json")
            boundary, build = manifest["source"], manifest["build"]
            require(all(boundary.get(key) == value for key, value in source.items()),
                    f"GCC {major} source boundary differs from the current source")
            require(boundary.get("input_sha256") == digest(source["inputs"])
                    and boundary.get("parent_commit") == PARENT
                    and boundary.get("original_showcase_parent_commit") == ORIGINAL_SHOWCASE_PARENT
                    and boundary.get("identity_captured_before_render") is True
                    and boundary.get("identity_unchanged_after_render") is True,
                    f"GCC {major} source boundary is incomplete or changed during rendering")
            identity = build["compiler_identity"]
            version = identity["version"].splitlines()[0]
            require("g++" in version and re.search(r"\b" + str(major) + r"\.\d+(?:\.\d+)?\s*$", version)
                    and build.get("compiler") == version,
                    f"Campaign does not identify actual GCC {major}")
            driver = identity["driver"]
            files = [driver, *[tool["file"] for tool in identity["tools"].values() if tool.get("file")]]
            require(all(Path(item["path"]).is_file()
                        and str(Path(item["path"]).resolve()) == item["realpath"]
                        and sha(Path(item["path"])) == item["sha256"] for item in files),
                    f"GCC {major} driver or toolchain bytes changed after rendering")
            request_keys = ("schema", "compiler_identity", "flags", "compile_sources",
                            "builder_sha256", "source_input_sha256")
            require(build.get("schema") == CACHE_SCHEMA
                    and build.get("flags") == FLAGS
                    and build.get("compile_sources") == ["native/src/" + name for name in GENERATION_SOURCES] + [EXPORTER]
                    and build.get("builder_sha256") == source["inputs"].get("tools/architecture/compiler_cache.py")
                    and build.get("source_input_sha256") == digest(source["inputs"])
                    and build.get("inputs") == source["inputs"]
                    and build.get("build_key") == digest({key: build[key] for key in request_keys})
                    and build.get("build_mode") == "fresh direct compilation; no shared object reuse",
                    f"GCC {major} build identity is stale or does not bind the requested compiler")
            cached = root / "build/architecture-exporters/interlaced_viaduct_export" / build["build_key"]
            require(read(cached / "build-identity.json") == build
                    and sha(cached / "interlaced_viaduct_export") == build["executable_sha256"],
                    f"GCC {major} private executable or cache identity was substituted")
            require(manifest.get("render_count") == 26 and len(manifest["cases"]) == 26,
                    f"GCC {major} campaign is incomplete")
            report["compilers"].append({"name": f"gcc{major}", "manifest": str(directory / "manifest.json"),
                "manifest_sha256": sha(directory / "manifest.json"), "compiler_identity": identity,
                "build_key": build["build_key"], "executable_sha256": build["executable_sha256"],
                "build_mode": build["build_mode"]})
            manifests.append(manifest)
            layers.append(read(directory / "layer-checks.json"))
        a, b = report["compilers"]
        require(a["build_key"] != b["build_key"] and a["executable_sha256"] != b["executable_sha256"]
                and a["compiler_identity"]["driver"]["sha256"] != b["compiler_identity"]["driver"]["sha256"],
                "GCC 13 and GCC 14 reused the same build key, compiler or executable bytes")
        require(layers[0] == layers[1] and layers[0].get("status") == "pass"
                and layers[0].get("seeds") == 32 and layers[0].get("assertions", 0) > 0,
                "Cross-compiler native layer checks failed or diverged")
        report["layer_checks"] = layers[0]
        groups = [{case["name"]: case for case in manifest["cases"]} for manifest in manifests]
        expected = {case["name"]: case for case in campaign(271828, 80, 64, 3)}
        require(all(group.keys() == expected.keys() for group in groups),
                "Missing, duplicated or substituted Interlaced campaign case identities")
        for name, parameters in expected.items():
            left, right = (group[name] for group in groups)
            require(all(case.get(key) == value for case in (left, right) for key, value in parameters.items()),
                    "Campaign parameter coverage changed: " + name)
            raw = [(directory / (name + ".cells")).read_bytes() for directory in (gcc13, gcc14)]
            png = [(directory / (name + ".png")).read_bytes() for directory in (gcc13, gcc14)]
            for index, case in enumerate((left, right)):
                require(len(raw[index]) == case["extent"][0] * case["extent"][1]
                        and hashlib.sha256(raw[index]).hexdigest() == case["material_sha256"]
                        and hashlib.sha256(png[index]).hexdigest() == case["png_sha256"],
                        "Stored native cells or PNG differ from their receipt: " + name)
            matches = {"material_bytes": raw[0] == raw[1], "png_bytes": png[0] == png[1],
                       "fingerprints": left["fingerprint"] == right["fingerprint"],
                       "chunk_receipts": left["receipts"] == right["receipts"]}
            report["cases"].append({"name": name, "module": left["module"],
                "module_version": left["module_version"], "seed": left["seed"],
                "origin": left["origin"], "extent": left["extent"],
                "material_sha256": left["material_sha256"], "png_sha256": left["png_sha256"],
                "fingerprint": left["fingerprint"], "matches": matches})
            if not all(matches.values()):
                report["failures"].append("Cross-compiler material/PNG/fingerprint/receipt mismatch: " + name)
    except (OSError, ValueError, TypeError, KeyError, IndexError, AttributeError) as error:
        report["failures"].append(str(error))
    report["cases_compared"] = len(report["cases"])
    report["material_byte_matches"] = sum(case["matches"]["material_bytes"] for case in report["cases"])
    report["png_byte_matches"] = sum(case["matches"]["png_bytes"] for case in report["cases"])
    report["status"] = "pass" if not report["failures"] and report["cases_compared"] == 26 else "fail"
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gcc13", type=Path, required=True)
    parser.add_argument("--gcc14", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = {"schema": "gentek80-interlaced-compiler-parity-v1", "status": "fail",
              "source_commit": args.source_sha, "failures": []}
    try:
        before = source_boundary()
        if before["commit"] != args.source_sha:
            raise ValueError("Requested source does not equal current HEAD")
        report = compare(args.gcc13.resolve(), args.gcc14.resolve(), before)
        if source_boundary() != before:
            raise ValueError("Source changed while comparing compiler campaigns")
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        report["status"] = "fail"
        report["failures"].append(str(error))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes((json.dumps(report, indent=2, sort_keys=True) + "\n").encode())
    print(json.dumps({key: report.get(key) for key in ("status", "source_commit", "cases_compared",
                                                     "material_byte_matches", "png_byte_matches", "failures")}))
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
