"""Current selection stays bounded when the explicit manifest is unavailable.

DOCS-RENAISSANCE reproduced a missing-manifest route that admitted 27 excluded
execution/research packets and omitted five current answer documents. These
tests exercise the actual public selection/chunking paths and malformed-input
counterexamples; historical authority regressions remain in their frozen suite.
"""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "docs"))
import retrieval_eval as retrieval
from retrieval_policy import FOCUSED, HISTORICAL_AUTHORITY
import check_docs


class CurrentRetrievalSelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.current = self.write("docs/systems/current.md", "# Current\nCurrent answer.\n")
        self.packet = self.write("docs/operations/packet.md", "---\nretrieval: explicit-only\n---\n# Prior packet\nAn old execution instruction.\n")
        self.manifest = self.write("docs/reference/retrieval-corpus.json", json.dumps({"documents": ["systems/current.md"]}))

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def test_fallback_excludes_explicit_packets_and_navigation(self):
        self.write("AGENTS.md", "# Agent navigation\nRead current contracts.\n")
        self.write("README.md", "# Overview\nFollow the guides.\n")
        self.write("docs/README.md", "# Portal\nSelect a topic.\n")
        self.write("docs/reference/another-index.md", "---\ndocument-kind: navigation\n---\n# Routes\nA route.\n")
        self.manifest.unlink()
        self.assertEqual(retrieval.selected_paths(self.root), [self.current])

    def test_manifest_cannot_reintroduce_an_explicit_packet(self):
        self.manifest.write_text(json.dumps({"documents": ["operations/packet.md"]}))
        with self.assertRaisesRegex(ValueError, "Default retrieval excludes"):
            retrieval.selected_paths(self.root)

    def test_direct_default_chunking_cannot_reintroduce_a_packet(self):
        with self.assertRaisesRegex(ValueError, "Default retrieval excludes"):
            retrieval.chunk_document(self.packet, self.root, 20)

    def test_manifest_and_direct_chunking_reject_navigation(self):
        nav = self.write("docs/reference/index.md", "---\ndocument-kind: 'navigation'\n---\n# Routes\nA route.\n")
        self.manifest.write_text(json.dumps({"documents": ["reference/index.md"]}))
        with self.assertRaisesRegex(ValueError, "Default retrieval excludes"):
            retrieval.selected_paths(self.root)
        with self.assertRaisesRegex(ValueError, "Default retrieval excludes"):
            retrieval.chunk_document(nav, self.root, 20)

    def test_fallback_includes_current_tools_and_material_lab(self):
        viewer = self.write("docs/tools/viewer.md", "# Viewer\nCurrent viewer procedure.\n")
        lab = self.write("docs/MATERIAL_LAB.md", "# Materials\nCurrent material entry.\n")
        self.manifest.unlink()
        self.assertEqual(set(retrieval.selected_paths(self.root)), {self.current, viewer, lab})

    def test_bad_authority_cannot_hide_behind_explicit_selection(self):
        self.manifest.unlink()
        for authority in (HISTORICAL_AUTHORITY, "[historical-non-authoritative]", "invented-authority"):
            with self.subTest(authority=authority):
                self.packet.write_text(f"---\nretrieval: explicit-only\nauthority: {authority}\n---\n# Packet\nOld.\n")
                with self.assertRaises(ValueError):
                    retrieval.selected_paths(self.root)

    def test_unknown_selection_fails_closed_in_every_default_entry(self):
        for value in ("[explicit-only]", "!tag explicit-only", "sometimes", ""):
            with self.subTest(value=value):
                self.current.write_text(f"---\nretrieval: {value}\n---\n# Current\nAnswer.\n")
                self.manifest.write_text(json.dumps({"documents": ["systems/current.md"]}))
                with self.assertRaisesRegex(ValueError, "Unsupported retrieval selection"):
                    retrieval.selected_paths(self.root)
                with self.assertRaisesRegex(ValueError, "Unsupported retrieval selection"):
                    retrieval.chunk_document(self.current, self.root, 20)
                self.manifest.unlink()
                with self.assertRaisesRegex(ValueError, "Unsupported retrieval selection"):
                    retrieval.selected_paths(self.root)

    def test_quoted_padded_and_escaped_keys_preserve_exclusion(self):
        self.manifest.unlink()
        for key in ('"retrieval"', "'retrieval'", "retrieval ", "  retrieval", r'"\u0072etrieval"'):
            for value in ("explicit-only", "'explicit-only'", '"explicit-only"'):
                with self.subTest(key=key, value=value):
                    self.packet.write_text(f"---\n{key}: {value}\n---\n# Packet\nOld.\n")
                    self.assertEqual(retrieval.selected_paths(self.root), [self.current])

    def test_duplicate_selection_keys_fail_closed_in_both_parsers(self):
        text = '---\nretrieval: explicit-only\n"retrieval": default\n---\n# Packet\nOld.\n'
        for parser in (retrieval.metadata_and_body, check_docs.metadata):
            with self.subTest(parser=parser.__module__):
                with self.assertRaisesRegex(ValueError, "Duplicate frontmatter retrieval"):
                    parser(text)

    def test_explicit_default_retains_current_content(self):
        self.current.write_text("---\nretrieval: default\n---\n# Current\nAnswer.\n")
        self.assertEqual(retrieval.selected_paths(self.root), [self.current])
        self.manifest.unlink()
        self.assertEqual(retrieval.selected_paths(self.root), [self.current])

    def test_owner_intent_authority_survives_every_chunk(self):
        self.current.write_text("---\nauthority: 'owner-confirmed-intent'\nstatus: Approved design\n---\n# Owner direction\n" + "Desired behavior is not implemented permission. " * 40)
        self.assertEqual(retrieval.selected_paths(self.root), [self.current])
        chunks = retrieval.chunk_document(self.current, self.root, 20)
        self.assertGreater(len(chunks), 1)
        for chunk in chunks:
            self.assertEqual(chunk["authority"], "owner-confirmed-intent")
            self.assertIn("authority: owner-confirmed-intent\n", chunk["text"])
            self.assertIn("status: Approved design", chunk["text"])

    def test_duplicate_document_kind_cannot_override_navigation(self):
        text = '---\ndocument-kind: navigation\n"document-kind": guide\n---\n# Index\nRoutes only.\n'
        for parser in (retrieval.metadata_and_body, check_docs.metadata):
            with self.subTest(parser=parser.__module__):
                with self.assertRaisesRegex(ValueError, "Duplicate frontmatter document-kind"):
                    parser(text)
        self.current.write_text(text)
        with self.assertRaisesRegex(ValueError, "Duplicate frontmatter document-kind"):
            retrieval.selected_paths(self.root)
        with self.assertRaisesRegex(ValueError, "Duplicate frontmatter document-kind"):
            retrieval.chunk_document(self.current, self.root, 20)
        self.manifest.unlink()
        with self.assertRaisesRegex(ValueError, "Duplicate frontmatter document-kind"):
            retrieval.selected_paths(self.root)

    def test_unsupported_document_kind_fails_closed_in_every_default_entry(self):
        for kind in ("[navigation]", "!tag navigation", "unknown-kind", ""):
            with self.subTest(kind=kind):
                self.current.write_text(f"---\ndocument-kind: {kind}\n---\n# Index\nRoutes only.\n")
                self.manifest.write_text(json.dumps({"documents": ["systems/current.md"]}))
                with self.assertRaisesRegex(ValueError, "Unsupported document-kind scalar"):
                    retrieval.selected_paths(self.root)
                with self.assertRaisesRegex(ValueError, "Unsupported document-kind scalar"):
                    retrieval.chunk_document(self.current, self.root, 20)
                self.manifest.unlink()
                with self.assertRaisesRegex(ValueError, "Unsupported document-kind scalar"):
                    retrieval.selected_paths(self.root)

    def test_history_keeps_its_own_opt_in_and_authority(self):
        # The real accepted archive uses explicit-history-only, which predates
        # the current-corpus selector and must not be rejected by its grammar.
        old = self.write("docs/history/engineering/old.md", "---\nretrieval: explicit-history-only\nauthority: historical-non-authoritative\nstatus: Approved\n---\n# Old rule\nOld instruction.\n")
        self.write("docs/history/engineering/retrieval-corpus.json", json.dumps({"documents": ["history/engineering/old.md"]}))
        self.assertEqual(retrieval.selected_paths(self.root, historical=True), [old])
        chunk = retrieval.chunk_document(old, self.root, 20, historical=True)[0]
        self.assertEqual(chunk["authority"], HISTORICAL_AUTHORITY)
        self.assertIn("NOT current instructions", chunk["text"])

    def test_repository_fallback_matches_manifest_without_extra_packets(self):
        source = Path(__file__).resolve().parents[2]
        expected = {p.relative_to(source).as_posix() for p in retrieval.selected_paths(source)}
        # Copy only the bounded fallback candidate set; no historical content is
        # needed to prove the current-selection equality.
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidates = [p for p in (source / "docs").rglob("*.md")
                          if p.relative_to(source / "docs").parts[0] in FOCUSED
                          or p.relative_to(source / "docs").as_posix() in {"README.md", "MATERIAL_LAB.md"}]
            candidates += [source / "README.md", source / "AGENTS.md"]
            for path in candidates:
                target = root / path.relative_to(source)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)
            actual = {p.relative_to(root).as_posix() for p in retrieval.selected_paths(root)}
        self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()
