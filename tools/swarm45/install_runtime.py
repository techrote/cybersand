#!/usr/bin/env python3
"""Install this run's exact adapter and CLI into the qualification project."""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil

import runtime_custody as custody


def install(runtime: Path, project: Path) -> dict:
    receipt = custody.verify(runtime)
    extension = project / "addons/cybersand_native/bin" / receipt["extension"]
    tools = project / "tools"
    extension.parent.mkdir(parents=True, exist_ok=True)
    tools.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(runtime / receipt["extension"], extension)
    shutil.copyfile(runtime / receipt["cli"], tools / receipt["cli"])
    if receipt["platform"] == "linux":
        (tools / receipt["cli"]).chmod(0o755)
    custody.write_json(tools / ("swarm004-runtime." + receipt["platform"] + ".json"), custody.cli_binding(receipt))
    return receipt


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    args = parser.parse_args()
    result = install(args.runtime.resolve(), args.project.resolve())
    print({"source": result["source_commit"], "platform": result["platform"], "cli": result["cli"]})


if __name__ == "__main__":
    main()
