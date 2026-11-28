"""Publish the two ObjectShard Workbench runtimes through the guarded native publisher."""

import os
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import re
import sys

CI = Path(__file__).resolve().parents[1] / "ci"
sys.path.insert(0, str(CI))
spec = spec_from_file_location("_objectshard_publisher", CI / "lcb001_shared_contract_runtime_publication.py")
engine = module_from_spec(spec)
spec.loader.exec_module(engine)

inherited_paths = {engine.WORKFLOW, engine.REQUEST}
engine.BRANCH = "integration/objectshard-m4-mainline-20261122"
engine.WORKFLOW = ".github/workflows/objectshard-m4-completion.yml"
engine.REQUEST = "tools/objectshard/production_runtime_request.json"
engine.EVIDENCE = "docs/audits/2026-11-25-objectshard-m4-delivery-recovery.md"
engine.PRESSURE_CASE = "godot/tests/test_object_shard_m4_same_world_extension.gd"
engine.REQUEST_VALUE = {
    "schema": "objectshard-m4-production-request-v1",
    "family": "objectshard-m4",
    "variant": "ordinary-workbench",
    "scope": "linux-windows-source-matched-native-runtime",
    "intent": "publish-source-matched-runtimes",
}
engine.BUNDLE_PREFIX = "objectshard-m4-production-attempt-" + os.environ.get("GITHUB_RUN_ATTEMPT", "1")
engine.EXECUTION_SCOPE = (
    "the native same-World attachment, Main-owned Rapier contact and retirement, "
    "and compact motion receipt checks under the pinned Godot 4.7 and Rapier runtimes"
)
engine.BUILD_EXACT = (engine.BUILD_EXACT - inherited_paths) | {
    engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE,
    "tools/ci/materialize_lfs.py", "tools/ci/native_candidate_identity.py",
    "tools/ci/reciprocal_windows_package.py", "tools/swarm45/runtime_custody.py",
    "godot/tools/swarm004-runtime.windows.json",
    "tools/ci/stage_windows_vc_runtime.ps1", "tools/ci/execution_policy.py",
    *(p.relative_to(engine.ROOT).as_posix() for p in (engine.ROOT / "tools/objectshard").iterdir()
      if p.is_file() and p.suffix in {".py", ".ps1", ".json"}),
}


def completion(schema: str) -> str:
    return (r'(?m)^\{(?=[^\n]*"schema":"' + re.escape(schema) +
            r'")(?=[^\n]*"failures":\[\])(?=[^\n]*"checks":[1-9][0-9]*[,}])[^\n]+\}$')


engine.CASE_MARKERS = {
    "test_object_shard_m4_same_world_extension": completion("objectshard-m4-actual-godot-sameworld-v1"),
    "test_object_shard_m4_shared_main_rapier": completion("objectshard-m4-existing-main-rapier-v1"),
    "test_object_shard_m4_compact_motion_packets": completion("objectshard-m4-compact-motion-packet-v1"),
}

verify_original = engine.verify_bundle


def verify_bundle(directory: Path, platform: str, source: str, validated: bool) -> dict:
    manifest = verify_original(directory, platform, source, validated)
    # Partial retries may download a previous successful producer's immutable
    # artifact. Bind its recorded attempt to the actual Actions job output.
    prefix = "OBJECTSHARD_VALIDATED_" if validated else "OBJECTSHARD_BUILT_"
    expected = os.environ.get(prefix + platform.upper() + "_ATTEMPT", os.environ["GITHUB_RUN_ATTEMPT"])
    key = "workflow_attempt" if validated else "build_attempt"
    engine.require(manifest[key] == expected, "ObjectShard producer attempt mismatch: " + platform)
    return manifest


engine.verify_bundle = verify_bundle


if __name__ == "__main__":
    raise SystemExit(engine.main())
