#!/usr/bin/env python3
"""Small fixed-source contract shared by this one-off proof and offline reader."""
from contextlib import contextmanager
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

SOURCES = {
    "baseline": ("846fe0533b3170e7b01f690518da49fc40cc24d1", "1232a6e825561ce8b5cd125e1bad7fa6aa7e1590"),
    "candidate": ("cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55", "062f8ec0df0e9f1cb548c11860968301cad0ae16"),
}
SUITES = ("soliding-normal", "soliding-asan")
TEST_NAMES = ("soliding_lifecycle", "settled_discovery", "settled_regions", "settled_world_discovery",
              "stage3b_runtime_storage", "stage3b_bounded_spatial_index",
              "stage3b_sparse_mutation_witness", "stage3b_sparse_activity_deadline")
WORKFLOW = ".github/workflows/ci-opt003-soliding-proof.yml"
PREFIX = "tools/ci/ci_opt003_soliding_proof/"
PROOF_FILES = (WORKFLOW, *[PREFIX + name for name in
               ("common.py", "proof.py", "run_arm.sh", "compare_pair.py", "test_compare_pair.py", "README.md")])
MODULES = ("execution_policy", "native_execution_policy", "verify_native_shards")
ENVIRONMENT = {"CXX": "g++-13", "CC": "gcc-13", "CYBERSAND_CI_WATCHDOG_SCALE": "1",
               "MAKEFLAGS": "", "MFLAGS": "", "GNUMAKEFLAGS": "", "MAKEFILES": ""}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n")
    temporary.replace(path)


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], timeout=300)


def blob(repository, sha, path):
    return git(repository, "show", sha + ":" + path)


def proof_identity(repository, sha):
    require(re.fullmatch(r"[0-9a-f]{40}", sha), "Proof requires full immutable SHA")
    changed = git(repository, "diff", "--name-only", SOURCES["candidate"][0], sha).decode().splitlines()
    require(set(changed) == set(PROOF_FILES), "Proof branch must add only the declared proof files")
    return {"sha": sha, "tree": git(repository, "rev-parse", sha + "^{tree}").decode().strip(),
            "fingerprints": {path: digest(blob(repository, sha, path)) for path in PROOF_FILES}}


@contextmanager
def canonical(repository):
    """Load original verifier/policy blobs, never code supplied in an artifact."""
    with tempfile.TemporaryDirectory(prefix="soliding-proof-reader-") as temporary:
        root = Path(temporary)
        base = SOURCES["baseline"][0]
        for name in MODULES:
            path = "tools/ci/" + name + ".py"
            raw = blob(repository, base, path)
            require(raw == blob(repository, SOURCES["candidate"][0], path), "Canonical validation changed")
            dest = root / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(raw)
        path = "godot/tests/support/ci_execution_policy.json"
        dest = root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(blob(repository, base, path))
        previous = {name: sys.modules.pop(name, None) for name in MODULES}
        old_scale = os.environ.get("CYBERSAND_CI_WATCHDOG_SCALE")
        os.environ["CYBERSAND_CI_WATCHDOG_SCALE"] = "1"
        sys.path.insert(0, str(root / "tools/ci"))
        try:
            yield importlib.import_module("verify_native_shards")
        finally:
            sys.path.pop(0)
            for name, module in previous.items():
                sys.modules.pop(name, None)
                if module is not None:
                    sys.modules[name] = module
            if old_scale is None:
                os.environ.pop("CYBERSAND_CI_WATCHDOG_SCALE", None)
            else:
                os.environ["CYBERSAND_CI_WATCHDOG_SCALE"] = old_scale


def expected_source(repository, arm, verifier):
    sha, tree = SOURCES[arm]
    require(git(repository, "rev-parse", sha + "^{tree}").decode().strip() == tree, "Fixed source tree differs")
    registry = blob(repository, sha, verifier.INPUTS["test_registry"]).decode()
    cases = re.findall(r'\{"([^\"]+)",\s*test_[A-Za-z0-9_]+\}', registry[registry.index("int main("):])
    return {"source_sha": sha, "source_tree": tree, "source_delta_paths": [], "expected_cases": cases,
            "source_fingerprints": {key: digest(blob(repository, sha, path)) for key, path in verifier.INPUTS.items()}}


def expected_tests(repository, arm, suite):
    target = "soliding-test" if suite == "soliding-normal" else "soliding-sanitize"
    text = blob(repository, SOURCES[arm][0], "Makefile").decode()
    body = re.findall(r"^" + target + r":[^\n]*\n((?:\t[^\n]*\n)+)", text, re.M)
    require(len(body) == 1, "Missing or ambiguous original test recipe")
    lines = [line.strip().replace("$(BUILD_DIR)", "build") for line in body[0].splitlines()]
    suffix = "" if suite == "soliding-normal" else "_sanitized"
    require(lines == ["./build/test_" + name + suffix for name in TEST_NAMES], "Original eight-test inventory changed")
    return lines
