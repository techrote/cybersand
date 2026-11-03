#!/usr/bin/env python3
"""Reject altered manifests using an actual source-bound runtime build bundle."""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import re
import tempfile

from run_graphical_campaign import authenticate_runtime, comparable_builds, git_value, read_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--runtime", required=True, type=Path)
    parser.add_argument("--candidate", choices=["control", "R"], required=True)
    args = parser.parse_args()
    head = git_value("HEAD")
    authenticate_runtime(args.manifest, args.runtime, args.candidate, head)
    original = read_json(args.manifest)
    controls = []
    with tempfile.TemporaryDirectory(prefix="render-copy-manifest-") as directory:
        path = Path(directory)/"altered.json"

        def rejects(name, mutation):
            altered = copy.deepcopy(original)
            mutation(altered)
            path.write_text(json.dumps(altered), encoding="utf-8")
            try:
                authenticate_runtime(path, args.runtime, args.candidate, head)
            except (ValueError, KeyError):
                controls.append(name)
                return
            raise RuntimeError("accepted altered manifest: " + name)

        rejects("wrong-platform-library", lambda d: d.update(artifact="wrong-library.dll"))
        rejects("wrong-source-tree", lambda d: d.update(source_tree="0"*40))
        rejects("native-input-omitted", lambda d: d["source_inputs"].pop(next(iter(d["source_inputs"]))))
        rejects("native-source-changed", lambda d: d["source_inputs"].update({"native/src/world.cpp": "0"*64}))
        rejects("build-inputs-omitted", lambda d: d.update(build_inputs={}))
        rejects("build-input-partial-omission", lambda d: d["build_inputs"].pop("tools/build_native_extension.sh"))
        rejects("toolchain-omitted", lambda d: d.pop("toolchain"))
        rejects("wrong-binary-hash", lambda d: d.update(sha256="0"*64))
        rejects("wrong-binary-size", lambda d: d.update(size=d["size"]+1))
    # Compare real authenticated build metadata against controlled corruptions.
    # Actual Control/R source and runtime pairing is separately enforced by the
    # campaign driver; these are adversarial checks of its comparator itself.
    comparable_builds(original, original)
    relocated = copy.deepcopy(original)
    relocated["toolchain"] = re.sub(r"(?m)^([0-9a-f]{64})[ \t]+\*?(.+)$",
        lambda match: match[1] + "  /different/build/root/" + match[2].replace("\\", "/").rsplit("/", 1)[-1],
        relocated["toolchain"])
    comparable_builds(original, relocated)

    def pair_rejects(name, mutation):
        altered = copy.deepcopy(original)
        mutation(altered)
        try:
            comparable_builds(original, altered)
        except (ValueError, KeyError):
            controls.append(name)
            return
        raise RuntimeError("accepted noncomparable build pair: " + name)

    pair_rejects("changed-toolchain-pair", lambda d: d.update(toolchain=d["toolchain"] + "\ncompiler flags changed: -O0"))
    pair_rejects("changed-archive-pair", lambda d: d.update(toolchain=re.sub(
        r"(?m)^[0-9a-f]{64}([ \t]+\*?.+)$", "0"*64 + r"\1", d["toolchain"])))
    pair_rejects("changed-build-script-pair", lambda d: d["build_inputs"].update({"tools/build_native_extension.sh":"0"*64}))
    print(json.dumps({"status": "passed", "positive": "actual authenticated runtime bundle",
                      "pair_comparator_positive": "authenticated metadata plus archive-path-only relocation",
                      "candidate": args.candidate, "negative_controls": controls}, indent=2))


if __name__ == "__main__":
    main()
