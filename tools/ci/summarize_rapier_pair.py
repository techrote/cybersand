"""Qualify a complete paired experiment without changing any trial outcome."""

import argparse
import json
from pathlib import Path

from summarize_physical_stress import summarize


def compare(root: Path, lock: dict) -> dict:
    reports = {variant: summarize(root / variant) for variant in ("control", "patched")}
    errors = []
    control, patched = reports["control"], reports["patched"]
    for error in control["errors"]:
        if not error.startswith("Required 50/50 passes for "):
            errors.append("control: " + error)
    for key, counts in control["counts"].items():
        if sum(counts.values()) != 50 or set(counts) - {"passed", "timeout"}:
            errors.append("Invalid control trial scope/outcome: " + key)
    errors.extend("patched: " + error for error in patched["errors"])
    if not any(counts.get("timeout", 0) for counts in control["counts"].values()):
        errors.append("Control did not reproduce a timeout")
    if control["source_shas"] != patched["source_shas"]:
        errors.append("Control and patched source revisions differ")
    identities = {}
    for variant in ("control", "patched"):
        for path in sorted((root / variant).glob("*/stress.json")):
            identity = json.loads(path.read_text(encoding="utf-8"))["identity"]
            build = identity.get("rapier_build", {})
            host = "windows" if "windows" in path.parent.name else "linux"
            key = host + "/" + variant
            expected_join = lock["base_join_source_sha256"] if variant == "control" else lock["patched_join_source_sha256"]
            expected_file = "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if host == "windows" else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
            if (build.get("variant") != variant or build.get("platform") != host
                    or build.get("source_sha") != identity["source_sha"]
                    or build.get("build_inputs") != lock or build.get("join_source_sha256") != expected_join
                    or build.get("upstream_cargo_lock_sha256") != lock["upstream_cargo_lock_sha256"]
                    or build.get("join_regression_exit") != (124 if variant == "control" else 0)
                    or build.get("artifacts", {}).get(expected_file) != identity["rapier_sha256"]
                    or build.get("godot_version") != identity["godot_version"]):
                errors.append("Invalid paired build identity: " + str(path))
            if key in identities and identities[key] != build:
                errors.append("Mixed build provenance: " + key)
            identities[key] = build
    for host in ("windows", "linux"):
        a = control["runtime_identities"].get(host)
        b = patched["runtime_identities"].get(host)
        if not a or not b or a[0] != b[0] or a[2] != b[2] or a[1] == b[1]:
            errors.append("Expected matching native/Godot and distinct Rapier runtime bytes: " + host)
        ca, cb = identities.get(host + "/control", {}), identities.get(host + "/patched", {})
        for field in ("upstream_cargo_lock_sha256", "resolved_cargo_lock_sha256", "rustc", "build_lock_sha256"):
            if not ca.get(field) or ca.get(field) != cb.get(field):
                errors.append("Paired build inputs differ: " + host + "/" + field)
    return {"qualified": not errors, "control": control, "patched": patched, "builds": identities, "errors": errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    lock = json.loads((Path(__file__).resolve().parents[2] / "third_party/rapier-bvh-build.lock.json").read_text(encoding="utf-8"))
    report = compare(args.root, lock)
    (args.root / "paired-summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"qualified": report["qualified"], "control_counts": report["control"]["counts"],
                      "patched_counts": report["patched"]["counts"], "errors": report["errors"]}, indent=2))
    return int(not report["qualified"])


if __name__ == "__main__":
    raise SystemExit(main())
