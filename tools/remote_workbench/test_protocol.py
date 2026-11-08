#!/usr/bin/env python3
"""No-network host/transport tests; native/renderer proof is the separate Xvfb job."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

HERE = Path(__file__).resolve().parent


def load(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load("remote_workbench_runner", "run.py")
verifier = load("remote_workbench_verifier", "verify.py")


def make_png(path: Path, pixel: tuple[int, int, int, int]) -> None:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(
            ">I", zlib.crc32(kind + data) & 0xFFFFFFFF
        )
    path.write_bytes(
        verifier.PNG_HEADER
        + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes((0, *pixel))))
        + chunk(b"IEND", b"")
    )


class ProtocolTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.auth = self.root / "authorization.json"
        self.commands = self.root / "commands.jsonl"
        self.auth.write_text(
            (HERE / "fixtures/roundtrip-authorization.json").read_text(),
            encoding="utf-8",
        )
        self.commands.write_text(
            (HERE / "fixtures/roundtrip-commands.jsonl").read_text(),
            encoding="utf-8",
        )

    def tearDown(self):
        self.directory.cleanup()

    def test_committed_roundtrip_is_bounded(self):
        doc = runner.validate_authorization(self.auth)
        self.assertEqual(doc["extent"], [512, 512])
        runner.validate_commands(self.commands, live=False)
        lines = [json.loads(x) for x in self.commands.read_text().splitlines()]
        self.assertEqual([c["seq"] for c in lines], list(range(1, 9)))
        self.assertEqual(lines[-2]["tool"], "stop")
        self.assertEqual(lines[-1]["tool"], "apply_edit")
        self.assertEqual(lines[-1]["expect_status"], "refused")
        self.assertEqual(lines[4]["args"]["ticks"], 4)

    def test_no_authorization_inside_model_tool_envelope(self):
        self.commands.write_text(
            '{"version":1,"seq":1,"tool":"authorize_task","args":{}}\n',
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ValueError, "Unsupported tool"):
            runner.validate_commands(self.commands, live=False)

    def test_no_unlisted_material_authorized(self):
        data = json.loads(self.auth.read_text())
        data["allowed_materials"] = [2]
        self.auth.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "Hard Wall"):
            runner.validate_authorization(self.auth)

    def test_no_float_material_allowed(self):
        data = json.loads(self.auth.read_text())
        data["allowed_materials"] = [58.0]
        self.auth.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "Hard Wall"):
            runner.validate_authorization(self.auth)

    def test_no_malformed_jsonl(self):
        self.commands.write_text('{"version":1, "seq":1,\n')
        with self.assertRaises((json.JSONDecodeError, ValueError)):
            runner.validate_commands(self.commands, live=False)

    def test_requires_complete_last_jsonl_record(self):
        self.commands.write_text('{"version":1,"seq":1,"tool":"stop","args":{}}')
        with self.assertRaisesRegex(ValueError, "newline"):
            runner.validate_commands(self.commands, live=False)

    def test_maximum_batch_commands(self):
        one = {"version": 1, "seq": 1, "tool": "observe", "args": {}}
        self.commands.write_text(
            "".join(json.dumps({**one, "seq": i}) + "\n" for i in range(1, 98))
        )
        with self.assertRaisesRegex(ValueError, "1-96"):
            runner.validate_commands(self.commands, live=False)

    def test_native_runtime_pointer_is_not_executable(self):
        sample = self.root / "fake.so"
        sample.write_bytes(b"version https://git-lfs.github.com/spec/v1\n" + b"x" * 1100)
        with self.assertRaisesRegex(ValueError, "Unmaterialized"):
            runner.verify_file(sample, binary=True)

    def test_png_decodes_actual_rgba_pixels(self):
        path = self.root / "frame.png"
        make_png(path, (12, 120, 200, 255))
        w, h, pixels = verifier.decode_png(path)
        self.assertEqual((w, h, pixels), (1, 1, bytes((12, 120, 200, 255))))
        make_png(path, (13, 120, 200, 255))
        self.assertNotEqual(pixels, verifier.decode_png(path)[2])

    def test_png_tampering_is_rejected(self):
        path = self.root / "frame.png"
        make_png(path, (12, 120, 200, 255))
        data = bytearray(path.read_bytes())
        data[-18] ^= 1
        path.write_bytes(data)
        with self.assertRaises(AssertionError):
            verifier.decode_png(path)

    def test_live_mode_has_one_process_not_one_per_command(self):
        godot = self.root / "Godot"
        godot.write_text("binary placeholder", encoding="utf-8")
        invocation = runner.build_command(
            godot, self.auth, self.commands, self.root / "out", True, False
        )
        self.assertEqual(invocation.count("--script"), 1)
        self.assertIn("--live", invocation)
        self.assertTrue(any("--commands=" in value for value in invocation))


if __name__ == "__main__":
    unittest.main(verbosity=2)
