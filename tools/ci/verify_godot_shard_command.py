"""Independently reconstruct target-OS commands from retained shard artifacts."""

from pathlib import Path, PurePosixPath, PureWindowsPath
import re

import run_godot_regressions as runner


def shard_case_command(godot: str, case: runner.Case, platform: str, project: str, index: int,
                       original: Path) -> list[str]:
    """Reconstruct the producer's full command from source and the original private profile."""
    command = runner.case_command(godot, case, platform)
    command[command.index("--path") + 1] = project
    if case.name == "test_persistent_areas_ordinary_launcher":
        return [*command, "--", "--workbench"]
    if case.name not in runner.PERSISTENT_PROFILE_CASES:
        return command
    evidence = original / (case.name + "-artifacts")
    children = list(evidence.glob("profile-*"))
    if (not evidence.is_dir() or evidence.is_symlink() or len(children) != 1
            or children[0].is_symlink() or not children[0].is_dir()
            or not re.fullmatch(r"profile-[a-z0-9_]{8}", children[0].name)):
        raise ValueError("Missing or ambiguous original private profile: " + str(evidence))
    # The reducer runs on Linux for both targets; retain the producing OS's path syntax.
    project_path = PureWindowsPath(project) if platform == "win32" else PurePosixPath(project)
    shard = ("windows-" if platform == "win32" else "shard-") + str(index)
    profile = project_path.parent / "build" / "godot-regressions" / shard / evidence.name / children[0].name
    command.extend(["--", "--persistent-start-paused", "--persistent-test-mode=write",
             "--persistent-test-workers=1", "--persistent-profile=" + str(profile),
             "--persistent-evidence=" + str(profile.parent)])
    if case.name in {"test_persistent_areas_workbench", "test_persistent_area_owner_timeout"}:
        command.append("--persistent-cache-off")
    if case.name == "test_persistent_area_ramcache":
        command.extend(("--ramcache-hot-samples=2", "--ramcache-warm-samples=2"))
    return command
