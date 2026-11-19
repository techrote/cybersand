#!/usr/bin/env python3
"""Branch-scoped Water ramp publisher using the qualified #676 evidence checks."""
import wave_waterwall_002_runtime_publication as parent

engine = parent.engine
engine.BRANCH = "codex/wave-water-ramp-003"
engine.WORKFLOW = ".github/workflows/wave-water-ramp-003-runtime-publication.yml"
engine.REQUEST = "tools/ci/wave_water_ramp_003_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-19-wave-water-ramp-003.md"
engine.REQUEST_VALUE = dict(engine.REQUEST_VALUE, schema="wave-water-ramp-003-runtime-publish-request-v1", variant="fresh-wave-spill-ballistic")
engine.BUILD_EXACT = engine.BUILD_EXACT | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/wave_water_ramp_003_runtime_publication.py",
    "tools/ci/test_wave_water_ramp_003_runtime_publication.py",
}
engine.EXECUTION_SCOPE += " Water ramp fresh Water defaults, staged tuning and native conservation."
if __name__ == "__main__":
    raise SystemExit(engine.main())
