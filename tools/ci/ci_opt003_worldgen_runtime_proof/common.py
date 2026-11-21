#!/usr/bin/env python3
"""Small fixed-source contract shared by this one-off proof and offline reader."""
from contextlib import contextmanager
import hashlib
import importlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile

SOURCES = {
    "baseline": ("cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55", "062f8ec0df0e9f1cb548c11860968301cad0ae16"),
    "candidate": ("19023b4016facfda2b13b9a1503742e4a9fe1982", "39b658c5de9c5e541312b5190bd5d8ba797c6bed"),
}
SUITES = ("worldgen",)
TEST_NAMES = ("world_generation", "world_generation_install", "generation_fields", "generation_modifiers",
              "generation_typed", "generation_typed_integration", "generation_spatial", "generation_grammar", "generation_planes")
SHOWCASES = ("megatruss_station", "seeded_typology_megablock", "metabolist_spine", "interlaced_viaduct",
             "rosework_gatehouse", "interlock_brutalism", "suspended_arcology")
WORKFLOW = ".github/workflows/ci-opt003-worldgen-runtime-proof.yml"
PREFIX = "tools/ci/ci_opt003_worldgen_runtime_proof/"
PROOF_FILES = (WORKFLOW, *[PREFIX + name for name in
               ("common.py", "proof.py", "run_arm.sh", "compare_pair.py", "test_compare_pair.py", "README.md")])
MODULES = ("execution_policy", "native_execution_policy", "verify_native_shards", "check_worldgen_build_inventory", "proof_physics")
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
def canonical(repository, arm):
    """Load this arm's original verifier/planner/physics blobs, never artifact code."""
    with tempfile.TemporaryDirectory(prefix="worldgen-runtime-proof-reader-") as temporary:
        root = Path(temporary)
        sha = SOURCES[arm][0]
        for name in MODULES[:-1]:
            path = "tools/ci/" + name + ".py"
            raw = blob(repository, sha, path)
            dest = root / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(raw)
        physics = root / "tools/physics/test_characterisation_cli.py"
        physics.parent.mkdir(parents=True, exist_ok=True)
        physics.write_bytes(blob(repository, sha, "tools/physics/test_characterisation_cli.py"))
        path = "godot/tests/support/ci_execution_policy.json"
        dest = root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(blob(repository, sha, path))
        previous = {name: sys.modules.pop(name, None) for name in MODULES}
        previous_path = sys.path[:]
        old_scale = os.environ.get("CYBERSAND_CI_WATCHDOG_SCALE")
        os.environ["CYBERSAND_CI_WATCHDOG_SCALE"] = "1"
        sys.path.insert(0, str(root / "tools/ci"))
        try:
            verifier = importlib.import_module("verify_native_shards")
            verifier.proof_inventory = importlib.import_module("check_worldgen_build_inventory")
            spec = importlib.util.spec_from_file_location("proof_physics", physics)
            module = importlib.util.module_from_spec(spec)
            sys.modules["proof_physics"] = module
            spec.loader.exec_module(module)
            verifier.proof_physics = module
            yield verifier
        finally:
            sys.path[:] = previous_path
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
    require(suite == "worldgen", "Only the complete worldgen family is admitted")
    text = blob(repository, SOURCES[arm][0], "Makefile").decode()
    result = {}
    for target, suffix in (("worldgen-test", ""), ("worldgen-sanitize", "_sanitized")):
        body = re.findall(r"^" + target + r":[^\n]*\n((?:\t[^\n]*\n)+)", text, re.M)
        require(len(body) == 1, "Missing or ambiguous original test recipe")
        lines = [line.strip().replace("$(BUILD_DIR)", "build") for line in body[0].splitlines()]
        require(lines == ["./build/test_" + name + suffix for name in TEST_NAMES], "Original nine-test main inventory changed")
        result[target] = {"ordered_main_tests": lines, "showcases": ["build/test_" + name + suffix for name in SHOWCASES]}
    return result


def budget(verifier):
    return {"family_timeout_seconds": verifier.family_timeout_seconds("worldgen"),
            "commands": [{"label": name, "policy_key": key, "command": command,
                          "timeout_seconds": verifier.command_timeout_seconds("worldgen", name)}
                         for name, key, command in verifier.COMMANDS["worldgen"]]}


def contract(repository, arm, verifier):
    inventory, physics = verifier.proof_inventory, verifier.proof_physics
    require(tuple(inventory.TESTS) == TEST_NAMES and tuple(inventory.SHOWCASES) == SHOWCASES,
            "Original 9+7 build inventory changed")
    plans = {target: {name: ["g++-13", *command[1:]] for name, command in inventory.expected_commands(sanitized).items()}
             for target, sanitized in (("worldgen-test", False), ("worldgen-sanitize", True))}
    invocation_plan = physics.invocation_plan()
    require(len(invocation_plan) == 154, "Original physics manifest must contain all 154 invocations")
    return {"source": expected_source(repository, arm, verifier), "tests": expected_tests(repository, arm, "worldgen"),
            "compiler_commands": plans, "physics_compiler_command": physics_compiler_command(repository, arm),
            "physics_invocations": invocation_plan, "budget": budget(verifier)}


def physics_compiler_command(repository, arm):
    text = blob(repository, SOURCES[arm][0], "Makefile").decode()
    variables = dict(re.findall(r"^(\w+)\s*:=\s*(.*)$", text, re.M))
    variables["CXX"] = "g++-13"
    recipe = re.findall(r"^\$\(BUILD_DIR\)/physics_characterisation_sanitized:[^\n]*\n\t([^\n]+)", text, re.M)
    require(len(recipe) == 1, "Original physics compiler recipe is missing/ambiguous")
    command = recipe[0].replace("$@", "build/physics_characterisation_sanitized")
    for _ in range(10):
        if "$(" not in command:
            return shlex.split(command)
        command = re.sub(r"\$\((\w+)\)", lambda match: variables[match[1]], command)
    raise ValueError("Physics compiler recipe has unresolved variables")


def assert_contract_parity(repository):
    baseline, candidate = SOURCES["baseline"][0], SOURCES["candidate"][0]
    immutable = ["native", "tools/physics", "tools/experiments", "godot", "third_party",
                 "tools/ci/run_timed_command.py", "tools/ci/execution_policy.py",
                 "tools/ci/execution_telemetry.py", "tools/ci/godot_timeout_diagnostics.py"]
    require(not git(repository, "diff", "--name-only", baseline, candidate, "--", *immutable).strip(),
            "Scientific sources or canonical ownership/verification boundary changed")
    workflow = ".github/workflows/native.yml"
    require(blob(repository, candidate, workflow).replace(b"            build/worldgen-showcase-logs/\n", b"")
            == blob(repository, baseline, workflow), "Native workflow changed beyond preserving original showcase logs")
    runner = "tools/ci/run_native_family.sh"
    require(blob(repository, candidate, runner).replace(b" -j2 --output-sync=target ", b" -j2 ")
            == blob(repository, baseline, runner), "Runner changed beyond two output grouping flags")
    planner = "tools/ci/native_execution_policy.py"
    require(blob(repository, candidate, planner).replace(b'"--output-sync=target", ', b"")
            == blob(repository, baseline, planner), "Planner changed beyond two output grouping flags")
    contracts, normalized = {}, {}
    for arm in SOURCES:
        with canonical(repository, arm) as verifier:
            contracts[arm] = contract(repository, arm, verifier)
            normalized[arm] = json.loads(json.dumps(contracts[arm]))
            normalized[arm].pop("source")
            for command in normalized[arm]["budget"]["commands"]:
                command["command"] = [arg for arg in command["command"] if arg != "--output-sync=target"]
    require(normalized["baseline"] == normalized["candidate"], "Compilation/test/physics/watchdog contract changed")
    return contracts
