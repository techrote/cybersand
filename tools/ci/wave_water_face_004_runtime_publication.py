#!/usr/bin/env python3
"""Branch-scoped full-face Water publisher using the qualified #677 evidence checks."""
import wave_water_ramp_003_runtime_publication as parent

engine = parent.engine
engine.BRANCH = "codex/wave-water-face-004"
engine.WORKFLOW = ".github/workflows/wave-water-face-004-runtime-publication.yml"
engine.REQUEST = "tools/ci/wave_water_face_004_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-19-wave-water-face-004.md"
engine.REQUEST_VALUE = dict(engine.REQUEST_VALUE, schema="wave-water-face-004-runtime-publish-request-v1", variant="full-face-spill-ballistic")
engine.BUILD_EXACT = engine.BUILD_EXACT | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/wave_water_face_004_runtime_publication.py",
    "tools/ci/test_wave_water_face_004_runtime_publication.py",
}
engine.EXECUTION_SCOPE += " Full-face Water discharge at fall speed 3 and native conservation."
if __name__ == "__main__":
    raise SystemExit(engine.main())
