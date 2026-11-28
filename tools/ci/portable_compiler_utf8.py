"""Install and verify the bounded UTF-8 Fusion manifest for pinned MinGW tools.

This is a candidate packaging correction for the exact GNU 14.2 toolchain
admitted by the PUBPRES evaluator. ``prepare`` may only mutate a copied
toolchain root; it refuses the known developer installation at C:\\mingw64.
The function preserves every non-target resource and proves all non-resource
PE section bytes remain identical. This does not itself qualify Materials Lab
authoring: the actual extracted authoring witness remains required.
"""
from __future__ import annotations

import ctypes
from ctypes import wintypes
import hashlib
import json
import mmap
import os
from pathlib import Path
import re
import struct
import subprocess
import xml.etree.ElementTree as ET

SCHEMA = "cybersand.portable-compiler-utf8-v1"
RECEIPT_NAME = "CYBERSAND-COMPILER-UTF8.json"
FAILURE_RECEIPT_NAME = "CYBERSAND-COMPILER-UTF8-FAILURE.json"
RT_MANIFEST = 24
CREATEPROCESS_MANIFEST_RESOURCE_ID = 1
ASSEMBLY_NS = "urn:schemas-microsoft-com:asm.v1"
ASSEMBLY_V3_NS = "urn:schemas-microsoft-com:asm.v3"
WINDOWS_SETTINGS_NS = "http://schemas.microsoft.com/SMI/2019/WindowsSettings"
UTF8_CODEPAGE = "UTF-8"
REFERENCE_SOURCE = {
    "manifest": "PUBPRES-MAINLINE-EVALUATOR.json",
    "sha256": "3384839616bdced47a97c67811b0b31269fd2410d50d146a508aa994466daef6",
    "source_commit": "65f71aaf4be3a67896bafac7f5220a0cb25a8fb7",
    "source_tree": "f6b7b8d3d613b70cdcdf3643fb906934b3887173",
}

# Paths relative to the copied dependencies/cxx root. The aliases intentionally
# remain separate manifest targets even when their original bytes are equal.
CORE_EXECUTABLE_SHA256 = {
    "bin/as.exe": "41128b74f89f251cfc138e4bc33896929d389bdb78d9f40fd3190d44a9953f82",
    "bin/c++.exe": "eccc5963340f7b57805b3750efc182c25c6d4eddb828c8cee2b0f974a0d943ac",
    "bin/cc.exe": "09004a692e2e60dc8dc74db053e6a9e14da98a055277d986c66cd87940300263",
    "bin/g++.exe": "eccc5963340f7b57805b3750efc182c25c6d4eddb828c8cee2b0f974a0d943ac",
    "bin/gcc.exe": "09004a692e2e60dc8dc74db053e6a9e14da98a055277d986c66cd87940300263",
    "bin/ld.exe": "bb85d4d163e876eb7121d13579020105be0d8d477cd83fc77407e142f5083b64",
    "bin/x86_64-w64-mingw32-c++.exe": "eccc5963340f7b57805b3750efc182c25c6d4eddb828c8cee2b0f974a0d943ac",
    "bin/x86_64-w64-mingw32-g++.exe": "eccc5963340f7b57805b3750efc182c25c6d4eddb828c8cee2b0f974a0d943ac",
    "bin/x86_64-w64-mingw32-gcc-14.2.0.exe": "09004a692e2e60dc8dc74db053e6a9e14da98a055277d986c66cd87940300263",
    "bin/x86_64-w64-mingw32-gcc.exe": "09004a692e2e60dc8dc74db053e6a9e14da98a055277d986c66cd87940300263",
    "libexec/gcc/x86_64-w64-mingw32/14.2.0/cc1.exe": "defbaf988d2f07bbacdf6144dea2f8c30d8d8fb5a81e5dba02282d02ec3eda8f",
    "libexec/gcc/x86_64-w64-mingw32/14.2.0/cc1plus.exe": "95d851f25039bb50391b3eccb0796835805325bcd8f790044d55c6ca7ba121ec",
    "libexec/gcc/x86_64-w64-mingw32/14.2.0/collect2.exe": "075426ea8f98522afda91aa319494d65ed7fa64841598c58289b4536797cb318",
    "x86_64-w64-mingw32/bin/as.exe": "41128b74f89f251cfc138e4bc33896929d389bdb78d9f40fd3190d44a9953f82",
    "x86_64-w64-mingw32/bin/ld.exe": "bb85d4d163e876eb7121d13579020105be0d8d477cd83fc77407e142f5083b64",
}


class CompilerMetadataError(RuntimeError):
    """The staged compiler differs from the registered PE/resource contract."""


def _need(condition: bool, message: str) -> None:
    if not condition:
        raise CompilerMetadataError(message)


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _canonical(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def _write_atomic(path: Path, value: object) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(_canonical(value))
    os.replace(temporary, path)


def _tag_namespace(tag: str) -> str:
    if not isinstance(tag, str):
        return ""
    return tag[1:].split("}", 1)[0] if tag.startswith("{") else ""


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1] if isinstance(tag, str) else ""


def _qname(namespace: str, name: str) -> str:
    return "{" + namespace + "}" + name if namespace else name


def _manifest_parser() -> ET.XMLParser:
    return ET.XMLParser(target=ET.TreeBuilder(insert_comments=True, insert_pis=True))


def _tree_manifest(data: bytes) -> ET.Element:
    _need(data and b"\x00" not in data.rstrip(b"\x00"), "Manifest contains an embedded NUL")
    raw = data.rstrip(b"\x00")
    _need(not re.search(br"<!\s*DOCTYPE\b", raw, re.IGNORECASE), "Refuse a DTD-bearing compiler manifest")
    try:
        root = ET.fromstring(raw, parser=_manifest_parser())
    except ET.ParseError as error:
        raise CompilerMetadataError("Compiler manifest is not valid XML: " + str(error)) from error
    _need(_local_name(root.tag) == "assembly", "Compiler manifest root is not Fusion assembly")
    return root


def _manifest_has_utf8(data: bytes) -> bool:
    root = _tree_manifest(data)
    if _tag_namespace(root.tag) != ASSEMBLY_NS:
        return False
    matches = [element for element in root.iter() if _local_name(element.tag) == "activeCodePage"]
    eligible = []
    for application in list(root):
        if (not isinstance(application.tag, str) or _local_name(application.tag) != "application"
                or _tag_namespace(application.tag) not in (ASSEMBLY_NS, ASSEMBLY_V3_NS)):
            continue
        for settings in list(application):
            if (not isinstance(settings.tag, str) or _local_name(settings.tag) != "windowsSettings"
                    or _tag_namespace(settings.tag) != _tag_namespace(application.tag)):
                continue
            eligible.extend(child for child in list(settings)
                            if child.tag == _qname(WINDOWS_SETTINGS_NS, "activeCodePage"))
    return (len(matches) == 1 and len(eligible) == 1 and matches[0] is eligible[0]
            and (eligible[0].text or "").strip().upper() == UTF8_CODEPAGE)


def _transform_manifest(data: bytes) -> tuple[bytes, dict]:
    """Add UTF-8 activeCodePage while preserving every existing XML node/attr.

    A conflicting or ambiguous activeCodePage is refused. The transform is
    idempotent for an already-correct manifest and keeps comments/PIs.
    """
    original = data.rstrip(b"\x00")
    root = _tree_manifest(data)
    active = [element for element in root.iter() if _local_name(element.tag) == "activeCodePage"]
    if active:
        _need(len(active) == 1 and active[0].tag == _qname(WINDOWS_SETTINGS_NS, "activeCodePage")
              and _manifest_has_utf8(original),
              "Compiler manifest has an unexpected or duplicate activeCodePage declaration")
        return original, {"changed": False, "active_code_page": UTF8_CODEPAGE,
                          "original_sha256": _sha_bytes(original), "output_sha256": _sha_bytes(original)}

    _need(_tag_namespace(root.tag) == ASSEMBLY_NS,
          "Compiler manifest uses an unexpected Fusion assembly namespace")
    applications = [child for child in list(root)
                    if isinstance(child.tag, str) and _local_name(child.tag) == "application"]
    _need(len(applications) <= 1, "Compiler manifest has ambiguous application nodes")
    if applications:
        application = applications[0]
        _need(_tag_namespace(application.tag) in (ASSEMBLY_NS, ASSEMBLY_V3_NS),
              "Compiler manifest application node uses an unexpected namespace")
    else:
        application = ET.SubElement(root, _qname(ASSEMBLY_V3_NS, "application"))
    app_ns = _tag_namespace(application.tag)
    settings_nodes = [child for child in list(application)
                      if isinstance(child.tag, str) and _local_name(child.tag) == "windowsSettings"]
    _need(len(settings_nodes) <= 1, "Compiler manifest has ambiguous windowsSettings nodes")
    if settings_nodes:
        settings = settings_nodes[0]
        _need(_tag_namespace(settings.tag) == app_ns,
              "Compiler manifest windowsSettings namespace differs from its application node")
    else:
        settings = ET.SubElement(application, _qname(app_ns or ASSEMBLY_V3_NS, "windowsSettings"))
    ET.SubElement(settings, _qname(WINDOWS_SETTINGS_NS, "activeCodePage")).text = UTF8_CODEPAGE

    # ElementTree preserves namespace URIs and all element/attribute data while
    # assigning stable prefixes. Existing XML declarations are kept in place;
    # RT_MANIFEST data is written as UTF-8 as required by the Fusion format.
    ET.register_namespace("", ASSEMBLY_NS)
    ET.register_namespace("asmv3", ASSEMBLY_V3_NS)
    ET.register_namespace("ws", WINDOWS_SETTINGS_NS)
    has_declaration = original.lstrip(b"\xef\xbb\xbf \t\r\n").startswith(b"<?xml")
    output = ET.tostring(root, encoding="utf-8", xml_declaration=has_declaration,
                         short_empty_elements=True)
    # Preserve an optional standalone declaration; no other declaration fields
    # affect the parsed manifest tree.
    declaration = re.match(br"\s*<\?xml\s+[^?]*\?>", original)
    if declaration and re.search(br"\bstandalone\s*=", declaration.group(0), re.IGNORECASE):
        standalone = re.search(br"\bstandalone\s*=\s*(['\"])(.*?)\1", declaration.group(0), re.IGNORECASE)
        if standalone:
            output = re.sub(br"\?>", b' standalone="' + standalone.group(2) + b'"?>', output, count=1)
    _need(_manifest_has_utf8(output), "Transformed compiler manifest failed UTF-8 readback")
    return output, {"changed": True, "active_code_page": UTF8_CODEPAGE,
                    "original_sha256": _sha_bytes(original), "output_sha256": _sha_bytes(output)}


def _rva_to_offset(rva: int, length: int, sections: list[dict], *, what: str) -> int:
    for section in sections:
        start = section["virtual_address"]
        span = max(section["virtual_size"], section["raw_size"])
        delta = rva - start
        if 0 <= delta < span and delta + length <= section["raw_size"]:
            return section["raw_pointer"] + delta
    raise CompilerMetadataError(f"PE {what} RVA is not backed by file data")


def _decode_resource_name(data: bytes, base: int, relative: int, limit: int) -> tuple[str, object]:
    offset = base + relative
    _need(relative + 2 <= limit, "PE resource name length lies outside resource directory")
    units = struct.unpack_from("<H", data, offset)[0]
    length = units * 2
    _need(relative + 2 + length <= limit, "PE resource name lies outside resource directory")
    try:
        value = data[offset + 2:offset + 2 + length].decode("utf-16le")
    except UnicodeDecodeError as error:
        raise CompilerMetadataError("PE resource name is invalid UTF-16") from error
    return ("name", value)


def _pe_inspect_bytes(data: bytes) -> dict:
    """Read PE sections, signature directory, and every leaf resource cross-platform."""
    _need(len(data) >= 0x40 and data[:2] == b"MZ", "Compiler input is not a PE image")
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    _need(pe_offset + 24 <= len(data) and data[pe_offset:pe_offset + 4] == b"PE\0\0",
          "Compiler input has an invalid PE signature")
    coff = pe_offset + 4
    section_count = struct.unpack_from("<H", data, coff + 2)[0]
    optional_size = struct.unpack_from("<H", data, coff + 16)[0]
    optional = coff + 20
    _need(optional + optional_size <= len(data), "PE optional header is truncated")
    magic = struct.unpack_from("<H", data, optional)[0]
    if magic == 0x10B:
        directory_count_offset, directories_offset = optional + 92, optional + 96
    elif magic == 0x20B:
        directory_count_offset, directories_offset = optional + 108, optional + 112
    else:
        raise CompilerMetadataError("Compiler input has unsupported PE optional-header magic")
    directory_count = struct.unpack_from("<I", data, directory_count_offset)[0]
    _need(optional_size >= directories_offset - optional, "PE data directory table is truncated")
    _need(directory_count >= 5 and directories_offset + 5 * 8 <= optional + optional_size,
          "PE image omits resource or certificate directories")
    resource_rva, resource_size = struct.unpack_from("<II", data, directories_offset + 2 * 8)
    certificate_offset, certificate_size = struct.unpack_from("<II", data, directories_offset + 4 * 8)
    sections_offset = optional + optional_size
    section_headers = sections_offset + section_count * 40
    _need(section_headers <= len(data), "PE section table is truncated")
    sections: list[dict] = []
    for index in range(section_count):
        offset = sections_offset + index * 40
        name = data[offset:offset + 8].split(b"\0", 1)[0].decode("ascii", errors="replace")
        virtual_size, virtual_address, raw_size, raw_pointer = struct.unpack_from("<IIII", data, offset + 8)
        characteristics = struct.unpack_from("<I", data, offset + 36)[0]
        _need(raw_pointer + raw_size <= len(data), f"PE section {name!r} extends beyond file")
        sections.append({"index": index, "name": name, "virtual_size": virtual_size,
                         "virtual_address": virtual_address, "raw_size": raw_size,
                         "raw_pointer": raw_pointer, "characteristics": characteristics,
                         "sha256": _sha_bytes(data[raw_pointer:raw_pointer + raw_size])})
    resource_section = None
    if resource_rva or resource_size:
        _need(resource_rva > 0 and resource_size > 0, "PE resource directory has incomplete bounds")
        resource_offset = _rva_to_offset(resource_rva, resource_size, sections, what="resource directory")
        for section in sections:
            if section["raw_pointer"] <= resource_offset < section["raw_pointer"] + section["raw_size"]:
                resource_section = section["index"]
                _need(not (section["characteristics"] & 0x20000000),
                      "PE resource section is executable; refuse compiler metadata update")
                break
        _need(resource_section is not None, "PE resources are not inside a PE section")
    resources: dict[str, dict] = {}
    resource_data_entries: dict[str, int] = {}
    if resource_rva:
        resource_base = _rva_to_offset(resource_rva, min(resource_size, 16), sections,
                                       what="resource directory")
        visited: set[int] = set()

        def walk(relative: int, path: tuple[tuple[str, object], ...]) -> None:
            _need(relative not in visited, "PE resource directory is cyclic or aliased")
            visited.add(relative)
            _need(relative + 16 <= resource_size, "PE resource directory header is truncated")
            header = resource_base + relative
            named, ids = struct.unpack_from("<HH", data, header + 12)
            count = named + ids
            _need(relative + 16 + count * 8 <= resource_size, "PE resource directory entries are truncated")
            for index in range(count):
                name_field, target_field = struct.unpack_from("<II", data, header + 16 + index * 8)
                component = _decode_resource_name(data, resource_base, name_field & 0x7FFFFFFF,
                                                  resource_size) if name_field & 0x80000000 \
                    else ("id", name_field & 0xFFFF)
                child_relative = target_field & 0x7FFFFFFF
                child_path = path + (component,)
                if target_field & 0x80000000:
                    walk(child_relative, child_path)
                    continue
                _need(child_relative + 16 <= resource_size, "PE resource data entry is truncated")
                leaf = resource_base + child_relative
                data_rva, size, codepage, reserved = struct.unpack_from("<IIII", data, leaf)
                file_offset = _rva_to_offset(data_rva, size, sections, what="resource data")
                key = "/".join((kind + ":" + str(value)) for kind, value in child_path)
                _need(key not in resources, "PE resource tree repeats a resource leaf")
                resource_bytes = data[file_offset:file_offset + size]
                resources[key] = {"path": [[kind, value] for kind, value in child_path],
                                  "bytes": size, "sha256": _sha_bytes(resource_bytes),
                                  "codepage": codepage, "reserved": reserved}
                resource_data_entries[key] = leaf
                if len(child_path) == 3 and child_path[0] == ("id", RT_MANIFEST) \
                        and child_path[1] == ("id", CREATEPROCESS_MANIFEST_RESOURCE_ID):
                    try:
                        resources[key]["active_code_page_utf8"] = _manifest_has_utf8(resource_bytes)
                    except CompilerMetadataError:
                        resources[key]["active_code_page_utf8"] = False

        walk(0, ())
    nonresource_sections = []
    for section in sections:
        if section["index"] == resource_section:
            continue
        nonresource_sections.append({key: section[key] for key in
                                     ("name", "virtual_size", "virtual_address", "raw_size",
                                      "characteristics", "sha256")})
    return {"machine": struct.unpack_from("<H", data, coff)[0],
            "pe32_plus": magic == 0x20B,
            "pe_checksum": struct.unpack_from("<I", data, optional + 64)[0],
            "certificate_table_present": bool(certificate_offset or certificate_size),
            "resource_rva": resource_rva, "resource_size": resource_size,
            "resource_section_index": resource_section,
            "resources": resources, "resource_data_entries": resource_data_entries,
            "sections": sections,
            "nonresource_sections": nonresource_sections,
            "nonresource_sections_sha256": _sha_bytes(_canonical(nonresource_sections))}


def _pe_header_diagnostics(data: bytes) -> dict:
    """Return bounded PE header and data-directory facts for failure evidence."""
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    coff = pe_offset + 4
    machine, sections, timestamp, symbol_table, symbol_count, optional_size, characteristics = \
        struct.unpack_from("<HHIIIHH", data, coff)
    optional = coff + 20
    magic = struct.unpack_from("<H", data, optional)[0]
    is_plus = magic == 0x20B
    directory_count_offset = optional + (108 if is_plus else 92)
    directories_offset = optional + (112 if is_plus else 96)
    directory_count = struct.unpack_from("<I", data, directory_count_offset)[0]
    def u16(offset: int) -> int:
        return struct.unpack_from("<H", data, optional + offset)[0]
    def u32(offset: int) -> int:
        return struct.unpack_from("<I", data, optional + offset)[0]
    def u64(offset: int) -> int:
        return struct.unpack_from("<Q", data, optional + offset)[0]
    fields = {
        "magic": magic,
        "linker_version": [data[optional + 2], data[optional + 3]],
        "size_of_code": u32(4),
        "size_of_initialized_data": u32(8),
        "size_of_uninitialized_data": u32(12),
        "address_of_entry_point": u32(16),
        "base_of_code": u32(20),
        "image_base": u64(24) if is_plus else u32(28),
        "section_alignment": u32(32),
        "file_alignment": u32(36),
        "os_version": [u16(40), u16(42)],
        "image_version": [u16(44), u16(46)],
        "subsystem_version": [u16(48), u16(50)],
        "win32_version_value": u32(52),
        "size_of_image": u32(56),
        "size_of_headers": u32(60),
        "checksum": u32(64),
        "subsystem": u16(68),
        "dll_characteristics": u16(70),
        "stack_reserve": u64(72) if is_plus else u32(72),
        "stack_commit": u64(80) if is_plus else u32(76),
        "heap_reserve": u64(88) if is_plus else u32(80),
        "heap_commit": u64(96) if is_plus else u32(84),
        "loader_flags": u32(104 if is_plus else 88),
        "number_of_rva_and_sizes": directory_count,
    }
    directory_names = ("export", "import", "resource", "exception", "security", "base_relocation",
                       "debug", "architecture", "global_pointer", "tls", "load_config", "bound_import",
                       "iat", "delay_import", "clr", "reserved")
    directories = {}
    for index, name in enumerate(directory_names[:min(directory_count, len(directory_names))]):
        rva, size = struct.unpack_from("<II", data, directories_offset + index * 8)
        directories[name] = {"rva_or_file_offset": rva, "size": size}
    return {"pe_offset": pe_offset,
            "coff": {"machine": machine, "number_of_sections": sections,
                     "timestamp": timestamp, "pointer_to_symbol_table": symbol_table,
                     "number_of_symbols": symbol_count, "size_of_optional_header": optional_size,
                     "characteristics": characteristics},
            "optional_header": fields, "data_directories": directories}


def _bounded_byte_diff(before: bytes, after: bytes, *, max_ranges: int = 32,
                       sample_bytes: int = 48) -> dict:
    """Describe changed spans without retaining executable contents."""
    common = min(len(before), len(after))
    first: list[dict] = []
    tail: list[dict] = []
    first_capacity = max_ranges // 2
    tail_capacity = max_ranges - first_capacity
    range_count = 0
    changed_bytes = 0
    first_offset = None
    last_end = None
    index = 0
    while index < common:
        if before[index] == after[index]:
            index += 1
            continue
        start = index
        while index < common and before[index] != after[index]:
            index += 1
        old_chunk, new_chunk = before[start:index], after[start:index]
        changed_bytes += sum(left != right for left, right in zip(old_chunk, new_chunk))
        record = {"offset_start": start, "offset_end_exclusive": index,
                  "before_length": len(old_chunk), "after_length": len(new_chunk),
                  "before_sha256": _sha_bytes(old_chunk), "after_sha256": _sha_bytes(new_chunk),
                  "before_sample_hex": old_chunk[:sample_bytes].hex(),
                  "after_sample_hex": new_chunk[:sample_bytes].hex()}
        if first_offset is None:
            first_offset = start
        last_end = index
        range_count += 1
        if len(first) < first_capacity:
            first.append(record)
        elif tail_capacity:
            tail.append(record)
            if len(tail) > tail_capacity:
                del tail[0]
    if len(before) != len(after):
        start = common
        old_chunk, new_chunk = before[start:], after[start:]
        changed_bytes += max(len(old_chunk), len(new_chunk))
        record = {"offset_start": start, "offset_end_exclusive": max(len(before), len(after)),
                  "before_length": len(old_chunk), "after_length": len(new_chunk),
                  "before_sha256": _sha_bytes(old_chunk), "after_sha256": _sha_bytes(new_chunk),
                  "before_sample_hex": old_chunk[:sample_bytes].hex(),
                  "after_sample_hex": new_chunk[:sample_bytes].hex()}
        if first_offset is None:
            first_offset = start
        last_end = max(len(before), len(after))
        range_count += 1
        if len(first) < first_capacity:
            first.append(record)
        elif tail_capacity:
            tail.append(record)
            if len(tail) > tail_capacity:
                del tail[0]
    ranges = first + tail
    return {"before_length": len(before), "after_length": len(after),
            "changed_byte_count": changed_bytes, "changed_range_count": range_count,
            "first_changed_offset": first_offset,
            "last_changed_offset": None if last_end is None else last_end - 1,
            "omitted_range_count": max(0, range_count - len(ranges)), "ranges": ranges}


def _section_diff_detail(before_data: bytes, after_data: bytes,
                         before_section: dict, after_section: dict) -> dict:
    before_chunk = before_data[before_section["raw_pointer"]:
                               before_section["raw_pointer"] + before_section["raw_size"]]
    after_chunk = after_data[after_section["raw_pointer"]:
                             after_section["raw_pointer"] + after_section["raw_size"]]
    diff = _bounded_byte_diff(before_chunk, after_chunk)
    for item in diff["ranges"]:
        item["before_file_offset_start"] = before_section["raw_pointer"] + item["offset_start"]
        item["after_file_offset_start"] = after_section["raw_pointer"] + item["offset_start"]
    return {"before_virtual_zero_fill_bytes": max(0, before_section["virtual_size"] - before_section["raw_size"]),
            "after_virtual_zero_fill_bytes": max(0, after_section["virtual_size"] - after_section["raw_size"]),
            "before_raw_padding_bytes": max(0, before_section["raw_size"] - before_section["virtual_size"]),
            "after_raw_padding_bytes": max(0, after_section["raw_size"] - after_section["virtual_size"]),
            "raw_byte_diff": diff}


def _section_mismatch_diagnostic(relative: str, before_data: bytes, after_data: bytes,
                                 before: dict, after_api: dict, after: dict) -> dict:
    before_sections = before["sections"]
    after_sections = after["sections"]
    changed_sections = []
    for index in range(max(len(before_sections), len(after_sections))):
        old = before_sections[index] if index < len(before_sections) else None
        new = after_sections[index] if index < len(after_sections) else None
        if old == new:
            continue
        changed_fields = {}
        if old is not None and new is not None:
            for field in ("name", "virtual_size", "virtual_address", "raw_size", "raw_pointer",
                          "characteristics", "sha256"):
                if old.get(field) != new.get(field):
                    changed_fields[field] = {"before": old.get(field), "after": new.get(field)}
            raw_detail = _section_diff_detail(before_data, after_data, old, new)
        else:
            raw_detail = None
            changed_fields["section_population"] = {"before": old, "after": new}
        changed_sections.append({"index": index, "before": old, "after": new,
                                 "changed_fields": changed_fields, "raw_diff": raw_detail})

    old_non_target = {key: row for key, row in before["resources"].items()
                      if not _is_target_resource(row)}
    new_non_target = {key: row for key, row in after["resources"].items()
                      if not _is_target_resource(row)}
    old_targets = {key: row for key, row in before["resources"].items()
                   if _is_target_resource(row)}
    new_targets = {key: row for key, row in after["resources"].items()
                   if _is_target_resource(row)}
    old_header = _pe_header_diagnostics(before_data)
    new_header = _pe_header_diagnostics(after_data)
    header_changes = {key: {"before": old_header.get(key), "after": new_header.get(key)}
                      for key in old_header if old_header.get(key) != new_header.get(key)}
    old_header_size = old_header["optional_header"]["size_of_headers"]
    new_header_size = new_header["optional_header"]["size_of_headers"]
    resource_changes = []
    for key in sorted(set(old_non_target) | set(new_non_target)):
        old = old_non_target.get(key)
        new = new_non_target.get(key)
        if old != new:
            resource_changes.append({"key": key, "before": old, "after": new})
    return {"schema": "cybersand.portable-compiler-utf8-failure-v1",
            "failure": "non-resource PE section identity changed",
            "stage": "portable GNU resource metadata preparation",
            "binary_relative_path": relative,
            "registered_original_sha256": CORE_EXECUTABLE_SHA256[relative],
            "before_sha256": _sha_bytes(before_data),
            "after_sha256": _sha_bytes(after_data),
            "before_file_size": len(before_data), "after_file_size": len(after_data),
            "before_sections": before_sections, "after_sections": after_sections,
            "changed_sections": changed_sections,
            "changed_nonresource_sections": [row for row in changed_sections
                                             if (row["index"] != before.get("resource_section_index")
                                                 and row["index"] != after.get("resource_section_index"))],
            "pe_headers_before": old_header, "pe_headers_after": new_header,
            "pe_header_changed_fields": header_changes,
            "pe_header_raw_diff": _bounded_byte_diff(before_data[:old_header_size],
                                                     after_data[:new_header_size]),
            "whole_file_raw_diff": _bounded_byte_diff(before_data, after_data),
            "resource_api_section_metadata": {
                "after_update_resource_before_metadata_repair": after_api["sections"],
                "after_metadata_repair": after["sections"]},
            "resource_preservation": {
                "before_non_target_resources": old_non_target,
                "after_non_target_resources": new_non_target,
                "non_target_resources_exact": old_non_target == new_non_target,
                "changed_non_target_resources": resource_changes,
                "before_target_manifests": old_targets,
                "after_target_manifests": new_targets,
                "before_resource_count": len(before["resources"]),
                "after_resource_count": len(after["resources"])}}


def inspect_pe(path: Path) -> dict:
    data = path.read_bytes()
    return {"file_sha256": _sha_bytes(data), **_pe_inspect_bytes(data)}


def _manifest_targets(pe: dict) -> list[tuple[int, bytes]]:
    result: list[tuple[int, bytes]] = []
    for item in pe["resources"].values():
        parts = item["path"]
        if len(parts) == 3 and parts[0] == ["id", RT_MANIFEST] \
                and parts[1] == ["id", CREATEPROCESS_MANIFEST_RESOURCE_ID] \
                and isinstance(parts[2][1], int):
            # Resource data itself is read by _resource_bytes below.
            result.append((parts[2][1], b""))
    return result


def _resource_bytes(data: bytes, resource_key: str) -> bytes:
    pe = _pe_inspect_bytes(data)
    for item in pe["resources"].values():
        parts = item["path"]
        key = "/".join(kind + ":" + str(value) for kind, value in parts)
        if key == resource_key:
            # Re-read the path using the validated resource walker.
            break
    else:
        raise CompilerMetadataError("Requested PE resource disappeared")
    return _find_resource_data(data, parts)


def _find_resource_data(data: bytes, wanted: list[list[object]]) -> bytes:
    """Return one resource payload after the full PE tree has been validated."""
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    coff = pe_offset + 4
    section_count = struct.unpack_from("<H", data, coff + 2)[0]
    optional_size = struct.unpack_from("<H", data, coff + 16)[0]
    optional = coff + 20
    magic = struct.unpack_from("<H", data, optional)[0]
    directories_offset = optional + (96 if magic == 0x10B else 112)
    resource_rva, resource_size = struct.unpack_from("<II", data, directories_offset + 2 * 8)
    sections_offset = optional + optional_size
    sections = []
    for index in range(section_count):
        offset = sections_offset + index * 40
        virtual_size, virtual_address, raw_size, raw_pointer = struct.unpack_from("<IIII", data, offset + 8)
        sections.append({"virtual_size": virtual_size, "virtual_address": virtual_address,
                         "raw_size": raw_size, "raw_pointer": raw_pointer})
    base = _rva_to_offset(resource_rva, min(resource_size, 16), sections, what="resource directory")
    path: tuple[tuple[str, object], ...] = ()

    def locate(relative: int, prefix: tuple[tuple[str, object], ...]) -> bytes | None:
        if relative + 16 > resource_size:
            return None
        header = base + relative
        named, ids = struct.unpack_from("<HH", data, header + 12)
        count = named + ids
        if relative + 16 + count * 8 > resource_size:
            return None
        for index in range(count):
            name_field, target_field = struct.unpack_from("<II", data, header + 16 + index * 8)
            if name_field & 0x80000000:
                component = _decode_resource_name(data, base, name_field & 0x7FFFFFFF, resource_size)
            else:
                component = ("id", name_field & 0xFFFF)
            current = prefix + (component,)
            child = target_field & 0x7FFFFFFF
            encoded = [[kind, value] for kind, value in current]
            if encoded == wanted and not (target_field & 0x80000000):
                if child + 16 > resource_size:
                    return None
                data_rva, size = struct.unpack_from("<II", data, base + child)
                file_offset = _rva_to_offset(data_rva, size, sections, what="resource data")
                return data[file_offset:file_offset + size]
            if target_field & 0x80000000:
                found = locate(child, current)
                if found is not None:
                    return found
        return None

    found = locate(0, path)
    if found is None:
        raise CompilerMetadataError("Requested PE resource data could not be located")
    return found


def _all_resource_payloads(data: bytes) -> dict[str, bytes]:
    """Extract leaf payloads for targeted updates; malformed trees are refused."""
    pe = _pe_inspect_bytes(data)
    result = {}
    for key in pe["resources"]:
        parts = pe["resources"][key]["path"]
        result[key] = _find_resource_data(data, parts)
    return result


def _int_resource(value: int):
    return ctypes.cast(ctypes.c_void_p(value), wintypes.LPCWSTR)


def _update_windows_resources(path: Path, updates: list[tuple[int, bytes]]) -> None:
    _need(os.name == "nt", "Windows resource updates require Windows")
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    begin = kernel.BeginUpdateResourceW
    begin.argtypes = [wintypes.LPCWSTR, wintypes.BOOL]
    begin.restype = wintypes.HANDLE
    update = kernel.UpdateResourceW
    update.argtypes = [wintypes.HANDLE, wintypes.LPCWSTR, wintypes.LPCWSTR,
                       wintypes.WORD, ctypes.c_void_p, wintypes.DWORD]
    update.restype = wintypes.BOOL
    end = kernel.EndUpdateResourceW
    end.argtypes = [wintypes.HANDLE, wintypes.BOOL]
    end.restype = wintypes.BOOL
    handle = begin(str(path), False)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    committed = False
    try:
        for language, payload in updates:
            buffer = (ctypes.c_ubyte * len(payload)).from_buffer_copy(payload)
            if not update(handle, _int_resource(RT_MANIFEST),
                          _int_resource(CREATEPROCESS_MANIFEST_RESOURCE_ID), language,
                          ctypes.cast(buffer, ctypes.c_void_p), len(payload)):
                raise ctypes.WinError(ctypes.get_last_error())
        if not end(handle, False):
            raise ctypes.WinError(ctypes.get_last_error())
        committed = True
        handle = None
    finally:
        if handle and not committed:
            end(handle, True)


def _pe_checksum_offset(data: bytes) -> int:
    _need(len(data) >= 0x40 and data[:2] == b"MZ", "Compiler input is not a PE image")
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    _need(pe_offset + 24 <= len(data) and data[pe_offset:pe_offset + 4] == b"PE\0\0",
          "Compiler input has an invalid PE signature")
    optional = pe_offset + 24
    optional_size = struct.unpack_from("<H", data, pe_offset + 20)[0]
    _need(optional_size >= 68 and optional + optional_size <= len(data),
          "PE optional header has no checksum field")
    return optional + 64


def _recompute_pe_checksum(path: Path) -> tuple[int, int]:
    """Recompute the PE checksum after Windows rewrites resource metadata."""
    _need(os.name == "nt", "PE checksum update requires Windows ImageHlp")
    data = bytearray(path.read_bytes())
    checksum_offset = _pe_checksum_offset(data)
    before = struct.unpack_from("<I", data, checksum_offset)[0]
    _need(0 < len(data) <= 0xFFFFFFFF, "PE image size is outside ImageHlp bounds")
    header_sum = wintypes.DWORD()
    checksum = wintypes.DWORD()
    imagehlp = ctypes.WinDLL("ImageHlp.dll", use_last_error=True)
    calculate = imagehlp.CheckSumMappedFile
    calculate.argtypes = [ctypes.c_void_p, wintypes.DWORD,
                          ctypes.POINTER(wintypes.DWORD), ctypes.POINTER(wintypes.DWORD)]
    calculate.restype = ctypes.c_void_p
    with path.open("rb") as stream:
        mapped = mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_COPY)
        try:
            mapped_view = (ctypes.c_char * len(data)).from_buffer(mapped)
            try:
                result = calculate(ctypes.c_void_p(ctypes.addressof(mapped_view)), len(data),
                                   ctypes.byref(header_sum), ctypes.byref(checksum))
            finally:
                del mapped_view
            _need(bool(result), "ImageHlp.CheckSumMappedFile rejected the mapped PE image")
        finally:
            mapped.close()
    struct.pack_into("<I", data, checksum_offset, checksum.value)
    path.write_bytes(data)
    return before, int(checksum.value)


def _restore_resource_data_entry_metadata(path: Path, before: dict, after: dict) -> tuple[dict, int]:
    """Restore Windows UpdateResource's normalized CodePage/Reserved words.

    UpdateResourceW may normalize resource data-entry metadata even for
    resources whose payload was not updated. This restores those two DWORDs
    for every pre-existing resource, including other manifest languages, using
    offsets obtained from the independently parsed, non-executable .rsrc tree.
    Payload bytes and resource IDs are checked before any patch is written.
    """
    before_resources, after_resources = before["resources"], after["resources"]
    _need(set(before_resources).issubset(after_resources),
          "Windows resource update removed a pre-existing resource")
    for key, value in after_resources.items():
        _need(key in before_resources or _is_target_resource(value),
              "Windows resource update added an unrelated resource")
    resource_section_index = after.get("resource_section_index")
    _need(type(resource_section_index) is int, "Updated PE has no bounded resource section")
    sections = after["sections"]
    _need(0 <= resource_section_index < len(sections), "Updated PE resource section index is invalid")
    section = sections[resource_section_index]
    patched = bytearray(path.read_bytes())
    offsets = after.get("resource_data_entries")
    _need(type(offsets) is dict, "Updated PE resource data-entry offsets are unavailable")
    for key, old in before_resources.items():
        new = after_resources[key]
        _need(old.get("path") == new.get("path"),
              "Windows resource update changed an existing resource identity")
        if not _is_target_resource(old):
            _need(old.get("bytes") == new.get("bytes") and old.get("sha256") == new.get("sha256"),
                  "Windows resource update changed a non-target payload")
        offset = offsets.get(key)
        _need(type(offset) is int and section["raw_pointer"] <= offset
              and offset + 16 <= section["raw_pointer"] + section["raw_size"]
              and offset + 16 <= len(patched),
              "Resource data-entry metadata is outside the bounded .rsrc section")
        struct.pack_into("<II", patched, offset + 8,
                         int(old.get("codepage", 0)), int(old.get("reserved", 0)))
    path.write_bytes(patched)
    _, prepared_checksum = _recompute_pe_checksum(path)
    restored = _pe_inspect_bytes(path.read_bytes())
    restored_resources = restored["resources"]
    _need(set(before_resources).issubset(restored_resources),
          "Restored PE resource population differs from its original")
    for key, old in before_resources.items():
        new = restored_resources[key]
        _need(old.get("codepage") == new.get("codepage")
              and old.get("reserved") == new.get("reserved"),
              "Resource CodePage/Reserved metadata was not preserved")
        if not _is_target_resource(old):
            _need(old == new, "A non-target resource changed after metadata restoration")
    _need(restored["pe_checksum"] == prepared_checksum,
          "Prepared PE checksum readback differs from ImageHlp result")
    return restored, prepared_checksum


def _target_manifest_rows(pe: dict) -> list[dict]:
    return [item for item in pe["resources"].values()
            if len(item["path"]) == 3 and item["path"][0] == ["id", RT_MANIFEST]
            and item["path"][1] == ["id", CREATEPROCESS_MANIFEST_RESOURCE_ID]
            and isinstance(item["path"][2][1], int)]


def _protected_source_root(root: Path) -> bool:
    """Return true for the known developer MinGW tree, including descendants."""
    text = str(root).replace("/", "\\").rstrip("\\").casefold()
    protected = r"c:\mingw64"
    return text == protected or text.startswith(protected + "\\")


def _assert_registered_tree(root: Path, *, expect_original: bool) -> dict[str, str]:
    actual: dict[str, str] = {}
    for relative, expected in CORE_EXECUTABLE_SHA256.items():
        path = root / Path(relative)
        _need(path.is_file() and not path.is_symlink(), "Missing or linked registered GNU executable: " + relative)
        actual[relative] = _sha_file(path)
        if expect_original:
            _need(actual[relative] == expected,
                  "Registered GNU executable bytes differ before UTF-8 preparation: " + relative)
    return actual


def _is_target_resource(item: dict) -> bool:
    path = item["path"]
    return (len(path) == 3 and path[0] == ["id", RT_MANIFEST]
            and path[1] == ["id", CREATEPROCESS_MANIFEST_RESOURCE_ID]
            and isinstance(path[2][1], int))


def _resource_path_key(path: list[list[object]]) -> str:
    _need(type(path) is list and all(type(part) is list and len(part) == 2 for part in path),
          "Compiler receipt contains a malformed PE resource path")
    return "/".join(str(part[0]) + ":" + str(part[1]) for part in path)


def _validate_receipt_transition(relative: str, row: dict) -> None:
    """Validate the claimed before/after invariants without Windows APIs."""
    for field in ("pe_checksum_before", "pe_checksum_after_api", "pe_checksum_prepared"):
        value = row.get(field)
        _need(type(value) is int and 0 <= value <= 0xFFFFFFFF,
              "Receipt PE checksum value is malformed: " + relative)
    before_sections = row.get("before_nonresource_sections")
    after_sections = row.get("after_nonresource_sections")
    _need(type(before_sections) is list and before_sections == after_sections,
          "Receipt does not prove unchanged non-resource sections: " + relative)
    section_digest = _sha_bytes(_canonical(before_sections))
    _need(row.get("nonresource_sections_sha256") == section_digest,
          "Receipt non-resource section digest is inconsistent: " + relative)

    before_resources, after_resources = row.get("resources_before"), row.get("resources_after")
    _need(type(before_resources) is dict and type(after_resources) is dict,
          "Receipt omits its before/after PE resource inventory: " + relative)
    for inventory in (before_resources, after_resources):
        for key, item in inventory.items():
            _need(type(item) is dict and type(item.get("path")) is list
                  and _resource_path_key(item["path"]) == key,
                  "Receipt PE resource key does not match its resource path: " + relative)
    before_other = {key: value for key, value in before_resources.items()
                    if not _is_target_resource(value)}
    after_other = {key: value for key, value in after_resources.items()
                   if not _is_target_resource(value)}
    _need(before_other == after_other,
          "Receipt claims a change to a non-target PE resource: " + relative)

    manifests = row.get("manifests_before")
    _need(type(manifests) is list and bool(manifests),
          "Receipt omits its target-manifest transformation records: " + relative)
    before_targets = {key: value for key, value in before_resources.items()
                      if _is_target_resource(value)}
    after_targets = {key: value for key, value in after_resources.items()
                     if _is_target_resource(value)}
    manifest_keys: set[str] = set()
    created_keys: set[str] = set()
    for manifest in manifests:
        _need(type(manifest) is dict and type(manifest.get("resource")) is list,
              "Receipt target-manifest record is malformed: " + relative)
        key = _resource_path_key(manifest["resource"])
        _need(key not in manifest_keys, "Receipt repeats a target-manifest record: " + relative)
        manifest_keys.add(key)
        _need(key in after_targets, "Receipt target manifest is absent after preparation: " + relative)
        _need(after_targets[key].get("sha256") == manifest.get("output_sha256"),
              "Receipt target-manifest output hash is inconsistent: " + relative)
        _need(after_targets[key].get("active_code_page_utf8") is True,
              "Receipt target manifest lacks UTF-8 activeCodePage: " + relative)
        if manifest.get("created_neutral_manifest") is True:
            _need(key not in before_targets and key == "id:24/id:1/id:0"
                  and manifest.get("original_sha256") is None
                  and manifest.get("sha256") is None and manifest.get("bytes") == 0,
                  "Receipt records an invalid synthesized neutral manifest: " + relative)
            created_keys.add(key)
        else:
            _need(key in before_targets
                  and before_targets[key].get("sha256") == manifest.get("original_sha256")
                  and manifest.get("sha256") == manifest.get("original_sha256")
                  and before_targets[key].get("bytes") == manifest.get("bytes")
                  and before_targets[key].get("codepage") == after_targets[key].get("codepage")
                  and before_targets[key].get("reserved") == after_targets[key].get("reserved"),
                  "Receipt target-manifest input hash is inconsistent: " + relative)
    _need(manifest_keys == set(after_targets),
          "Receipt target-manifest population differs after preparation: " + relative)
    _need(set(before_targets) == manifest_keys - created_keys,
          "Receipt changed the target-manifest language population: " + relative)


def _manifest_updates(path: Path, before_data: bytes, before_pe: dict) -> tuple[list[tuple[int, bytes]], dict]:
    payloads = _all_resource_payloads(before_data)
    targets = _target_manifest_rows(before_pe)
    manifests_before = []
    updates = []
    if targets:
        for row in targets:
            key = "/".join(kind + ":" + str(value) for kind, value in row["path"])
            original = payloads[key]
            transformed, transform = _transform_manifest(original)
            language = int(row["path"][2][1])
            updates.append((language, transformed))
            manifests_before.append({"resource": row["path"], "sha256": _sha_bytes(original),
                                    "bytes": len(original), **transform})
    else:
        minimal = (b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                   b'<assembly xmlns="' + ASSEMBLY_NS.encode("ascii") + b'" manifestVersion="1.0">'
                   b'<assemblyIdentity type="win32" name="CyberSand.PortableGNUCompiler" version="1.0.0.0"/>'
                   b'<application xmlns="' + ASSEMBLY_V3_NS.encode("ascii") + b'">'
                   b'<windowsSettings><activeCodePage xmlns="' + WINDOWS_SETTINGS_NS.encode("ascii")
                   + b'">UTF-8</activeCodePage></windowsSettings></application></assembly>')
        _need(_manifest_has_utf8(minimal), "Minimal Fusion UTF-8 manifest failed parse")
        updates.append((0, minimal))
        manifests_before.append({"resource": [["id", RT_MANIFEST], ["id", CREATEPROCESS_MANIFEST_RESOURCE_ID], ["id", 0]],
                                 "sha256": None, "bytes": 0, "changed": True,
                                 "active_code_page": UTF8_CODEPAGE,
                                 "original_sha256": None, "output_sha256": _sha_bytes(minimal),
                                 "created_neutral_manifest": True})
    return updates, {"manifests_before": manifests_before}


def prepare(root: str | os.PathLike[str]) -> dict:
    """Patch only an exact copy of the admitted GNU core files and write receipt.

    ``root`` is the copied ``dependencies/cxx`` root, never the source compiler
    installation. The exact originals are pinned by the recovered package
    custody manifest. Existing receipt is treated as idempotent verification.
    """
    _need(os.name == "nt", "UTF-8 compiler metadata preparation requires Windows")
    compiler_root = Path(root).resolve(strict=True)
    _need(compiler_root.is_dir(), "Compiler root is not a directory")
    _need(not _protected_source_root(compiler_root), "Refuse to modify the developer C:\\mingw64 toolchain")
    receipt_path = compiler_root / RECEIPT_NAME
    if receipt_path.exists():
        try:
            existing = json.loads(receipt_path.read_bytes())
        except (OSError, json.JSONDecodeError) as error:
            raise CompilerMetadataError("Existing prepared compiler receipt is unreadable") from error
        verify(compiler_root, existing, execute=False)
        return existing
    original_hashes = _assert_registered_tree(compiler_root, expect_original=True)
    binaries = {}
    for relative in CORE_EXECUTABLE_SHA256:
        path = compiler_root / Path(relative)
        before_data = path.read_bytes()
        before = _pe_inspect_bytes(before_data)
        _need(not before["certificate_table_present"],
              "Refuse to update Authenticode-signed GNU executable: " + relative)
        updates, manifest_record = _manifest_updates(path, before_data, before)
        before_resources = before["resources"]
        _update_windows_resources(path, updates)
        after_api = _pe_inspect_bytes(path.read_bytes())
        after, prepared_checksum = _restore_resource_data_entry_metadata(path, before, after_api)
        after_data = path.read_bytes()
        _need(not after["certificate_table_present"], "Resource update unexpectedly produced a signed image")
        if before["nonresource_sections"] != after["nonresource_sections"]:
            diagnostic = _section_mismatch_diagnostic(
                relative, before_data, after_data, before, after_api, after)
            _write_atomic(compiler_root / FAILURE_RECEIPT_NAME, diagnostic)
            _need(False, "A non-resource PE section changed during metadata update: " + relative
                  + f"; bounded diagnostics written to {FAILURE_RECEIPT_NAME}")
        after_payloads = _all_resource_payloads(after_data)
        after_targets = _target_manifest_rows(after)
        _need(bool(after_targets), "Updated compiler has no process manifest resource: " + relative)
        for row in after_targets:
            key = "/".join(kind + ":" + str(value) for kind, value in row["path"])
            _need(_manifest_has_utf8(after_payloads[key]),
                  "Updated compiler manifest is missing activeCodePage=UTF-8: " + relative)
        before_non_targets = {key: value for key, value in before_resources.items()
                              if not _is_target_resource(value)}
        after_non_targets = {key: value for key, value in after["resources"].items()
                             if not _is_target_resource(value)}
        _need(before_non_targets == after_non_targets,
              "A non-target PE resource changed during metadata update: " + relative)
        binaries[relative] = {"original_sha256": original_hashes[relative],
                              "prepared_sha256": _sha_bytes(after_data),
                              "pe_checksum_before": before["pe_checksum"],
                              "pe_checksum_after_api": after_api["pe_checksum"],
                              "pe_checksum_prepared": prepared_checksum,
                              "before_nonresource_sections": before["nonresource_sections"],
                              "after_nonresource_sections": after["nonresource_sections"],
                              "nonresource_sections_sha256": after["nonresource_sections_sha256"],
                              "resources_before": before_resources,
                              "resources_after": after["resources"],
                              **manifest_record}
    receipt = {"schema": SCHEMA, "status": "prepared-candidate",
               "reference_source": REFERENCE_SOURCE,
               "compiler_root_kind": "copied GNU 14.2 dependencies/cxx tree",
               "active_code_page": UTF8_CODEPAGE,
               "resource_type": RT_MANIFEST,
               "resource_name": CREATEPROCESS_MANIFEST_RESOURCE_ID,
               "original_registered_sha256": CORE_EXECUTABLE_SHA256,
               "binaries": binaries}
    # Ensure the full tree is valid before making the receipt visible.
    verify(compiler_root, receipt, execute=False)
    _write_atomic(receipt_path, receipt)
    return receipt


def verify(root: str | os.PathLike[str], receipt: dict | None = None, *, execute: bool = True) -> dict:
    """Verify a prepared tree; static mode works on non-Windows archive readers."""
    compiler_root = Path(root).resolve(strict=True)
    _need(compiler_root.is_dir(), "Compiler root is not a directory")
    _need(not _protected_source_root(compiler_root), "Refuse to verify the developer C:\\mingw64 toolchain as a staged root")
    receipt_path = compiler_root / RECEIPT_NAME
    if receipt is None:
        _need(receipt_path.is_file(), "Prepared compiler metadata receipt is missing")
        try:
            receipt = json.loads(receipt_path.read_bytes())
        except (OSError, json.JSONDecodeError) as error:
            raise CompilerMetadataError("Prepared compiler metadata receipt is unreadable") from error
    _need(type(receipt) is dict and receipt.get("schema") == SCHEMA
          and receipt.get("status") == "prepared-candidate", "Unsupported UTF-8 compiler receipt")
    _need(receipt.get("reference_source") == REFERENCE_SOURCE
          and receipt.get("original_registered_sha256") == CORE_EXECUTABLE_SHA256,
          "UTF-8 compiler receipt does not match the registered source binaries")
    binaries = receipt.get("binaries")
    _need(type(binaries) is dict and set(binaries) == set(CORE_EXECUTABLE_SHA256),
          "UTF-8 compiler receipt has an incomplete executable population")
    current_hashes = _assert_registered_tree(compiler_root, expect_original=False)
    rows = {}
    for relative in CORE_EXECUTABLE_SHA256:
        path = compiler_root / Path(relative)
        row = binaries[relative]
        _need(type(row) is dict, "Prepared compiler binary receipt is malformed: " + relative)
        _validate_receipt_transition(relative, row)
        data = path.read_bytes()
        pe = _pe_inspect_bytes(data)
        _need(not pe["certificate_table_present"], "Prepared GNU executable is unexpectedly signed: " + relative)
        _need(current_hashes[relative] == row.get("prepared_sha256"),
              "Prepared GNU executable hash differs from receipt: " + relative)
        _need(pe["nonresource_sections"] == row.get("after_nonresource_sections")
              and pe["nonresource_sections_sha256"] == row.get("nonresource_sections_sha256"),
              "Prepared non-resource PE section identity differs from receipt: " + relative)
        _need(pe["pe_checksum"] == row.get("pe_checksum_prepared"),
              "Prepared PE checksum differs from receipt: " + relative)
        _need(pe["resources"] == row.get("resources_after"),
              "Prepared PE resource identity differs from receipt: " + relative)
        targets = _target_manifest_rows(pe)
        _need(bool(targets), "Prepared GNU executable has no RT_MANIFEST/#1: " + relative)
        payloads = _all_resource_payloads(data)
        for target in targets:
            key = "/".join(kind + ":" + str(value) for kind, value in target["path"])
            _need(_manifest_has_utf8(payloads[key]),
                  "Prepared GNU executable lacks activeCodePage=UTF-8: " + relative)
        _need(row.get("original_sha256") == CORE_EXECUTABLE_SHA256[relative],
              "Receipt original hash is not the registered GNU executable: " + relative)
        rows[relative] = {"sha256": current_hashes[relative],
                          "active_code_page_manifests": len(targets),
                          "nonresource_sections_sha256": pe["nonresource_sections_sha256"]}
    execution = None
    if execute:
        _need(os.name == "nt", "Executable GNU verifier is Windows-only; use execute=False for static archive verification")
        driver = compiler_root / "bin/g++.exe"
        env = {key: os.environ[key] for key in ("SystemRoot", "TEMP", "TMP") if key in os.environ}
        env["PATH"] = str(compiler_root / "bin") + os.pathsep + str(compiler_root / "x86_64-w64-mingw32/bin") \
            + os.pathsep + str(Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32")
        try:
            process = subprocess.run([str(driver), "--version"], cwd=compiler_root, env=env,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     timeout=30, check=False, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        except (OSError, subprocess.TimeoutExpired) as error:
            raise CompilerMetadataError("Prepared bundled GNU driver did not execute: " + str(error)) from error
        _need(process.returncode == 0 and b"14.2.0" in process.stdout,
              "Prepared bundled GNU driver version readback failed")
    # This object is persisted in portable package identity, so keep it
    # independent of the absolute staging/extraction root and execution mode.
    # The caller's path-specific evidence belongs in its outer path receipt.
    result = {"schema": SCHEMA, "status": "verified", "binaries": rows}
    if receipt_path.is_file():
        result["receipt_sha256"] = _sha_file(receipt_path)
    return result


__all__ = ["SCHEMA", "RECEIPT_NAME", "CORE_EXECUTABLE_SHA256", "CompilerMetadataError",
           "prepare", "verify", "inspect_pe", "_transform_manifest", "_manifest_has_utf8"]
