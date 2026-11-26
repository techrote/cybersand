#!/usr/bin/env python3
"""Compose unchanged Windows evaluators at an admitted accepted-main checkpoint.

This request harness is separate from the product checkout. The existing Goblin
builder supplies an unchanged common payload; the outer manifest adds ordinary
Workbench entry and explicit, bounded extracted-package proof.
No native build, runtime publication, release or physical acceptance is implied.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import io
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import zipfile

SCHEMA = "cybersand-accepted-main-evaluator-request-v1"
MANIFEST = "mainline-evaluation-manifest.json"
FOUNDATIONS = {
    "goblin_001": "d4484bd5b488cb419bfaa94f1e69be8128734405",
    "ambient_001": "d0af9b6015c27417fddd67f79afdcf656a609571",
}
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
SOURCE_FILES = (
    "tools/ci/mainline_evaluator.py", "tools/ci/test_mainline_evaluator.py",
    "tools/ci/verify_mainline_launchers.ps1",
    ".github/workflows/mergedown-mainline-windows.yml",
    "tools/fixtures/mergedown-mainline-windows-request.json",
)
SOURCE_CONTRACTS = {
    "tools/gip014/Open-goblin.ps1": "ecab5353a894e7b481542e38090685e8d3ae5779f57741b41587ffb1e8129620",
    "tools/qualify_ambient.py": "7e014097f39f9d416067bcace63fda4dacf4d1de91f89d4fbff87bc970dc07ae",
    "tools/qualify_workbench_landscapes.py": "4a07fbb56600038ed16500d24c632ab1ae88a55337cb8d8b3f1cf12fbd895c86",
    "tools/ci/execution_policy.py": "7bf7c89f51b8edc6c14e9b600a843c6b56f4806c902b09058912a32c881b63d6",
    "tools/ci/materialize_lfs.py": "9a98d7c1d5535691afeb1d0a794e1b2ae7258f1aaaa89df4ae25607267a01efb",
    "tools/ci/godot_timeout_diagnostics.py": "3c0bf0552b8d1d4ed408f9ea3df94d2f3416aae51e37f644456da6594d1f7fcd",
    "godot/tests/test_ambient_default_off_integration.gd": "f02ac9d36519168b3caefe77c46cb9fbb1f52b232db343559da0aeb149ed2eaf",
}
DEFAULT_OFF_CASE = "test_ambient_default_off_integration"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_contract_sha(path: Path) -> str:
    # Established repository text policy deliberately checks PowerShell out as
    # CRLF on Windows. Bind its canonical committed text without weakening any
    # raw payload, runtime, archive, process-log or publication hash comparison.
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def read(path: Path) -> dict:
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result
    value = json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=unique)
    require(isinstance(value, dict), "Expected a JSON object: " + str(path))
    return value


def write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def git(root: Path, *arguments: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *arguments], text=True, timeout=60).strip()


def exact_hash(value: object, length: int) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{" + str(length) + "}", value) is not None and value != "0" * length


def request(path: Path) -> dict:
    value = read(path)
    require(value.get("schema") == SCHEMA and value.get("repository") == "techrote/cybersand",
            "Wrong accepted-main delivery request")
    require(value.get("status") == "admitted", "Request is prepared only; source admission has not been requested")
    require(exact_hash(value.get("source_commit"), 40) and exact_hash(value.get("source_tree"), 40),
            "Request must pin full source commit and tree identities")
    require(value.get("accepted_main_at_request") == value["source_commit"],
            "Request must identify an actual accepted-main checkpoint")
    require(value.get("required_foundations") == FOUNDATIONS,
            "Both original qualified foundation ancestries are required")
    require(type(value.get("native_source_input_count")) is int and value["native_source_input_count"] == 105
            and type(value.get("rapier_source_input_count")) is int and value["rapier_source_input_count"] == 4,
            "This narrow retained-runtime adapter requires the unchanged 105/4 input contract")
    require(value.get("owner_playfeel_accepted") is False and value.get("public_release") is False,
            "A delivery request cannot grant physical acceptance or a public release")
    return value


def product_module(product: Path, name: str):
    sys.path.insert(0, str(product.resolve() / "tools"))
    sys.path.insert(0, str(product.resolve() / "tools/ci"))
    module = importlib.import_module(name)
    require(Path(module.__file__).resolve().is_relative_to(product.resolve()),
            "A source helper was imported from another checkout")
    return module


def registered_default_case(product: Path):
    runner = product_module(product, "run_godot_regressions")
    cases = [case for case in runner.discover_cases(product.resolve()) if case.name == DEFAULT_OFF_CASE]
    require(len(cases) == 1 and cases[0].flags == ("--script", "res://tests/" + DEFAULT_OFF_CASE + ".gd")
            and cases[0].requires_display is False, "Expected one unchanged canonical default-OFF case registration")
    return cases[0]


def execution_budget(policy: dict, default_case) -> dict:
    values = policy["watchdogs"]
    complex_case = sum(values[key] for key in ("complex_fixture_seconds", "operation_seconds", "diagnostic_capture_seconds", "terminate_grace_seconds"))
    # Preserve the existing source-helper allowances, including four separate
    # AMBIENT processes (two imports and two actual case processes).
    workbench = values["godot_import_seconds"] + values["graphical_case_seconds"] + 60
    goblin = 240 + 2 * 180 + 180 + 120
    rows = [
        {"name": "checkout, dependencies and admission", "seconds": values["godot_setup_seconds"]},
        {"name": "source/runtime metadata operations", "seconds": values["godot_metadata_seconds"]},
        {"name": "default-OFF import and exact registered fixture", "seconds": values["godot_import_seconds"] + default_case.timeout + 2 * 15},
        {"name": "five-example ANGLE import and capture", "seconds": values["godot_import_seconds"] + complex_case + 2 * 15},
        {"name": "delivered Workbench CMD plus retirement/output drain", "seconds": workbench + 60},
        {"name": "delivered Goblin fixed self-tests and graphics plus retirement/drain", "seconds": goblin + 60},
        {"name": "archive construction and final byte/receipt verification", "seconds": 900},
        {"name": "evidence retention and upload", "seconds": values["aggregate_headroom_seconds"]},
    ]
    total = sum(row["seconds"] for row in rows)
    require(total <= 360 * 60 and values["godot_job_minutes"] >= 360,
            "Complete source-derived delivery allowance exceeds the supported 360-minute parent; reconcile phases without reducing case watchdogs")
    return {"schema": "cybersand-mainline-evaluator-budget-v1", "policy": policy, "rows": rows,
            "total_seconds": total, "required_minutes": math.ceil(total / 60), "parent_minutes": 360,
            "default_off_registered_case": {"name": default_case.name, "flags": list(default_case.flags),
                                            "timeout_seconds": default_case.timeout, "requires_display": default_case.requires_display},
            "launcher_watchdogs": {"workbench": int(workbench), "goblin": goblin},
            "expected_case_inventory": ["default_off_68", "ambient_five_example_ANGLE", "goblin_actor_workshop64", "goblin_save_reopen64", "goblin_graphics", "ordinary_CMD", "goblin_CMD"],
            "full_ambient_feature_campaign_claimed": False}


def expected_runtime(product: Path) -> dict:
    result = {}
    for name, relative, count in (("native", "godot/addons/cybersand_native/runtime-provenance.json", 105),
                                   ("rapier", "godot/addons/godot-rapier2d/runtime-provenance.windows.json", 4)):
        manifest = read(product / relative)
        require(len(manifest.get("source_inputs", {})) == count and exact_hash(manifest.get("sha256"), 64),
                "Unexpected retained provenance/input contract: " + name)
        result[name + "_sha256"] = manifest["sha256"]
        result[name + "_provenance_sha256"] = sha(product / relative)
    return result


def admit(request_path: Path, product: Path, harness: Path) -> dict:
    value = request(request_path)
    require(git(product, "rev-parse", "HEAD") == value["source_commit"]
            and git(product, "rev-parse", "HEAD^{tree}") == value["source_tree"],
            "Product checkout differs from the requested immutable source")
    require(not git(product, "status", "--porcelain", "--untracked-files=all"),
            "Product checkout must contain only clean committed source")
    accepted = git(product, "rev-parse", "refs/remotes/origin/main")
    git(product, "merge-base", "--is-ancestor", value["source_commit"], accepted)
    for name, commit in FOUNDATIONS.items():
        try:
            git(product, "merge-base", "--is-ancestor", commit, value["source_commit"])
        except subprocess.CalledProcessError as error:
            raise ValueError("Accepted source lacks qualified " + name + " ancestry") from error
    for name, digest in SOURCE_CONTRACTS.items():
        require(source_contract_sha(product / name) == digest, "Changed proof/watchdog contract requires review: " + name)
    budget = execution_budget(product_module(product, "execution_policy").identity(), registered_default_case(product))
    harness_commit = git(harness, "rev-parse", "HEAD")
    if os.environ.get("GITHUB_SHA"):
        require(harness_commit == os.environ["GITHUB_SHA"], "Harness does not match its Actions run source")
    require(not git(harness, "status", "--porcelain", "--untracked-files=all"),
            "Delivery harness must be clean committed source")
    return {
        "schema": "cybersand-accepted-main-evaluator-admission-v1", "status": "passed",
        "source_commit": value["source_commit"], "source_tree": value["source_tree"],
        "accepted_main_at_request": value["accepted_main_at_request"],
        "accepted_main_observed": accepted, "source_is_accepted_main_ancestor": True,
        "required_foundations": FOUNDATIONS, "request_sha256": sha(request_path),
        "harness_commit": harness_commit, "harness_tree": git(harness, "rev-parse", "HEAD^{tree}"),
        "harness_inputs_sha256": {name: sha(harness / name) for name in SOURCE_FILES},
        "proof_source_contracts_sha256": SOURCE_CONTRACTS,
        "proof_source_hash_mode": "SHA256 of repository LF-canonical text; all package/runtime/log hashes remain raw bytes",
        "execution_budget": budget,
        "runtime_expected": expected_runtime(product),
        "native_source_input_count": 105, "rapier_source_input_count": 4,
        "owner_playfeel_accepted": False, "public_release": False,
    }


def safe_name(name: str) -> bool:
    path = PurePosixPath(name)
    return bool(path.parts) and path.as_posix() == name and not path.is_absolute() and ".." not in path.parts and "\\" not in name and ":" not in name


def extract(archive: Path, destination: Path, prefix: str = "") -> None:
    require(not destination.exists(), "Constituent extraction must be pristine")
    destination.mkdir(parents=True)
    seen: set[str] = set()
    with zipfile.ZipFile(archive) as bundle:
        require(bundle.testzip() is None, "Constituent ZIP has a CRC failure")
        for item in bundle.infolist():
            require(item.filename.startswith(prefix), "Unexpected constituent ZIP root")
            if item.is_dir():
                continue
            name = item.filename[len(prefix):]
            require(safe_name(name), "Unsafe constituent path: " + name)
            require(name.casefold() not in seen, "Duplicate or Windows-colliding constituent path")
            seen.add(name.casefold())
            require(not stat.S_ISLNK(item.external_attr >> 16), "Symlink is not an evaluator payload")
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(bundle.read(item))


def verify_constituent_identities(admission: dict, goblin: dict) -> None:
    require(admission.get("schema") == "cybersand-accepted-main-evaluator-admission-v1"
            and admission.get("status") == "passed" and admission.get("source_is_accepted_main_ancestor") is True,
            "Successful accepted-main admission is required")
    require(goblin.get("schema") == "cybersand-goblin-evaluator-v1",
            "Only the unchanged established Goblin source package is supported")
    require(all(goblin.get(key) == admission[key] for key in ("source_commit", "source_tree")),
            "Constituent package source does not match accepted-main admission")
    provenance = goblin["provenance"]
    require(provenance.get("native_source_input_count") == 105
            and provenance.get("rapier_source_input_count") == 4,
            "Retained native/Rapier input contract changed; a newly reconciled adapter is required")
    require(provenance.get("source_commit") == admission["source_commit"] and provenance.get("source_tree") == admission["source_tree"]
            and provenance.get("source_dirty") is False, "Goblin provenance must identify the clean admitted source")
    require(all(provenance.get(key) == value for key, value in admission["runtime_expected"].items()),
            "Goblin native/Rapier runtime or provenance differs from admitted accepted source")


def run_verifiers(product: Path, folder: Path, goblin_report: Path | None = None) -> None:
    command = [sys.executable, str(product / "tools/gip014/package_evaluator.py"), "--verify-extracted", str(folder / "workbench")]
    if goblin_report:
        command.extend(["--qualification", str(goblin_report)])
    subprocess.run(command, check=True, timeout=180)


def verify(folder: Path, pristine: bool = False) -> dict:
    manifest = read(folder / MANIFEST)
    require(manifest.get("schema") == "cybersand-accepted-main-evaluator-v1" and manifest.get("owner_playfeel_accepted") is False,
            "Wrong mainline manifest or physical acceptance claim")
    expected = set(manifest["files_sha256"]) | {MANIFEST}
    for name, digest in manifest["files_sha256"].items():
        require(safe_name(name) and exact_hash(digest, 64), "Unsafe manifest member or digest")
        path = folder / name
        require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(folder.resolve()) and sha(path) == digest,
                "Mainline payload changed: " + name)
    actual = {p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file()}
    if pristine:
        require(actual == expected, "Pristine mainline evaluator has missing or unexpected files")
    else:
        for name in actual - expected:
            allowed = name.startswith(("workbench/godot/.godot/", "workbench/userdata/", "workbench/test-output/"))
            if name.endswith((".gd.uid", ".gdshader.uid")) and name[:-4] in expected:
                allowed = True
            require(allowed, "Unexpected executable or output in mainline payload: " + name)
    return manifest


def verify_archive(archive: Path, manifest_path: Path) -> None:
    manifest = read(manifest_path)
    expected = {**manifest["files_sha256"], MANIFEST: sha(manifest_path)}
    with zipfile.ZipFile(archive) as bundle:
        require(bundle.testzip() is None, "Delivered archive has a CRC failure")
        members = [item for item in bundle.infolist() if not item.is_dir()]
        require(len(members) == len(expected) and {item.filename for item in members} == set(expected),
                "Delivered archive inventory differs from its tested manifest")
        for item in members:
            require(safe_name(item.filename) and not stat.S_ISLNK(item.external_attr >> 16)
                    and hashlib.sha256(bundle.read(item)).hexdigest() == expected[item.filename],
                    "Delivered archive bytes differ from its tested manifest: " + item.filename)


def assemble(args) -> None:
    admission = read(args.admission)
    require(not args.output.exists() and not args.archive.exists(), "Delivery outputs must be new")
    args.output.mkdir(parents=True)
    extract(args.goblin_archive, args.output / "workbench", "CyberSand-goblin/")
    goblin = read(args.output / "workbench/goblin-evaluator-manifest.json")
    verify_constituent_identities(admission, goblin)
    run_verifiers(args.product, args.output)
    sys.path.insert(0, str(args.product.resolve() / "tools"))
    stage = importlib.import_module("package_explore001_candidate")
    ambient_runner = importlib.import_module("qualify_ambient")
    runtime = ambient_runner.windows.verify_retained_runtime(args.product.resolve())
    require(len(runtime["native_source_inputs"]) == 105, "Changed native input contract")
    require(runtime["cybersand_runtime"]["sha256"] == goblin["provenance"]["native_sha256"]
            and runtime["rapier_runtime"]["sha256"] == goblin["provenance"]["rapier_sha256"]
            and runtime["runtime_source_commit"] == goblin["provenance"]["native_build_commit"],
            "Original Goblin payload and retained product runtime differ")
    dependencies = product_module(args.product, "package_workbench_landscape_review").DEPENDENCIES
    for name, digest in dependencies.items():
        require(sha(args.output / "workbench" / name) == digest,
                "Accepted pinned engine/notice/redistribution bytes differ: " + name)
    stage.verify_vc_runtime(args.output / "workbench")
    profiles = stage.stage_generator_profiles(args.output / "workbench")
    guides = ["docs/operations/ambient-workbench.md", "docs/systems/ambient-actors.md"]
    guide_archive = subprocess.check_output(["git", "archive", "HEAD", "--", *guides], cwd=args.product, timeout=60)
    with tarfile.open(fileobj=io.BytesIO(guide_archive)) as source:
        for entry in source:
            if entry.isfile():
                require(safe_name(entry.name), "Unsafe accepted-source guide path")
                target = args.output / "workbench" / entry.name
                require(not target.exists(), "Guide staging must not replace original payload files")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.extractfile(entry).read())
    examples = {p.name: sha(p) for p in (args.output / "workbench/godot/examples/workbench").glob("ambient-*.json")}
    require(set(examples) == {name + ".json" for name in ambient_runner.EXAMPLES},
            "Ordinary package requires all five committed AMBIENT examples")
    goblin_guides = ["workbench/docs/operations/gip014-goblin-gameplay-qa.md", "workbench/docs/research/gip014-goblin-gameplay-qa.md"]
    goblin_guide = next((name for name in goblin_guides if (args.output / name).is_file()), None)
    require(goblin_guide is not None and (args.output / "workbench/docs/operations/ambient-workbench.md").is_file(),
            "Both named owner guides must actually exist in this package")
    for name, expected in ((NATIVE, goblin["provenance"]["native_sha256"]), (RAPIER, goblin["provenance"]["rapier_sha256"]),
                           ("Godot_v4.7-stable_win64.exe", goblin["provenance"]["godot_sha256"]),
                           ("Godot_v4.7-stable_win64_console.exe", goblin["provenance"]["godot_console_sha256"])):
        require(sha(args.output / "workbench" / name) == expected,
                "Actual accepted-source runtime/engine bytes differ: " + name)
    launchers = {
        "Open Workbench.cmd": (
            '@echo off\nsetlocal\ncd /d "%~dp0workbench"\n'
            'set "APPDATA=%~dp0workbench\\userdata\\roaming"\nset "LOCALAPPDATA=%~dp0workbench\\userdata\\local"\n'
            'set "XDG_DATA_HOME=%~dp0workbench\\userdata\\roaming"\n'
            f'set "CYBERSAND_SOURCE_REVISION={admission["source_commit"]}"\n'
            '"%~dp0workbench\\Godot_v4.7-stable_win64_console.exe" --headless --path "%~dp0workbench\\godot" --editor --quit\n'
            'if errorlevel 1 (\n  if not "%CYBERSAND_EVALUATOR_AUTOMATION%"=="1" if not "%~1"=="--headless" pause\n  exit /b 1\n)\n'
            '"%~dp0workbench\\Godot_v4.7-stable_win64_console.exe" --path "%~dp0workbench\\godot" --rendering-method gl_compatibility --rendering-driver opengl3_angle %* -- --workbench\n'
            'set "mainline_exit=%errorlevel%"\n'
            'if not "%mainline_exit%"=="0" if not "%CYBERSAND_EVALUATOR_AUTOMATION%"=="1" if not "%~1"=="--headless" pause\n'
            'exit /b %mainline_exit%\n'),
        "Open Goblin.cmd": '@echo off\nsetlocal\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0workbench\\Open goblin.ps1" %*\nexit /b %errorlevel%\n',
    }
    for name, value in launchers.items():
        (args.output / name).write_text(value, encoding="utf-8", newline="\r\n")
    guide = (
        "# CyberSand — accepted-main Windows Workbench\n\n"
        f"**Accepted product source:** `{admission['source_commit']}`.\n\n"
        "Extract the whole ZIP into a writable folder. Double-click **Open Workbench.cmd**. "
        "The first launch imports resources locally. Ordinary blank startup keeps both new experimental features off.\n\n"
        "## Try procedural inhabitants\n\n"
        "Open **Actor Composition…**, choose one of the five ambient examples, select **Load scene**, then **Play**. "
        "The examples cover Oil/Water interests, ledges, an industrial yard, a settlement and flight. "
        "The example selector and profile editor expose the opt-in behaviour; loading an example is an explicit action. "
        "Read `workbench/docs/operations/ambient-workbench.md` for profile editing, manual piloting, and save/reopen.\n\n"
        "## Try the optional Goblin gameplay explorer\n\n"
        "Double-click **Open Goblin.cmd** for its separate opt-in developer scene. "
        "It creates a fresh disposable profile under `workbench/test-output`; it does not run during ordinary Workbench startup. "
        f"Read `{goblin_guide}` for controls, finite campaigns and limitations.\n\n"
        "## Saves, evidence and acceptance\n\n"
        "Ordinary authored saves stay under `workbench/userdata`. To reopen one, launch Workbench and use its saved-start loading controls "
        "to select the authored layout and settings. "
        "Keep this whole extracted folder together. Both launchers use one source-matched application, "
        "Godot, native DLL and Rapier DLL. The existing Goblin source package and verifier remain intact; "
        "the outer manifest records the added ordinary launcher, source-authored guides and canonical generator profiles.\n\n"
        "Physical Windows/NVIDIA playfeel acceptance of AMBIENT and Goblin remains outstanding. "
        "Historical Draft/HOLD language inside the feature guides records that feature gate, not the accepted-main status above. "
        "Full application correctness is supplied by the accepted source's Ready Native/GDE qualification. "
        "This package has separate explicit default-OFF, five-example graphics, Goblin gameplay/save-reopen and launcher proof; "
        "it does not claim a new complete AMBIENT feature campaign. "
        "This is a review artifact, not a public release.\n\n"
        f"Native build source: `{runtime['runtime_source_commit']}`. Its original provenance is retained; "
        "the unchanged 105 native and four Rapier source inputs are checked before reuse. No new DLL build is claimed. "
        f"Packaging harness: `{admission['harness_commit']}`. "
        "`mainline-evaluation-manifest.json` identifies every immutable file. The accompanying delivery receipt "
        "binds this ZIP to the final extracted Windows and top-level launcher checks.\n"
    )
    (args.output / "READ-ME.md").write_text(guide, encoding="utf-8")
    write(args.output / "accepted-source-admission.json", admission)
    files = {p.relative_to(args.output).as_posix(): sha(p) for p in sorted(args.output.rglob("*")) if p.is_file()}
    manifest = {
        "schema": "cybersand-accepted-main-evaluator-v1", "source_commit": admission["source_commit"],
        "source_tree": admission["source_tree"], "harness_commit": admission["harness_commit"],
        "harness_tree": admission["harness_tree"], "accepted_main_observed": admission["accepted_main_observed"],
        "native_runtime": runtime, "goblin_provenance": goblin["provenance"],
        "native_rebuilt": False, "owner_playfeel_accepted": False, "public_release": False,
        "execution_budget": admission["execution_budget"],
        "experimental_default_enabled": False,
        "qualification": "Explicit extracted-package proof is required; full application qualification remains the accepted-source Ready campaign",
        "expected_package_proof": ["ambient_default_off_68_checks", "ambient_five_example_ANGLE_capture", "goblin_actor_workshop_64", "goblin_save_reopen_64", "goblin_graphical_smoke", "delivered_workbench_CMD", "delivered_goblin_CMD"],
        "constituent_archive_sha256": sha(args.goblin_archive),
        "constituent_manifest_sha256": sha(args.output / "workbench/goblin-evaluator-manifest.json"),
        "generator_profiles_sha256": profiles, "ambient_examples_sha256": examples,
        "files_sha256": files,
    }
    write(args.output / MANIFEST, manifest)
    run_verifiers(args.product, args.output)
    verify(args.output, pristine=True)
    args.archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.archive, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in sorted(args.output.rglob("*")):
            if path.is_file():
                bundle.write(path, path.relative_to(args.output).as_posix())
    verify_archive(args.archive, args.output / MANIFEST)
    args.archive.with_suffix(".zip.sha256").write_text(sha(args.archive) + "  " + args.archive.name + "\n", encoding="utf-8")
    shutil.copyfile(args.output / MANIFEST, args.archive.with_suffix(".manifest.json"))


def qualify_default_off(args) -> None:
    require(sys.platform == "win32", "This delivery requires actual Windows fixture execution")
    require(not args.output.exists(), "Default-OFF proof must preserve earlier evidence")
    args.output.mkdir(parents=True)
    runner = product_module(args.product, "qualify_ambient")
    identity = runner.source_identity()
    report = {**identity, "schema": "cybersand-mainline-default-off-proof-v1", "status": "running",
              "platform": sys.platform, "cases": [], "full_ambient_campaign": False}
    try:
        runtime = runner.verify_runtime_identity()
        report["runtime"] = runtime
        report["engine"] = runner.engine_identity(args.godot)
        before = runner.project_identity(args.project, identity, runtime)
        env = runner.case_environment(args.output / "userdata")
        env["CYBERSAND_SOURCE_REVISION"] = identity["source_commit"]
        command = [str(args.godot), "--headless", "--path", str(args.project)]
        row = runner.execute(command + ["--editor", "--quit"], args.output / "import", env,
                             runner.execution_policy.watchdog_seconds("godot_import_seconds"))
        row["process_sha256"] = sha(args.output / "import/process.json")
        report["import"] = row
        write(args.output / "qualification.json", report)

        require(row["status"] == "passed", "Extracted default-OFF import failed")
        case = registered_default_case(args.product)
        report["registered_case"] = {"name": case.name, "flags": list(case.flags), "timeout_seconds": case.timeout}
        row = runner.execute(command + list(case.flags) + ["--", "--ci"],
                             args.output / "default_off", env, case.timeout)
        row.update(name="default_off", process_sha256=sha(args.output / "default_off/process.json"))
        report["cases"] = [row]
        require(row["status"] == "passed", "Extracted default-OFF fixture failed")
        text = (args.output / "default_off/process.log").read_text(encoding="utf-8")
        lines = [line.removeprefix("AMBIENT_DEFAULT_OFF ") for line in text.splitlines() if line.startswith("AMBIENT_DEFAULT_OFF ")]
        require(len(lines) == 1, "Expected one actual default-OFF completion")
        detail = json.loads(lines[0])
        require(detail.get("checks") == 68 and detail.get("failures") == [] and len(detail.get("phases", [])) == 5,
                "The complete promoted 68-check default-OFF fixture did not execute")
        write(args.output / "default_off/report.json", detail)
        row["report_sha256"] = sha(args.output / "default_off/report.json")
        require(runner.source_identity() == identity and runner.verify_runtime_identity() == runtime
                and runner.project_identity(args.project, identity, runtime) == before,
                "Source, runtime or extracted project changed during default-OFF execution")
        report.update(status="passed", input_custody="passed")
    except Exception as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        write(args.output / "qualification.json", report)


def checked_log(package: Path, name: str, digest: str) -> str:
    require(isinstance(name, str) and safe_name(name) and name.startswith("test-output/") and exact_hash(digest, 64),
            "Reported Goblin log is outside its declared package-local evidence")
    path = package / name
    require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(package.resolve()) and sha(path) == digest,
            "Reported original Goblin log changed or escapes its package")
    text = path.read_text(encoding="utf-8-sig")
    require(not re.search(r"SCRIPT ERROR:|Parse Error:|Failed to load script|ERROR:|Fatal signal|Segmentation fault", text),
            "Original Goblin import/graphics log contains an execution error")
    return text


def verify_goblin_auxiliary_logs(package: Path, report: dict) -> dict:
    imported = checked_log(package, report["import_log"], report["import_log_sha256"])
    require("Godot Engine v4.7.stable.official.5b4e0cb0f" in imported,
            "Original extracted import lacks the pinned engine initialization")
    graphical = report.get("graphical_smoke", {})
    require(graphical.get("status") == "pass", "Original Goblin graphical execution did not pass")
    text = checked_log(package, graphical["log"], graphical["log_sha256"])
    lines = [line.removeprefix("GOBLIN_INTERACTIVE_RESULT ") for line in text.splitlines() if line.startswith("GOBLIN_INTERACTIVE_RESULT ")]
    require(len(lines) == 1, "Original Goblin graphical log lacks unique completed execution")
    result = json.loads(lines[0])
    require(type(result.get("checks")) is int and result["checks"] > 0 and result.get("failures") == []
            and result.get("evidence_kind") == "graphical_godot"
            and re.search(r"OpenGL.*ANGLE|ANGLE.*OpenGL", text),
            "Original Goblin graphical log does not prove clean assertions on actual Windows ANGLE")
    return {"import_log": report["import_log"], "import_log_sha256": report["import_log_sha256"],
            "graphical_log": graphical["log"], "graphical_log_sha256": graphical["log_sha256"],
            "graphical_terminal": result}


def finalize(args) -> None:
    manifest = verify(args.extracted)
    launchers = read(args.launchers)
    require(launchers.get("schema") == "cybersand-mainline-launcher-proof-v1" and launchers.get("status") == "passed"
            and launchers.get("source_commit") == manifest["source_commit"] and launchers.get("manifest_sha256") == sha(args.extracted / MANIFEST),
            "Actual top-level launcher proof is missing or belongs to another package")
    require(set(launchers.get("cases", {})) == {"workbench", "goblin"}, "Both delivered launchers must execute")
    for name, row in launchers["cases"].items():
        require(row.get("status") == "passed" and row.get("exit_code") == 0 and row.get("pid", 0) > 0
                and row.get("output_drain_complete") is True
                and row.get("timeout_seconds") == manifest["execution_budget"]["launcher_watchdogs"][name],
                "Incomplete actual launcher execution: " + name)
        for key in ("stdout", "stderr"):
            require(sha(Path(row[key])) == row[key + "_sha256"], "Launcher evidence changed")
        if name == "workbench":
            text = Path(row["stdout"]).read_text(encoding="utf-8") + Path(row["stderr"]).read_text(encoding="utf-8")
            require(row.get("arguments") == "--quit-after 180" and re.search(r"OpenGL.*ANGLE|ANGLE.*OpenGL", text)
                    and sum(line.startswith("SHARED_WORKBENCH_LAUNCH_READY") for line in text.splitlines()) == 1,
                    "Delivered ordinary CMD requires its actual native-ready and graphical ANGLE evidence")
    report_path = Path(launchers["goblin_report"])
    require(sha(report_path) == launchers["goblin_report_sha256"], "Goblin report changed after execution")
    auxiliary = verify_goblin_auxiliary_logs(args.extracted / "workbench", read(report_path))
    run_verifiers(args.product, args.extracted, goblin_report=report_path)
    ambient = read(args.default_off / "qualification.json")
    graphical = read(args.graphical / "qualification.json")
    for name, result in (("extracted gameplay", ambient), ("extracted graphics", graphical)):
        require(result.get("status") == "passed" and result.get("input_custody") == "passed"
                and result.get("source_commit") == manifest["source_commit"] and result.get("source_tree") == manifest["source_tree"]
                and result.get("platform") == "win32", "Incomplete or mismatched " + name)
    require(ambient.get("schema") == "cybersand-mainline-default-off-proof-v1"
            and ambient.get("full_ambient_campaign") is False
            and len(ambient["cases"]) == 1 and ambient["cases"][0]["name"] == "default_off"
            and ambient["cases"][0].get("status") == "passed", "The declared explicit default-OFF case inventory is incomplete")
    registered = registered_default_case(args.product)
    require(ambient["registered_case"]["timeout_seconds"] == registered.timeout
            and ambient["cases"][0]["timeout_seconds"] == registered.timeout
            and manifest["execution_budget"]["default_off_registered_case"]["timeout_seconds"] == registered.timeout,
            "Default-OFF invocation or budget shortened the canonical registered watchdog")
    detail = read(args.default_off / "default_off/report.json")
    require(detail.get("checks") == 68 and detail.get("failures") == [] and len(detail.get("phases", [])) == 5,
            "Incomplete actual default-OFF result")
    require(graphical.get("headless") is False and graphical.get("graphical") is not None,
            "Headless is not final extracted graphical qualification")
    # Reuse the accepted source's original process/log/image receipt verifiers.
    # Do not promote success summaries without their actual hashed artifacts.
    code = (
        "import json, pathlib, sys; "
        "sys.path.insert(0, str(pathlib.Path(sys.argv[1]).resolve() / 'tools')); "
        "import package_ambient_evaluator as p; "
        "p.verify_qualification(pathlib.Path(sys.argv[2]), json.loads((pathlib.Path(sys.argv[2]) / 'qualification.json').read_text())); "
        "p.verify_graphical(pathlib.Path(sys.argv[3]), p.source_identity())"
    )
    subprocess.run([sys.executable, "-c", code, str(args.product), str(args.default_off), str(args.graphical)], check=True, timeout=180)
    verify_archive(args.archive, args.extracted / MANIFEST)
    require(git(args.product, "rev-parse", "HEAD") == manifest["source_commit"]
            and not git(args.product, "status", "--porcelain", "--untracked-files=all"), "Product source changed during delivery")
    write(args.output, {
        "schema": "cybersand-accepted-main-delivery-receipt-v1", "status": "passed",
        "source_commit": manifest["source_commit"], "source_tree": manifest["source_tree"],
        "harness_commit": manifest["harness_commit"], "harness_tree": manifest["harness_tree"],
        "archive": args.archive.name, "archive_sha256": sha(args.archive), "archive_size": args.archive.stat().st_size,
        "manifest_sha256": sha(args.extracted / MANIFEST), "launchers_sha256": sha(args.launchers),
        "extracted_default_off_sha256": sha(args.default_off / "qualification.json"),
        "extracted_graphics_sha256": sha(args.graphical / "qualification.json"),
        "goblin_report_sha256": sha(report_path), "owner_playfeel_accepted": False, "public_release": False,
        "goblin_auxiliary_log_readback": auxiliary,
        "native_rebuilt": False, "native_runtime": manifest["native_runtime"],
        "execution_budget": manifest["execution_budget"], "full_ambient_feature_campaign": False,
        "run_id": os.environ.get("GITHUB_RUN_ID"), "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
    })


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    resolve = commands.add_parser("read-request")
    resolve.add_argument("--request", type=Path, required=True)
    resolve.add_argument("--github-output", type=Path)
    admission = commands.add_parser("admit")
    admission.add_argument("--request", type=Path, required=True)
    admission.add_argument("--product", type=Path, required=True)
    admission.add_argument("--harness", type=Path, required=True)
    admission.add_argument("--output", type=Path, required=True)
    create = commands.add_parser("assemble")
    for name in ("admission", "product", "goblin-archive", "output", "archive"):
        create.add_argument("--" + name, type=Path, required=True)
    verification = commands.add_parser("verify")
    verification.add_argument("folder", type=Path)
    verification.add_argument("--pristine", action="store_true")
    default_off = commands.add_parser("qualify-default-off")
    for name in ("product", "project", "godot", "output"):
        default_off.add_argument("--" + name, type=Path, required=True)
    delivery = commands.add_parser("finalize")
    for name in ("product", "extracted", "archive", "launchers", "default-off", "graphical", "output"):
        delivery.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    if args.command == "read-request":
        value = request(args.request)
        if args.github_output:
            with args.github_output.open("a", encoding="utf-8") as stream:
                stream.write("source_commit=" + value["source_commit"] + "\n")
        print(json.dumps(value, sort_keys=True))
    elif args.command == "admit":
        write(args.output, admit(args.request, args.product, args.harness))
    elif args.command == "assemble":
        assemble(args)
    elif args.command == "qualify-default-off":
        qualify_default_off(args)
    elif args.command == "verify":
        manifest = verify(args.folder, args.pristine)
        print(json.dumps({"verified": True, "source_commit": manifest["source_commit"], "files": len(manifest["files_sha256"])}))
    else:
        finalize(args)


if __name__ == "__main__":
    main()
