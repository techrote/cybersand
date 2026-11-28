"""Reader-family custody at a distinct measured application root.

These tests run fresh isolated Python processes. They execute the unchanged
frozen reader's real path and native-binary guards; no Godot/native library is
loaded. Argument-spy coverage separately proves P/C application roots remain
authoritative after choosing driver-owned reader code.
"""
from __future__ import annotations

import subprocess
import sys
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRELUDE = r"""
import json
import sys
import tempfile
import types
from pathlib import Path
from unittest import mock
sys.path.insert(0, str(DRIVER / "tools/pubpres_mainline"))
import common

with tempfile.TemporaryDirectory(prefix="pubpres-reader (P) ") as scratch:
    scratch = Path(scratch)
    app = scratch / "application"
    runtime = scratch / "runtime"
    runtime.mkdir()
    for relative in ("tools/pubpres_final_recovery/retained_runtime.py",
                     "tools/pubpres_final/runtime_replay.py"):
        path = app / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("raise AssertionError('evaluated application reader executed')\n")
    source = {"source_commit": "a" * 40, "source_tree": "b" * 40}
    original = {"source_commit": "c" * 40, "source_tree": "d" * 40}
    record = dict(original, schema="deliberately-invalid-native-build", returncode=0,
                  production_runtime_promotion=False, toolchain_drift_allowed=False)
    (runtime / "PUBPRES-RUNTIME.json").write_text(json.dumps(record))
    roots = []
    def identity(root):
        roots.append(root)
        assert root == app.resolve(), (root, app)
        return source
    common.source_identity = identity
    def admit_readers():
        try:
            common.runtime_record(app, runtime, "windows")
        except ValueError as error:
            assert str(error) == "Failed or unknown experimental native build", str(error)
        else:
            raise AssertionError("invalid original build was admitted")
        import retained_runtime
        import runtime_replay
        assert Path(retained_runtime.__file__).resolve() == DRIVER / "tools/pubpres_final_recovery/retained_runtime.py"
        assert Path(runtime_replay.__file__).resolve() == DRIVER / "tools/pubpres_final/runtime_replay.py"
        return retained_runtime, runtime_replay
"""

class SpawnReaderBindingTests(unittest.TestCase):
    def probe(self, body):
        script = "from pathlib import Path\nDRIVER = Path(" + repr(str(ROOT)) + ")\n"
        script += PRELUDE + textwrap.indent(textwrap.dedent(body), "    ")
        result = subprocess.run([sys.executable, "-I", "-B", "-c", script],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_cold_import_never_executes_evaluated_application_readers(self):
        self.probe("""
            retained, replay = admit_readers()
            assert roots == [app.resolve()]
            assert replay.FROZEN_FILE == DRIVER / "tools/pubpres_playability/run_campaign.py"
            assert Path(replay.frozen.__file__).resolve() == replay.FROZEN_FILE
        """)

    def test_explicit_application_root_and_build_identity_are_not_replaced(self):
        self.probe("""
            retained, replay = admit_readers()
            seen = []
            def verify(root, original_source, folder, *, target_platform):
                seen.append(("verify", root, original_source, folder, target_platform))
                return {"independent_native_guard": True}
            def bind(root, application, folder, *, target_platform):
                seen.append(("bind", root, application, folder, target_platform))
                return {"original_build": original, "application": application}
            with mock.patch.object(replay, "verify_recorded_runtime", verify), mock.patch.object(retained, "make_binding", bind):
                for name in ("P", "C"):
                    app = scratch / name
                    app.mkdir()
                    got_record, got = common.runtime_record(app, runtime, "windows")
                    assert got_record == record and got["independent_native_guard"] is True
                    assert got["application_binding"]["application"] == source
                    assert seen[-2] == ("verify", app.resolve(), original, runtime.resolve(), "windows")
                    assert seen[-1] == ("bind", app.resolve(), source, runtime.resolve(), "windows")
        """)

    def test_foreign_cached_reader_family_is_refused(self):
        self.probe("""
            fake = types.ModuleType("runtime_replay")
            fake.__file__ = str(app / "tools/pubpres_final/runtime_replay.py")
            fake.verify_recorded_runtime = lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError("foreign reader was invoked"))
            sys.modules["runtime_replay"] = fake
            try:
                common.runtime_record(app, runtime, "windows")
            except ValueError as error:
                assert str(error) == "Frozen runtime readers came from another measurement source", str(error)
            else:
                raise AssertionError("foreign cached reader was admitted")
        """)

    def test_unchanged_frozen_campaign_path_guard_still_refuses_mixed_module(self):
        self.probe("""
            retained, replay = admit_readers()
            previous = replay.frozen
            replay.frozen = types.SimpleNamespace(__file__=str(app / "tools/pubpres_playability/run_campaign.py"))
            try:
                try:
                    common.runtime_record(app, runtime, "windows")
                except ValueError as error:
                    assert str(error) == "Frozen runtime module came from another path", str(error)
                else:
                    raise AssertionError("foreign frozen campaign was admitted")
            finally:
                replay.frozen = previous
        """)

    def test_real_frozen_native_byte_guard_remains_active_on_both_platforms(self):
        self.probe("""
            retained, replay = admit_readers()
            for platform, name, build_script in (
                ("windows", "cybersand_native.windows.x86_64.dll", "tools/build_native_extension_windows.sh"),
                ("linux", "libcybersand_native.linux.x86_64.so", "tools/build_native_extension.sh"),
            ):
                data = b"wrong native bytes"
                (runtime / name).write_bytes(data)
                record.update(schema="pubpres-playability-native-build-v1", platform=platform,
                              runtime_file=name, build_script=build_script,
                              runtime_bytes=len(data), runtime_sha256="0" * 64)
                (runtime / "PUBPRES-RUNTIME.json").write_text(json.dumps(record))
                try:
                    common.runtime_record(app, runtime, platform)
                except ValueError as error:
                    assert str(error) == "Experimental native binary hash/size differs", str(error)
                else:
                    raise AssertionError("wrong native bytes were admitted")
        """)
if __name__ == "__main__":
    unittest.main()
