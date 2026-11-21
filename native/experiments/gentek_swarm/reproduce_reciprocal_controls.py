#!/usr/bin/env python3
"""Reproduce frozen SWARM-003 E8 and hard-only on all 108 established cases.

The same retained external driver links each source tree's unchanged legacy
implementation. Frozen files are extracted from Git and never edited. Every
failed case, native array, domain, work receipt and prose field must match after
the existing enumerated source/definition-only normalization.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import signal
import sys
import tarfile
import tempfile

from reciprocal_gallery import read_record
from run_admission import normalized_negotiated
from run_negotiated import DONORS, HARNESS, HERE, ROOT, canonical, fingerprint, first_mismatch, git, now, unpack_source
from run_reciprocal import CompressionWorker, PARENT, atomic_json, code_inputs, inventory
from run_resilience import CommandRunner, RunnerCancelled, retained_source_inputs, verify_committed_inputs

LEGACY = ("common", "fixtures", "meshing", "io", "frameweaver", "mosaic", "receptor",
          "negotiated", "mosaic_admission", "resilience_solver")
SEEDS = [605, 1701, 2718, 4099, 8191, 12289]
DRIVER = r'''#include "resilience.hpp"
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
using namespace cybersand::gentek_swarm;
int main(int argc,char**argv) try {
    if(argc!=3)throw std::invalid_argument("expected OUTPUT SOURCE");
    const std::filesystem::path out=argv[1];
    if(std::filesystem::exists(out)&&(!std::filesystem::is_directory(out)||!std::filesystem::is_empty(out)))
        throw std::invalid_argument("fresh output required");
    std::filesystem::create_directories(out);
    std::vector<std::string> files;
    unsigned invalid=0;
    const auto index=[&](const char*status){
        std::ofstream stream(out/"campaign.json.partial");
        stream<<"{\"result\":\""<<status<<"\",\"expected_records\":216,\"records\":[";
        for(std::size_t i=0;i<files.size();++i){if(i)stream<<',';stream<<"{\"file\":\""<<files[i]<<"\"}";}
        stream<<"]}\n";stream.close();if(!stream)throw std::runtime_error("control index write failed");
        std::filesystem::remove(out/"campaign.json");std::filesystem::rename(out/"campaign.json.partial",out/"campaign.json");
    };
    index("RUNNING");
    for(const auto& f:fixture_names())for(const auto*p:{"sparse_regular","branching_irregular","dense_cohesive"})
        for(const auto seed:{605ULL,1701ULL,2718ULL,4099ULL,8191ULL,12289ULL}) {
            const auto prepared=prepare_admission(fixture(f),profile(p),seed,argv[2]);
            for(const bool hard:{false,true}) {
                const ResilienceOptions options=hard?
                    ResilienceOptions{ResilienceAdmission::CompatibilityHardOnly,SolveSchedule::SinglePreferred,
                        ResilienceFallback::HardOnly,ReceiverPolicy::RequiredOriginalNative,4}:
                    ResilienceOptions{ResilienceAdmission::CompatibilityFour,SolveSchedule::SinglePreferred,
                        ResilienceFallback::NativeCore,ReceiverPolicy::RequiredOriginalNative,8};
                const auto value=negotiate_resilient(prepared,options);
                const auto file=std::string(hard?"E8_hard_only_":"E8_")+f+'_'+p+'_'+std::to_string(seed)+".json";
                write_resilience_json((out/file).string(),value);files.push_back(file);
                invalid+=value.candidate.mosaic.result.status==Status::Invalid;
            }
            index("RUNNING");
        }
    index(invalid?"FAIL":"PASS");std::cout<<"CONTROL_RECORDS "<<files.size()<<" invalid="<<invalid<<'\n';
    return invalid?1:0;
}catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 2;}
'''


def definition_hash(root):
    harness = root / HARNESS
    files = [(path, path.name) for path in sorted(harness.glob("*.cpp"))]
    files += [(path, path.name) for path in sorted(harness.glob("*.hpp"))]
    files += [(root / name, "../../../" + str(name)) for name in DONORS]
    return hashlib.sha256(b"".join(name.encode() + b"\0" + path.read_bytes() for path, name in files)).hexdigest()


def source_inventory(root):
    return {path.relative_to(root).as_posix(): fingerprint(path)
            for path in sorted([path for path in (root / HARNESS).iterdir() if path.is_file()] + [root / path for path in DONORS])}


def normalized(document, identity):
    if document.get("schema") != 4 or document.get("type") != "resilient_negotiation":
        raise ValueError("unexpected frozen E8 schema/type")
    value = dict(document)
    value["digest"] = "<source-dependent>"
    value["candidate"] = normalized_negotiated(document["candidate"], identity)
    return value


def compare(frozen, current, identity, destination):
    manifests = [json.loads((root / "campaign.json").read_text()) for root in (frozen, current)]
    names = [{record["file"] for record in manifest["records"]} for manifest in manifests]
    storage = [json.loads((root / "storage.json").read_text())["records"] for root in (frozen, current)]
    report = {"schema": 1, "frozen_source": PARENT, "candidate_source": identity,
              "normalization": "Only enumerated source identity, request/result digests, and compiled-definition SHA256 suffix; no behavioral/prose equivalence table is used.",
              "expected_cases_per_policy": 108, "seeds": SEEDS, "cases": [], "errors": [], "started_utc": now()}
    if names[0] != names[1] or len(names[0]) != 216 or any(manifest["result"] != "PASS" for manifest in manifests):
        report["errors"].append({"frozen_cases": len(names[0]), "candidate_cases": len(names[1]),
                                 "missing": sorted(names[0] - names[1]), "unexpected": sorted(names[1] - names[0]),
                                 "campaign_results": [manifest["result"] for manifest in manifests]})
    for name in sorted(names[0] & names[1]):
        before, before_hash = read_record(frozen, name, storage[0])
        after, after_hash = read_record(current, name, storage[1])
        a, b = normalized(before, PARENT), normalized(after, identity)
        a_hash, b_hash = hashlib.sha256(canonical(a)).hexdigest(), hashlib.sha256(canonical(b)).hexdigest()
        policy = "E8_hard_only" if name.startswith("E8_hard_only_") else "E8"
        record = {"file": name, "policy": policy, "equal": a_hash == b_hash,
                  "frozen_behavior_sha256": a_hash, "candidate_behavior_sha256": b_hash,
                  "frozen_raw_sha256": before_hash, "candidate_raw_sha256": after_hash}
        report["cases"].append(record)
        if not record["equal"]:
            report["errors"].append({"file": name, "first_mismatch": first_mismatch(a, b)})
    report["policies"] = {policy: {"cases_compared": sum(row["policy"] == policy for row in report["cases"]),
                                   "exact_matches": sum(row["policy"] == policy and row["equal"] for row in report["cases"])}
                          for policy in ("E8", "E8_hard_only")}
    report["exact_matches"] = sum(row["equal"] for row in report["cases"])
    report["result"] = "FAIL" if report["errors"] or any(row["cases_compared"] != 108 for row in report["policies"].values()) else "PASS"
    report["finished_utc"] = now()
    atomic_json(destination, report)
    if report["result"] != "PASS":
        raise RuntimeError("Frozen E8/hard-only reproduction differs; all raw cases retained")
    return {key: report[key] for key in ("result", "policies", "exact_matches", "normalization")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--build", type=Path, default=Path("/tmp/sw4-frozen-controls-build"))
    parser.add_argument("--allow-dirty", action="store_true")
    parser.add_argument("--snapshot", type=Path, help="Resume as explicitly snapshot-qualified development evidence from a retained interrupted manifest")
    args = parser.parse_args()
    out, build_parent = args.out.resolve(), args.build.resolve()
    if out.is_relative_to(ROOT) or build_parent.is_relative_to(ROOT) or out.is_relative_to(build_parent) or build_parent.is_relative_to(out):
        parser.error("Separate source, build and evidence trees are required")
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        parser.error("Fresh output directory required")
    source, dirty = git("rev-parse", "HEAD"), git("status", "--porcelain")
    if args.snapshot and not args.allow_dirty:
        parser.error("Snapshot replay is development evidence and requires --allow-dirty")
    if dirty and not args.allow_dirty:
        parser.error("Dirty source requires explicitly labelled --allow-dirty development run")
    all_inputs, inputs = retained_source_inputs(), code_inputs()
    identity = source + ("+dirty-" + hashlib.sha256(canonical(inputs)).hexdigest()[:12] if dirty else "")
    snapshot_manifest = None
    if args.snapshot:
        snapshot_path = args.snapshot.resolve()
        snapshot_manifest = json.loads(snapshot_path.read_text())
        source, identity = snapshot_manifest["source_commit"], snapshot_manifest["execution_identity"]
        all_inputs = snapshot_manifest["source_inputs"]
        dirty = snapshot_manifest.get("dirty_status", "captured development snapshot")
        snapshot_archive = snapshot_path.parent / "candidate-source.tar.gz"
        if fingerprint(snapshot_archive) != snapshot_manifest["source_archives"]["candidate-source.tar.gz"]:
            raise ValueError("Retained candidate source archive hash changed")
    if not dirty and not args.snapshot:
        verify_committed_inputs(all_inputs)
    out.mkdir(parents=True, exist_ok=True)
    build_parent.mkdir(parents=True, exist_ok=True)
    build = Path(tempfile.mkdtemp(prefix="e8-", dir=build_parent))
    manifest = {"schema": 1, "programme": "GENTEK-SWARM-004 frozen SWARM-003 reproduction",
                "source_commit": source, "execution_identity": identity,
                "source_tree": snapshot_manifest["source_tree"] if snapshot_manifest else git("rev-parse", "HEAD^{tree}"),
                "frozen_source": PARENT, "clean_source": not bool(dirty), "dirty_status": dirty,
                "source_inputs": all_inputs, "seeds": SEEDS, "expected_records_per_source": 216,
                "build_directory": str(build), "platform": platform.platform(), "started_utc": now(),
                "source_custody_scope": "captured_snapshot" if args.snapshot else "live_source",
                "snapshot_manifest": str(args.snapshot.resolve()) if args.snapshot else None,
                "commands": [], "result": "RUNNING"}
    save = lambda: atomic_json(out / "manifest.json", manifest)
    runner = CommandRunner(out, manifest, save)
    save()
    prior = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}

    def cancel(signum, _frame):
        raise RunnerCancelled(signal.Signals(signum).name)

    for sig in prior:
        signal.signal(sig, cancel)
    try:
        runner.execute("parent-ancestry", ["git", "merge-base", "--is-ancestor", PARENT, source], 30)
        runner.execute("compiler", [os.environ.get("CXX", "g++"), "--version"], 30)
        manifest["compiler"] = (out / "compiler.log").read_text().splitlines()[0]
        archive = out / "frozen-source.tar.gz"
        runner.execute("frozen-source-export", ["git", "archive", "--format=tar.gz", "-o", archive, PARENT, "--", HARNESS, *DONORS], 60)
        frozen_source = build / "frozen-source"
        unpack_source(archive, frozen_source)
        frozen_inputs = source_inventory(frozen_source)
        atomic_json(out / "frozen-source-inventory.json", frozen_inputs)
        candidate_source = ROOT
        if args.snapshot:
            candidate_source = build / "candidate-source"
            unpack_source(snapshot_archive, candidate_source)
            if source_inventory(candidate_source) != all_inputs:
                raise ValueError("Captured source bytes differ from their original inventory")
        with tarfile.open(out / "candidate-source.tar.gz", "w:gz") as snapshot:
            for name in all_inputs:
                snapshot.add(candidate_source / name, arcname=name, recursive=False)
        driver = out / "frozen-control-driver.cpp"
        driver.write_text(DRIVER)
        manifest["driver_sha256"] = fingerprint(driver)
        if snapshot_manifest and manifest["driver_sha256"] != snapshot_manifest["driver_sha256"]:
            raise ValueError("Replay driver differs from the originally retained control driver")
        manifest["source_archives"] = {name: fingerprint(out / name) for name in ("frozen-source.tar.gz", "candidate-source.tar.gz")}
        manifest["definitions"], manifest["binaries"] = {}, {}
        for label, root, source_id in (("frozen", frozen_source, PARENT), ("candidate", candidate_source, identity)):
            definition = definition_hash(root)
            binary = build / (label + "-e8-controls")
            command = [os.environ.get("CXX", "g++"), "-std=c++20", "-Wall", "-Wextra", "-Wpedantic", "-Werror", "-O2",
                       "-I" + str(root / "native/include"), "-I" + str(root / HARNESS),
                       '-DGENTEK_DEFINITION_SHA256="' + definition + '"',
                       *[root / HARNESS / (name + ".cpp") for name in LEGACY], root / "native/src/generation_spatial.cpp", driver, "-o", binary]
            runner.execute(label + "-build", command, 1200)
            manifest["definitions"][label] = definition
            manifest["binaries"][label] = {"path": str(binary), "sha256": fingerprint(binary)}
            campaign = out / label
            compressor = CompressionWorker(campaign)
            compressor.start()
            failure = None
            try:
                runner.execute(label + "-108-case-controls", [binary, campaign, source_id], 1200)
            except BaseException as error:
                failure = error
            finally:
                try:
                    compressor.finish(drain=not isinstance(failure, RunnerCancelled))
                except BaseException as error:
                    manifest[label + "_compression_error"] = f"{type(error).__name__}: {error}"
                    if failure is None:
                        failure = error
            if failure:
                raise failure
        manifest["comparison"] = compare(out / "frozen", out / "candidate", identity, out / "frozen-e8-comparison.json")
        if args.snapshot:
            if source_inventory(candidate_source) != all_inputs:
                raise RuntimeError("Captured candidate source changed during reproduction")
        elif git("rev-parse", "HEAD") != source or retained_source_inputs() != all_inputs or code_inputs() != inputs:
            raise RuntimeError("Live source changed during frozen reproduction")
        if source_inventory(frozen_source) != frozen_inputs:
            raise RuntimeError("Frozen source changed during reproduction")
        if not dirty and not args.snapshot:
            verify_committed_inputs(all_inputs)
        manifest.update(result="PASS", source_custody_revalidated=True)
    except RunnerCancelled as error:
        manifest.update(result="CANCELLED", error=str(error))
        raise
    except BaseException as error:
        manifest.update(result="FAIL", error=f"{type(error).__name__}: {error}")
        raise
    finally:
        for sig, handler in prior.items():
            signal.signal(sig, handler)
        manifest["finished_utc"] = now()
        manifest["artifact_inventory"] = inventory(out)
        save()
    print(json.dumps(manifest["comparison"], indent=2))


if __name__ == "__main__":
    main()
