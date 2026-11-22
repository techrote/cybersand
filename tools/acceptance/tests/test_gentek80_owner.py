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
        "Open Workbench.cmd": b"echo MOCK ONLY\r\n",
        "READ-ME.md": b"MOCK fixture; not real release",
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


if __name__ == "__main__":
    unittest.main()
