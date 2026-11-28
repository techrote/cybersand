#!/usr/bin/env python3
"""Bounded independent-review negatives; never modify the original archive.

Synthetic artifact metadata is deliberately repinned where stated, challenging
the semantic joins rather than merely the outer ZIP digest. No native execution.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
from types import SimpleNamespace
import zipfile


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("archive", "metadata", "repo", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--artifact-id", type=int, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    inspector = Path(__file__).with_name("review_native_candidate.py")
    spec = importlib.util.spec_from_file_location("independent_native_review", inspector)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    metadata = json.loads(args.metadata.read_text())
    original_hash = sha(args.archive)
    rows = []

    def refused(label, expected, *, archive=None, supplied_metadata=None, source=None, git_ref=None):
        supplied_metadata = supplied_metadata or metadata
        path = args.output / (label + "-metadata.json")
        path.write_text(json.dumps(supplied_metadata, indent=2, sort_keys=True) + "\n")
        candidate = SimpleNamespace(archive=archive or args.archive, metadata=path, repo=args.repo,
                                    source_sha=source or args.source_sha, git_ref=git_ref or args.source_sha,
                                    artifact_id=args.artifact_id)
        try:
            module.review(candidate)
        except ValueError as error:
            if expected not in str(error):
                raise RuntimeError(label + " failed for an unrelated reason: " + str(error)) from error
            rows.append({"case": label, "refused": True, "reason": str(error),
                         "archive_bytes": candidate.archive.stat().st_size,
                         "archive_sha256": sha(candidate.archive), "metadata_sha256": sha(path)})
        else:
            raise RuntimeError(label + " unexpectedly admitted an invalid archive")

    bad = copy.deepcopy(metadata)
    next(row for row in bad["artifacts"] if row["id"] == args.artifact_id)["digest"] = "sha256:" + "0" * 64
    refused("incorrect-external-digest", "external GitHub size or digest", supplied_metadata=bad)
    refused("incorrect-source", "External artifact source differs", source="0" * 40)
    refused("incorrect-source-tree", "Reviewed Git tree differs", git_ref="f5b7ac7e651356c9f6d5657dfb0cb9d60111be81")

    def repin(path):
        value = copy.deepcopy(metadata)
        artifact = next(row for row in value["artifacts"] if row["id"] == args.artifact_id)
        artifact.update(size_in_bytes=path.stat().st_size, digest="sha256:" + sha(path))
        return value

    with zipfile.ZipFile(args.archive) as original:
        input_names = sorted(name for name in original.namelist() if name.endswith("/inputs.json"))
        records = {name: json.loads(original.read(name)) for name in input_names}
        for group, label in (("native", "missing-native-source-key"),
                             ("retained-lab-native-budgets", "missing-benchmark-source-key")):
            name = next(name for name in input_names if name.startswith(group + "/"))
            changed = copy.deepcopy(records)
            removed = sorted(changed[name]["sources"])[0]
            del changed[name]["sources"][removed]
            specification = {key: value for key, value in changed[name].items()
                             if key not in {"git_head", "git_status", "source_root", "input_digest"}}
            changed[name]["input_digest"] = hashlib.sha256(json.dumps(specification, sort_keys=True).encode()).hexdigest()
            mutant = args.output / (label + ".zip")
            with zipfile.ZipFile(mutant, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as out:
                for item, value in changed.items():
                    out.writestr(item, json.dumps(value, indent=2, sort_keys=True) + "\n")
                # The benchmark map is read after native sources. Preserve that
                # entire earlier input group so its own source join succeeds.
                if group != "native":
                    first = next(item for item in input_names if item.startswith("native/"))
                    prefix = first.rsplit("/", 1)[0]
                    for source_path in records[first]["sources"]:
                        member = prefix + "/source/" + source_path
                        out.writestr(member, original.read(member))
            refused(label, group + " incomplete or unexpected source-input inventory",
                    archive=mutant, supplied_metadata=repin(mutant))
            rows[-1].update(removed_source_key=removed, input_digest_recomputed=True, synthetic_external_metadata_repinned=True)
            mutant.unlink()

        mutant = args.output / "substituted-benchmark-command.zip"
        prefix = next(name.rsplit("/", 1)[0] for name in input_names if name.startswith("retained-lab-native-budgets/"))
        changed_paths = {"retained-lab-native-budgets/summary.json", prefix + "/summary.json"}
        with zipfile.ZipFile(mutant, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as out:
            for info in original.infolist():
                if info.filename in changed_paths:
                    value = json.loads(original.read(info.filename))
                    value["execution"]["command"] = ["true"]
                    out.writestr(info, json.dumps(value, indent=2, sort_keys=True) + "\n")
                else:
                    with original.open(info) as incoming, out.open(info, "w") as outgoing:
                        shutil.copyfileobj(incoming, outgoing, length=1024 * 1024)
        refused("substituted-benchmark-command", "Benchmark executable or exact unfiltered sample arguments differ",
                archive=mutant, supplied_metadata=repin(mutant))
        rows[-1].update(mutated_summary_copies=sorted(changed_paths), synthetic_external_metadata_repinned=True)
        mutant.unlink()

    assert sha(args.archive) == original_hash
    result = {"schema": "objectshard-m4-native-candidate-review-adversity-v1", "status": "passed",
              "source_commit": args.source_sha, "inspector_sha256": sha(inspector),
              "challenger_sha256": sha(Path(__file__)), "original_archive_sha256": original_hash,
              "original_archive_unchanged": True, "negative_controls": rows,
              "scope": "Six focused false-PASS challenges; synthetic metadata never becomes qualification evidence; no native executable is run.",
              "retention": "Keep original externally pinned artifact and these repeatable recipes; generated mutant ZIPs removed after recorded refusal to conserve shared memory."}
    (args.output / "review.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": result["status"], "refusals": len(rows), "original_archive_unchanged": True}))


if __name__ == "__main__":
    main()
