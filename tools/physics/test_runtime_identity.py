"""Disposable platform-selection and fail-closed measurement identity probes."""
import json
from types import SimpleNamespace
from unittest.mock import patch
import tempfile
import unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import runtime_identity as r


class RuntimeIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.engine = self.root / "engine"
        self.engine.write_bytes(b"engine-fixture-only")
        self.libraries = {}
        for addon, name, prefix in (("cybersand_native", "cybersand_native", "res://addons/cybersand_native/"),
                                    ("godot-rapier2d", "godot-rapier2d", "")):
            directory = self.root / "godot/addons" / addon
            (directory / "bin").mkdir(parents=True)
            lines = ["[libraries]"]
            for system, suffix in (("linux", "so"), ("windows", "dll")):
                relative = f"bin/{system}.{suffix}"
                library = directory / relative
                library.write_bytes((addon + system).encode())
                self.libraries[(addon, system)] = library
                lines += [f'{system}.{mode}.x86_64 = "{prefix}{relative}"' for mode in ("debug", "release")]
            (directory / (name + ".gdextension")).write_text("\n".join(lines))

    def select(self, system="Linux", machine="x86_64"):
        return r.selected_artifacts(self.root, self.engine, system=system, machine=machine)

    def test_linux_uses_real_selected_so_and_no_windows_dll(self):
        paths, metadata = self.select()
        self.assertEqual(paths, [self.engine, self.libraries[("cybersand_native", "linux")], self.libraries[("godot-rapier2d", "linux")]])
        self.assertEqual(metadata["system"], "Linux")

    def test_windows_amd64_uses_selected_dll(self):
        paths, _ = self.select("Windows", "AMD64")
        self.assertEqual(paths[1:], [self.libraries[("cybersand_native", "windows")], self.libraries[("godot-rapier2d", "windows")]])

    def test_unsupported_os_or_arch_refuses(self):
        for system, machine in (("Darwin", "arm64"), ("Linux", "aarch64"), ("Windows", "x86")):
            with self.subTest(system=system, machine=machine), self.assertRaisesRegex(ValueError, "No supported"):
                self.select(system, machine)

    def test_missing_selected_library_not_silently_omitted(self):
        self.libraries[("cybersand_native", "linux")].unlink()
        with self.assertRaises(FileNotFoundError): self.select()

    def test_lfs_pointer_not_binary_identity(self):
        self.libraries[("godot-rapier2d", "linux")].write_bytes(b"version https://git-lfs.github.com/spec/v1\noid sha256:abcd\nsize 5\n")
        with self.assertRaisesRegex(ValueError, "LFS pointer"): self.select()

    def test_descriptor_change_is_observed_not_hardcoded(self):
        path = self.root / "godot/addons/cybersand_native/cybersand_native.gdextension"
        old = self.libraries[("cybersand_native", "linux")]
        new = old.with_name("candidate.so")
        new.write_bytes(b"new runtime")
        path.write_text(path.read_text().replace("bin/linux.so", "bin/candidate.so"))
        self.assertEqual(self.select()[0][1], new)

    def test_ambiguous_debug_release_and_escape_refuse(self):
        path = self.root / "godot/addons/cybersand_native/cybersand_native.gdextension"
        original = path.read_text()
        path.write_text(original.replace('linux.release.x86_64 = "res://addons/cybersand_native/bin/linux.so"', 'linux.release.x86_64 = "res://elsewhere.so"'))
        with self.assertRaisesRegex(ValueError, "Ambiguous"): self.select()
        path.write_text(original.replace("res://addons/cybersand_native/bin/linux.so", "../../../../engine"))
        with self.assertRaisesRegex(ValueError, "leaves project"): self.select()

    def test_post_capture_drift_and_removal_refuse(self):
        before = r.materialized_hashes([self.engine])
        self.assertEqual(r.verify_unchanged(before), before)
        self.engine.write_bytes(b"replacement")
        with self.assertRaisesRegex(ValueError, "changed during"): r.verify_unchanged(before)
        self.engine.unlink()
        with self.assertRaises(FileNotFoundError): r.verify_unchanged(before)

    def test_fresh_output_preserves_existing_failed_evidence(self):
        out = r.fresh_output(self.root / "attempt")
        failed = out / "failure.log"
        failed.write_bytes(b"retained failure")
        with self.assertRaises(FileExistsError): r.fresh_output(out)
        self.assertEqual(failed.read_bytes(), b"retained failure")

    def test_actual_engine_version_is_checked_against_lock(self):
        lock = self.root / "third_party/godot-runtime.lock.json"
        lock.parent.mkdir()
        lock.write_text(json.dumps({"godot_version":"4.7.stable.fixture"}))
        with patch.object(r.platform, "system", return_value="Linux"), patch.object(r.platform, "machine", return_value="x86_64"), \
                patch.object(r.subprocess, "run", return_value=SimpleNamespace(stdout="4.7.stable.fixture\n")) as probe:
            _, metadata = r.desktop_runtime(self.root, self.engine)
            self.assertEqual(metadata["godot_version"], "4.7.stable.fixture")
            self.assertEqual(probe.call_args.args[0], [str(self.engine), "--version"])
            probe.return_value.stdout = "4.6.stable.fixture\n"
            with self.assertRaisesRegex(ValueError, "version mismatch"):
                r.desktop_runtime(self.root, self.engine)


if __name__ == "__main__": unittest.main()
