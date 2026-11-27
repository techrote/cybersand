#!/usr/bin/env python3
"""Source-bound SWARM-004 qualification; holdouts require committed selection.

Raw native JSON is losslessly compressed only after the native campaign lists a
completed record. Both byte hashes are retained. No failed case is filtered.
This is native qualification, never Windows/Workbench or physics acceptance.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import signal
import sys
import tarfile
import tempfile
import threading

from run_negotiated import DONORS, HERE, ROOT, canonical, fingerprint, git, now
from run_resilience import CommandRunner, RunnerCancelled, retained_source_inputs, verify_committed_inputs

PARENT = "cd0de74b83a66b5408668f81c82d854db45479ce"
HOLDOUT_SEEDS = [19457, 32771]
SUITES = ("test_assembly", "test_reciprocal_mosaic", "test_reciprocal")


def code_inputs():
    paths = sorted(p for p in HERE.iterdir() if p.is_file() and
                   (p.suffix in (".cpp", ".hpp", ".py") or p.name.startswith("Makefile")))
    paths.extend(ROOT / p for p in DONORS)
    return {p.relative_to(ROOT).as_posix(): fingerprint(p) for p in paths}


def atomic_json(path, document):
    path = Path(path)
    temporary = path.with_name(path.name + ".partial")
    temporary.write_text(json.dumps(document, indent=2) + "\n")
    temporary.replace(path)


def read_selection(path, policy, inputs, clean):
    if not clean:
        raise ValueError("Holdouts require clean committed source, never --allow-dirty")
    path = Path(path).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise ValueError("Holdout selection must be a committed repository file")
    relative = path.relative_to(ROOT).as_posix()
    git("ls-files", "--error-unmatch", "--", relative)
    if git("hash-object", "--", relative) != git("rev-parse", "HEAD:" + relative):
        raise ValueError("Selection differs from its committed source")
    selection = json.loads(path.read_text())
    source_hash = hashlib.sha256(canonical(inputs)).hexdigest()
    if selection.get("selected_policy") != policy or selection.get("holdout_seeds") != HOLDOUT_SEEDS:
        raise ValueError("Selection must freeze selected_policy and holdout_seeds [19457, 32771]")
    if selection.get("source_input_fingerprint") != source_hash:
        raise ValueError("Selection source_input_fingerprint does not match the complete current native build inputs")
    return {"path": relative, "sha256": fingerprint(path), "document": selection,
            "selection_commit": git("log", "-1", "--format=%H", "HEAD", "--", relative)}


class CompressionWorker:
    """Keep campaign disk use bounded without changing any native evidence bytes."""

    def __init__(self, root):
        self.root = Path(root).resolve()
        self.stop = threading.Event()
        self.drain_on_stop = True
        self.records = {}
        self.error = None
        self.thread = threading.Thread(target=self._run, name="reciprocal-evidence-compressor", daemon=False)

    def start(self):
        self.thread.start()

    def _save(self):
        atomic_json(self.root / "storage.json", {"schema": 1, "encoding": "gzip; original bytes unchanged",
                    "records": self.records, "error": self.error})

    def _pass(self):
        manifest = self.root / "campaign.json"
        try:
            campaign = json.loads(manifest.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return
        for record in campaign.get("records", []):
            if self.stop.is_set() and not self.drain_on_stop:
                return  # remaining immutable JSON stays available verbatim
            name = record["file"]
            if name in self.records:
                continue
            raw = (self.root / name).resolve()
            if not raw.is_relative_to(self.root.resolve()) or raw.suffix != ".json":
                raise ValueError("Campaign record path escapes its evidence directory")
            if not raw.is_file():
                raise ValueError(f"Completed campaign record disappeared: {name}")
            packed = raw.with_name(raw.name + ".gz")
            if packed.exists():
                raise ValueError(f"Unexpected existing compressed record: {packed}")
            temporary = packed.with_name(packed.name + ".partial")
            digest = hashlib.sha256()
            size = 0
            with raw.open("rb") as source, temporary.open("xb") as destination:
                with gzip.GzipFile(filename="", fileobj=destination, mode="wb", compresslevel=6, mtime=0) as compressed:
                    for block in iter(lambda: source.read(1024 * 1024), b""):
                        digest.update(block)
                        size += len(block)
                        compressed.write(block)
            temporary.replace(packed)
            check = hashlib.sha256()
            with gzip.open(packed, "rb") as restored:
                for block in iter(lambda: restored.read(1024 * 1024), b""):
                    check.update(block)
            if check.hexdigest() != digest.hexdigest():
                raise ValueError(f"Lossless compression failed verification: {name}")
            self.records[name] = {"file": packed.relative_to(self.root).as_posix(), "raw_bytes": size,
                "raw_sha256": digest.hexdigest(), "compressed_bytes": packed.stat().st_size,
                "compressed_sha256": fingerprint(packed)}
            self._save()
            raw.unlink()  # only after the recoverable byte-equivalent copy and manifest exist

    def _run(self):
        try:
            while not self.stop.wait(0.4):
                self._pass()
            if self.drain_on_stop:
                self._pass()
        except BaseException as error:
            self.error = f"{type(error).__name__}: {error}"
        finally:
            if self.root.is_dir():
                self._save()

    def finish(self, drain=True):
        self.drain_on_stop = drain
        self.stop.set()
        self.thread.join()
        if self.error:
            raise RuntimeError("Native evidence compression failed: " + self.error)


def verified_frozen_evidence(path, identity):
    path = Path(path).resolve()
    manifest_path = path / "manifest.json" if path.is_dir() else path
    value = json.loads(manifest_path.read_text())
    if value.get("result") != "PASS" or value.get("execution_identity") != identity or not value.get("source_custody_revalidated"):
        raise ValueError("Frozen B/C evidence is not a passing exact-source qualification")
    b = value["control_qualification"]["swarm001_regression"]
    c = value["frozen_c_regression"]
    if b.get("exact_matches") != 171 or c.get("exact_matches") != 72:
        raise ValueError("Frozen control record does not establish B 171/171 and C 72/72")
    return {"manifest": str(manifest_path), "sha256": fingerprint(manifest_path), "B": b, "C": c}


def inventory(out):
    records = {}
    for path in sorted(Path(out).rglob("*")):
        if path.is_file() and path.name not in ("manifest.json", "sha256sums.txt"):
            records[path.relative_to(out).as_posix()] = fingerprint(path)
    (Path(out) / "sha256sums.txt").write_text("".join(f"{digest}  {name}\n" for name, digest in records.items()))
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--build", type=Path, default=Path("/tmp/gentek-reciprocal-build"))
    parser.add_argument("--lane", choices=("known", "holdout"), default="known")
    parser.add_argument("--selected-policy")
    parser.add_argument("--selection", type=Path, default=HERE / "SELECTION-RECIPROCAL.json")
    parser.add_argument("--qualification", action="store_true")
    parser.add_argument("--frozen-evidence", type=Path)
    parser.add_argument("--sanitize", action="store_true")
    parser.add_argument("--allow-dirty", action="store_true")
    parser.add_argument("--tests-only", action="store_true")
    args = parser.parse_args()
    out, build_parent = args.out.resolve(), args.build.resolve()
    if out.is_relative_to(ROOT) or build_parent.is_relative_to(ROOT):
        parser.error("Evidence and fresh build directories must be outside the source repository")
    if out.is_relative_to(build_parent) or build_parent.is_relative_to(out):
        parser.error("Evidence and build directories must be separate trees")
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        parser.error("Use a fresh empty evidence directory")
    registration = json.loads((HERE / "RECIPROCAL_REGISTRATION.json").read_text())
    if args.selected_policy and args.selected_policy not in registration["policies"]:
        parser.error("Unknown registered selected policy")
    if args.qualification and (args.allow_dirty or not args.sanitize or args.tests_only):
        parser.error("Qualification requires clean source, --sanitize and the complete declared campaign")
    if args.qualification and args.lane == "known" and args.selected_policy:
        parser.error("Known qualification requires every registered policy; selection belongs after the comparison")
    if args.lane == "holdout" and (not args.selected_policy or args.selected_policy == "validation_off_diagnostic"):
        parser.error("Holdouts require one committed admissible selected policy")
    source, tree, dirty = git("rev-parse", "HEAD"), git("rev-parse", "HEAD^{tree}"), git("status", "--porcelain")
    if dirty and not args.allow_dirty:
        parser.error("Dirty source requires explicit --allow-dirty development labelling")
    inputs, all_inputs = code_inputs(), retained_source_inputs()
    source_hash = hashlib.sha256(canonical(inputs)).hexdigest()
    identity = source + ("+dirty-" + source_hash[:12] if dirty else "")
    if not dirty:
        verify_committed_inputs(all_inputs)
    selection = read_selection(args.selection, args.selected_policy, inputs, not bool(dirty)) if args.lane == "holdout" else None
    out.mkdir(parents=True, exist_ok=True)
    build_parent.mkdir(parents=True, exist_ok=True)
    build = Path(tempfile.mkdtemp(prefix=source_hash[:16] + "-", dir=build_parent))
    manifest = {"schema": 1, "programme": "GENTEK-SWARM-004", "scope": "Native research; Draft/HOLD; no Windows or Workbench acceptance",
        "source_commit": source, "source_tree": tree, "execution_identity": identity, "parent_commit": PARENT,
        "branch": git("branch", "--show-current"), "clean_source": not bool(dirty), "dirty_status": dirty,
        "source_inputs": inputs, "source_input_fingerprint": source_hash, "complete_harness_and_donor_inputs": all_inputs,
        "registration": registration, "lane": args.lane, "selected_policy": args.selected_policy, "selection": selection,
        "fresh_build_directory": str(build), "platform": platform.platform(), "python": sys.version,
        "qualification_requested": args.qualification, "sanitizers_requested": args.sanitize,
        "leak_check": "disabled under host instrumentation; no leak pass claimed", "tests_only": args.tests_only,
        "started_utc": now(), "result": "RUNNING", "commands": []}

    def save():
        atomic_json(out / "manifest.json", manifest)

    def custody():
        if git("rev-parse", "HEAD") != source or git("rev-parse", "HEAD^{tree}") != tree or code_inputs() != inputs or retained_source_inputs() != all_inputs:
            raise RuntimeError("Source changed during this source-qualified run")
        if not dirty:
            if git("status", "--porcelain"):
                raise RuntimeError("Clean source became dirty during qualification")
            verify_committed_inputs(all_inputs)

    runner = CommandRunner(out, manifest, save)
    save()
    prior = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}

    def cancel(signum, _frame):
        raise RunnerCancelled(signal.Signals(signum).name)

    for sig in prior:
        signal.signal(sig, cancel)
    try:
        atomic_json(out / "source-inventory.json", all_inputs)
        with tarfile.open(out / "source-snapshot.tar.gz", "w:gz") as archive:
            for name in all_inputs:
                archive.add(ROOT / name, arcname=name, recursive=False)
        manifest["source_archive"] = {"file": "source-snapshot.tar.gz", "sha256": fingerprint(out / "source-snapshot.tar.gz")}
        runner.execute("parent-ancestry", ["git", "merge-base", "--is-ancestor", PARENT, source], 30)
        runner.execute("compiler", [os.environ.get("CXX", "g++"), "--version"], 30)
        manifest["compiler"] = (out / "compiler.log").read_text().splitlines()[0]
        runner.execute("runner-lifecycle-tests", [sys.executable, HERE / "test_resilience_runner.py"], 120)
        if args.qualification:
            if args.frozen_evidence:
                manifest["frozen_controls"] = verified_frozen_evidence(args.frozen_evidence, identity)
            else:
                frozen = out / "frozen-controls"
                runner.execute("frozen-b-c", [sys.executable, HERE / "run_admission.py", "--out", frozen, "--sanitize"], 3600)
                manifest["frozen_controls"] = verified_frozen_evidence(frozen, identity)
            frozen_e8 = out / "frozen-e8-controls"
            runner.execute("frozen-e8-hard-only", [sys.executable, HERE / "reproduce_reciprocal_controls.py", "--out", frozen_e8], 3600)
            frozen_e8_manifest = json.loads((frozen_e8 / "manifest.json").read_text())
            if frozen_e8_manifest.get("result") != "PASS" or frozen_e8_manifest.get("execution_identity") != identity or not frozen_e8_manifest.get("source_custody_revalidated"):
                raise RuntimeError("Frozen E8/hard-only source qualification failed")
            manifest["frozen_e8_controls"] = {"manifest": str(frozen_e8 / "manifest.json"),
                "sha256": fingerprint(frozen_e8 / "manifest.json"), "comparison": frozen_e8_manifest["comparison"]}
        runner.execute("reciprocal-build", ["make", "-C", HERE, "-f", "Makefile.reciprocal", f"BUILD={build}", "all"], 1200)
        runner.execute("reciprocal-evidence-parser-tests", [sys.executable, HERE / "test_reciprocal_io.py",
            "--binary", build / "gentek_reciprocal"], 180)
        runner.execute("reciprocal-gallery-damage-tests", [sys.executable, HERE / "test_reciprocal_gallery.py",
            "--binary", build / "gentek_reciprocal"], 180)
        for suite in SUITES:
            runner.execute(suite.replace("_", "-"), [build / suite], 1200)
        if args.sanitize:
            sanitized = Path(tempfile.mkdtemp(prefix=source_hash[:16] + "-san-", dir=build_parent))
            manifest["sanitizer_build_directory"] = str(sanitized)
            runner.execute("reciprocal-sanitizer-build", ["make", "-C", HERE, "-f", "Makefile.reciprocal",
                f"BUILD={sanitized}", "SANITIZE=1", "all"], 1800)
            for suite in SUITES:
                runner.execute(suite.replace("_", "-") + "-sanitized", [sanitized / suite], 1200)
        custody()
        if not args.tests_only:
            if args.lane == "holdout" and read_selection(args.selection, args.selected_policy, inputs, not bool(git("status", "--porcelain"))) != selection:
                raise RuntimeError("Frozen selection changed before opening holdouts")
            campaign = out / args.lane
            compressor = CompressionWorker(campaign)
            compressor.start()
            command = [build / "gentek_reciprocal", "campaign", campaign, identity, args.lane]
            if args.selected_policy:
                command.append(args.selected_policy)
            campaign_error = None
            try:
                runner.execute(args.lane + "-native-campaign", command, 3600)
            except BaseException as error:
                campaign_error = error
            finally:
                try:
                    compressor.finish(drain=not isinstance(campaign_error, RunnerCancelled))
                except BaseException as error:
                    manifest["compression_error"] = f"{type(error).__name__}: {error}"
                    if campaign_error is None:
                        campaign_error = error
            if isinstance(campaign_error, RunnerCancelled):
                raise campaign_error
            if campaign_error is None:
                causal = campaign / "causal"
                causal_compressor = CompressionWorker(causal)
                causal_compressor.start()
                causal_command = [build / "audit_reciprocal_causality", causal, identity, args.lane]
                if args.selected_policy:
                    causal_command.append(args.selected_policy)
                causal_error = None
                try:
                    runner.execute(args.lane + "-native-causal-controls", causal_command, 3600)
                except BaseException as error:
                    causal_error = error
                finally:
                    try:
                        causal_compressor.finish(drain=not isinstance(causal_error, RunnerCancelled))
                    except BaseException as error:
                        manifest["causal_compression_error"] = f"{type(error).__name__}: {error}"
                        if causal_error is None:
                            causal_error = error
                if causal_error:
                    raise causal_error
                causal_summary = json.loads((causal / "causal_summary.json").read_text())
                native_campaign = json.loads((campaign / "campaign.json").read_text())
                if (causal_summary.get("result") != "PASS" or causal_summary.get("source") != identity or
                        causal_summary.get("lane") != args.lane):
                    raise RuntimeError("Native causal controls lack a passing exact-source/lane receipt")
                if (set(causal_summary["policy_totals"]) != set(native_campaign["registered_policies"]) or
                        any(counts.get("cases") != native_campaign["expected_cases_per_policy"]
                            for counts in causal_summary["policy_totals"].values())):
                    raise RuntimeError("Native causal controls lack complete registered policy/case coverage")
                manifest["causal_controls"] = {"summary": str(causal / "causal_summary.json"),
                    "sha256": fingerprint(causal / "causal_summary.json"),
                    "policy_totals": causal_summary["policy_totals"]}
            if (campaign / "campaign.json").is_file():
                runner.execute(args.lane + "-native-gallery", [sys.executable, HERE / "reciprocal_gallery.py", campaign], 1800)
                manifest["native_summary"] = json.loads((campaign / "reciprocal_summary.json").read_text())
            if campaign_error:
                raise campaign_error
            if manifest["native_summary"]["audit"]["result"] != "PASS":
                raise RuntimeError("Native material/ownership campaign audit failed")
        custody()
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
        manifest["binaries"] = {name: fingerprint(build / name) for name in ("gentek_reciprocal", "audit_reciprocal_causality", *SUITES) if (build / name).is_file()}
        if manifest.get("sanitizer_build_directory"):
            sanitized = Path(manifest["sanitizer_build_directory"])
            manifest["sanitized_binaries"] = {name: fingerprint(sanitized / name) for name in SUITES if (sanitized / name).is_file()}
        manifest["artifact_inventory"] = inventory(out)
        save()
    print(f"Retained reciprocal evidence: {out}", flush=True)


if __name__ == "__main__":
    main()
