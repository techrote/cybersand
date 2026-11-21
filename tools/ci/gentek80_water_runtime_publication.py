#!/usr/bin/env python3
"""Exact-branch/source-qualified evidence for the merged Water + GENTEK-80 candidate.

This dedicated wrapper changes only the explicit branch, workflow and request
identity of the existing strict Gentek publisher. The existing source, native,
gallery, replay, lease and target-OS validation must still pass. No automatic
publication into the repository, Ready promotion or merge is authorized.
"""
from __future__ import annotations
import gentek80_runtime_publication as gentek80

engine = gentek80.engine
engine.BRANCH = "integration/gentek80-water-conflict-reconcile"
engine.WORKFLOW = ".github/workflows/gentek80-water-merged-requalification.yml"
engine.REQUEST = "tools/ci/gentek80_water_publish_request.json"
engine.EVIDENCE = "docs/audits/gentek80-water-conflict-reconciliation.md"
engine.REQUEST_VALUE = {
    "schema": "gentek80-water-main-runtime-qualification-v1",
    "family": "gen007-architectural-generator",
    "variant": "72-repaired-classic-plus-eight-showcases-with-accepted-water",
    "scope": "combined-water-gentek80-source-qualified-linux-windows-native-graphical-owner-package",
    "intent": "qualify-source-matched-runtimes-without-merge",
}
engine.BUILD_EXACT = set(engine.BUILD_EXACT) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/gentek80_water_runtime_publication.py",
    "tools/ci/ci_opt_publish_request.py",
    "tools/ci/test_ci_opt_publish_request.py",
    "tools/ci/test_gentek80_water_runtime_publication.py",
    "tools/architecture/gentek80_reference_inputs.py",
    "tools/architecture/test_gentek80_reference_inputs.py",
    "tools/architecture/gentek80_water_reference_delta.json",
}
gentek80.REFERENCE_DELTA_POLICY = "tools/architecture/gentek80_water_reference_delta.json"

def main() -> int:
    return gentek80.main()

if __name__ == "__main__":
    raise SystemExit(main())
