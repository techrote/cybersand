"""Windows PowerShell admission adversaries. Synthetic fixtures are NOT real Godot acceptance."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / "gentek80_owner.ps1"
SOURCE = "a" * 40
TREE = "b" * 40
NATIVE = "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
RAPIER = "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def fixture(root):
    root.mkdir()
    files = {
        "Godot_v4.7-stable_win64.exe": b"MZfake-GUI",
        "Godot_v4.7-stable_win64_console.exe": b"MZfake-console",
        "Open Workbench.cmd": b"call verifier \\r\\n",
        "Verify and Open Workbench.cmd": b"powershell.exe MOCK\r\n",
        "READ-ME.md": b"MOCK fixture; not real release",
        "OWNER-ACCEPTANCE.md": b"MOCK owner guide",
        "tools/acceptance/gentek80_owner.ps1": b"MOCK fixture; not real script",
        "docs/operations/gentek80-physical-owner-acceptance.md": b"MOCK owner guide",
        "vcruntime140.dll": b"MZfake-VC",
        "godot/project.godot": b"[application]\n",
        NATIVE: b"MZfake-native",
        RAPIER: b"MZfake-rapier",
    }
    files["source-built-candidate-provenance.json"] = json.dumps({
        "source_commit": SOURCE, "source_tree": TREE, "sha256": digest(files[NATIVE]),
    }).encode()
    for i in range(110):
        files[f"godot/fixtures/part_{i:03d}.txt"] = f"part {i}".encode()
    for name, content in files.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    (root / "candidate-manifest.json").write_text(json.dumps({
        "schema": 1, "source_commit": SOURCE, "source_tree": TREE,
        "godot_version": "4.7.stable.official.5b4e0cb0f",
        "native_sha256": digest(files[NATIVE]),
        "files_sha256": {name: digest(content) for name, content in files.items()},
    }), encoding="utf8")


def zipup(src, dest, extras=None):
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as out:
        for path in src.rglob("*"):
            if path.is_file():
                out.write(path, path.relative_to(src).as_posix())
        for name, payload in (extras or {}).items():
            out.writestr(name, payload)
    return digest(dest.read_bytes())


@unittest.skipUnless(os.name == "nt" and shutil.which("powershell.exe"),
                     "Real Windows PowerShell only; Linux results must be SKIP")
class WindowsAdmission(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.src = self.root / "synthetic"
        fixture(self.src)
        self.zip = self.root / "candidate.zip"
        self.sha = zipup(self.src, self.zip)

    def run_ps(self, mode, expected, **kwargs):
        cmd = ["powershell.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy",
               "Bypass", "-File", str(SCRIPT), "-Action", mode]
        for key, val in kwargs.items():
            cmd.extend(["-" + key, str(val)])
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        message = result.stdout + "\n" + result.stderr
        self.assertEqual(result.returncode == 0, expected, message)
        return message

    def test_archive_and_unicode_extract(self):
        self.run_ps("VerifyArchive", True, ArchivePath=self.zip, ExpectedArchiveSha256=self.sha)
        dst = self.root / "profile (external)" / "空格 Ω" / "nested"
        self.run_ps("Extract", True, ArchivePath=self.zip, ExpectedArchiveSha256=self.sha,
                    ExpectedSource=SOURCE, Destination=dst)
        self.run_ps("VerifyPayload", True, PackagePath=dst, ExpectedSource=SOURCE)
        self.assertEqual((dst / NATIVE).read_bytes(), (self.src / NATIVE).read_bytes())

    def test_wrong_hash_truncated_zip_refuse(self):
        self.run_ps("VerifyArchive", False, ArchivePath=self.zip, ExpectedArchiveSha256="0" * 64)
        broken = self.root / "truncated.zip"
        broken.write_bytes(self.zip.read_bytes()[:-24])
        self.run_ps("VerifyArchive", False, ArchivePath=broken,
                    ExpectedArchiveSha256=digest(broken.read_bytes()))

    def test_traversal_and_case_collision_refuse(self):
        bad = self.root / "traversal.zip"
        sha = zipup(self.src, bad, {"../escape.txt": b"forbidden"})
        self.run_ps("Extract", False, ArchivePath=bad, ExpectedArchiveSha256=sha,
                    ExpectedSource=SOURCE, Destination=self.root / "extract1")
        self.assertFalse((self.root / "escape.txt").exists())
        bad = self.root / "collision.zip"
        sha = zipup(self.src, bad, {"GODOT/PROJECT.GODOT": b"collision"})
        self.run_ps("Extract", False, ArchivePath=bad, ExpectedArchiveSha256=sha,
                    ExpectedSource=SOURCE, Destination=self.root / "extract2")

    def test_stale_source_missing_runtime_changed_engine_refuse(self):
        self.run_ps("VerifyPayload", True, PackagePath=self.src, ExpectedSource=SOURCE)
        self.run_ps("VerifyPayload", False, PackagePath=self.src, ExpectedSource="c" * 40)
        native = self.src / NATIVE
        original = native.read_bytes()
        native.write_bytes(b"MZchanged")
        self.run_ps("VerifyPayload", False, PackagePath=self.src, ExpectedSource=SOURCE)
        native.write_bytes(original)
        rapier = self.src / RAPIER
        original = rapier.read_bytes()
        rapier.unlink()
        self.run_ps("VerifyPayload", False, PackagePath=self.src, ExpectedSource=SOURCE)
        rapier.write_bytes(original)
        (self.src / "Godot_v4.7-stable_win64_console.exe").write_bytes(b"MZwrong-executable")
        self.run_ps("VerifyPayload", False, PackagePath=self.src, ExpectedSource=SOURCE)

    def test_manifest_extra_script_and_import_cache(self):
        mf = self.src / "candidate-manifest.json"
        data = json.loads(mf.read_text())
        data["source_commit"] = "c" * 40
        mf.write_text(json.dumps(data))
        self.run_ps("VerifyPayload", False, PackagePath=self.src, ExpectedSource=SOURCE)
        data["source_commit"] = SOURCE
        mf.write_text(json.dumps(data))
        extra = self.src / "godot" / "scripts" / "unauthorised.gd"
        extra.parent.mkdir(parents=True)
        extra.write_bytes(b"unexpected code")
        self.run_ps("VerifyPayload", False, PackagePath=self.src, ExpectedSource=SOURCE)
        extra.unlink()
        cache = self.src / "godot" / ".godot" / "imported" / "safe.cache"
        cache.parent.mkdir(parents=True)
        cache.write_bytes(b"engine-owned cache")
        self.run_ps("VerifyPayload", True, PackagePath=self.src, ExpectedSource=SOURCE)

    def test_owner_decisions_not_invented(self):
        formdir = self.root / "owner form"
        self.run_ps("NewChecklist", True, ResultsDirectory=formdir)
        form = formdir / "owner-decisions.json"
        self.run_ps("Collect", False, PackagePath=self.src, ExpectedSource=SOURCE,
                    DecisionsPath=form, ResultsDirectory=self.root / "refused")
        data = json.loads(form.read_text(encoding="utf-8-sig"))
        self.assertEqual(len(data["cases"]), 20)
        for row in data["cases"]:
            row["decision"] = "SKIP"
        form.write_text(json.dumps(data), encoding="utf8")
        self.run_ps("Collect", True, PackagePath=self.src, ExpectedSource=SOURCE,
                    DecisionsPath=form, ResultsDirectory=self.root / "accepted")
        receipt = json.loads((self.root / "accepted" / "gentek80-owner-report.json").read_text())
        self.assertEqual(receipt["status"], "INCOMPLETE")
        # A set of unsubstantiated PASS flags is not physical acceptance.
        for row in data["cases"]:
            row["decision"] = "PASS"
        form.write_text(json.dumps(data), encoding="utf8")
        self.run_ps("Collect", True, PackagePath=self.src, ExpectedSource=SOURCE,
                    DecisionsPath=form, ResultsDirectory=self.root / "unsubstantiated-pass")
        dishonest = json.loads((self.root / "unsubstantiated-pass" / "gentek80-owner-report.json").read_text())
        self.assertEqual(dishonest["status"], "INCOMPLETE")
        self.assertTrue(dishonest["owner_metadata_issues"])
        self.assertIn("Independently authenticated manifest SHA-256 not supplied",
                      dishonest["owner_metadata_issues"])

        external_manifest_pin = digest((self.src / "candidate-manifest.json").read_bytes())
        # A wrong independent manifest pin is PACKAGE-REJECTED even for all-PASS declarations.
        self.run_ps("Collect", True, PackagePath=self.src, ExpectedSource=SOURCE,
                    ExpectedManifestSha256="0" * 64, DecisionsPath=form,
                    ResultsDirectory=self.root / "wrong-manifest-pin")
        mismatch = json.loads((self.root / "wrong-manifest-pin" / "gentek80-owner-report.json").read_text())
        self.assertEqual(mismatch["status"], "PACKAGE-REJECTED")
        self.assertIn("manifest", mismatch["verification_error"].lower())

        # An original ZIP requires its own external hash pin, not merely a manifest pin.
        self.run_ps("Collect", True, PackagePath=self.src, ExpectedSource=SOURCE,
                    ExpectedManifestSha256=external_manifest_pin, ArchivePath=self.zip,
                    DecisionsPath=form, ResultsDirectory=self.root / "missing-zip-pin")
        no_archive_pin = json.loads((self.root / "missing-zip-pin" / "gentek80-owner-report.json").read_text())
        self.assertEqual(no_archive_pin["status"], "INCOMPLETE")
        self.assertTrue(any("authenticated ZIP SHA-256" in issue
                            for issue in no_archive_pin["owner_metadata_issues"]))

        # Deliberately wrong ZIP pin is a package rejection, never an owner PASS.
        self.run_ps("Collect", True, PackagePath=self.src, ExpectedSource=SOURCE,
                    ExpectedManifestSha256=external_manifest_pin, ArchivePath=self.zip,
                    ExpectedArchiveSha256="0" * 64, DecisionsPath=form,
                    ResultsDirectory=self.root / "wrong-zip-pin")
        wrong_zip_pin = json.loads((self.root / "wrong-zip-pin" / "gentek80-owner-report.json").read_text())
        self.assertEqual(wrong_zip_pin["status"], "PACKAGE-REJECTED")
        self.assertIn("archive", wrong_zip_pin["archive_verification_error"].lower())

        # Both externally supplied hashes are accepted as provenance, but these
        # synthetic PASS declarations still lack physical Windows/NVIDIA evidence.
        self.run_ps("Collect", True, PackagePath=self.src, ExpectedSource=SOURCE,
                    ExpectedManifestSha256=external_manifest_pin, ArchivePath=self.zip,
                    ExpectedArchiveSha256=self.sha, DecisionsPath=form,
                    ResultsDirectory=self.root / "authentic-but-not-physical")
        pinned = json.loads((self.root / "authentic-but-not-physical" / "gentek80-owner-report.json").read_text())
        self.assertEqual(pinned["status"], "INCOMPLETE")
        self.assertTrue(pinned["independently_pinned_manifest"])
        self.assertEqual(pinned["archive_sha256"], self.sha)
        self.assertIsNone(pinned["archive_verification_error"])

        # An unrelated independently hashed ZIP is not provenance for this
        # extracted package, even if both independent pins are individually valid.
        unrelated = self.root / "unrelated-payload"
        shutil.copytree(self.src, unrelated)
        changed = unrelated / "godot/fixtures/part_000.txt"
        changed.write_bytes(b"different but self-consistent original ZIP")
        modified = unrelated / "candidate-manifest.json"
        data = json.loads(modified.read_text(encoding="utf8"))
        data["files_sha256"]["godot/fixtures/part_000.txt"] = digest(changed.read_bytes())
        modified.write_text(json.dumps(data), encoding="utf8")
        foreign_archive = self.root / "unrelated-source.zip"
        foreign_pin = zipup(unrelated, foreign_archive)
        self.run_ps("Collect", True, PackagePath=self.src, ExpectedSource=SOURCE,
                    ExpectedManifestSha256=external_manifest_pin,
                    ArchivePath=foreign_archive, ExpectedArchiveSha256=foreign_pin,
                    DecisionsPath=form, ResultsDirectory=self.root / "foreign-archive-refused")
        foreign = json.loads((self.root / "foreign-archive-refused" / "gentek80-owner-report.json").read_text())
        self.assertEqual(foreign["status"], "PACKAGE-REJECTED")
        self.assertIn("manifest", foreign["archive_verification_error"].lower())

    def test_failed_payload_extraction_is_atomic(self):
        corrupt = self.root / "corrupt"
        shutil.copytree(self.src, corrupt)
        (corrupt / NATIVE).write_bytes(b"MZcorrupt-but-valid-ZIP")
        bad = self.root / "bad-payload.zip"
        sha = zipup(corrupt, bad)
        destination = self.root / "staged parent (Ω)" / "final candidate"
        self.run_ps("Extract", False, ArchivePath=bad, ExpectedArchiveSha256=sha,
                    ExpectedSource=SOURCE, Destination=destination)
        self.assertFalse(destination.exists(), "partial final candidate must be absent")
        self.assertEqual(list(destination.parent.glob(".gentek80-staging-*")), [])

    def test_version_import_and_gui_use_isolated_owner_profile(self):
        # No import or version probe may write to the caller's ordinary Godot
        # user profile. This checks ordering without opening any real GUI.
        body = (Path(__file__).resolve().parents[1] / "gentek80_owner.ps1").read_text(encoding="utf8")
        launch = body.split(" 'Launch'{", 1)[1].split(" 'NewChecklist'{", 1)[0]
        for setting in ("$env:APPDATA=$roaming", "$env:LOCALAPPDATA=$local",
                        "$env:CYBERSAND_SOURCE_REVISION=$ExpectedSource"):
            self.assertLess(launch.index(setting), launch.index("& $console --version"))
            self.assertLess(launch.index(setting), launch.index("& $console --headless"))
            self.assertLess(launch.index(setting), launch.index("Start-Process -FilePath $gui"))

    def test_independent_manifest_pin_rejects_self_consistent_tamper(self):
        mf = self.src / "candidate-manifest.json"
        external_pin = digest(mf.read_bytes())
        self.run_ps("VerifyPayload", True, PackagePath=self.src, ExpectedSource=SOURCE,
                    ExpectedManifestSha256=external_pin)
        engine = self.src / "Godot_v4.7-stable_win64_console.exe"
        engine.write_bytes(b"MZattacker-mutated-engine")
        manifest = json.loads(mf.read_text())
        manifest["files_sha256"]["Godot_v4.7-stable_win64_console.exe"] = digest(engine.read_bytes())
        mf.write_text(json.dumps(manifest), encoding="utf8")
        # Deliberately prove why an externally authenticated pin is essential.
        self.run_ps("VerifyPayload", True, PackagePath=self.src, ExpectedSource=SOURCE)
        self.run_ps("VerifyPayload", False, PackagePath=self.src, ExpectedSource=SOURCE,
                    ExpectedManifestSha256=external_pin)


if __name__ == "__main__":
    unittest.main()
