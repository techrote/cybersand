#!/usr/bin/env python3
"""Re-read frozen Strata003 paired evidence across host path dialects.

This external adapter never changes the application, original evidence, or
frozen reader on disk. Its only reader-code substitution interprets a retained
command basename using the recorded platform instead of the verifier's host.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path, PurePosixPath, PureWindowsPath
import subprocess
import sys
import types

APPLICATION = "fd0830abcfadd9ae19162e5677943bb131223e59"
APPLICATION_TREE = "fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499"
READER = "tools/ci/strata3_predecessor_compare.py"
OLD_EXPRESSION = "Path(command[-1]).name"
NEW_EXPRESSION = "_recorded_command_name(command[-1], record.get('host', {}).get('platform'))"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def recorded_command_name(value: str, recorded_platform: str) -> str:
    require(isinstance(value, str) and bool(value) and "\x00" not in value,
            "Invalid retained command path")
    if recorded_platform == "win32":
        return PureWindowsPath(value).name
    if recorded_platform == "linux":
        return PurePosixPath(value).name
    raise ValueError("Unsupported retained command platform")


def adapt_verify_source(source: str) -> tuple[str, str]:
    tree = ast.parse(source)
    functions = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "verify"]
    require(len(functions) == 1, "Frozen reader must contain exactly one verify function")
    original = ast.get_source_segment(source, functions[0])
    require(isinstance(original, str) and original.count(OLD_EXPRESSION) == 1,
            "Frozen command basename expression changed")
    adapted = original.replace(OLD_EXPRESSION, NEW_EXPRESSION, 1)
    require(adapted.replace(NEW_EXPRESSION, OLD_EXPRESSION, 1) == original,
            "Portable adapter changed more than the registered expression")
    return original, adapted


def load_frozen_reader(source_repo: Path):
    root = source_repo.resolve()

    def git(*arguments: str) -> bytes:
        return subprocess.check_output(["git", "-C", str(root), *arguments], stderr=subprocess.PIPE)

    require(git("rev-parse", "HEAD").decode().strip() == APPLICATION,
            "Portable reader requires the exact frozen fd application checkout")
    require(git("rev-parse", "HEAD^{tree}").decode().strip() == APPLICATION_TREE,
            "Frozen application tree differs")
    require(not git("diff", "--name-only", "HEAD", "--", "tools").strip(),
            "Frozen reader or its tracked tool dependencies changed")
    untracked = git("ls-files", "--others", "--exclude-standard", "--", "tools").decode().splitlines()
    require(not any(name.endswith(".py") for name in untracked),
            "Untracked Python dependency in frozen source tools")
    path = root / READER
    source_bytes = path.read_bytes()
    require(source_bytes == git("show", APPLICATION + ":" + READER),
            "Frozen reader bytes differ from exact Git source")
    original_source, adapted_source = adapt_verify_source(source_bytes.decode("utf-8"))

    # Import dependencies from the immutable application, not this adapter's tree.
    sys.path[:0] = [str(root / "tools" / "ci"), str(root / "tools")]
    module = types.ModuleType("_strata3_predecessor_frozen_fd")
    module.__file__ = str(path)
    exec(compile(source_bytes, str(path), "exec"), module.__dict__)
    require(Path(module.previous.__file__).resolve() == root / "tools/ci/qualify_strata2_workbench.py",
            "Predecessor dependency loaded outside frozen source")
    require(Path(module.metrics.__file__).resolve() == root / "tools/ci/strata_process_metrics.py",
            "Resource observer dependency loaded outside frozen source")
    namespace = dict(module.__dict__)
    namespace["_recorded_command_name"] = recorded_command_name
    exec(compile(adapted_source, str(Path(__file__).resolve()) + "::frozen-verify-one-expression", "exec"), namespace)
    identity = {
        "application_source": APPLICATION,
        "application_tree": APPLICATION_TREE,
        "frozen_reader_path": READER,
        "frozen_reader_sha256": digest(source_bytes),
        "frozen_verify_function_sha256": digest(original_source.encode()),
        "portable_verify_function_sha256": digest(adapted_source.encode()),
        "adapter_sha256": digest(Path(__file__).read_bytes()),
        "substitution_count": 1,
        "old_expression": OLD_EXPRESSION,
        "new_expression": NEW_EXPRESSION,
        "all_other_frozen_gate_code_unchanged": True,
    }
    return module, namespace["verify"], identity


def verify_portable(folder: Path, source_repo: Path) -> dict:
    folder = folder.resolve()
    raw_record = (folder / "comparison.json").read_bytes()
    record = json.loads(raw_record)
    frozen, portable, identity = load_frozen_reader(source_repo)
    require(record.get("candidate_source") == frozen.previous.identity(),
            "Retained candidate source is not the exact frozen fd identity")

    # Preserve the original outcome; never relabel a rejected reader as a pass.
    try:
        original_summary = frozen.verify(folder)
        original_outcome = {"status": "passed", "summary": original_summary}
    except Exception as error:
        original_outcome = {"status": "rejected", "reason": str(error)}
    summary = portable(folder)
    if original_outcome["status"] == "passed":
        require(original_outcome["summary"] == summary,
                "Portable and original admitted summaries disagree")
    require((folder / "comparison.json").read_bytes() == raw_record,
            "Original comparison changed during read-only verification")
    return {
        "schema": "strata3-portable-predecessor-verification-v1",
        "status": "passed",
        "reader_identity": identity,
        "recorded_platform": record["host"]["platform"],
        "comparison_sha256": digest(raw_record),
        "original_frozen_reader_outcome": original_outcome,
        "portable_reader_summary": summary,
        "scope": "Cross-host retained-command basename correction only; original observations and all frozen gates remain unchanged. No application mutation or new runtime execution.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-repo", required=True, type=Path)
    parser.add_argument("--verify", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    try:
        result = verify_portable(arguments.verify, arguments.source_repo)
        output = json.dumps(result, indent=2, sort_keys=True) + "\n"
        if arguments.output:
            require(not arguments.output.exists(), "Use a fresh portable verification receipt")
            arguments.output.parent.mkdir(parents=True, exist_ok=True)
            arguments.output.write_text(output, encoding="utf-8")
        print(output)
        return 0
    except Exception as error:
        print("PORTABLE_PREDECESSOR_REJECTED: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
