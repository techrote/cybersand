"""Reuse the donor's bounded process and evidence validators without retagging it."""
from __future__ import annotations

import importlib.util
from pathlib import Path

import runtime_custody as custody


def load(name: str, relative: str):
    spec = importlib.util.spec_from_file_location(name, custody.ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


legacy = load("swarm456_shared_graphical_validators", "tools/swarm006/qualify_workbench.py")

HEADLESS_CASES = (
    ("runtime-selector", "test_workbench_reciprocal_runtime.gd", "SWARM45_RUNTIME ", 60),
    ("protocol", "test_workbench_reciprocal_protocol.gd", "SWARM004_PROTOCOL ", 60),
    ("controller-mechanical", "test_workbench_reciprocal_controller.gd", "SWARM004_CONTROLLER ", 90),
    ("controls-native", "swarm45_reciprocal_controls.gd", "SWARM004_CONTROLS ", 180),
)


def graphical_processes(examples: dict) -> list[tuple[str, str | None]]:
    """Independent exact inventory; reopen is conditional on actual native Apply."""
    expected = [("import", None), ("native-adapter", None)]
    expected.extend((name, None) for name, _script, _marker, _timeout in HEADLESS_CASES)
    expected.append(("input-integrity", None))
    for name, specification in legacy.EXAMPLES.items():
        if specification.get("negative"):
            modes = ["blocked"]
        elif specification.get("evaluate"):
            authority = examples.get(name, {}).get("native_outcome", {}).get("native_can_apply")
            custody.require(type(authority) is bool, "Native evaluation omits explicit Apply authority: " + name)
            modes = ["evaluate", "reopen"] if authority else ["evaluate"]
        else:
            modes = ["create", "reopen"]
        expected.extend((mode, name) for mode in modes)
    expected.append(("lifecycle", None))
    return expected


def layout_identity(project: Path) -> dict:
    """Read every original installed byte; only newly generated UID/cache files are outside it."""
    root = project.parent
    descriptors = [root / name for name in ("source-stage.json", "candidate-manifest.json") if (root / name).is_file()]
    custody.require(len(descriptors) == 1, "Execution requires one exact source-stage or package inventory")
    descriptor = descriptors[0]
    records = legacy.read_report(descriptor).get("files_sha256")
    custody.verify_inventory(root, records)
    actual = set()
    for path in root.rglob("*"):
        custody.require(not path.is_symlink(), "Execution layout contains a symlink")
        if not path.is_file() or path == descriptor:
            continue
        relative = path.relative_to(root).as_posix()
        if ".godot" in path.relative_to(root).parts:
            continue
        if path.suffix == ".uid" and relative not in records:
            continue
        actual.add(relative)
    custody.require(actual == set(records), "Execution layout has unlisted or missing non-generated files")
    return {"manifest": descriptor.name, "manifest_sha256": custody.sha(descriptor), "files_sha256": records}


def input_report_errors(directory: Path, report: dict, source: str, cli_sha: str,
                        test_sha: str, platform: str) -> list[str]:
    errors = legacy.input_integrity_errors(directory, report, source, cli_sha, test_sha, require_graphics=False)
    if report.get("platform") != {"windows": "Windows", "linux": "Linux"}[platform] or report.get("display") in (None, "", "headless"):
        errors.append("Input integrity did not execute graphically on the actual target OS")
    errors.extend("Missing original input screenshot: " + name for name in legacy.INPUT_CAPTURES
                  if not legacy.original_png(directory / name))
    cases = legacy.object_dict(report.get("cases"))
    for kind in ("active", "off", "hidden"):
        dispatch = legacy.object_dict(legacy.object_dict(cases.get("busy-" + kind)).get("input_dispatch"))
        if (type(dispatch.get("press_count")) is not int or dispatch["press_count"] != 1
                or dispatch.get("busy") is not True
                or dispatch.get("phase") != ("cancelling" if kind == "hidden" else "running")
                or dispatch.get("visible") is not (kind != "hidden")
                or dispatch.get("territory_mode") is not (kind != "off")):
            errors.append("Busy input lacks its actual canvas dispatch witness: " + kind)
        if (any(type(dispatch.get(key)) is not bool for key in ("thread_pending", "thread_started", "thread_alive", "child_alive"))
                or type(dispatch.get("child_pid")) is not int or dispatch["child_pid"] < -1):
            errors.append("Busy input dispatch omits native work state: " + kind)
        if kind == "hidden":
            # Finished but unjoined preparation is still genuinely owned work.
            if dispatch.get("thread_pending") is not True or dispatch.get("thread_started") is not True:
                errors.append("Hidden input was not dispatched with a retained preparation thread")
        elif dispatch.get("child_alive") is not True or not legacy.positive_integer(dispatch.get("child_pid")):
            errors.append("Busy input was not dispatched with a live native child: " + kind)
        if (dispatch.get("paint_dragging_at_dispatch") is not False
                or dispatch.get("paint_dragging_after_dispatch") is not False):
            errors.append("Busy input dispatch entered Paint: " + kind)
    keyboard = legacy.object_dict(cases.get("keyboard"))
    for label, keycode in (("undo", ord("Z")), ("redo", ord("Y"))):
        for action in ("button", "shortcut"):
            dispatch = legacy.object_dict(keyboard.get(label + "_" + action + "_dispatch"))
            if (type(dispatch.get("press_count")) is not int or dispatch["press_count"] != 1
                    or dispatch.get("busy") is not True or dispatch.get("phase") != "running"
                    or dispatch.get("child_alive") is not True
                    or not legacy.positive_integer(dispatch.get("child_pid"))
                    or dispatch["child_pid"] != keyboard.get(label + "_child_pid")):
                errors.append("Busy history input lacks actual dispatch with the same live child: " + label + "/" + action)
            if (dispatch.get("paint_dragging_at_dispatch") is not False
                    or dispatch.get("paint_dragging_after_dispatch") is not False):
                errors.append("Busy history input dispatch entered Paint: " + label + "/" + action)
            if action == "button":
                if dispatch.get("button_disabled") is not True:
                    errors.append("Busy history button was not disabled at dispatch: " + label)
            elif (type(dispatch.get("keycode")) is not int or dispatch["keycode"] != keycode
                    or dispatch.get("ctrl_pressed") is not True or dispatch.get("pressed") is not True
                    or dispatch.get("echo") is not False or dispatch.get("history_unchanged_after_dispatch") is not True
                    or type(dispatch.get("apply_delta_after_dispatch")) is not int or dispatch["apply_delta_after_dispatch"] != 0):
                errors.append("Busy history shortcut lacks exact non-mutating Ctrl-key delivery: " + label)
    return errors


def ui_report_errors(report: dict, mode: str, example: str, source: str, cli_sha: str,
                     test_sha: str, platform: str) -> list[str]:
    # The immutable donor validator remains Windows-only. This new integration
    # applies the same source/receipt/plane assertions to its separately named
    # Linux gate, then enforces the actual requested OS and graphical display.
    errors = legacy.ui_report_errors(report, mode, example, source, cli_sha, test_sha)
    errors = [message for message in errors if message != "actual Windows graphical execution is required"]
    if report.get("platform") != {"windows": "Windows", "linux": "Linux"}[platform]:
        errors.append("UI report did not execute on the requested target OS")
    if report.get("display") in (None, "", "headless"):
        errors.append("UI report did not use an actual graphical display")
    if mode != "lifecycle":
        # Positive recovery evaluations finish their saved-evidence corruption
        # challenge by restoring the original bytes and inspecting that save.
        # This deliberately leaves the dock historical before the separately
        # required fresh-process Reopen; no transaction authority is restored.
        saved_evaluation = (mode == "evaluate" and bool(legacy.EXAMPLES[example].get("evaluate"))
                            and report.get("native_can_apply") is True)
        historical = mode == "reopen" or saved_evaluation
        if report.get("historical_only") is not historical:
            errors.append("UI transaction authority differs from fresh versus saved inspection scope")
        if historical and (report.get("controller_phase") != "historical" or report.get("apply_disabled") is not True
                           or report.get("undo_disabled") is not True):
            errors.append("Saved inspection restored transaction authority")
        if saved_evaluation and (report.get("applied") is not True
                                 or report.get("transport_refusals", {}).get("corrupted_saved_evidence") is not True):
            errors.append("Recovery saved inspection lacks acknowledged Apply and the saved-evidence refusal")
        if example == "transaction" and mode in ("create", "reopen"):
            required = ("pending_shared_text", "gesture_lifecycle") if mode == "create" else (
                "historical_cancel_latched", "historical_edit_latched", "historical_failed_generation_latched",
                "historical_fresh_generation", "historical_files_unchanged")
            refusals = report.get("integration_refusals", {})
            if not isinstance(refusals, dict) or any(refusals.get(name) is not True for name in required):
                errors.append("Unified typed-input/gesture/historical-authority gates are incomplete")
    return errors


def historical_refresh_errors(directory: Path, report: dict, receipt: dict) -> list[str]:
    """Independently bind the successful fresh child that releases inspection-only authority."""
    errors = []
    stage = "historical-refresh"
    names = {stage + "-" + suffix for suffix in ("request.txt", "result.json", "native-pixels.png", "material.le16")}
    hashes = report.get("native_evidence_sha256", {}).get(stage, {})
    if not isinstance(hashes, dict) or set(hashes) != names:
        return ["Historical recovery lacks its complete fresh native evidence"]
    try:
        custody.verify_inventory(directory, hashes)
        value = legacy.read_report(directory / (stage + "-result.json"))
        closure = legacy.closure_outcome(value.get("status"), value.get("metrics"))
        if (value.get("source") != receipt["source_commit"] or value.get("status") != "complete"
                or value.get("can_apply") is not True or not closure["closure_evaluated"] or closure["remaining"] != 0):
            errors.append("Historical recovery did not retain a successful current-source child")
        for owner, prefix in (("frame", "frameweaver.frontier-growth-v0."), ("mosaic", "mosaic.prepared-regions-v0.")):
            native = value.get("input", {}).get(owner, {})
            if native.get("source") != receipt["source_commit"] or native.get("definition") != prefix + receipt["native_definition_sha256"]:
                errors.append("Historical recovery did not use the combined current native definition: " + owner)
        cells = value.get("cells")
        if not isinstance(cells, list) or any(type(cell) is not int or not 0 <= cell <= 65535 for cell in cells):
            errors.append("Historical recovery has malformed native materials")
        elif b"".join(cell.to_bytes(2, "little") for cell in cells) != (directory / (stage + "-material.le16")).read_bytes():
            errors.append("Historical recovery material plane differs from its native result")
        if not legacy.original_png(directory / (stage + "-native-pixels.png"), 1):
            errors.append("Historical recovery lacks original native pixels")
    except (OSError, ValueError, TypeError) as error:
        errors.append("Historical recovery custody failed: " + str(error))
    return errors


def package_identity(directory: Path, receipt: dict) -> dict:
    manifest = legacy.read_report(directory / "candidate-manifest.json")
    custody.require(manifest.get("programme") == "GENTEK-SWARM-006"
                    and manifest.get("qualification_programme") == custody.QUALIFICATION_PROGRAMME
                    and manifest.get("runtime_programme") == custody.PROGRAMME
                    and manifest.get("native_definition_sha256") == receipt["native_definition_sha256"]
                    and manifest.get("draft_hold") is True,
                    "Package is not the mainline integration evaluator")
    custody.require(manifest.get("source_commit") == receipt["source_commit"]
                    and manifest.get("source_tree") == receipt["source_tree"], "Package source identity changed")
    custody.require(manifest.get("owner_visual_acceptance") == "pending", "Package must not claim owner acceptance")
    custody.verify_inventory(directory, manifest.get("files_sha256"))
    custody.require(legacy.read_report(directory / custody.NAME) == receipt, "Packaged runtime custody changed")
    binding = custody.cli_binding(receipt)
    for name in ("swarm004-runtime.windows.json", "swarm004-runtime.json"):
        custody.require(legacy.read_report(directory / "godot/tools" / name) == binding, "Packaged preferred/generic runtime binding changed")
    return manifest


def verify_project(project: Path, receipt: dict) -> None:
    # Include scenes, settings, shaders, authoring inputs and tests, not just the
    # visible panel. Runtime paths are separately verified against built bytes.
    for name, digest in receipt["build_inputs_sha256"].items():
        if name.startswith("godot/"):
            candidate = project / Path(name).relative_to("godot")
            custody.require(custody.canonical(candidate) == digest, "Project input changed: " + name)
    extension = project / "addons/cybersand_native/bin" / receipt["extension"]
    custody.require(custody.sha(extension) == receipt["files"][receipt["extension"]]["sha256"],
                    "Project is not running the source-built adapter")


def qualification_engine(engine: Path, platform: str) -> Path:
    """Launch the actual pinned engine, so its PID is the report's PID.

    Godot's Windows console executable is a wrapper which starts the sibling
    GUI executable. Its Popen PID cannot be joined to OS.get_process_id() from
    the engine without separately captured parent/child evidence. Q5 retained
    no such evidence; keep that refusal and avoid the wrapper for new runs.
    """
    custody.require(engine.is_file() and not engine.is_symlink(), "Missing or linked qualification engine")
    if platform == "windows":
        name = "Godot_v4.7-stable_win64.exe"
        custody.require(engine.name in (name, "Godot_v4.7-stable_win64_console.exe"),
                        "Qualification requires the pinned Windows engine filename")
        engine = engine.with_name(name)
        custody.require(engine.is_file() and not engine.is_symlink(),
                        "Missing or linked actual Windows engine beside the console wrapper")
    return engine.resolve()


def verify_engine(engine: Path) -> str:
    import subprocess
    version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
    custody.require(version == legacy.VERSION, "Godot pin mismatch: " + version)
    return version
