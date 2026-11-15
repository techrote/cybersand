#!/usr/bin/env python3
"""Challenge missing or forged Wave Flow qualification, preserving shared guards."""
import hashlib
import inspect
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import lcb001_shared_contract_runtime_publication as shared
import wave_mt_runtime_publication as profile
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import package_wave_flow_candidate as package


class WaveRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # The Wave wrapper forces canonical archive text. Read these reviewed
        # blobs for unit fixtures; the real-archive regression below separately
        # exercises Git's conversion under inherited Windows-style settings.
        names = [*package.REGENERATED_RAPIER_IMPORTS,
                 *[name.removesuffix(".import") for name in package.REGENERATED_RAPIER_IMPORTS]]
        cls.committed_import_inputs = {
            name: subprocess.check_output(["git", "show", "HEAD:" + name], cwd=package.ROOT)
            for name in names
        }

    def staged_package(self, root):
        """Small inherited-payload fixture; it does not execute/fake Godot."""
        root.mkdir(parents=True)
        runtime = profile.engine.RUNTIMES["windows"]
        payload = {
            runtime: b"MZ-source-built-candidate",
            "godot/project.godot": b"config_version=5\n",
            "godot/scripts/authored.gd": b"extends Node\n",
            "godot/scripts/authored.gd.uid": b"uid://authored-stable-identity\n",
            "godot/assets/authored.svg": b"<svg xmlns='http://www.w3.org/2000/svg'/>\n",
            "godot/assets/authored.svg.import": b"[params]\nsvg/scale=2.0\n",
            "source-built-candidate-provenance.json": b'{"fixture":"inherited candidate identity"}\n',
            "godot/addons/cybersand_native/retained-runtime-provenance.reference.json":
                b'{"fixture":"inherited historical runtime reference"}\n',
        }
        for name, expected in package.REGENERATED_RAPIER_IMPORTS.items():
            # Use the reviewed committed metadata, including editor-only flags;
            # a dependency update must not silently broaden this exclusion.
            payload[name] = self.committed_import_inputs[name]
            self.assertEqual(hashlib.sha256(payload[name]).hexdigest(), expected)
            image = name.removesuffix(".import")
            payload[image] = self.committed_import_inputs[image]
        for name, data in payload.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        manifest = {"source_commit": "1" * 40, "native_sha256": package.sha(root / runtime),
                    "files_sha256": package.files(root)}
        (root / "candidate-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        return payload

    def runtime_evidence_fixture(self, root):
        """Copy/admission fixture only: the real Windows verifier is stubbed."""
        bundle = root.parent / "runtime-bundle"
        bundle.mkdir()
        logs = {}
        for name in ["import", *profile.engine.CASE_MARKERS]:
            path = bundle / (name + ".log")
            path.write_bytes(("UNIT TEST COPY FIXTURE; NO RUNTIME EXECUTION: " + name + "\n").encode())
            logs[path.name] = package.sha(path)
        report = {"fixture": "copy admission only; no target-OS validation", "log_sha256": logs}
        (bundle / "validation.json").write_text(json.dumps(report), encoding="utf-8")
        provenance = {"source_commit": "1" * 40,
                      "sha256": package.sha(root / profile.engine.RUNTIMES["windows"]),
                      "toolchain": "UNIT TEST: NO COMPILER CLAIM",
                      "validation_sha256": package.sha(bundle / "validation.json")}
        profile.engine.manifest_path(bundle, "windows").write_text(json.dumps(provenance), encoding="utf-8")
        return bundle, provenance

    def build_package(self, root):
        payload = self.staged_package(root)
        bundle, provenance = self.runtime_evidence_fixture(root)
        args = SimpleNamespace(output=root, engine=Path("Godot_v4.7-stable_win64.exe"),
                               engine_notices=Path("notices"), native_candidate=bundle,
                               vc_runtime=Path("vc-runtime"))
        with patch.object(package.subprocess, "run") as inherited, \
                patch.object(profile.engine, "verify_bundle", return_value=provenance) as admission:
            package.build(args)
            inherited.assert_called_once()
            self.assertIn(str(package.ROOT / "tools/package_explore001_candidate.py"),
                          inherited.call_args.args[0])
            child_environment = inherited.call_args.kwargs["env"]
            count = int(child_environment["GIT_CONFIG_COUNT"])
            self.assertEqual(child_environment[f"GIT_CONFIG_KEY_{count - 2}"], "core.autocrlf")
            self.assertEqual(child_environment[f"GIT_CONFIG_VALUE_{count - 2}"], "false")
            self.assertEqual(child_environment[f"GIT_CONFIG_KEY_{count - 1}"], "core.eol")
            self.assertEqual(child_environment[f"GIT_CONFIG_VALUE_{count - 1}"], "lf")
            self.assertEqual(child_environment["GIT_LFS_SKIP_SMUDGE"], "1")
            admission.assert_called_once_with(bundle, "windows", "1" * 40, validated=True)
        self.assertEqual((root / "source-built-runtime-provenance.json").read_bytes(),
                         profile.engine.manifest_path(bundle, "windows").read_bytes())
        for name in ["validation.json", "import.log", *[name + ".log" for name in profile.engine.CASE_MARKERS]]:
            self.assertEqual((root / "qualification/runtime" / name).read_bytes(), (bundle / name).read_bytes())
        return payload, package.verify(root)

    def test_original_source_lfs_and_target_os_guards_are_preserved(self):
        self.assertIsNot(profile.engine, shared)
        for name in ("context", "require_publication_request", "check_source", "check_index",
                     "input_ledgers", "runtime_identity", "verify_bundle", "record_build",
                     "execute", "stage"):
            with self.subTest(name=name):
                self.assertEqual(inspect.getsource(getattr(profile.engine, name)),
                                 inspect.getsource(getattr(shared, name)))
        self.assertEqual(profile.engine.BRANCH, "astra/wave-mt-001-669-finisher")

    def test_takeover_publication_refuses_the_previous_owners_branch(self):
        source, tree = "1" * 40, "2" * 40
        branch = profile.engine.BRANCH
        workflow = "techrote/cybersand/" + profile.engine.WORKFLOW + "@refs/heads/"
        environment = {
            "GITHUB_REPOSITORY": "techrote/cybersand", "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/" + branch, "GITHUB_WORKFLOW_REF": workflow + branch,
            "GITHUB_SHA": source, "GITHUB_RUN_ID": "631", "GITHUB_RUN_ATTEMPT": "1",
        }
        def git(*arguments):
            self.assertEqual(arguments[0], "rev-parse")
            return ((source if arguments[1] == "HEAD" else tree) + "\n").encode()
        with patch.object(profile.engine, "git", side_effect=git), patch.dict(os.environ, environment):
            self.assertEqual(profile.engine.context(source)["source_tree"], tree)
            for key, value in {
                "GITHUB_REF": "refs/heads/codex/wave-mt-001-parallel-20261115",
                "GITHUB_WORKFLOW_REF": workflow + "codex/wave-mt-001-parallel-20261115",
            }.items():
                with self.subTest(key=key), patch.dict(os.environ, {key: value}), self.assertRaises(RuntimeError):
                    profile.engine.context(source)

    def test_all_wave_sections_required(self):
        valid = {key: True for key in profile.WAVE_SECTIONS}
        def output(value, failures=0):
            return f"WAVE_FLOW: 61 assertions; {failures} failures; completed=" + json.dumps(value) + "\n"
        profile.verify_wave_summary(output(valid))
        for key in valid:
            for bad in (False, 1, "true", None):
                with self.subTest(section=key, value=bad), self.assertRaises(RuntimeError):
                    profile.verify_wave_summary(output(valid | {key: bad}))
            missing = dict(valid)
            del missing[key]
            with self.assertRaises(RuntimeError):
                profile.verify_wave_summary(output(missing))
        for bad in ("", output(valid, 1), output(valid) * 2,
                    output(valid).replace("61 assertions", "0 assertions"),
                    output(valid | {"unexpected": True}),
                    "WAVE_FLOW: 61 assertions; 0 failures; completed={oops}\n"):
            with self.assertRaises(RuntimeError):
                profile.verify_wave_summary(bad)

    def test_extracted_package_rejects_changed_or_missing_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            runtime = root / profile.engine.RUNTIMES["windows"]
            runtime.parent.mkdir(parents=True)
            runtime.write_bytes(b"MZ-test-candidate")
            launcher = root / "Test It.cmd"
            launcher.write_text("verified launcher\n", encoding="utf-8")
            manifest = {"launcher": "Test It.cmd", "native_sha256": package.sha(runtime),
                        "files_sha256": package.files(root)}
            manifest_path = root / "candidate-manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            digest = package.sha(manifest_path)
            self.assertEqual(package.verify(root), manifest)
            generated = root / "godot/.godot/import-cache"
            generated.parent.mkdir(parents=True)
            generated.write_text("generated by import", encoding="utf-8")
            with self.assertRaises(RuntimeError):
                package.verify(root)  # Additional bytes cannot enter the delivered ZIP.
            package.verify_original_payload(root, manifest, digest)
            for path in (runtime, launcher):
                original = path.read_bytes()
                path.write_bytes(original + b"changed")
                with self.assertRaises(RuntimeError):
                    package.verify_original_payload(root, manifest, digest)
                path.write_bytes(original)
            manifest_path.write_text(json.dumps(manifest) + " ", encoding="utf-8")
            with self.assertRaises(RuntimeError):
                package.verify_original_payload(root, manifest, digest)

    def test_wave_build_omits_only_reviewed_generated_sidecars_before_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "package"
            original, manifest = self.build_package(root)
            self.assertEqual(manifest["regenerated_imports_sha256"], package.REGENERATED_RAPIER_IMPORTS)
            for name, data in original.items():
                with self.subTest(name=name):
                    if name in package.REGENERATED_RAPIER_IMPORTS:
                        self.assertFalse((root / name).exists())
                        self.assertNotIn(name, manifest["files_sha256"])
                    else:
                        self.assertEqual((root / name).read_bytes(), data)
                        self.assertEqual(package.sha(root / name), manifest["files_sha256"][name])
            self.assertEqual(manifest["files_sha256"], package.files(root))
            self.assertIn("-- --wave-flow", (root / "Test It.cmd").read_text(encoding="utf-8"))
            qualification = manifest["runtime_qualification"]
            self.assertEqual(qualification["provenance"], "source-built-runtime-provenance.json")
            self.assertEqual(qualification["validation"], "qualification/runtime/validation.json")
            self.assertEqual(qualification["logs"], ["qualification/runtime/" + name + ".log"
                                                    for name in ["import", *profile.engine.CASE_MARKERS]])
            for name in [qualification["provenance"], qualification["validation"], *qualification["logs"]]:
                self.assertEqual(manifest["files_sha256"][name], package.sha(root / name))

    def test_import_generation_does_not_exempt_images_uids_runtime_or_authored_settings(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "package"
            original, manifest = self.build_package(root)
            digest = package.sha(root / "candidate-manifest.json")
            generated = [*package.REGENERATED_RAPIER_IMPORTS,
                         "godot/.godot/imported/generated.ctex", "godot/scripts/generated.gd.uid"]
            for name in generated:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"new derived import output")
            # New import outputs are allowed only after the exact initial
            # inventory has passed; they can never enter the delivered baseline.
            with self.assertRaises(RuntimeError):
                package.verify(root)
            package.verify_original_payload(root, manifest, digest)
            protected = [profile.engine.RUNTIMES["windows"], "godot/scripts/authored.gd",
                         "godot/scripts/authored.gd.uid", "godot/assets/authored.svg.import",
                         *[name.removesuffix(".import") for name in package.REGENERATED_RAPIER_IMPORTS]]
            for name in protected:
                with self.subTest(name=name):
                    path = root / name
                    path.write_bytes(original[name] + b"unexpected change")
                    with self.assertRaisesRegex(RuntimeError, "Packaged input changed"):
                        package.verify_original_payload(root, manifest, digest)
                    path.unlink()
                    with self.assertRaisesRegex(RuntimeError, "Packaged input changed"):
                        package.verify_original_payload(root, manifest, digest)
                    path.write_bytes(original[name])
            package.verify_original_payload(root, manifest, digest)

    def test_changed_reviewed_import_settings_refuse_before_any_omission(self):
        for name in package.REGENERATED_RAPIER_IMPORTS:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary) / "package"
                self.staged_package(root)
                path = root / name
                path.write_bytes(path.read_bytes() + b"\nsvg/scale=2.0\n")
                before = package.files(root)
                with self.assertRaisesRegex(RuntimeError, "Reviewed Rapier import settings changed"):
                    package.omit_regenerated_imports(root)
                self.assertEqual(package.files(root), before)

    def test_import_omission_requires_the_source_image(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "package"
            self.staged_package(root)
            name = next(iter(package.REGENERATED_RAPIER_IMPORTS))
            (root / name.removesuffix(".import")).unlink()
            before = package.files(root)
            with self.assertRaisesRegex(RuntimeError, "requires its source image"):
                package.omit_regenerated_imports(root)
            self.assertEqual(package.files(root), before)

    def test_wave_adaptation_rejects_changed_inherited_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "package"
            self.staged_package(root)
            (root / "godot/scripts/authored.gd.uid").write_bytes(b"changed authored identity")
            args = SimpleNamespace(output=root, engine=Path("Godot_v4.7-stable_win64.exe"),
                                   engine_notices=Path("notices"), native_candidate=Path("candidate"),
                                   vc_runtime=Path("vc-runtime"))
            before = package.files(root)
            with patch.object(package.subprocess, "run"), self.assertRaisesRegex(RuntimeError, "before Wave adaptation"):
                package.build(args)
            self.assertEqual(package.files(root), before)

    def test_package_refuses_runtime_bundle_without_actual_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "package"
            self.staged_package(root)
            before = package.files(root)
            identity = json.loads((root / "candidate-manifest.json").read_text())
            with patch.object(profile.engine, "verify_bundle", side_effect=RuntimeError("Incomplete execution evidence")) as admission:
                with self.assertRaisesRegex(RuntimeError, "Incomplete execution evidence"):
                    package.stage_runtime_evidence(Path("unqualified-bundle"), root, identity)
            admission.assert_called_once_with(Path("unqualified-bundle"), "windows", "1" * 40, validated=True)
            self.assertEqual(package.files(root), before)

    def test_package_binds_validated_runtime_to_the_delivered_dll(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "package"
            self.staged_package(root)
            bundle, provenance = self.runtime_evidence_fixture(root)
            identity = json.loads((root / "candidate-manifest.json").read_text())
            before = package.files(root)
            with patch.object(profile.engine, "verify_bundle", return_value=provenance | {"sha256": "0" * 64}):
                with self.assertRaisesRegex(RuntimeError, "differs from the packaged DLL"):
                    package.stage_runtime_evidence(bundle, root, identity)
            self.assertEqual(package.files(root), before)

    def test_evidence_cannot_change_between_validation_and_copy(self):
        for name, message in [("runtime-provenance.json", "provenance changed"),
                              ("validation.json", "report changed"),
                              ("test_wave_flow.log", "log changed")]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary) / "package"
                self.staged_package(root)
                bundle, provenance = self.runtime_evidence_fixture(root)
                identity = json.loads((root / "candidate-manifest.json").read_text())
                path = bundle / name
                if name == "runtime-provenance.json":
                    path.write_text(json.dumps(provenance | {"toolchain": "changed toolchain"}))
                else:
                    path.write_bytes(path.read_bytes() + b" ")
                before = package.files(root)
                with patch.object(profile.engine, "verify_bundle", return_value=provenance):
                    with self.assertRaisesRegex(RuntimeError, message):
                        package.stage_runtime_evidence(bundle, root, identity)
                self.assertEqual(package.files(root), before)

    def test_archive_overrides_append_without_mutating_inherited_configuration(self):
        inherited = {"GIT_CONFIG_COUNT": "3", "GIT_CONFIG_KEY_0": "core.autocrlf",
                     "GIT_CONFIG_VALUE_0": "true", "GIT_CONFIG_KEY_1": "core.eol",
                     "GIT_CONFIG_VALUE_1": "crlf", "GIT_CONFIG_KEY_2": "fixture.preserved",
                     "GIT_CONFIG_VALUE_2": "existing", "GIT_LFS_SKIP_SMUDGE": "0"}
        with patch.dict(os.environ, inherited):
            before = dict(os.environ)
            actual = package.archive_environment()
            self.assertEqual(dict(os.environ), before)
        for key, value in inherited.items():
            if key not in {"GIT_CONFIG_COUNT", "GIT_LFS_SKIP_SMUDGE"}:
                self.assertEqual(actual[key], value)
        self.assertEqual(actual["GIT_CONFIG_COUNT"], "5")
        self.assertEqual(actual["GIT_CONFIG_KEY_3"], "core.autocrlf")
        self.assertEqual(actual["GIT_CONFIG_VALUE_3"], "false")
        self.assertEqual(actual["GIT_CONFIG_KEY_4"], "core.eol")
        self.assertEqual(actual["GIT_CONFIG_VALUE_4"], "lf")
        self.assertEqual(actual["GIT_LFS_SKIP_SMUDGE"], "1")

    def test_real_git_archive_under_crlf_retains_pins_and_explicit_attributes(self):
        inherited = {"GIT_CONFIG_COUNT": "2", "GIT_CONFIG_KEY_0": "core.autocrlf",
                     "GIT_CONFIG_VALUE_0": "true", "GIT_CONFIG_KEY_1": "core.eol",
                     "GIT_CONFIG_VALUE_1": "crlf"}
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, inherited):
            repository = Path(temporary) / "source"
            repository.mkdir()
            def git(*arguments, environment=None):
                return subprocess.check_output(["git", "-C", str(repository), *arguments],
                                               env=environment, stderr=subprocess.PIPE)
            git("init")
            payload = dict(self.committed_import_inputs)
            payload.update({".gitattributes": b"* text=auto\n*.gd text eol=lf\n*.cmd text eol=crlf\n*.bin -text\n",
                            "godot/fixture.gd": b"extends Node\n",
                            "godot/fixture.gd.uid": b"uid://authored-identity\n",
                            "launch.cmd": b"@echo off\nexit /b 0\n",
                            "binary.bin": b"\x00retained\r\nbytes\n"})
            for name, data in payload.items():
                path = repository / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            git("add", ".")
            git("-c", "user.name=Archive Fixture", "-c", "user.email=fixture@example.invalid",
                "-c", "commit.gpgsign=false", "commit", "-m", "archive conversion fixture")
            configuration = (repository / ".git/config").read_bytes()
            def archive(environment):
                with tarfile.open(fileobj=io.BytesIO(git("archive", "HEAD", environment=environment))) as tar:
                    return {entry.name: tar.extractfile(entry).read() for entry in tar if entry.isfile()}
            converted = archive(dict(os.environ))
            canonical = archive(package.archive_environment())
            extracted = Path(temporary) / "canonical-package"
            for name, data in canonical.items():
                path = extracted / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            for name, expected in package.REGENERATED_RAPIER_IMPORTS.items():
                self.assertIn(b"\r\n", converted[name])
                self.assertNotEqual(hashlib.sha256(converted[name]).hexdigest(), expected)
                self.assertEqual(canonical[name], self.committed_import_inputs[name])
                self.assertEqual(hashlib.sha256(canonical[name]).hexdigest(), expected)
            self.assertEqual(package.omit_regenerated_imports(extracted), package.REGENERATED_RAPIER_IMPORTS)
            self.assertEqual(canonical["godot/fixture.gd"], payload["godot/fixture.gd"])
            self.assertEqual(canonical["godot/fixture.gd.uid"], payload["godot/fixture.gd.uid"])
            self.assertEqual(canonical["launch.cmd"], payload["launch.cmd"].replace(b"\n", b"\r\n"))
            self.assertEqual(canonical["binary.bin"], payload["binary.bin"])
            self.assertEqual((repository / ".git/config").read_bytes(), configuration)


if __name__ == "__main__":
    unittest.main()
