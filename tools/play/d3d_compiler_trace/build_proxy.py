#!/usr/bin/env python3
"""Build an x64, NONQUALIFYING D3DCompiler forwarding trace DLL with the Windows SDK.

No Godot launch, DLL installation, compiler replacement, or renderer configuration is
performed. Run from an x64 MSVC developer environment. The system DLL is only read.
"""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def pe_exports(path: Path) -> dict:
    raw = path.read_bytes()
    require(len(raw) >= 64 and raw[:2] == b"MZ", "not a PE file")
    pe = struct.unpack_from("<I", raw, 60)[0]
    require(pe + 24 <= len(raw) and raw[pe:pe + 4] == b"PE\0\0", "invalid PE header")
    machine, sections, stamp = struct.unpack_from("<HHI", raw, pe + 4)
    opt_size = struct.unpack_from("<H", raw, pe + 20)[0]
    opt = pe + 24
    require(machine == 0x8664 and struct.unpack_from("<H", raw, opt)[0] == 0x20B,
            "only native Windows x64 PE32+ is supported")
    require(opt_size >= 120 and opt + opt_size + sections * 40 <= len(raw), "invalid sections")
    image_size = struct.unpack_from("<I", raw, opt + 56)[0]
    export_rva, export_size = struct.unpack_from("<II", raw, opt + 112)
    require(export_rva and export_size, "missing exports")
    regions = []
    for i in range(sections):
        at = opt + opt_size + i * 40
        virtual_size, virtual_address, file_size, file_offset = struct.unpack_from("<IIII", raw, at + 8)
        characteristics = struct.unpack_from("<I", raw, at + 36)[0]
        regions.append((virtual_address, max(virtual_size, file_size), file_offset, file_size, characteristics))

    def offset(rva: int, length: int = 1) -> int:
        for start, _size, file_at, size, _flags in regions:
            if start <= rva and rva + length <= start + size:
                result = file_at + rva - start
                require(result + length <= len(raw), "truncated PE data")
                return result
        raise ValueError(f"RVA 0x{rva:x} is not file backed")

    def cstring(rva: int) -> str:
        at = offset(rva)
        end = raw.find(b"\0", at, min(len(raw), at + 4096))
        require(end >= at, "unterminated PE export string")
        return raw[at:end].decode("ascii")

    directory = offset(export_rva, 40)
    base, functions, names, eat, name_rvas, name_ordinals = struct.unpack_from("<IIIIII", raw, directory + 16)
    require(0 < functions <= 4096 and names <= 4096, "unreasonable export table")
    require(base + functions <= 65536, "ordinal exceeds GetProcAddress WORD range")
    entries = {}
    for i in range(functions):
        rva = struct.unpack_from("<I", raw, offset(eat + i * 4, 4))[0]
        if not rva:
            continue
        forwarded = export_rva <= rva < export_rva + export_size
        executable = any(start <= rva < start + size and flags & 0x20000000
                         for start, size, _at, _file_size, flags in regions)
        require(forwarded or executable, f"ordinal {base + i} appears to export data, unsupported")
        entries[i] = {"ordinal": base + i, "rva": rva, "names": [],
                      "forwarder": cstring(rva) if forwarded else None}
    for i in range(names):
        rva = struct.unpack_from("<I", raw, offset(name_rvas + i * 4, 4))[0]
        index = struct.unpack_from("<H", raw, offset(name_ordinals + i * 2, 2))[0]
        require(index in entries, "named null/missing ordinal")
        name = cstring(rva)
        require(re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", name) is not None, "unexpected decorated export")
        entries[index]["names"].append(name)
    exports = sorted(entries.values(), key=lambda item: item["ordinal"])
    require(all(len(entry["names"]) <= 1 for entry in exports), "aliased export ordinal needs explicit review")
    require({"D3DCompile", "D3DCompile2", "D3DDisassemble"}.issubset(
        {name for entry in exports for name in entry["names"]}), "required compiler exports absent")
    return {"path": str(path.resolve()), "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
            "machine": machine, "pe_timestamp": stamp, "image_size": image_size,
            "exports": exports}


def generate(original: dict, output: Path) -> None:
    exports = original["exports"]
    definitions = ["LIBRARY d3dcompiler_47", "EXPORTS"]
    assembly = ["option casemap:none", "EXTERN pace003_resolve:PROC", ".code",
                # All original register and stack arguments survive resolution.
                # Incoming RSP is 8 mod 16; 136 bytes includes 32-byte shadow space.
                "pace003_forward_common PROC FRAME", "    sub rsp, 136", "    .allocstack 136",
                "    .endprolog", "    mov [rsp+32], rcx", "    mov [rsp+40], rdx",
                "    mov [rsp+48], r8", "    mov [rsp+56], r9",
                "    movdqu [rsp+64], xmm0", "    movdqu [rsp+80], xmm1",
                "    movdqu [rsp+96], xmm2", "    movdqu [rsp+112], xmm3",
                "    mov ecx, r10d", "    call pace003_resolve",
                "    mov rcx, [rsp+32]", "    mov rdx, [rsp+40]",
                "    mov r8, [rsp+48]", "    mov r9, [rsp+56]",
                "    movdqu xmm0, [rsp+64]", "    movdqu xmm1, [rsp+80]",
                "    movdqu xmm2, [rsp+96]", "    movdqu xmm3, [rsp+112]",
                "    add rsp, 136", "    jmp rax", "pace003_forward_common ENDP"]
    for index, entry in enumerate(exports):
        name = entry["names"][0] if entry["names"] else None
        symbol = "pace003_" + name if name in {"D3DCompile", "D3DCompile2"} else f"pace003_forward_{index}"
        export_name = name or f"pace003_ordinal_{entry['ordinal']}"
        definitions.append(f"    {export_name}={symbol} @{entry['ordinal']}" + (" NONAME" if name is None else ""))
        if symbol.startswith("pace003_forward_"):
            assembly += [f"PUBLIC {symbol}", f"{symbol} PROC", f"    mov r10d, {index}", "    jmp pace003_forward_common", f"{symbol} ENDP"]
    assembly.append("END")
    header = ["// Generated from the exact native System32 DLL; do not hand edit.",
              f"static const unsigned int kExportCount = {len(exports)};",
              "static const unsigned short kExportOrdinals[] = {" + ",".join(str(e["ordinal"]) for e in exports) + "};",
              "static const char *const kExportNames[] = {" + ",".join(json.dumps(e["names"][0] if e["names"] else f"#{e['ordinal']}") for e in exports) + "};",
              "static const char kExpectedOriginalSha256[] = " + json.dumps(original["sha256"]) + ";"]
    (output / "proxy.def").write_text("\n".join(definitions) + "\n", encoding="ascii")
    (output / "proxy_forward.asm").write_text("\n".join(assembly) + "\n", encoding="ascii")
    (output / "proxy_exports.h").write_text("\n".join(header) + "\n", encoding="ascii")


def run(command: list[str], output: Path, name: str) -> None:
    try:
        result = subprocess.run(command, cwd=output, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                check=False, timeout=120)
    except subprocess.TimeoutExpired as error:
        (output / name).write_bytes(error.stdout or b"")
        (output / (name + ".timeout.json")).write_text(json.dumps({"command": command, "timeout_s": 120,
                                                                  "status": "build_process_timeout"}) + "\n")
        raise RuntimeError(f"bounded helper build timed out; original output retained in {output / name}") from error
    (output / name).write_bytes(result.stdout)
    require(result.returncode == 0, f"build failed ({result.returncode}), see {output / name}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--original", type=Path, help="read-only original, default native System32")
    parser.add_argument("--generate-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    require(not output.exists(), "output must be new; retained diagnostic evidence is never overwritten")
    output.mkdir(parents=True)
    source = Path(__file__).resolve().parent
    if args.original is None:
        require(os.name == "nt" and ctypes.sizeof(ctypes.c_void_p) == 8, "requires native Windows x64 Python")
        buffer = ctypes.create_unicode_buffer(32768)
        count = ctypes.windll.kernel32.GetSystemDirectoryW(buffer, len(buffer))
        require(0 < count < len(buffer), "GetSystemDirectoryW failed")
        args.original = Path(buffer.value, "d3dcompiler_47.dll")
    original = pe_exports(args.original.resolve())
    (output / "system-compiler-before.json").write_text(json.dumps(original, indent=2) + "\n")
    generate(original, output)
    if args.generate_only:
        print(json.dumps({"status": "generated_only", "original": original["sha256"]}))
        return
    require(os.name == "nt", "MSVC build requires Windows")
    run(["ml64.exe", "/nologo", "/c", "/Fo" + str(output / "proxy_forward.obj"), str(output / "proxy_forward.asm")], output, "assembler.log")
    run(["cl.exe", "/nologo", "/std:c++17", "/EHsc", "/W4", "/WX", "/O2", "/MT", "/LD",
         "/I" + str(output), str(source / "d3dcompiler_trace.cpp"), str(output / "proxy_forward.obj"),
         "/link", "/DEF:" + str(output / "proxy.def"), "/OUT:" + str(output / "d3dcompiler_47.dll"), "bcrypt.lib"], output, "compiler.log")
    proxy = pe_exports(output / "d3dcompiler_47.dll")
    shape = lambda item: [(entry["ordinal"], entry["names"]) for entry in item["exports"]]
    require(shape(proxy) == shape(original), "proxy export names/ordinals differ from System32 original")
    after = pe_exports(args.original.resolve())
    require(after == original, "System32 compiler changed during build")
    run(["cl.exe", "/nologo", "/std:c++17", "/EHsc", "/W4", "/WX", "/O2", "/MT",
         str(source / "proxy_preflight.cpp"), "/Fe:" + str(output / "proxy_preflight.exe")], output, "preflight-build.log")
    receipt = {"scope": "NONQUALIFYING diagnostic helper; no engine launched", "system_original": original,
               "proxy": proxy, "system_original_unchanged": after == original,
               "preflight_executed": False, "source_files": [],
               "environment": {key: os.environ.get(key) for key in ("VCToolsVersion", "WindowsSDKVersion", "VSCMD_ARG_TGT_ARCH")}}
    for path in [Path(__file__), source / "d3dcompiler_trace.cpp", source / "proxy_preflight.cpp",
                 output / "proxy.def", output / "proxy_forward.asm", output / "proxy_exports.h"]:
        data = path.read_bytes()
        receipt["source_files"].append({"path": str(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    (output / "build-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"status": "built_not_executed", "proxy": proxy["sha256"], "original": original["sha256"]}))


if __name__ == "__main__":
    main()
