"""Qualify a complete paired experiment without changing any trial outcome."""

import argparse
import json
import os
from pathlib import Path

from summarize_physical_stress import report_batch, summarize


def compare(root: Path, lock: dict, **expected) -> dict:
    reports = {variant: summarize(root / variant, expected_variant=variant, **expected)
               for variant in ("control", "patched")}
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
    if control["campaign_ids"] != patched["campaign_ids"]:
        errors.append("Control and patched run/attempt identities differ")
    identities, paired_hosts = {}, {}
    for variant in ("control", "patched"):
        for path in sorted((root / variant).glob("*/stress.json")):
            report = json.loads(path.read_text(encoding="utf-8"))
            identity = report["identity"]
            if report.get("input_verification_complete") is not True or report.get("input_drift") != []:
                errors.append("Missing or failed final input verification: " + str(path))
            if report.get("preflight_passed") is not True:
                errors.append("Missing or failed preflight receipt: " + str(path))
            build = identity.get("rapier_build", {})
            host = identity.get("host")
            if host not in ("windows", "linux") or identity.get("variant") != variant:
                errors.append("Invalid explicit paired host/variant identity: " + str(path))
                continue
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
            if identity.get("paired_protocol") != "same-host-alternating-v1":
                errors.append("Missing or unsupported same-host pairing protocol: " + str(path))
            else:
                batch = identity.get("pair_batch")
                if (type(batch) is not int or batch not in range(5) or report_batch(path) != (host, batch)
                        or identity.get("batch") != batch):
                    errors.append("Invalid same-host batch identity: " + str(path))
                    continue
                if (host, batch, variant) in paired_hosts:
                    errors.append("Duplicate same-host batch identity: " + str(path))
                paired_hosts[(host, batch, variant)] = identity
                if (identity.get("paired_protocol") != "same-host-alternating-v1" or batch not in range(5)
                        or not identity.get("pair_host_id") or not identity.get("fixture_inputs")
                        or identity.get("hardware", {}).get("physical_cores", 0) < 2):
                    errors.append("Missing same-host hardware/fixture identity: " + str(path))
                for result in report["results"]:
                    first = "control" if (result["iteration"] + batch) % 2 == 0 else "patched"
                    if result.get("pair_position") != int(variant != first):
                        errors.append("Unexpected pair order: " + str(path))
    for host in ("windows", "linux"):
        a = control["runtime_identities"].get(host)
        b = patched["runtime_identities"].get(host)
        if not a or not b or a[0] != b[0] or a[2] != b[2] or a[1] == b[1]:
            errors.append("Expected matching native/Godot and distinct Rapier runtime bytes: " + host)
        ca, cb = identities.get(host + "/control", {}), identities.get(host + "/patched", {})
        for field in ("upstream_cargo_lock_sha256", "resolved_cargo_lock_sha256", "rustc", "build_lock_sha256"):
            if not ca.get(field) or ca.get(field) != cb.get(field):
                errors.append("Paired build inputs differ: " + host + "/" + field)
    for host in ("windows", "linux"):
        for batch in range(5):
            a = paired_hosts.get((host, batch, "control"), {})
            b = paired_hosts.get((host, batch, "patched"), {})
            for field in ("pair_host_id", "hardware", "fixture_inputs"):
                if not a.get(field) or a.get(field) != b.get(field):
                    errors.append(f"Mismatched same-host pair: {host}/{batch}/{field}")
    return {"qualified": not errors, "control": control, "patched": patched, "builds": identities, "errors": errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    lock = json.loads((Path(__file__).resolve().parents[2] / "third_party/rapier-bvh-build.lock.json").read_text(encoding="utf-8"))
    report = compare(args.root, lock, expected_source_sha=os.getenv("GITHUB_SHA"),
                     expected_run_id=os.getenv("GITHUB_RUN_ID"), expected_run_attempt=os.getenv("GITHUB_RUN_ATTEMPT"))
    (args.root / "paired-summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"qualified": report["qualified"], "control_counts": report["control"]["counts"],
                      "patched_counts": report["patched"]["counts"], "errors": report["errors"]}, indent=2))
    return int(not report["qualified"])


if __name__ == "__main__":
    raise SystemExit(main())
