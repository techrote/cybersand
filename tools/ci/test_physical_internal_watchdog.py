"""Actual-Godot proof that fixture watchdog runs while main is synchronously blocked."""

import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="physical-watchdog-") as folder:
        project = Path(folder)
        helpers = project / "tests/helpers"
        helpers.mkdir(parents=True)
        for name in ("physical_internal_watchdog.gd", "physical_internal_watchdog_probe.gd", "physical_progress.gd"):
            shutil.copyfile(ROOT / "godot/tests/helpers" / name, helpers / name)
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Watchdog probe"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        command = [args.godot, "--headless", "--path", str(project), "--script",
                   "res://tests/helpers/physical_internal_watchdog_probe.gd"]
        healthy = subprocess.run(command, capture_output=True, text=True, timeout=20)
        healthy_output = healthy.stdout + healthy.stderr
        assert healthy.returncode == 0, healthy_output
        assert "ERROR:" not in healthy_output, healthy_output
        assert "joined=true passed=true" in healthy_output, healthy_output
        blocked = subprocess.run([*command, "--", "--blocked-main"], stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, timeout=20)
        output = blocked.stdout
        assert blocked.returncode != 0, output
        assert "ERROR: REGRESSION_WATCHDOG case=internal_watchdog_probe" in output, output
        assert "joined=true passed=false" in output, output
        expiry = re.search(r"limit_ms=50 elapsed_ms=(\d+)", output)
        recovery = re.search(r"main_returned_ms=(\d+)", output)
        assert expiry and recovery, output
        assert int(expiry[1]) < int(recovery[1]), output
        assert output.index("ERROR: REGRESSION_WATCHDOG case=") < output.index("main_returned_ms="), output
        print(f"Internal Godot watchdog: healthy pass; blocked main observed at {expiry[1]}ms "
              f"before main returned at {recovery[1]}ms; sticky failure and join verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
