#!/usr/bin/env python3
"""Build or verify the opt-in goblin Windows developer evaluator.

Packaging creates an UNQUALIFIED candidate. The extracted Windows package must
pass its own fixed launcher self-tests before the owner may receive a qualified
evaluator. Existing source-matched native/Rapier binaries are reused; this tool
does not rebuild or publish runtime libraries or change a production default.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile

import replay_identity
from corpus_io import load_corpus
from verify_transcript import load as load_tape, verify as verify_tape

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "cybersand-goblin-evaluator-v1"
MANIFEST = "goblin-evaluator-manifest.json"
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
GODOT = "Godot_v4.7-stable_win64.exe"
CONSOLE = "Godot_v4.7-stable_win64_console.exe"
REQUIRED_CASES = ("actor_workshop", "save_reopen")
LINEAGE_SCHEMA = "cybersand-goblin-authored-lineage-test-v1"
LINEAGE_SCRIPT = "godot/goblin/tests/test_authored_lineage.gd"
LINEAGE_MARKER = "GOBLIN_AUTHORED_LINEAGE_RESULT "
LINEAGE_CASES = {
    "fresh_authored": ([{"id": "save_layout", "args": {}}, {"id": "reopen_layout", "args": {}}], True),
    "retained_evolved": ([{"id": "play", "args": {"ticks": 16}}, {"id": "pause", "args": {}},
                          {"id": "response_mode", "args": {"mode": "LA-EVENT-OFF"}},
                          {"id": "save_layout", "args": {}}, {"id": "reopen_layout", "args": {}}], False),
    "restore_authored": ([{"id": "play", "args": {"ticks": 16}}, {"id": "pause", "args": {}},
                          {"id": "response_mode", "args": {"mode": "LA-EVENT-OFF"}}, {"id": "restore_start", "args": {}},
                          {"id": "save_layout", "args": {}}, {"id": "reopen_layout", "args": {}}], True),
    "actor_reset_retains_evolved": ([{"id": "actor_place", "args": {"model": "kestrel", "x": 256, "y": 96}},
                                     {"id": "play", "args": {"ticks": 16}}, {"id": "pause", "args": {}},
                                     {"id": "actor_reset", "args": {}}, {"id": "actor_remove", "args": {}},
                                     {"id": "save_layout", "args": {}}, {"id": "reopen_layout", "args": {}}], False),
}
LINEAGE_CONTRACT = {"schema": LINEAGE_SCHEMA, "script": "res://goblin/tests/test_authored_lineage.gd",
                    "fixture": "conservation_cell", "policy": "CONTROL", "seed": 13,
                    "native_cases": list(LINEAGE_CASES), "actions": 20, "wall_seconds": 300}


def sha(path: Path, algorithm: str = "sha256") -> str:
    result = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def git(*arguments: str) -> str:
    return subprocess.check_output(["git", *arguments], cwd=ROOT, text=True, timeout=30).strip()


def windows_pin() -> dict:
    tree = ast.parse((ROOT / "tools/ci/run_windows_godot_regressions.py").read_text(encoding="utf-8"))
    result = {}
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id in {"GODOT_SHA512", "GODOT_VERSION"}:
                    result[target.id] = ast.literal_eval(node.value)
                elif isinstance(target, ast.Name) and target.id == "RAPIER_IMPORT_DESCRIPTORS":
                    value = node.value
                    if not isinstance(value, ast.Call) or not isinstance(value.func, ast.Name) or value.func.id != "frozenset" or len(value.args) != 1 or value.keywords:
                        raise ValueError("Existing Windows import-descriptor rule is unavailable")
                    result[target.id] = frozenset(ast.literal_eval(value.args[0]))
    if len(result) != 3 or re.fullmatch(r"[0-9a-f]{128}", result["GODOT_SHA512"]) is None:
        raise ValueError("Existing Windows Godot pin is unavailable")
    if len(result["RAPIER_IMPORT_DESCRIPTORS"]) != 4 or not all(isinstance(name, str) and name.startswith("godot/addons/godot-rapier2d/") and name.endswith(".import") and safe_relative(name) for name in result["RAPIER_IMPORT_DESCRIPTORS"]):
        raise ValueError("Existing Windows import-descriptor scope differs")
    return result


def runtime_inputs() -> tuple[dict, dict]:
    provenance, source_inputs = {}, {}
    for name, path in (("native", "godot/addons/cybersand_native/runtime-provenance.json"),
                       ("rapier", "godot/addons/godot-rapier2d/runtime-provenance.windows.json")):
        manifest = json.loads((ROOT / path).read_text(encoding="utf-8"))
        artifact = ROOT / manifest["artifact"]
        if sha(artifact) != manifest["sha256"] or artifact.stat().st_size != manifest["size"]:
            raise ValueError(name + " retained runtime bytes are not materialized/source-matched")
        for relative, expected in manifest["source_inputs"].items():
            actual = hashlib.sha256((ROOT / relative).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
            if actual != expected:
                raise ValueError(name + " retained runtime source drift: " + relative)
            source_inputs[relative] = expected
        provenance[name + "_sha256"] = manifest["sha256"]
        provenance[name + "_provenance_sha256"] = sha(ROOT / path)
        provenance[name + "_source_input_count"] = len(manifest["source_inputs"])
        provenance[name + "_build_commit"] = manifest.get("source_commit", manifest.get("build_commit"))
    return provenance, source_inputs


def safe_relative(name: str) -> bool:
    path = PurePosixPath(name)
    return not path.is_absolute() and bool(path.parts) and path.as_posix() == name and ".." not in path.parts and "\\" not in name and ":" not in name


def checked_member(path: Path, name: str) -> Path:
    if not safe_relative(name):
        raise ValueError("Non-relative package member: " + name)
    result = path / name
    if result.is_symlink() or not result.resolve().is_relative_to(path.resolve()):
        raise ValueError("Symlink is not an evaluator payload: " + name)
    return result


def copy_committed_source(destination: Path, source_inputs: dict) -> dict:
    # The accepted Windows runner already treats these four Rapier text
    # descriptors as LF-canonical inputs. Canonicalize before freezing package
    # bytes; extraction and post-test verification remain raw SHA comparisons.
    import_descriptors = windows_pin()["RAPIER_IMPORT_DESCRIPTORS"]
    normalized_imports = {}
    names = ["godot", "examples/worldgen", "third_party/godot-runtime.lock.json", "THIRD_PARTY_NOTICES.md",
             "LICENSE_STATUS.md", "docs/operations/gip014-goblin-gameplay-qa.md", "docs/research/gip014-goblin-gameplay-qa.md",
             "docs/research/gip014-goblin-002.md", "docs/research/goblin002-exploration-handover.md",
             "docs/research/goblin002-gameplay-handover.md", "docs/research/goblin002-replay-delivery-handover.md",
             "tools/gip014", *source_inputs]
    committed = set(git("ls-tree", "-r", "--name-only", "HEAD").splitlines())
    names = [name for name in names if name in committed or any(path.startswith(name + "/") for path in committed)]
    payload = subprocess.check_output(["git", "archive", "HEAD", "--", *names], cwd=ROOT, timeout=60)
    with tarfile.open(fileobj=io.BytesIO(payload)) as archive:
        for entry in archive:
            if not entry.isfile() or not safe_relative(entry.name):
                continue
            if entry.name.startswith("godot/.godot/"):
                if entry.name not in {"godot/.godot/.gdignore", "godot/.godot/extension_list.cfg", "godot/.godot/global_script_class_cache.cfg"}:
                    continue
            if entry.name.startswith("godot/") and not replay_identity.platform_game_input(entry.name.removeprefix("godot/"), "windows"):
                continue
            stream = archive.extractfile(entry)
            if stream is None:
                raise ValueError("Unreadable committed source member")
            data = stream.read()
            if data.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", data)
                actual = (ROOT / entry.name).read_bytes()
                if pointer is None or hashlib.sha256(actual).hexdigest() != pointer[1].decode() or len(actual) != int(pointer[2]):
                    raise ValueError("Unmaterialized or changed committed LFS payload: " + entry.name)
                data = actual
            if entry.name in import_descriptors:
                original = data
                data = data.replace(b"\r\n", b"\n")
                normalized_imports[entry.name] = {
                    "archive_sha256": hashlib.sha256(original).hexdigest(),
                    "packaged_sha256": hashlib.sha256(data).hexdigest(),
                    "crlf_pairs_removed": original.count(b"\r\n"),
                }
            target = destination / entry.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    if set(normalized_imports) != import_descriptors:
        raise ValueError("Committed package lacks the existing four Rapier import descriptors")
    rule = ROOT / "tools/ci/run_windows_godot_regressions.py"
    return {"schema": "cybersand-goblin-import-descriptor-normalization-v1", "operation": "CRLF to LF before package manifest",
            "rule_source": rule.relative_to(ROOT).as_posix(), "rule_source_sha256": sha(rule), "files": normalized_imports}


def stage_campaign_evidence(source: Path, destination: Path, provenance: dict) -> dict:
    """Copy immutable, independently checked native tapes as explicit replay examples."""
    if not source.is_dir() or source.is_symlink():
        raise ValueError("Campaign evidence must be an ordinary retained directory")
    candidates = sorted(source.rglob("transcript.json"), key=lambda p: (p != source / "control-64/transcript.json", str(p)))
    root = destination / "replay-corpus"
    root.mkdir()
    seen, cases = set(), []
    for path in candidates:
        if path.is_symlink() or path.stat().st_size > 32 * 1024 * 1024:
            continue
        digest = sha(path)
        if digest in seen:
            continue
        tape = load_tape(path)
        checked = verify_tape(tape)
        if not checked["valid"] or tape["header"].get("evidence_kind") == "unit_fixture" or tape["summary"].get("termination") != "budget_complete" or tape["summary"].get("failures"):
            continue
        if not replay_identity.same(tape["header"].get("provenance"), provenance):
            continue
        case_id = f"case-{len(cases):03d}"
        target = root / (case_id + ".json")
        shutil.copyfile(path, target)
        record = {"id": case_id, "path": target.relative_to(destination).as_posix(), "sha256": digest,
                  "fixture": tape["header"]["fixture_id"], "policy": tape["header"]["policy"],
                  "seed": tape["header"]["seed"], "attempted_actions": len(tape["steps"]),
                  "evidence_kind": tape["header"]["evidence_kind"], "source_bytes_preserved": True}
        memory = [path.parent / "corpus.json"] if (path.parent / "corpus.json").is_file() else list(path.parent.glob("profile/**/goblin/corpus.json"))
        if len(memory) == 1:
            load_corpus(memory[0])
            memory_target = root / (case_id + "-memory.json")
            shutil.copyfile(memory[0], memory_target)
            record.update(memory_path=memory_target.relative_to(destination).as_posix(), memory_sha256=sha(memory_target))
        cases.append(record)
        seen.add(digest)
        if len(cases) == 8:
            break
    if not cases:
        raise ValueError("Successor evaluator requires at least one actual source-matched replay tape")
    index = {"schema": "cybersand-goblin-portable-replay-v1", "source_commit": provenance["source_commit"],
             "source_bytes_preserved": True, "physical_checkpoint_resume": False, "cases": cases}
    path = root / "index.json"
    path.write_text(json.dumps(index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return {"path": "replay-corpus/index.json", "sha256": sha(path), "cases": len(cases), "required_replay_case": cases[0]["id"]}


def verify_memory_roundtrip(directory: Path, memory: dict, manifest: dict) -> None:
    if not isinstance(memory, dict) or memory.get("status") != "pass" or memory.get("initial_memory_absent") is not True or memory.get("final_fixed_memory_absent") is not True or memory.get("clear_preserved_archives") is not True or memory.get("backup_count") != 1 or memory.get("cleared_fixed_files") != 3:
        raise ValueError("Actual isolated memory save/import/backup/clear gate is incomplete")
    imported = memory.get("fresh_profile_import", {})
    if memory.get("first_memory_sha256") != memory.get("backup_sha256") or memory.get("latest_memory_sha256") != memory.get("source_corpus_sha256") or memory.get("latest_memory_sha256") != imported.get("staged_sha256") or memory.get("first_memory_sha256") == memory.get("latest_memory_sha256"):
        raise ValueError("Persistent memory publication/backup identities disagree")
    corpora = []
    for path_key, hash_key, value in (("first_corpus", "first_corpus_sha256", memory),
                                     ("source_corpus", "source_corpus_sha256", memory),
                                     ("staged_corpus", "staged_sha256", imported)):
        path = checked_member(directory, value.get(path_key, ""))
        if not path.is_file() or sha(path) != value.get(hash_key):
            raise ValueError("Memory roundtrip artifact hash mismatch")
        data = load_corpus(path)
        if not data["records"]:
            raise ValueError("Memory qualification requires actual nonempty campaign records")
        corpora.append(data)
    if memory["first_corpus_sha256"] != memory["first_memory_sha256"] or imported.get("source_sha256") != memory["latest_memory_sha256"]:
        raise ValueError("Memory publication does not preserve exact actual source bytes")
    count = len(corpora[-1]["records"])
    if not 1 <= count <= 64 or imported.get("records") != count or memory.get("records") != count:
        raise ValueError("Imported memory record accounting differs")
    log = checked_member(directory, imported.get("admission_log", ""))
    if not log.is_file() or sha(log) != imported.get("admission_log_sha256"):
        raise ValueError("Memory admission log hash mismatch")
    text = log.read_text(encoding="utf-8-sig")
    lines = [line.removeprefix("GOBLIN_CORPUS_IMPORT_VALID ") for line in text.splitlines() if line.startswith("GOBLIN_CORPUS_IMPORT_VALID ")]
    if len(lines) != 1 or any(marker in text for marker in ("SCRIPT ERROR:", "Parse Error:", "ERROR:")):
        raise ValueError("Memory admission lacks a unique clean actual validator result")
    result = json.loads(lines[0])
    if result.get("ok") is not True or result.get("records") != count or result.get("verification") != "imported hints only":
        raise ValueError("Memory import did not validate supported hints")
    archives = memory.get("archive_checks", [])
    if not 1 <= len(archives) <= 8:
        raise ValueError("Memory clear must retain bounded actual archived tapes")
    for item in archives:
        path = checked_member(directory, item["path"])
        if not path.is_file() or sha(path) != item["sha256"]:
            raise ValueError("Archived native tape changed during memory clear")
        tape = load_tape(path)
        if not verify_tape(tape)["valid"] or tape["header"].get("provenance") != manifest["provenance"] or tape["header"].get("evidence_kind") != "packaged_evaluator":
            raise ValueError("Preserved memory archive is not the packaged actual campaign")


def portable_index(directory: Path, manifest: dict) -> dict:
    item = manifest.get("portable_replay_index", {})
    if item.get("path") != "replay-corpus/index.json":
        raise ValueError("Portable replay index must use its fixed package location")
    path = checked_member(directory, item["path"])
    if not path.is_file() or sha(path) != item.get("sha256"):
        raise ValueError("Portable replay index hash mismatch")
    index = json.loads(path.read_text(encoding="utf-8"))
    cases = index.get("cases", [])
    if index.get("schema") != "cybersand-goblin-portable-replay-v1" or not 1 <= len(cases) <= 8 or len(cases) != item.get("cases"):
        raise ValueError("Portable replay catalogue is missing or exceeds its bound")
    if index.get("source_commit") != manifest["source_commit"] or index.get("physical_checkpoint_resume") is not False:
        raise ValueError("Portable replay identity/scope mismatch")
    ids = set()
    for case in cases:
        case_id = case.get("id")
        if not isinstance(case_id, str) or re.fullmatch(r"case-[0-9]{3}", case_id) is None or case_id in ids or case.get("path") != f"replay-corpus/{case_id}.json":
            raise ValueError("Unsupported portable replay case identity")
        ids.add(case_id)
        tape_path = checked_member(directory, case["path"])
        if sha(tape_path) != case.get("sha256"):
            raise ValueError("Portable tape hash mismatch")
        tape = load_tape(tape_path)
        if not verify_tape(tape)["valid"] or not replay_identity.same(tape["header"].get("provenance"), manifest["provenance"]) or tape["header"].get("evidence_kind") == "unit_fixture":
            raise ValueError("Portable tape lacks actual source-matched evidence")
        if "memory_path" in case:
            if case["memory_path"] != f"replay-corpus/{case_id}-memory.json":
                raise ValueError("Unsupported portable memory path")
            memory = checked_member(directory, case["memory_path"])
            if sha(memory) != case.get("memory_sha256"):
                raise ValueError("Portable memory hash mismatch")
            load_corpus(memory)
    if item.get("required_replay_case") not in ids:
        raise ValueError("Required portable replay case is absent")
    return index


def verify_portable_replay(directory: Path, report: dict, manifest: dict) -> None:
    result = report.get("portable_replay", {})
    if result.get("status") != "pass" or result.get("semantic_match") is not True or result.get("case_id") != manifest["portable_replay_index"]["required_replay_case"]:
        raise ValueError("Actual extracted portable semantic replay has not passed")
    expected = f"replay-corpus/{result['case_id']}.json"
    if result.get("original") != expected:
        raise ValueError("Portable replay report identifies another source tape")
    for key in ("original", "transcript", "log"):
        path = checked_member(directory, result[key])
        if not path.is_file() or sha(path) != result.get(key + "_sha256"):
            raise ValueError("Portable replay evidence hash mismatch")
    original = load_tape(checked_member(directory, result["original"]))
    actual = load_tape(checked_member(directory, result["transcript"]))
    if not verify_tape(actual)["valid"] or actual["header"].get("provenance") != manifest["provenance"] or actual.get("replay_result", {}).get("semantic_match") is not True:
        raise ValueError("Actual portable replay validation/source identity failed")
    for key in ("fixture_id", "fixture_version", "fixture_sha256", "initial_scene_identity", "seed", "pacing_ms"):
        if original["header"].get(key, 0 if key == "pacing_ms" else None) != actual["header"].get(key, 0 if key == "pacing_ms" else None):
            raise ValueError("Portable replay changed its fixture/seed/pacing")
    if [row["semantic_sha256"] for row in original["steps"]] != [row["semantic_sha256"] for row in actual["steps"]]:
        raise ValueError("Portable replay semantic observations differ")
    text = checked_member(directory, result["log"]).read_text(encoding="utf-8-sig")
    results = [line.removeprefix("GOBLIN_CAMPAIGN_RESULT ") for line in text.splitlines() if line.startswith("GOBLIN_CAMPAIGN_RESULT ")]
    if text.splitlines().count("GOBLIN_CAMPAIGN_COMPLETE") != 1 or len(results) != 1 or any(marker in text for marker in ("SCRIPT ERROR:", "Parse Error:", "ERROR:")):
        raise ValueError("Portable replay has no unique clean completion")
    terminal = json.loads(results[0])
    if terminal.get("validation", {}).get("ok") is not True or terminal.get("validation", {}).get("errors") or terminal.get("summary") != actual["summary"] or terminal.get("replay", {}).get("semantic_match") is not True or terminal.get("evidence_exported") is not True:
        raise ValueError("Portable replay terminal acknowledgement differs from its tape")


def verify_graphical(directory: Path, report: dict) -> None:
    graphical = report.get("graphical_smoke", {})
    if graphical.get("status") != "pass":
        raise ValueError("Extracted graphical laboratory has not passed")
    path = checked_member(directory, graphical.get("log", ""))
    if not path.is_file() or sha(path) != graphical.get("log_sha256"):
        raise ValueError("Graphical evidence log hash mismatch")
    text = path.read_text(encoding="utf-8-sig")
    lines = [line.removeprefix("GOBLIN_INTERACTIVE_RESULT ") for line in text.splitlines() if line.startswith("GOBLIN_INTERACTIVE_RESULT ")]
    if len(lines) != 1 or any(marker in text for marker in ("SCRIPT ERROR:", "Parse Error:", "ERROR:")) or json.loads(lines[0]).get("failures"):
        raise ValueError("Graphical laboratory did not complete cleanly")
    screenshots = graphical.get("screenshots", [])
    if not 1 <= len(screenshots) <= 16:
        raise ValueError("Actual graphical screenshots are required")
    for image in screenshots:
        path = checked_member(directory, image["path"])
        if not path.is_file() or sha(path) != image["sha256"] or path.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError("Graphical screenshot is missing or changed")


def _lineage_checks(value) -> bool:
    return isinstance(value, dict) and 0 < len(value) <= 4096 and all(item is True for item in value.values())


def _lineage_capture(capture: dict, observation: dict) -> str:
    """Check an actual full-plane capture independently of its applicability label."""
    first, last, receipt, admission = (capture.get(key, {}) for key in
                                      ("source_before", "source_after", "native_receipt", "admission"))
    checksum = capture.get("material_sha256", "")
    if (capture.get("source_matches") is not True or "error" in capture
            or capture.get("region") != [0, 0, 512, 512] or capture.get("count") != 262144
            or not isinstance(checksum, str) or re.fullmatch(r"[0-9a-f]{64}", checksum) is None
            or admission.get("status") != "queued" or receipt.get("status") != "completed"
            or receipt.get("kind") != "capture" or receipt.get("backend") != "CyberNativeCellWorld"
            or receipt.get("region") != capture["region"] or receipt.get("operation_id") != admission.get("operation_id")
            or type(admission.get("operation_id")) is not int or admission["operation_id"] < 0
            or receipt.get("observed_generation") != first.get("generation")
            or first.get("paused") is not True or last.get("paused") is not True
            or first.get("failed") is not False or last.get("failed") is not False):
        raise ValueError("Authored-lineage full native capture lacks actual source/receipt proof")
    for key in ("generation", "revision", "tick"):
        if (type(first.get(key)) is not int or first[key] < 0 or first[key] != last.get(key)
                or first[key] != receipt.get(key) or first[key] != observation.get("native", {}).get(key)):
            raise ValueError("Authored-lineage capture does not match its actual native observation")
    return checksum


def verify_authored_lineage(directory: Path, receipt: dict, manifest: dict) -> None:
    """Require four real source-matched authored-lineage cases in a v3 evaluator.

    The expected relationship comes from the fixed ordinary operation sequences:
    fresh/Restore starts compare equal, while played material retained through
    response/actor resets differs from its authored reopen. A pass label or a
    newly suppressed assertion alone cannot satisfy this gate.
    """
    try:
        if manifest.get("required_authored_lineage") != LINEAGE_CONTRACT:
            raise ValueError("Unsupported fixed authored-lineage qualification contract")
        if (not isinstance(receipt, dict) or receipt.get("status") != "pass"
                or receipt.get("script") != LINEAGE_CONTRACT["script"]
                or receipt.get("script_sha256") != manifest.get("files_sha256", {}).get(LINEAGE_SCRIPT)
                or not isinstance(receipt.get("script_sha256"), str)
                or re.fullmatch(r"[0-9a-f]{64}", receipt["script_sha256"]) is None
                or receipt.get("wall_limit_seconds") != 300 or receipt.get("native_case_count") != 4
                or receipt.get("attempted_actions") != 20 or receipt.get("completed_actions") != 20
                or not isinstance(receipt.get("profile"), str)
                or re.fullmatch(r"test-output/[0-9a-f]{32}", receipt["profile"]) is None):
            raise ValueError("Extracted authored-lineage gate lacks fixed source/process accounting")
        prefix = receipt["profile"] + "/"
        if (receipt.get("log") != prefix + "authored-lineage.log"
                or not isinstance(receipt.get("report"), str) or not receipt["report"].startswith(prefix)
                or not receipt["report"].endswith("/goblin/authored-lineage-test.json")):
            raise ValueError("Authored-lineage evidence is outside its fixed disposable profile")
        paths = {}
        for key, limit in (("log", 16 * 1024 * 1024), ("report", 8 * 1024 * 1024)):
            path = checked_member(directory, receipt[key])
            if not path.is_file() or not 0 < path.stat().st_size <= limit or sha(path) != receipt.get(key + "_sha256"):
                raise ValueError("Authored-lineage evidence is missing, oversized or changed")
            paths[key] = path
        raw = json.loads(paths["report"].read_text(encoding="utf-8-sig"))
        if (raw.get("schema") != LINEAGE_SCHEMA or raw.get("status") != "pass" or raw.get("failures") != []
                or raw.get("provenance") != manifest.get("provenance") or raw["provenance"].get("source_dirty") is not False
                or not _lineage_checks(raw.get("checks")) or receipt.get("checks") != len(raw["checks"])
                or raw.get("actual_actions") != {"attempted": 20, "completed": 20}):
            raise ValueError("Actual authored-lineage native report or exact provenance did not pass")
        text = paths["log"].read_text(encoding="utf-8-sig")
        markers = [line.removeprefix(LINEAGE_MARKER) for line in text.splitlines() if line.startswith(LINEAGE_MARKER)]
        if len(markers) != 1 or any(marker in text for marker in ("SCRIPT ERROR:", "Parse Error:", "ERROR:", "Fatal signal", "Segmentation fault")):
            raise ValueError("Authored-lineage native log lacks a unique clean completion")
        terminal = json.loads(markers[0])
        if terminal.get("status") != "pass" or terminal.get("failures") != [] or terminal.get("actual_actions") != raw["actual_actions"]:
            raise ValueError("Authored-lineage native completion differs from the actual report")
        cases = raw.get("native_cases")
        if not isinstance(cases, list) or len(cases) != 4 or {row.get("id") for row in cases} != set(LINEAGE_CASES):
            raise ValueError("All four distinct authored-lineage native cases are required")
        total = 0
        for case in cases:
            actions, equality = LINEAGE_CASES[case["id"]]
            tape = case.get("transcript", {})
            rows = tape.get("steps", [])
            header = tape.get("header", {})
            if (case.get("status") != "pass" or not _lineage_checks(case.get("checks"))
                    or case.get("expected_equality_applicable") is not equality
                    or type(case.get("save_index")) is not int or case["save_index"] != len(actions) - 2
                    or type(case.get("reopen_index")) is not int or case["reopen_index"] != len(actions) - 1
                    or [row.get("action") for row in rows] != actions
                    or header.get("fixture_id") != "conservation_cell" or header.get("policy") != "CONTROL"
                    or header.get("seed") != 13 or header.get("budget") != len(actions)
                    or header.get("evidence_kind") != "packaged_evaluator" or header.get("provenance") != manifest["provenance"]
                    or header.get("pacing_ms") != 0 or tape.get("summary", {}).get("termination") != "budget_complete"
                    or tape.get("summary", {}).get("attempted_actions") != len(actions)
                    or tape.get("summary", {}).get("completed_actions") != len(actions)):
                raise ValueError("Authored-lineage tape differs from its exact ordinary gameplay case")
            checked = verify_tape(tape)
            if not checked.get("valid") or checked.get("independent_failures") or checked.get("unreported_failures") or checked.get("summary", {}).get("failures"):
                raise ValueError("Independent authored-lineage transcript readback failed")
            for row in rows:
                if (row.get("status") != "completed" or row.get("admission", {}).get("accepted") is not True
                        or row.get("classification") != "game_observation"
                        or row.get("before", {}).get("adapter_version") != 3 or row.get("after", {}).get("adapter_version") != 3
                        or any(item.get("status") == "fail" for item in row.get("assertions", []))):
                    raise ValueError("Authored-lineage case contains a refusal, partial effect or assertion failure")
            saved, reopened = rows[-2:]
            first = _lineage_capture(saved.get("persistence_capture", {}), saved["after"])
            last = _lineage_capture(reopened.get("persistence_capture", {}), reopened["after"])
            saved_proof, reopened_proof = saved.get("persistence", {}), reopened.get("persistence", {})
            lineage = saved_proof.get("saved_material_lineage")
            if (not isinstance(lineage, dict) or lineage.get("schema") != "cybersand-goblin-material-lineage-v1"
                    or lineage.get("state") != ("authored_compatible" if equality else "simulation_exposed")
                    or lineage.get("source") != {key: saved["after"]["native"].get(key) for key in ("generation", "revision", "tick")}
                    or reopened_proof.get("saved_material_lineage") != lineage
                    or reopened_proof.get("saved_capture") != saved["persistence_capture"]
                    or saved_proof.get("material_sha256") != first or reopened_proof.get("saved_material_sha256") != first
                    or reopened_proof.get("reopened_material_sha256") != last
                    or saved_proof.get("saved_native_tick") != 0 or reopened_proof.get("saved_native_tick") != 0
                    or saved["after"]["native"].get("tick") != 0
                    or saved_proof.get("native_material_equality_applicable") is not equality
                    or reopened_proof.get("native_material_equality_applicable") is not equality
                    or (first == last) is not equality):
                raise ValueError("Authored-lineage actual retained material/Save/Reopen relationship differs")
            expected_reason = "available" if equality else "simulation_exposed_lineage"
            assertion = [item for item in reopened.get("assertions", []) if item.get("id") == "authored_reopen_materials"]
            if (saved_proof.get("native_material_equality_reason") != expected_reason
                    or reopened_proof.get("native_material_equality_reason") != expected_reason
                    or len(assertion) != 1 or assertion[0].get("status") != ("pass" if equality else "not_applicable")):
                raise ValueError("Authored-lineage oracle applicability or positive equality was not established")
            if case["id"] != "fresh_authored":
                played = next(row for row in rows if row["action"]["id"] == "play")
                if played["after"]["native"].get("tick", 0) < 16:
                    raise ValueError("Authored-lineage evolved case lacks actual native progression")
            total += len(rows)
        if total != raw["actual_actions"]["completed"]:
            raise ValueError("Authored-lineage report action totals differ from actual tapes")
    except (KeyError, TypeError, IndexError, AttributeError) as error:
        raise ValueError("Malformed authored-lineage native evidence") from error


def build(archive_path: Path, notices: Path, vc_runtime: Path, output: Path, campaign_evidence: Path | None = None) -> dict:
    if git("status", "--porcelain", "--untracked-files=all"):
        raise ValueError("Evaluator packaging requires clean committed source")
    if output.exists():
        raise ValueError("Evaluator output must be new; original evidence is retained")
    if output.suffix.lower() != ".zip":
        raise ValueError("Evaluator output must be a ZIP file")
    if campaign_evidence is None:
        raise ValueError("Successor packaging requires actual source-matched campaign evidence")
    pins = windows_pin()
    if sha(archive_path, "sha512") != pins["GODOT_SHA512"]:
        raise ValueError("Windows Godot archive differs from existing exact pin")
    provenance, inputs = runtime_inputs()
    provenance.update(source_commit=git("rev-parse", "HEAD"), source_tree=git("rev-parse", "HEAD^{tree}"),
                      source_dirty=False, platform="windows", godot_version=pins["GODOT_VERSION"],
                      runtime_basis="existing retained source-matched libraries; no fresh native build claimed")
    sys.path.insert(0, str(ROOT / "tools"))
    from package_explore001_candidate import stage_vc_runtime
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="goblin-evaluator-", dir=output.parent) as temporary:
        staged = Path(temporary) / "CyberSand-goblin"
        staged.mkdir()
        import_normalization = copy_committed_source(staged, inputs)
        with zipfile.ZipFile(archive_path) as engine:
            if engine.testzip() is not None:
                raise ValueError("Pinned Godot ZIP failed integrity check")
            for name in (GODOT, CONSOLE):
                if engine.namelist().count(name) != 1:
                    raise ValueError("Pinned Godot ZIP lacks unique " + name)
                (staged / name).write_bytes(engine.read(name))
        provenance["godot_sha256"] = sha(staged / GODOT)
        provenance["godot_console_sha256"] = sha(staged / CONSOLE)
        for name in ("LICENSE.txt", "COPYRIGHT.txt"):
            source = notices / name
            if not source.is_file() or source.stat().st_size < 100:
                raise ValueError("Official Godot notice unavailable: " + name)
            shutil.copyfile(source, staged / ("Godot-" + name))
        stage_vc_runtime(vc_runtime, staged)
        for name in ("cmd", "ps1"):
            shutil.copyfile(staged / "tools/gip014" / ("Open-goblin." + name), staged / ("Open goblin." + name))
        guide = staged / "docs/research/gip014-goblin-002.md"
        if not guide.is_file():
            guide = staged / "docs/operations/gip014-goblin-gameplay-qa.md"
        if not guide.is_file():
            guide = staged / "docs/research/gip014-goblin-gameplay-qa.md"
        if not guide.is_file():
            raise ValueError("Committed goblin developer guide is missing")
        shutil.copyfile(guide, staged / "READ-ME.md")
        (staged / "source-inputs.json").write_text(json.dumps({"source_commit": provenance["source_commit"],
            "source_tree": provenance["source_tree"], "source_inputs": inputs}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        provenance["replay_identity"] = replay_identity.build(provenance, staged / "godot")
        portable = stage_campaign_evidence(campaign_evidence, staged, provenance)
        files = {path.relative_to(staged).as_posix(): sha(path) for path in sorted(staged.rglob("*")) if path.is_file()}
        project_files = {name.removeprefix("godot/"): digest for name, digest in files.items()
                         if name.startswith("godot/") and not name.startswith("godot/.godot/")}
        provenance["project_files_sha256"] = hashlib.sha256(json.dumps(project_files, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        manifest = {"schema": SCHEMA, "qualification": "unqualified candidate; extracted Windows self-tests required",
                    "source_commit": provenance["source_commit"], "source_tree": provenance["source_tree"], "provenance": provenance,
                    "godot_archive_sha512": pins["GODOT_SHA512"], "files_sha256": files,
                    "import_descriptor_normalization": import_normalization, "successor_contract_version": 3,
                    "portable_replay_index": portable,
                    "required_authored_lineage": LINEAGE_CONTRACT,
                    "required_discovery": {"fixture": "alchemy", "policy": "COVERAGE_HUNTER", "seed": 13, "budget": 64,
                                           "minimum_completed_features": 12, "minimum_expanded_features": 3},
                    "required_selftests": [{"fixture": name, "policy": "CONTROL", "seed": 13, "budget": 64} for name in REQUIRED_CASES]}
        (staged / MANIFEST).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        verify_extracted(staged)
        if git("status", "--porcelain", "--untracked-files=all") or git("rev-parse", "HEAD") != provenance["source_commit"]:
            raise ValueError("Source changed during evaluator packaging")
        with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as package:
            for path in sorted(staged.rglob("*")):
                if path.is_file():
                    package.write(path, path.relative_to(staged.parent).as_posix())
    return {"package": str(output), "package_sha256": sha(output), "source_commit": provenance["source_commit"],
            "qualification": "unqualified candidate; do not publish before extracted Windows self-tests"}


def verify_extracted(directory: Path, qualification: Path | None = None) -> dict:
    manifest_path = directory / MANIFEST
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    if manifest.get("schema") != SCHEMA or not isinstance(manifest.get("files_sha256"), dict):
        raise ValueError("Unknown evaluator manifest")
    for name, expected in manifest["files_sha256"].items():
        path = checked_member(directory, name)
        if not path.is_file() or not isinstance(expected, str) or re.fullmatch(r"[0-9a-f]{64}", expected) is None or sha(path) != expected:
            raise ValueError("Extracted evaluator payload hash mismatch: " + name)
    version = manifest.get("successor_contract_version", 1)
    if type(version) is not int or version not in (1, 2, 3):
        raise ValueError("Unsupported evaluator qualification contract version")
    successor = version in (2, 3)
    if successor:
        provenance = manifest.get("provenance", {})
        names = [name.removeprefix("godot/") for name in manifest["files_sha256"] if name.startswith("godot/")]
        if not replay_identity.valid(provenance) or replay_identity.build(provenance, directory / "godot", names) != provenance["replay_identity"]:
            raise ValueError("Portable replay identity differs from exact packaged game inputs")
        portable_index(directory, manifest)
    if version == 3 and (manifest.get("required_authored_lineage") != LINEAGE_CONTRACT
                         or LINEAGE_SCRIPT not in manifest["files_sha256"]):
        raise ValueError("Fixed authored-lineage native contract is missing from the evaluator")
    if qualification is None:
        return {"payload_verified": True, "qualified": False, "files": len(manifest["files_sha256"])}
    report = json.loads(qualification.read_text(encoding="utf-8-sig"))
    if report.get("schema") != "cybersand-goblin-package-selftest-v1" or report.get("status") != "pass" or report.get("platform") != "Windows":
        raise ValueError("Extracted Windows package self-test did not pass")
    if report.get("manifest_sha256") != sha(manifest_path) or report.get("source_commit") != manifest.get("source_commit") or report.get("source_tree") != manifest.get("source_tree"):
        raise ValueError("Windows self-test qualifies a different package/source")
    rows = report.get("cases", [])
    required_cases = {*REQUIRED_CASES, "alchemy"} if successor else set(REQUIRED_CASES)
    if len(rows) != len(required_cases) or {row.get("fixture") for row in rows} != required_cases:
        raise ValueError("Complete actor-workshop and save/reopen cases are required")
    for row in rows:
        if row.get("status") != "pass" or row.get("policy") != ("COVERAGE_HUNTER" if successor and row.get("fixture") == "alchemy" else "CONTROL") or row.get("budget") != 64 or row.get("seed") != 13 or row.get("termination") != "budget_complete" or row.get("attempted_actions") != 64 or not 1 <= row.get("completed_actions", 0) <= 64 or row.get("assertion_failures") != 0 or row.get("validation_ok") is not True or row.get("completion_marker") is not True:
            raise ValueError("Incomplete extracted Windows self-test evidence")
        for key in ("log", "transcript"):
            path = checked_member(directory, row[key])
            if not path.is_file() or sha(path) != row[key + "_sha256"]:
                raise ValueError("Windows self-test artifact hash mismatch: " + key)
        try:
            from .verify_transcript import load, verify
        except ImportError:
            from verify_transcript import load, verify
        tape = load(checked_member(directory, row["transcript"]))
        readback = verify(tape)
        if not readback["valid"] or readback["summary"]["failures"] or tape["header"].get("provenance") != manifest.get("provenance"):
            raise ValueError("Independent Windows transcript/source readback failed: " + str(readback.get("errors")))
        if tape["header"].get("fixture_id") != row["fixture"] or tape["header"].get("policy") != row["policy"] or tape["header"].get("seed") != row["seed"] or tape["header"].get("budget") != row["budget"] or tape["header"].get("evidence_kind") != "packaged_evaluator":
            raise ValueError("Self-test report does not identify the actual packaged campaign")
        for key in ("termination", "attempted_actions", "completed_actions"):
            if tape["summary"].get(key) != row[key]:
                raise ValueError("Self-test report differs from actual transcript: " + key)
        text = checked_member(directory, row["log"]).read_text(encoding="utf-8-sig")
        results = [line[len("GOBLIN_CAMPAIGN_RESULT "):] for line in text.splitlines() if line.startswith("GOBLIN_CAMPAIGN_RESULT ")]
        if text.splitlines().count("GOBLIN_CAMPAIGN_COMPLETE") != 1 or len(results) != 1 or any(marker in text for marker in ("SCRIPT ERROR:", "Parse Error:", "ERROR:", "Fatal signal", "Segmentation fault")):
            raise ValueError("Actual package log lacks a unique clean completion")
        completion = json.loads(results[0])
        if completion.get("validation", {}).get("ok") is not True or completion.get("validation", {}).get("errors") or completion.get("summary") != tape["summary"]:
            raise ValueError("Godot completion/validation does not match actual transcript")
        if successor and row["fixture"] == "alchemy":
            from vocabulary import NEW_ARGUMENTS
            features = {name for name, count in tape["summary"]["completed_features"].items() if count > 0}
            if len(features) < 12 or len(features & set(NEW_ARGUMENTS)) < 3:
                raise ValueError("Extracted discovery omitted useful expanded gameplay vocabulary")
            continue
        required_features = {"brush", "rectangle", "undo", "redo", "play", "save_layout", "reopen_layout"}
        if row["fixture"] == "actor_workshop":
            required_features.add("actor_drive")
        if not all(tape["summary"]["completed_features"].get(name, 0) > 0 for name in required_features):
            raise ValueError("Extracted Windows campaign omitted required actual gameplay features")
    if successor:
        verify_memory_roundtrip(directory, report.get("memory_roundtrip"), manifest)
        verify_portable_replay(directory, report, manifest)
        verify_graphical(directory, report)
    if version == 3:
        verify_authored_lineage(directory, report.get("authored_lineage"), manifest)
    return {"payload_verified": True, "qualified": True, "source_commit": manifest["source_commit"],
            "manifest_sha256": sha(manifest_path), "qualification_sha256": sha(qualification), "cases": len(rows),
            "scope": "hosted extracted Windows developer evaluator; no physical NVIDIA acceptance claim"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot-archive", type=Path)
    parser.add_argument("--engine-notices", type=Path)
    parser.add_argument("--vc-runtime", type=Path)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--campaign-evidence", type=Path)
    parser.add_argument("--verify-extracted", type=Path)
    parser.add_argument("--qualification", type=Path)
    args = parser.parse_args()
    if args.verify_extracted:
        result = verify_extracted(args.verify_extracted.resolve(), args.qualification)
    elif all((args.godot_archive, args.engine_notices, args.vc_runtime, args.out)):
        result = build(args.godot_archive.resolve(), args.engine_notices.resolve(), args.vc_runtime.resolve(), args.out.resolve(), args.campaign_evidence.resolve() if args.campaign_evidence else None)
    else:
        parser.error("build requires --godot-archive, --engine-notices, --vc-runtime, --out; or --verify-extracted")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
