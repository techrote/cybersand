#!/usr/bin/env python3
"""Branch-scoped Wave Water and Oil publisher using the qualified #678 evidence checks."""
import wave_water_face_004_runtime_publication as parent

engine = parent.engine
engine.BRANCH = "codex/wave-oil-buoyancy"
engine.WORKFLOW = ".github/workflows/wave-oil-buoyancy-runtime-publication.yml"
engine.REQUEST = "tools/ci/wave_oil_buoyancy_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-19-wave-oil-buoyancy.md"
engine.REQUEST_VALUE = dict(engine.REQUEST_VALUE, schema="wave-oil-buoyancy-runtime-publish-request-v1", variant="water-oil-density-exchange")
engine.BUILD_EXACT = engine.BUILD_EXACT | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/wave_oil_buoyancy_runtime_publication.py",
    "tools/ci/test_wave_oil_buoyancy_runtime_publication.py",
}
engine.EXECUTION_SCOPE += " Native Water and Oil conservation, slick formation and spray after a fresh wave."
if __name__ == "__main__":
    raise SystemExit(engine.main())
