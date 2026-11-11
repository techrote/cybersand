#!/usr/bin/env python3
"""Offline source-history, dependency isolation and package-custody controls."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_materials_lab_candidate as subject


class PackageTests(unittest.TestCase):
    def command(self, root, *args):
        return subprocess.check_output(["git", "-C", str(root), *args],
                                       env=subject.clean_git_environment(), stderr=subprocess.PIPE)

    def test_fresh_history_preserves_commits_without_machine_configuration_or_untracked_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "original"
            root.mkdir()
            self.command(root, "init")
            (root / ".gitattributes").write_bytes(b"source.txt text eol=lf\nretained-crlf.txt -text\n")
            (root / "source.txt").write_bytes(b"baseline\n")
            (root / "retained-crlf.txt").write_bytes(b"literal CRLF history\r\n")
            self.command(root, "add", ".gitattributes", "source.txt", "retained-crlf.txt")
            self.command(root, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-m", "baseline")
            first = self.command(root, "rev-parse", "HEAD").decode().strip()
            (root / "source.txt").write_bytes(b"candidate\n")
            self.command(root, "add", "source.txt")
            self.command(root, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-m", "candidate")
            head = self.command(root, "rev-parse", "HEAD").decode().strip()
            self.command(root, "remote", "add", "origin", "https://example.invalid/private-checkout")
            self.command(root, "config", "credential.helper", "fixture-private-helper")
            (root / ".git/hooks/private-marker").write_text("private machine data")
            (root / "untracked-private.txt").write_text("must not ship")
            template = Path(temporary) / "machine-template"
            template.mkdir()
            (template / "private-template-marker").write_text("private template data")
            destination = Path(temporary) / "delivery/source"
            with patch.dict(os.environ, {"GIT_TEMPLATE_DIR": str(template), "GIT_CONFIG_COUNT": "1",
                                        "GIT_CONFIG_KEY_0": "credential.helper", "GIT_CONFIG_VALUE_0": "injected-private-helper"}):
                identity = subject.clean_source_repository(root, head, destination)
            self.assertEqual(identity["source_commit"], head)
            self.assertGreater(identity["bundle_bytes"], 0)
            self.assertEqual(self.command(destination, "show", first + ":source.txt"), b"baseline\n")
            self.assertEqual(self.command(destination, "show", first + ":retained-crlf.txt"), b"literal CRLF history\r\n")
            self.assertEqual((destination / "retained-crlf.txt").read_bytes(), b"literal CRLF history\r\n")
            self.assertEqual(self.command(destination, "merge-base", "--is-ancestor", first, head), b"")
            self.assertEqual((destination / "source.txt").read_text(), "candidate\n")
            self.assertEqual(self.command(destination, "remote"), b"")
            self.assertFalse((destination / "untracked-private.txt").exists())
            self.assertFalse((destination / ".git/hooks/private-marker").exists())
            self.assertFalse((destination / ".git/private-template-marker").exists())
            configuration = (destination / ".git/config").read_text()
            self.assertNotIn("private-checkout", configuration)
            self.assertNotIn("fixture-private-helper", configuration)
            self.assertNotIn("injected-private-helper", configuration)
            with self.assertRaisesRegex(RuntimeError, "overwrite"):
                subject.clean_source_repository(root, head, destination)

    def test_dependency_environment_does_not_find_host_authoring_tools_or_user_python(self):
        with patch.dict(os.environ, {"PATH": "host-secret-tools", "PYTHONPATH": "private-imports",
                                     "PYTHONHOME": "private-python", "GIT_DIR": "other-repository",
                                     "GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "core.hooksPath",
                                     "GIT_CONFIG_VALUE_0": "private-hooks", "GIT_TEMPLATE_DIR": "private-template"}):
            environment = subject.dependency_environment(Path("evaluation"))
        self.assertNotIn("host-secret-tools", environment["PATH"])
        self.assertNotIn("PYTHONPATH", environment)
        self.assertNotIn("PYTHONHOME", environment)
        self.assertNotIn("GIT_DIR", environment)
        self.assertNotIn("GIT_CONFIG_COUNT", environment)
        self.assertNotIn("GIT_CONFIG_KEY_0", environment)
        self.assertNotIn("GIT_CONFIG_VALUE_0", environment)
        self.assertNotIn("GIT_TEMPLATE_DIR", environment)
        self.assertEqual(environment["PYTHONNOUSERSITE"], "1")
        self.assertIn("dependencies", environment["CYBERSAND_LAB_CXX"])

    def test_python_packaging_keeps_stdlib_not_installed_packages_or_caches(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, out = Path(temporary) / "python", Path(temporary) / "copied"
            for name in ("python.exe", "python312.dll", "LICENSE.txt", "Lib/json/__init__.py",
                         "Lib/site-packages/private_package.py", "Lib/json/__pycache__/private.pyc", "DLLs/_hashlib.pyd"):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"fixture")
            subject.copy_python(root, out)
            self.assertTrue((out / "LICENSE.txt").is_file())
            self.assertTrue((out / "Lib/json/__init__.py").is_file())
            self.assertTrue((out / "DLLs/_hashlib.pyd").is_file())
            self.assertFalse((out / "Lib/site-packages").exists())
            self.assertFalse((out / "Lib/json/__pycache__").exists())

    def fixture(self, root):
        runtime = root / "source" / subject.engine.RUNTIMES["windows"]
        runtime.parent.mkdir(parents=True)
        runtime.write_bytes(b"native fixture bytes")
        manifest = {"schema": "cybersand-materials-lab-evaluation-v1", "platform": "windows",
                    "source_commit": "a" * 40, "native_sha256": subject.sha(runtime), "runtime_active_candidates": False}
        native_manifest = root / "source" / subject.engine.MANIFESTS["windows"]
        native_manifest.write_bytes(subject.canonical({"sha256": manifest["native_sha256"],
            "source_commit": manifest["source_commit"], "status": "validated-development-runtime"}))
        manifest["files_sha256"] = subject.file_map(root)
        (root / subject.MANIFEST).write_bytes(subject.canonical(manifest))
        return manifest, runtime

    def test_complete_package_map_refuses_addition_loss_or_runtime_drift(self):
        for mode in ("positive", "extra", "missing", "changed", "native_binding", "active"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                manifest, runtime = self.fixture(root)
                if mode == "extra": (root / "unrecorded.exe").write_bytes(b"unknown")
                if mode == "missing": runtime.unlink()
                if mode == "changed": runtime.write_bytes(b"changed")
                if mode == "native_binding":
                    manifest["native_sha256"] = "0" * 64
                    (root / subject.MANIFEST).write_bytes(subject.canonical(manifest))
                if mode == "active":
                    manifest["runtime_active_candidates"] = True
                    (root / subject.MANIFEST).write_bytes(subject.canonical(manifest))
                if mode == "positive": self.assertEqual(subject.verify_package(root)["source_commit"], "a" * 40)
                else:
                    with self.assertRaises(RuntimeError): subject.verify_package(root)

    @unittest.skipUnless(os.name == "posix", "Portable symlink-copy negative is qualified on POSIX")
    def test_external_dependency_symlink_is_never_followed_into_delivery(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "private").write_text("do not copy")
            source = root / "dependency"
            source.mkdir()
            (source / "external").symlink_to(root / "private")
            with self.assertRaisesRegex(RuntimeError, "symlink"):
                subject.copy_portable_tree(source, root / "output")
            self.assertFalse((root / "output").exists())


if __name__ == "__main__":
    unittest.main()
