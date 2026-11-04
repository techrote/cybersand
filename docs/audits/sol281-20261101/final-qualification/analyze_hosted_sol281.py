#!/usr/bin/env python3
"""Summarize original SOL281 host artifacts without changing their evidence.

Example:
  python evidence/analyze_hosted_sol281.py hosted-qualification/first-hosts \
    --output evidence/sol281-first-hosted-analysis --source <full-source-sha>

Inputs may be artifact ZIPs, directories containing them, extracted artifact
directories, or report.json files. This is an analysis, not a replacement for
the repository's strict qualification reader or runtime publication verifier.
The original host status is retained; a failed host never becomes a physics row
with invented zero measurements. All output timings are observational.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import zipfile


ENVIRONMENTS = ("packed_sand", "embedded_sand", "mixed")
POPULATED = "cybersand.sol281.populated.v1"
LIMITATIONS = [
    "Actual solid-versus-cell penetration depth and overlap area: NOT MEASURED. "
    "max_translation is the maximum distance of the body transform origin from "
    "its initial pose; max_rotation is the maximum absolute rotation. Neither is penetration.",
    "Mechanical energy/contact work, contact-quality thresholds, allocation counts, "
    "GPU/render time and interactive frame pacing: NOT MEASURED by these headless reports.",
    "Native displacement attempts/outcomes are cumulative strict-mechanism invocations. "
    "Coupling contacts/displaced/unresolved are totals from feedback accepted by the "
    "main-thread consumer; their denominators differ. They cannot be combined into a failure rate.",
    "Baseline strict-mechanism counters are zero because that mechanism is disabled; "
    "ordinary current-main ejection still runs and may displace cells.",
    "ForeignOccupancy is a target-mask refusal, including the aggregate's own/swept "
    "mask; it does not count only other bodies. Outcome categories reflect the final "
    "priority-ordered guard decision. NoVacancy is not a replacement empty-route census.",
    "moved_cells > accepted > 0 proves at least one actual multi-parcel transaction. "
    "It does not establish deep-bed yielding quality or a useful penetration bound.",
    "Exact live Sand quantity and Water mass are reported. The 14-check populated "
    "test also asserts exact aggregate payload and sole ownership; these JSON files "
    "do not retain every surrounding parcel's state/temperature history.",
    "The deterministic recipe is executed with real asynchronous worker/main scheduling. "
    "Different trajectories, feedback counts, CPU models and sampling prevent causal "
    "speedup/resistance claims from this single before/after comparison.",
]
TIMING_DEFINITIONS = {
    "worker": "observed_worker_step_ms_total / timed_snapshots; consumed healthy same-epoch snapshots only, not all native ticks",
    "native": "observed_native_tick_ms_total / timed_snapshots; consumed healthy same-epoch snapshots only, not all native ticks",
    "sync": "main_sync_ms_total / main_sync_segments; separate response-consumption and state-publication segments, not whole frames",
    "rapier": "rapier_step_ms_total / timed_rapier_steps; actual bridge.step calls",
    "terrain": "terrain_refresh_ms is total installation/drain time; terrain_refreshes counts admitted revisions/install events, not timed calls; no per-call mean is derived",
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def loads(data):
    return json.loads(data, parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))


class Artifact:
    def __init__(self, path):
        self.path = path.resolve()
        self.archive = zipfile.ZipFile(path) if path.suffix == ".zip" else None
        if self.archive:
            names = [n for n in self.archive.namelist() if pathlib.PurePosixPath(n).name == "report.json"]
            if len(names) != 1:
                raise ValueError(f"Expected one host report in {path}, found {len(names)}")
            self.report_name = names[0]
            self.base = pathlib.PurePosixPath(names[0]).parent
        else:
            self.report_name = "report.json"
            self.base = path.parent

    def read(self, relative):
        part = pathlib.PurePosixPath(relative)
        if part.is_absolute() or ".." in part.parts:
            raise ValueError(f"Unsafe evidence path: {relative}")
        if self.archive:
            return self.archive.read(str(self.base / part))
        return (self.base / part).read_bytes()

    def report(self):
        return self.archive.read(self.report_name) if self.archive else self.path.read_bytes()


def discover(inputs):
    paths = set()
    for raw in inputs:
        path = pathlib.Path(raw).resolve()
        if path.is_dir():
            paths.update(path.rglob("sol281-host-*.zip"))
            paths.update(path.rglob("report.json"))
        else:
            paths.add(path)
    if not paths:
        raise ValueError("No host artifacts or report.json inputs")
    return sorted(paths)


def timer(coupling, prefix, count_key):
    count = coupling[count_key]
    total = coupling[prefix + "_ms_total"]
    return {"total_ms": total, "count": count, "count_field": count_key,
            "mean_ms": total / count if count else None, "max_ms": coupling[prefix + "_ms_max"]}


def populated_row(host, record, result):
    c, d = result["coupling"], result["displacement"]
    mode = "candidate" if result["conservative_displacement"] else "baseline"
    if result["platform"] != host["platform"] or record["name"] != f"{result['surroundings']}-{mode}-w{result['workers']}":
        raise ValueError("Populated result identity disagrees with its original host record")
    return {
        "platform": host["platform"], "workers": result["workers"],
        "environment": result["surroundings"], "mode": mode,
        "host_status": host["status"], "case_status": record["status"],
        "result_sha256": record["result"]["sha256"], "case": record["name"],
        "checks": result["checks"], "failures": result["failures"],
        "sand_before": result["sand_before"], "sand_after": result["sand_after"],
        "water_mass_before": result["water_mass_before"], "water_mass_after": result["water_mass_after"],
        "quantities_equal": result["sand_before"] == result["sand_after"] and result["water_mass_before"] == result["water_mass_after"],
        "max_translation_cells": result["max_translation"], "max_abs_rotation_radians": result["max_rotation"],
        "actual_multi_parcel_observed": d["moved_cells"] > d["accepted"] > 0,
        "displacement": d, "coupling": c,
        "timings": {"worker": timer(c, "observed_worker_step", "timed_snapshots"),
                    "native": timer(c, "observed_native_tick", "timed_snapshots"),
                    "sync": timer(c, "main_sync", "main_sync_segments"),
                    "rapier": timer(c, "rapier_step", "timed_rapier_steps"),
                    "terrain": {"total_ms": c["terrain_refresh_ms"], "revision_events": c["terrain_refreshes"]}},
        "case_process_seconds": record["seconds"],
    }


def analyze(paths, expected_source):
    hosts, rows, seen = [], [], set()
    for path in paths:
        artifact = Artifact(path)
        raw = artifact.report()
        report = loads(raw)
        if report.get("schema") != "cybersand.sol281.qualification.v1":
            raise ValueError(f"Not a SOL281 host qualification report: {path}")
        slot = (report["platform"], report["cohort"])
        if slot in seen:
            raise ValueError(f"Duplicate platform/cohort; analyze each run separately: {slot}")
        seen.add(slot)
        source = report["source"]
        if expected_source and source["sha"] != expected_source:
            raise ValueError(f"Unexpected source {source['sha']} in {path}")
        host = {key: report.get(key) for key in ("platform", "cohort", "status", "errors", "source", "runtime", "engine", "rapier", "source_unchanged", "checkout_inputs_unchanged", "build_manifest_sha256")}
        host.update({"artifact": str(path), "report_sha256": sha(raw), "records": len(report["records"]), "assertions": 0, "ordinary_controls": 0})
        name_match = re.search(r"-(\d+)-(\d+)(?:\.zip)?$", str(path.parent if path.name == "report.json" else path))
        host["run"] = {"id": name_match[1], "attempt": name_match[2]} if name_match else None
        try:
            performance = loads(artifact.read("performance.jsonl").splitlines()[0])
            ps = performance["source"]
            if ps["commit"] != source["sha"] or ps["tree"] != source["tree"]:
                raise ValueError(f"Performance source differs from original report: {path}")
            host["hardware"] = performance["host"]
            host["run"] = {"id": ps["run_id"], "attempt": ps["run_attempt"]}
        except (KeyError, FileNotFoundError):
            host["hardware"] = None
        for record in report["records"]:
            result = record.get("readback")
            if record.get("result"):
                content = artifact.read(record["result"]["path"])
                if sha(content) != record["result"]["sha256"]:
                    raise ValueError(f"Result hash differs from original record: {path}, {record['name']}")
                result = loads(content)
            if isinstance(result, dict):
                host["assertions"] += result.get("checks", 0)
                if result.get("schema") == POPULATED:
                    rows.append(populated_row(host, record, result))
            else:
                host["ordinary_controls"] += record["name"].startswith("ordinary-")
        hosts.append(host)
    sources = {(h["source"]["sha"], h["source"]["tree"]) for h in hosts}
    runs = {(h["run"]["id"], h["run"]["attempt"]) for h in hosts if h["run"]}
    if len(sources) != 1 or len(runs) > 1:
        raise ValueError("Mixed source trees or hosted runs; analyze each separately")
    rows.sort(key=lambda r: (r["platform"], r["workers"], ENVIRONMENTS.index(r["environment"]), r["mode"]))
    hosts.sort(key=lambda h: (h["platform"], h["cohort"]))
    return {"schema": "cybersand.sol281.hosted-analysis.v1", "source": hosts[0]["source"],
            "run": next((h["run"] for h in hosts if h["run"]), None),
            "scope": "Derived tables from original host reports/results; original qualification and publication verifiers remain authoritative",
            "hosts": hosts, "populated": rows, "timing_definitions": TIMING_DEFINITIONS,
            "measurement_inventory": {"body_translation_rotation": "MEASURED", "sand_quantity_water_mass": "MEASURED", "native_displacement_outcomes": "MEASURED", "solid_cell_penetration_depth": "NOT MEASURED", "solid_cell_overlap_area": "NOT MEASURED", "energy_contact_work": "NOT MEASURED", "graphical_frame_pacing": "NOT MEASURED"},
            "limitations": LIMITATIONS}


def table(headers, rows):
    return "\n".join(["| " + " | ".join(headers) + " |", "| " + " | ".join("---" for _ in headers) + " |"] + ["| " + " | ".join(str(v).replace("|", "\\|").replace("\n", " ") for v in row) + " |" for row in rows])


def render(report):
    run_label = f"{report['run']['id']}, attempt {report['run']['attempt']}" if report['run'] else "not recorded"
    lines = ["# SOL281 hosted before/after analysis", "", f"Source `{report['source']['sha']}`; tree `{report['source']['tree']}`.", "", f"Hosted run: {run_label}. Original host results are retained below; analysis is not an independent qualification gate.", "", "## Execution inventory", ""]
    lines.append(table(["Platform", "Cohort", "Original status", "Cases", "Numbered assertions", "Ordinary controls", "Errors"],
                       [(h["platform"], h["cohort"], h["status"], h["records"], h["assertions"], h["ordinary_controls"], "; ".join(h["errors"] or [])) for h in report["hosts"]]))
    usable = [r for r in report["populated"] if r["host_status"] == "passed" and r["case_status"] == "passed" and not r["failures"]]
    groups = {}
    for row in usable:
        groups.setdefault((row["platform"], row["workers"], row["environment"]), {})[row["mode"]] = row
    pairs = [(key, value["baseline"], value["candidate"]) for key, value in groups.items() if set(value) == {"baseline", "candidate"}]
    lines += ["", "Only complete baseline/candidate pairs from passed hosts appear in the comparison tables. B = ordinary current-main ejection; C = bounded conservative chain displacement. Missing or failed hosts have no inferred physics values.", "", "## Exact quantities and measured body motion", "", "All paired cells show B / C. Translation is in simulation cells; rotation is in radians. Neither quantity is penetration.", ""]
    def quantity(r, prefix):
        return f"{r[prefix + '_before']}→{r[prefix + '_after']}"
    lines.append(table(["Platform", "Workers", "Environment", "Sand B / C", "Water mass B / C", "Max translation B / C", "Max abs rotation B / C"],
                       [(*k, f"{quantity(b, 'sand')} / {quantity(c, 'sand')}", f"{quantity(b, 'water_mass')} / {quantity(c, 'water_mass')}", f"{b['max_translation_cells']:.4f} / {c['max_translation_cells']:.4f}", f"{b['max_abs_rotation_radians']:.4f} / {c['max_abs_rotation_radians']:.4f}") for k,b,c in pairs]))
    lines += ["", "## Native displacement and sampled contact totals", "", "Native attempts, accepts and parcels are strict-mechanism counters. Coupling counts are from accepted main-thread feedback and have a different denominator. Baseline zeros in strict counters do not mean that baseline ejection did no work.", ""]
    lines.append(table(["Platform", "Workers", "Environment", "Attempts B / C", "Accepts B / C", "Parcels B / C", "C multi-parcel", "Sampled contacts B / C", "Sampled displaced B / C", "Sampled unresolved B / C"],
                       [(*k, *(f"{b['displacement'][x]} / {c['displacement'][x]}" for x in ("attempts", "accepted", "moved_cells")), c["actual_multi_parcel_observed"], *(f"{b['coupling'][x]} / {c['coupling'][x]}" for x in ("contacts", "displaced", "unresolved"))) for k,b,c in pairs]))
    lines += ["", "## Candidate final refusal classifications", "", "Target-mask is the recorded `ForeignOccupancy` category and includes own/swept masks. The full JSON retains every category, including zeros, intermediate blocker counts and native transaction outcomes.", ""]
    causes = ("Capacity", "ForeignOccupancy", "GeometryBlocked", "NoVacancy", "UnsupportedMaterial")
    lines.append(table(["Platform", "Workers", "Environment", "Capacity", "Target-mask", "Geometry", "No vacancy", "Unsupported", "Other nonzero refusals"],
                       [(*k, *(c["displacement"]["outcomes"][x] for x in causes), ", ".join(f"{x}={v}" for x,v in c["displacement"]["outcomes"].items() if v and x not in (*causes,"Applied")) or "none") for k,b,c in pairs]))
    lines += ["", "## Observed timing", "", "All paired cells show B / C. Means and maxima are milliseconds. Full totals and denominators are retained in JSON. These are sampled observations, not a claim of causal performance improvement.", ""]
    def value(b,c,key,field):
        vals = [r["timings"][key][field] for r in (b,c)]
        return " / ".join("—" if v is None else f"{v:.4f}" if isinstance(v,float) else str(v) for v in vals)
    lines.append(table(["Platform", "Workers", "Environment", "Snapshots B / C", "Worker mean B / C", "Worker max B / C", "Native mean B / C", "Native max B / C"],
                       [(*k, value(b,c,"worker","count"), value(b,c,"worker","mean_ms"), value(b,c,"worker","max_ms"), value(b,c,"native","mean_ms"), value(b,c,"native","max_ms")) for k,b,c in pairs]))
    lines += ["", table(["Platform", "Workers", "Environment", "Sync segments B / C", "Sync mean B / C", "Sync max B / C", "Rapier steps B / C", "Rapier mean B / C", "Rapier max B / C", "Terrain total B / C", "Terrain revisions B / C"],
                       [(*k, value(b,c,"sync","count"), value(b,c,"sync","mean_ms"), value(b,c,"sync","max_ms"), value(b,c,"rapier","count"), value(b,c,"rapier","mean_ms"), value(b,c,"rapier","max_ms"), value(b,c,"terrain","total_ms"), value(b,c,"terrain","revision_events")) for k,b,c in pairs]), ""]
    lines.extend(f"- **{name}:** {definition}." for name,definition in TIMING_DEFINITIONS.items())
    lines += ["", "## Runtime and source references", ""]
    lines.append(table(["Platform", "Cohort", "Native SHA-256", "CPU", "Source unchanged", "Checkout bytes unchanged"],
                       [(h["platform"], h["cohort"], (h["runtime"] or {}).get("sha256", "not reached"), (h["hardware"] or {}).get("cpu_model", "not reached"), h["source_unchanged"], h["checkout_inputs_unchanged"]) for h in report["hosts"]]))
    lines += ["", "Original artifact paths, report hashes, result hashes, engine/Rapier identity and raw counter values are retained in the adjacent analysis JSON.", "", "## Measurement limits", ""]
    lines.extend(f"- {limitation}" for limitation in LIMITATIONS)
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+")
    parser.add_argument("--source", help="Require this exact source SHA")
    parser.add_argument("--output", required=True, help="Output prefix (.json and .md are appended)")
    args = parser.parse_args()
    report = analyze(discover(args.inputs), args.source)
    prefix = pathlib.Path(args.output)
    prefix.parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(str(prefix) + ".json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    pathlib.Path(str(prefix) + ".md").write_text(render(report), encoding="utf-8")
    print(json.dumps({"source": report["source"], "hosts": len(report["hosts"]), "passed_hosts": sum(h["status"] == "passed" for h in report["hosts"]), "populated_rows": len(report["populated"]), "output": str(prefix)}))


if __name__ == "__main__":
    main()
