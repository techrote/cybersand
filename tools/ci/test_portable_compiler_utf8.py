"""Pure contract tests for the candidate GNU Fusion-manifest metadata tool."""
from __future__ import annotations

import json
import struct
import unittest
import xml.etree.ElementTree as ET

import portable_compiler_utf8 as candidate


def _existing_manifest() -> bytes:
    return (b'<?xml version="1.0" encoding="utf-8" standalone="yes"?>\n'
            b'<assembly xmlns="' + candidate.ASSEMBLY_NS.encode("ascii")
            + b'" manifestVersion="1.0" custom="retained">'
            b'<assemblyIdentity name="mingw-tool" processorArchitecture="amd64"/>'
            b'<!-- preserve this comment -->'
            b'<dependency optional="yes"><dependentAssembly><assemblyIdentity name="runtime"/>'
            b'</dependentAssembly></dependency>'
            b'<application><windowsSettings custom="setting">'
            b'<dpiAware>true</dpiAware></windowsSettings></application></assembly>')


def _synthetic_pe(manifest: bytes) -> bytes:
    """Build a tiny PE32 image containing .text and RT_MANIFEST/#1/lang 0."""
    resource_size = 0x60 + len(manifest)
    resource_raw_size = (resource_size + 0x1FF) & ~0x1FF
    image = bytearray(0x400 + resource_raw_size)
    image[:2] = b"MZ"
    struct.pack_into("<I", image, 0x3C, 0x80)
    pe = 0x80
    image[pe:pe + 4] = b"PE\0\0"
    coff = pe + 4
    struct.pack_into("<HHIIIHH", image, coff, 0x8664, 2, 0, 0, 0, 0xE0, 0x0022)
    optional = coff + 20
    struct.pack_into("<H", image, optional, 0x10B)
    struct.pack_into("<I", image, optional + 60, 0x200)  # SizeOfHeaders
    struct.pack_into("<I", image, optional + 92, 16)  # NumberOfRvaAndSizes
    struct.pack_into("<II", image, optional + 96 + 2 * 8, 0x2000, resource_size)
    section_table = optional + 0xE0
    image[section_table:section_table + 8] = b".text\0\0\0"
    struct.pack_into("<IIII", image, section_table + 8, 0x100, 0x1000, 0x200, 0x200)
    struct.pack_into("<I", image, section_table + 36, 0x60000020)
    resource = section_table + 40
    image[resource:resource + 8] = b".rsrc\0\0\0"
    struct.pack_into("<IIII", image, resource + 8, resource_raw_size, 0x2000,
                     resource_raw_size, 0x400)
    struct.pack_into("<I", image, resource + 36, 0x40000040)
    image[0x200:0x400] = bytes((index * 13) & 255 for index in range(0x200))

    base = 0x400
    struct.pack_into("<IIHHHH", image, base, 0, 0, 0, 0, 0, 1)
    struct.pack_into("<II", image, base + 16, candidate.RT_MANIFEST, 0x80000018)
    struct.pack_into("<IIHHHH", image, base + 0x18, 0, 0, 0, 0, 0, 1)
    struct.pack_into("<II", image, base + 0x28, candidate.CREATEPROCESS_MANIFEST_RESOURCE_ID, 0x80000030)
    struct.pack_into("<IIHHHH", image, base + 0x30, 0, 0, 0, 0, 0, 1)
    struct.pack_into("<II", image, base + 0x40, 0, 0x48)
    struct.pack_into("<IIII", image, base + 0x48, 0x2060, len(manifest), 0, 0)
    image[base + 0x60:base + 0x60 + len(manifest)] = manifest
    return bytes(image)


def _semantic_tree(data: bytes):
    return ET.fromstring(data, parser=ET.XMLParser(target=ET.TreeBuilder(insert_comments=True,
                                                                          insert_pis=True)))


class ManifestTransformTests(unittest.TestCase):
    def test_existing_fusion_nodes_attributes_and_comments_are_retained(self):
        before = _existing_manifest()
        after, evidence = candidate._transform_manifest(before)
        first, second = _semantic_tree(before), _semantic_tree(after)
        self.assertTrue(evidence["changed"])
        self.assertEqual(first.tag, second.tag)
        self.assertEqual(first.attrib, second.attrib)
        before_existing = [(node.tag, dict(node.attrib), node.text, node.tail)
                           for node in first.iter() if node is not first]
        after_existing = [(node.tag, dict(node.attrib), node.text, node.tail)
                          for node in second.iter() if node is not second
                          and node.tag != candidate._qname(candidate.WINDOWS_SETTINGS_NS,
                                                            "activeCodePage")]
        self.assertEqual(before_existing, after_existing)
        self.assertTrue(candidate._manifest_has_utf8(after))
        self.assertIn(b'standalone="yes"', after.split(b"?>", 1)[0])

    def test_missing_application_creates_namespaced_minimal_path(self):
        source = (b'<assembly xmlns="' + candidate.ASSEMBLY_NS.encode("ascii")
                  + b'" manifestVersion="1.0" custom="keep"><assemblyIdentity name="existing"/></assembly>')
        output, _ = candidate._transform_manifest(source)
        root = _semantic_tree(output)
        application = next(child for child in root if candidate._local_name(child.tag) == "application")
        settings = next(child for child in application if candidate._local_name(child.tag) == "windowsSettings")
        active = next(iter(settings))
        self.assertEqual(candidate._tag_namespace(application.tag), candidate.ASSEMBLY_V3_NS)
        self.assertEqual(candidate._tag_namespace(settings.tag), candidate.ASSEMBLY_V3_NS)
        self.assertEqual(active.tag, candidate._qname(candidate.WINDOWS_SETTINGS_NS, "activeCodePage"))
        self.assertTrue(candidate._manifest_has_utf8(output))

    def test_unqualified_application_is_refused(self):
        source = (b'<assembly xmlns="' + candidate.ASSEMBLY_NS.encode("ascii")
                  + b'" manifestVersion="1.0"><application xmlns=""/></assembly>')
        with self.assertRaises(candidate.CompilerMetadataError):
            candidate._transform_manifest(source)

    def test_documented_v1_application_namespace_is_preserved(self):
        source = (b'<assembly xmlns="' + candidate.ASSEMBLY_NS.encode("ascii")
                  + b'" manifestVersion="1.0"><application><windowsSettings/></application></assembly>')
        output, _ = candidate._transform_manifest(source)
        root = _semantic_tree(output)
        application = next(child for child in root if candidate._local_name(child.tag) == "application")
        settings = next(child for child in application if candidate._local_name(child.tag) == "windowsSettings")
        self.assertEqual(candidate._tag_namespace(application.tag), candidate.ASSEMBLY_NS)
        self.assertEqual(candidate._tag_namespace(settings.tag), candidate.ASSEMBLY_NS)
        self.assertTrue(candidate._manifest_has_utf8(output))

    def test_already_utf8_is_byte_idempotent(self):
        source = (b'<assembly xmlns="' + candidate.ASSEMBLY_NS.encode("ascii") + b'" manifestVersion="1.0">'
                  b'<application xmlns="' + candidate.ASSEMBLY_V3_NS.encode("ascii")
                  + b'"><windowsSettings><activeCodePage xmlns="'
                  + candidate.WINDOWS_SETTINGS_NS.encode("ascii") + b'">UTF-8</activeCodePage>'
                  b'</windowsSettings></application></assembly>')
        output, evidence = candidate._transform_manifest(source)
        self.assertFalse(evidence["changed"])
        self.assertEqual(output, source)

    def test_conflicting_duplicate_or_misplaced_active_code_page_is_refused(self):
        prefix = b'<assembly xmlns="' + candidate.ASSEMBLY_NS.encode("ascii") + b'" manifestVersion="1.0">'
        valid_ns = b' xmlns="' + candidate.WINDOWS_SETTINGS_NS.encode("ascii") + b'"'
        conflicting = prefix + b'<application><windowsSettings><activeCodePage' + valid_ns + b'>1252</activeCodePage>' \
            b'</windowsSettings></application></assembly>'
        duplicate = prefix + b'<application><windowsSettings><activeCodePage' + valid_ns + b'>UTF-8</activeCodePage>' \
            b'<activeCodePage' + valid_ns + b'>UTF-8</activeCodePage></windowsSettings></application></assembly>'
        misplaced = prefix + b'<activeCodePage' + valid_ns + b'>UTF-8</activeCodePage></assembly>'
        for source in (conflicting, duplicate, misplaced):
            with self.subTest(source=source), self.assertRaises(candidate.CompilerMetadataError):
                candidate._transform_manifest(source)

    def test_doctype_is_rejected(self):
        source = (b'<!DOCTYPE assembly [<!ENTITY e "x">]><assembly xmlns="'
                  + candidate.ASSEMBLY_NS.encode("ascii") + b'" manifestVersion="1.0">'
                  b'<description>&e;</description></assembly>')
        with self.assertRaises(candidate.CompilerMetadataError):
            candidate._transform_manifest(source)


class PEInspectionTests(unittest.TestCase):
    def test_pe_parser_finds_target_resource_and_separates_code_section(self):
        manifest = _existing_manifest()
        image = _synthetic_pe(manifest)
        inspected = candidate._pe_inspect_bytes(image)
        key = "id:24/id:1/id:0"
        self.assertIn(key, inspected["resources"])
        self.assertEqual(inspected["resources"][key]["bytes"], len(manifest))
        self.assertEqual(inspected["resources"][key]["sha256"], candidate._sha_bytes(manifest))
        self.assertEqual([section["name"] for section in inspected["nonresource_sections"]], [".text"])
        self.assertTrue(inspected["nonresource_sections_sha256"])

    def test_protected_toolchain_root_is_exact_and_ancestor_bounded(self):
        self.assertTrue(candidate._protected_source_root(__import__("pathlib").Path(r"C:\mingw64")))
        self.assertTrue(candidate._protected_source_root(__import__("pathlib").Path(r"C:\mingw64\bin")))
        self.assertFalse(candidate._protected_source_root(__import__("pathlib").Path(r"C:\mingw64-copy")))

    def test_section_failure_diagnostic_pins_changed_bytes_without_payload_dump(self):
        before_data = _synthetic_pe(_existing_manifest())
        after_data = bytearray(before_data)
        after_data[0x210] ^= 0x55
        before = candidate._pe_inspect_bytes(before_data)
        after = candidate._pe_inspect_bytes(bytes(after_data))
        diagnostic = candidate._section_mismatch_diagnostic(
            "bin/as.exe", before_data, bytes(after_data), before, after, after)
        text = json.dumps(diagnostic, sort_keys=True)
        self.assertLess(len(text), 100_000)
        self.assertEqual(diagnostic["failure"], "non-resource PE section identity changed")
        self.assertEqual(diagnostic["before_sha256"], candidate._sha_bytes(before_data))
        self.assertEqual(diagnostic["after_sha256"], candidate._sha_bytes(bytes(after_data)))
        changed = diagnostic["changed_nonresource_sections"]
        self.assertEqual(len(changed), 1)
        self.assertEqual(changed[0]["before"]["name"], ".text")
        raw_diff = changed[0]["raw_diff"]["raw_byte_diff"]
        self.assertEqual(raw_diff["changed_byte_count"], 1)
        self.assertEqual(raw_diff["ranges"][0]["before_file_offset_start"], 0x210)
        self.assertTrue(diagnostic["resource_preservation"]["non_target_resources_exact"])

    def test_raw_byte_diff_retains_bounded_first_and_last_ranges(self):
        before = bytes(1024)
        after = bytearray(before)
        for offset in range(0, len(after), 2):
            after[offset] = 1
        diff = candidate._bounded_byte_diff(before, bytes(after), max_ranges=8)
        self.assertEqual(diff["changed_byte_count"], 512)
        self.assertEqual(diff["changed_range_count"], 512)
        self.assertEqual(diff["omitted_range_count"], 504)
        self.assertEqual(len(diff["ranges"]), 8)
        self.assertEqual(diff["first_changed_offset"], 0)
        self.assertEqual(diff["last_changed_offset"], 1022)


class ReceiptProofTests(unittest.TestCase):
    @staticmethod
    def _target(language: int, digest: str, *, active: bool) -> dict:
        return {"path": [["id", 24], ["id", 1], ["id", language]],
                "bytes": 10, "sha256": digest, "codepage": 0, "reserved": 0,
                "active_code_page_utf8": active}

    def _receipt_row(self, languages: tuple[int, ...], *, create_neutral: bool = False) -> dict:
        sections = [{"name": ".text", "sha256": "code-section"}]
        before_resources = {"id:16/id:1/id:0":
                            {"path": [["id", 16], ["id", 1], ["id", 0]],
                             "bytes": 3, "sha256": "version-resource"}}
        after_resources = {key: dict(value) for key, value in before_resources.items()}
        manifests = []
        languages_before = () if create_neutral else languages
        languages_after = (0,) if create_neutral else languages
        for language in languages_before:
            key = f"id:24/id:1/id:{language}"
            original = f"input-{language}"
            output = f"output-{language}"
            before_resources[key] = self._target(language, original, active=False)
            after_resources[key] = self._target(language, output, active=True)
            manifests.append({"resource": before_resources[key]["path"], "sha256": original,
                              "bytes": 10, "original_sha256": original,
                              "output_sha256": output, "changed": True,
                              "active_code_page": "UTF-8"})
        if create_neutral:
            language = 0
            key = "id:24/id:1/id:0"
            output = "output-created-neutral"
            after_resources[key] = self._target(language, output, active=True)
            manifests.append({"resource": after_resources[key]["path"], "sha256": None,
                              "bytes": 0, "original_sha256": None,
                              "output_sha256": output, "changed": True,
                              "active_code_page": "UTF-8", "created_neutral_manifest": True})
        return {"before_nonresource_sections": sections,
                "after_nonresource_sections": sections,
                "nonresource_sections_sha256": candidate._sha_bytes(candidate._canonical(sections)),
                "pe_checksum_before": 0,
                "pe_checksum_after_api": 1,
                "pe_checksum_prepared": 2,
                "resources_before": before_resources,
                "resources_after": after_resources,
                "manifests_before": manifests}

    def test_existing_neutral_manifest_and_localized_population_are_preserved(self):
        for languages in ((0,), (0, 1033), (1033,)):
            with self.subTest(languages=languages):
                candidate._validate_receipt_transition("fixture.exe", self._receipt_row(languages))

    def test_synthesized_neutral_manifest_is_explicitly_recorded(self):
        candidate._validate_receipt_transition(
            "fixture.exe", self._receipt_row((), create_neutral=True))

    def test_receipt_cannot_claim_unrelated_resource_or_section_changes(self):
        row = self._receipt_row((0, 1033))
        row["resources_after"]["id:16/id:1/id:0"]["sha256"] = "changed-version-resource"
        with self.assertRaises(candidate.CompilerMetadataError):
            candidate._validate_receipt_transition("fixture.exe", row)
        row = self._receipt_row((0,))
        row["after_nonresource_sections"] = [{"name": ".text", "sha256": "changed-code"}]
        with self.assertRaises(candidate.CompilerMetadataError):
            candidate._validate_receipt_transition("fixture.exe", row)

    def test_receipt_cannot_hide_a_preexisting_target_language(self):
        row = self._receipt_row((0, 1033))
        del row["resources_before"]["id:24/id:1/id:1033"]
        with self.assertRaises(candidate.CompilerMetadataError):
            candidate._validate_receipt_transition("fixture.exe", row)

    def test_receipt_cannot_normalize_target_resource_metadata(self):
        row = self._receipt_row((0,))
        row["resources_after"]["id:24/id:1/id:0"]["codepage"] = 1252
        with self.assertRaises(candidate.CompilerMetadataError):
            candidate._validate_receipt_transition("fixture.exe", row)


if __name__ == "__main__":
    unittest.main()
