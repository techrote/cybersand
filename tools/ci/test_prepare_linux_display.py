"""Exercise mirror avoidance and original package failure propagation."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


@unittest.skipUnless(os.name == "posix", "Linux shell setup contract")
class DisplaySetupTests(unittest.TestCase):
    def run_setup(self, *, missing="", failure=""):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "dpkg-query").write_text(
                '#!/bin/bash\n[[ " $MISSING " == *" ${@: -1} "* ]] || printf installed\n')
            (root / "sudo").write_text(
                '#!/bin/bash\necho "$*" >> "$CALLS"\n'
                '[[ "$*" != *" $FAILURE "* && "$*" != *" $FAILURE" ]] || exit 42\n')
            for name in ("dpkg-query", "sudo"):
                (root / name).chmod(0o755)
            env = {**os.environ, "PATH": str(root) + os.pathsep + os.environ["PATH"],
                   "MISSING": missing, "FAILURE": failure or "never-fail",
                   "CALLS": str(root / "calls")}
            script = Path(__file__).with_name("prepare_linux_display.sh")
            result = subprocess.run(["bash", str(script)], env=env, capture_output=True, timeout=10)
            calls = (root / "calls").read_text().splitlines() if (root / "calls").exists() else []
            return result.returncode, calls

    def test_preinstalled_image_never_contacts_mirror(self):
        code, calls = self.run_setup()
        self.assertEqual((code, calls), (0, []))

    def test_only_missing_packages_installed_with_bounded_network_retries(self):
        code, calls = self.run_setup(missing="xvfb xauth")
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 2)
        self.assertIn("APT::Update::Error-Mode=any update", calls[0])
        self.assertTrue(calls[1].endswith("install --no-install-recommends --yes xvfb xauth"))
        for call in calls:
            for option in ("Acquire::Retries=3", "Acquire::http::Timeout=30", "Acquire::https::Timeout=30"):
                self.assertIn(option, call)

    def test_failed_update_cannot_continue_with_stale_package_indexes(self):
        code, calls = self.run_setup(missing="xvfb", failure="update")
        self.assertEqual(code, 42)
        self.assertEqual(len(calls), 1)

    def test_failed_install_is_preserved(self):
        code, calls = self.run_setup(missing="xvfb", failure="install")
        self.assertEqual(code, 42)
        self.assertEqual(len(calls), 2)


if __name__ == "__main__":
    unittest.main()
