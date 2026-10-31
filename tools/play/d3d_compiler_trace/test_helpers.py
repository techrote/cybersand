#!/usr/bin/env python3
"""Parser/receipt regressions; synthetic bytes never count as driver evidence."""
import json
from pathlib import Path
import struct
import tempfile
import unittest

import build_proxy
import readback


def pe_fixture() -> bytes:
    raw = bytearray(0x800)
    raw[:2] = b"MZ"
    struct.pack_into("<I", raw, 0x3C, 0x80)
    raw[0x80:0x84] = b"PE\0\0"
    struct.pack_into("<HHI", raw, 0x84, 0x8664, 2, 12345)
    struct.pack_into("<H", raw, 0x94, 0xF0)
    struct.pack_into("<H", raw, 0x98, 0x20B)
    struct.pack_into("<I", raw, 0x98 + 56, 0x3000)
    struct.pack_into("<I", raw, 0x98 + 108, 16)
    struct.pack_into("<II", raw, 0x98 + 112, 0x2000, 0x100)
    text = 0x98 + 0xF0
    struct.pack_into("<IIII", raw, text + 8, 0x200, 0x1000, 0x200, 0x200)
    struct.pack_into("<I", raw, text + 36, 0x60000020)
    struct.pack_into("<IIII", raw, text + 48, 0x400, 0x2000, 0x400, 0x400)
    struct.pack_into("<I", raw, text + 76, 0x40000040)
    struct.pack_into("<IIIIII", raw, 0x410, 1, 3, 3, 0x2028, 0x2034, 0x2040)
    struct.pack_into("<III", raw, 0x428, 0x1000, 0x1010, 0x1020)
    offset = 0x450
    for i, name in enumerate((b"D3DCompile", b"D3DCompile2", b"D3DDisassemble")):
        struct.pack_into("<I", raw, 0x434 + 4 * i, offset + 0x1C00)
        struct.pack_into("<H", raw, 0x440 + 2 * i, i)
        raw[offset:offset + len(name) + 1] = name + b"\0"
        offset += len(name) + 1
    return bytes(raw)


class Helpers(unittest.TestCase):
    def test_original_exports_and_generation(self):
        with tempfile.TemporaryDirectory() as name:
            output = Path(name)
            path = output / "original.dll"
            path.write_bytes(pe_fixture())
            result = build_proxy.pe_exports(path)
            self.assertEqual([item["names"] for item in result["exports"]], [["D3DCompile"], ["D3DCompile2"], ["D3DDisassemble"]])
            build_proxy.generate(result, output)
            self.assertIn("D3DCompile=pace003_D3DCompile @1", (output / "proxy.def").read_text())
            self.assertIn("D3DDisassemble=pace003_forward_2 @3", (output / "proxy.def").read_text())

    def test_reject_non_executable_export(self):
        with tempfile.TemporaryDirectory() as name:
            path = Path(name, "original.dll")
            raw = bytearray(pe_fixture())
            struct.pack_into("<I", raw, 0x98 + 0xF0 + 36, 0x40000040)
            path.write_bytes(raw)
            with self.assertRaisesRegex(ValueError, "export data"):
                build_proxy.pe_exports(path)

    def test_reject_wrong_arch(self):
        with tempfile.TemporaryDirectory() as name:
            path = Path(name, "original.dll")
            raw = bytearray(pe_fixture())
            struct.pack_into("<H", raw, 0x84, 0x14C)
            path.write_bytes(raw)
            with self.assertRaisesRegex(ValueError, "x64"):
                build_proxy.pe_exports(path)

    def fixture(self, directory):
        source = b"// synthetic parser fixture only\nfloat4 m_material_colour;\n"
        source_name = "d3d-17-1-source.hlsl"
        Path(directory, source_name).write_bytes(source)
        field = lambda value: {"value": value, "truncated": False}
        manifest = {"system_original": {"path": "C:\\Windows\\System32\\d3dcompiler_47.dll", "sha256": "a" * 64,
                                        "image_size": 4096, "exports": [{}, {}, {}]}, "proxy": {"sha256": "b" * 64}}
        events = [
            {"event_index": 1, "event": "identity", "pid": 17, "tid": 18, "system_sha256": "a" * 64,
             "expected_system_sha256": "a" * 64, "proxy_sha256": "b" * 64,
             "system_module": manifest["system_original"]["path"], "proxy_module": "D:\\diagnostic\\d3dcompiler_47.dll",
             "exports_forwarded": 3, "system_module_base": 10000, "d3dcompile_address": 10001, "d3dcompile2_address": 10002},
            {"event_index": 2, "event": "compile_begin", "pid": 17, "tid": 18, "call": 1, "api": "D3DCompile",
             "source": {"complete": True, "file": source_name, "bytes": len(source), "written": len(source)},
             "source_name": field("synthetic"), "entry": field("main"), "target": field("ps_5_0"), "flags1": 49152,
             "flags2": 0, "include_pointer_present": False, "defines": [], "defines_truncated": False, "begin_qpc": 1},
        ]
        return manifest, events

    def write(self, directory, events):
        Path(directory, "d3d-trace-17.jsonl").write_text("".join(json.dumps(event) + "\n" for event in events))

    def test_timeout_retains_open_call_without_faking_completion(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, events = self.fixture(directory)
            self.write(directory, events)
            report = readback.inspect(Path(directory), manifest)
            self.assertEqual(report["processes"][0]["open_call_ids"], [1])
            self.assertFalse(report["processes"][0]["calls"][0]["completed"])
            self.assertIsNone(report["processes"][0]["calls"][0]["wall_s"])

    def test_reject_wrong_proxy_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, events = self.fixture(directory)
            events[0]["proxy_sha256"] = "c" * 64
            self.write(directory, events)
            with self.assertRaisesRegex(ValueError, "proxy SHA"):
                readback.inspect(Path(directory), manifest)

    def test_reject_truncated_source(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, events = self.fixture(directory)
            Path(directory, events[1]["source"]["file"]).write_bytes(b"truncated")
            self.write(directory, events)
            with self.assertRaisesRegex(ValueError, "byte count"):
                readback.inspect(Path(directory), manifest)

    def test_reject_outside_system_image_target(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, events = self.fixture(directory)
            events[0]["d3dcompile_address"] = 9999
            self.write(directory, events)
            with self.assertRaisesRegex(ValueError, "outside authentic"):
                readback.inspect(Path(directory), manifest)

    def test_retain_failed_compile_hresult(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, events = self.fixture(directory)
            events.append({"event_index": 3, "event": "compile_end", "pid": 17, "tid": 18, "call": 1,
                           "call_start_qpc": 2, "call_end_qpc": 3, "logging_errors": 0, "dropped_events": 0,
                           "skipped_captures": 0, "wall_s": 0.1, "thread_cpu_s": 0.09, "hresult": 2147500037})
            self.write(directory, events)
            report = readback.inspect(Path(directory), manifest)
            self.assertEqual(report["processes"][0]["calls"][0]["hresult"], 2147500037)


if __name__ == "__main__":
    unittest.main()
