#!/usr/bin/env python3
"""Attribute stripped AMD64 PE functions using matching COFF archive sections.

This does not unwind stacks or infer names from nearby exports. Callers supply
RVAs recovered by a debugger and independently verify their archive provenance.
All function bytes except actual COFF relocation fields must match.
"""

import argparse
import json
from pathlib import Path
import struct


def archive_objects(archive):
    if archive[:8] != b"!<arch>\n":
        raise ValueError("Expected a COFF archive")
    offset, names = 8, b""
    while offset < len(archive):
        header = archive[offset:offset + 60]
        size = int(header[48:58])
        name = header[:16].decode().strip()
        data = archive[offset + 60:offset + 60 + size]
        if name == "//":
            names = data
        elif name.startswith("/") and name[1:].isdigit():
            name = names[int(name[1:]):].split(b"\0")[0].split(b"/\n")[0].decode()
        if name.endswith(".o"):
            yield name, data
        offset += 60 + size + size % 2


def pe_functions(image):
    pe = struct.unpack_from("<I", image, 0x3c)[0]
    if image[pe:pe + 4] != b"PE\0\0" or struct.unpack_from("<H", image, pe + 4)[0] != 0x8664:
        raise ValueError("Expected an AMD64 PE image")
    count = struct.unpack_from("<H", image, pe + 6)[0]
    optional = pe + 24
    start = optional + struct.unpack_from("<H", image, pe + 20)[0]
    sections = [struct.unpack_from("<8sIIIIIIHHI", image, start + i * 40) for i in range(count)]

    def raw(rva):
        for _, virtual_size, virtual, size, offset, *_ in sections:
            if virtual <= rva < virtual + max(virtual_size, size):
                return offset + rva - virtual
        raise ValueError(f"Unmapped RVA {rva:#x}")

    pdata, length = struct.unpack_from("<II", image, optional + 112 + 3 * 8)
    functions = [struct.unpack_from("<III", image, raw(pdata) + i * 12) for i in range(length // 12)]
    return raw, functions


def coff_sections(data):
    big = data[:4] == b"\x00\x00\xff\xff"
    if big:
        count, symbols, symbol_count = struct.unpack_from("<III", data, 44)
        header, symbol_size = 56, 20
    else:
        count = struct.unpack_from("<H", data, 2)[0]
        symbols, symbol_count = struct.unpack_from("<II", data, 8)
        header = 20 + struct.unpack_from("<H", data, 16)[0]
        symbol_size = 18
    strings = data[symbols + symbol_count * symbol_size:]
    names, index = {}, 0
    while index < symbol_count:
        offset = symbols + index * symbol_size
        name = data[offset:offset + 8]
        if name[:4] == b"\0" * 4:
            start = struct.unpack_from("<I", name, 4)[0]
            name = strings[start:strings.find(b"\0", start)]
        else:
            name = name.split(b"\0")[0]
        value = struct.unpack_from("<I", data, offset + 8)[0]
        section = struct.unpack_from("<i" if big else "<h", data, offset + 12)[0]
        auxiliary = data[offset + symbol_size - 1]
        if section > 0 and value == 0 and not name.startswith(b"."):
            names.setdefault(section, []).append(name.decode(errors="replace"))
        index += 1 + auxiliary
    for index in range(count):
        name, _, _, size, offset, relocations, _, relocation_count, _, _ = struct.unpack_from("<8sIIIIIIHHI", data, header + index * 40)
        if name.startswith(b".text") and size >= 16:
            yield index + 1, data[offset:offset + size], names.get(index + 1, []), relocations, relocation_count


def match_functions(archive, image, rvas):
    raw, functions = pe_functions(image)
    targets = {rva: next((f for f in functions if f[0] <= rva < f[1]), None) for rva in rvas}
    result = {hex(rva): {"begin": hex(f[0]), "end": hex(f[1]), "matches": []}
              for rva, f in targets.items() if f}
    for object_name, data in archive_objects(archive):
        for section, code, names, relocations, count in coff_sections(data):
            for rva, function in targets.items():
                if function is None:
                    continue
                start, end, _ = function
                candidate = image[raw(start):raw(start) + min(len(code), end - start)]
                # Leave possible linker-rewritten prefixes unattributed. An
                # exact three-byte filter avoids parsing unrelated sections;
                # the complete comparison below still checks every fixed byte.
                if code[:3] != candidate[:3]:
                    continue
                ignored = set()
                for i in range(count):
                    position, _, kind = struct.unpack_from("<IIH", data, relocations + i * 10)
                    if kind == 0:  # IMAGE_REL_AMD64_ABSOLUTE, no relocation.
                        continue
                    if kind not in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11):
                        raise ValueError(f"Unsupported AMD64 relocation type {kind}")
                    width = 8 if kind == 1 else 2 if kind == 10 else 4
                    ignored.update(range(position, position + width))
                length = min(len(code), len(candidate))
                if length >= 16 and all(code[i] == candidate[i] for i in range(length) if i not in ignored):
                    result[hex(rva)]["matches"].append({
                        "object": object_name, "section": section, "names": names,
                        "verified_bytes": length, "relocation_bytes": sum(i < length for i in ignored),
                    })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--dll", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("rvas", nargs="+", type=lambda value: int(value, 0))
    args = parser.parse_args()
    result = match_functions(args.archive.read_bytes(), args.dll.read_bytes(), args.rvas)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    for rva, record in result.items():
        print(rva, record["begin"], [(m["names"], m["verified_bytes"]) for m in record["matches"]])


if __name__ == "__main__":
    main()
