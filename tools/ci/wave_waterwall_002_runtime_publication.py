#!/usr/bin/env python3
"""Branch-scoped Waterwall 002 publisher using the qualified #672 evidence checks."""
import wave_waterwall_runtime_publication as parent

engine = parent.engine
engine.BRANCH = "codex/wave-waterwall-002"
engine.WORKFLOW = ".github/workflows/wave-waterwall-002-runtime-publication.yml"
engine.REQUEST = "tools/ci/wave_waterwall_002_publish_request.json"
engine.EVIDENCE = "docs/audits/2026-11-19-wave-waterwall-002.md"
engine.REQUEST_VALUE = dict(engine.REQUEST_VALUE, schema="wave-waterwall-002-runtime-publish-request-v1")
engine.BUILD_EXACT = engine.BUILD_EXACT | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/wave_waterwall_002_runtime_publication.py",
    "tools/ci/test_wave_waterwall_002_runtime_publication.py",
}
engine.EXECUTION_SCOPE += " Waterwall 002 staged Sloshy and Max over-ledge controls and native conservation."
if __name__ == "__main__":
    raise SystemExit(engine.main())
