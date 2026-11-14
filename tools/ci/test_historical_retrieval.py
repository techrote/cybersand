"""Prevent historical prose from becoming ordinary implementation context."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "docs"))
import retrieval_eval as retrieval
from retrieval_policy import HISTORICAL_AUTHORITY, require_authority
import check_docs


class HistoricalRetrievalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.current = self.write("docs/systems/current.md", "# Current contract\nA present contract.\n")
        self.old = self.write("docs/history/engineering/old.md", "---\nstatus: Approved\n---\n# Old rule\n" + "must never use this old implementation " * 80)
        self.manifest = self.write("docs/reference/retrieval-corpus.json", json.dumps({"documents": ["systems/current.md"]}))
        self.history_manifest = self.write("docs/history/engineering/retrieval-corpus.json", json.dumps({"documents": ["history/engineering/old.md"]}))

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def test_default_selection_excludes_archive_and_does_not_expand_links(self):
        self.current.write_text("# Current\n[History](../history/engineering/old.md)\n", encoding="utf-8")
        self.assertEqual(retrieval.selected_paths(self.root), [self.current])
        chunks = retrieval.chunk_document(self.current, self.root, 20)
        self.assertTrue(all("must never" not in c["text"] for c in chunks))

    def test_default_manifest_cannot_smuggle_archive_into_current_answers(self):
        self.manifest.write_text(json.dumps({"documents": ["history/engineering/old.md"]}))
        with self.assertRaisesRegex(ValueError, "Authority boundary"):
            retrieval.selected_paths(self.root)

    def test_direct_default_chunking_cannot_bypass_selection(self):
        with self.assertRaisesRegex(ValueError, "Authority boundary"):
            retrieval.chunk_document(self.old, self.root, 20)

    def test_every_historical_chunk_overrides_an_old_approved_label(self):
        chunks = retrieval.chunk_document(self.old, self.root, 20, historical=True)
        self.assertGreater(len(chunks), 3)
        for chunk in chunks:
            self.assertEqual(chunk["authority"], HISTORICAL_AUTHORITY)
            self.assertIn("NOT current instructions", chunk["text"])
            self.assertIn("source-status: Approved (historical source label only)", chunk["text"])
            self.assertIn("explicit-history-only", chunk["text"])

    def test_missing_source_metadata_does_not_remove_historical_envelope(self):
        self.old.write_text("# Unlabelled archive\nAn old instruction.\n")
        self.assertEqual(retrieval.chunk_document(self.old, self.root, 20, True)[0]["authority"], HISTORICAL_AUTHORITY)

    def test_opt_in_selects_only_explicit_history_and_requires_its_manifest(self):
        self.assertEqual(retrieval.selected_paths(self.root, True), [self.old])
        self.history_manifest.unlink()
        with self.assertRaisesRegex(ValueError, "manifest is required"):
            retrieval.selected_paths(self.root, True)

    def test_history_manifest_cannot_mix_current_guidance(self):
        self.history_manifest.write_text(json.dumps({"documents": ["systems/current.md"]}))
        with self.assertRaisesRegex(ValueError, "Authority boundary"):
            retrieval.selected_paths(self.root, True)

    def test_missing_default_manifest_still_excludes_history(self):
        self.manifest.unlink()
        self.assertEqual(retrieval.selected_paths(self.root), [self.current])

    def test_history_tag_outside_archive_fails_closed(self):
        self.current.write_text("---\nauthority: historical-non-authoritative\n---\n# Copied archive\nOld rule.\n")
        with self.assertRaisesRegex(ValueError, "Authority boundary"):
            retrieval.selected_paths(self.root)

    def test_quoted_history_tags_cannot_bypass_any_default_entry(self):
        for quote in ('"', "'"):
            with self.subTest(quote=quote):
                self.current.write_text(f"---\nauthority: {quote}{HISTORICAL_AUTHORITY}{quote}\n---\n# Copied archive\nOld rule.\n")
                self.manifest.write_text(json.dumps({"documents": ["systems/current.md"]}))
                with self.assertRaisesRegex(ValueError, "Authority boundary"):
                    retrieval.selected_paths(self.root)
                with self.assertRaisesRegex(ValueError, "Authority boundary"):
                    retrieval.chunk_document(self.current, self.root, 20)
                self.manifest.unlink()
                with self.assertRaisesRegex(ValueError, "Authority boundary"):
                    retrieval.selected_paths(self.root)

    def test_unknown_authority_syntax_fails_closed(self):
        self.current.write_text("---\nauthority: [historical-non-authoritative]\n---\n# Copied archive\nOld rule.\n")
        with self.assertRaisesRegex(ValueError, "Unsupported retrieval authority"):
            retrieval.selected_paths(self.root)

    def test_authority_key_spellings_cannot_hide_historical_copies(self):
        for key in ('"authority"', "'authority'", 'authority ', '  authority', r'"\u0061uthority"'):
            with self.subTest(key=key):
                text = f"---\n{key}: {HISTORICAL_AUTHORITY}\n---\n# Copied archive\nOld rule.\n"
                self.current.write_text(text)
                self.manifest.write_text(json.dumps({"documents": ["systems/current.md"]}))
                with self.assertRaisesRegex(ValueError, "Authority boundary"):
                    retrieval.selected_paths(self.root)
                with self.assertRaisesRegex(ValueError, "Authority boundary"):
                    retrieval.chunk_document(self.current, self.root, 20)
                with self.assertRaisesRegex(ValueError, "Authority boundary"):
                    require_authority(self.current, self.root, historical=False, metadata=check_docs.metadata(text))
                self.manifest.unlink()
                with self.assertRaisesRegex(ValueError, "Authority boundary"):
                    retrieval.selected_paths(self.root)

    def test_duplicate_authority_declarations_fail_closed(self):
        text = f"---\nauthority: {HISTORICAL_AUTHORITY}\n\"authority\": current-documentation\n---\nOld rule.\n"
        for parser in (retrieval.metadata_and_body, check_docs.metadata):
            with self.subTest(parser=parser.__module__):
                with self.assertRaisesRegex(ValueError, "Duplicate frontmatter authority"):
                    parser(text)

    def test_unsupported_authority_key_syntax_is_rejected(self):
        text = f"---\n&label authority: {HISTORICAL_AUTHORITY}\n---\nOld rule.\n"
        for parser in (retrieval.metadata_and_body, check_docs.metadata):
            with self.subTest(parser=parser.__module__):
                with self.assertRaisesRegex(ValueError, "Unsupported frontmatter key"):
                    parser(text)

    def test_shared_key_reader_preserves_simple_block_lists(self):
        text = '---\n"authority" : owner-confirmed-intent\ncanonical-for:\n  - owner-intent\n---\n# Current intent\n'
        meta = check_docs.metadata(text)
        self.assertEqual(meta["canonical-for"], ["owner-intent"])
        self.assertEqual(meta["authority"], "owner-confirmed-intent")
        self.assertEqual(retrieval.metadata_and_body(text)[0]["authority"], "owner-confirmed-intent")

    def test_symlink_alias_does_not_escape_archive_classification(self):
        alias = self.root / "docs/systems/alias.md"
        try:
            alias.symlink_to(self.old)
        except (NotImplementedError, OSError) as exc:
            self.skipTest(str(exc))
        self.manifest.write_text(json.dumps({"documents": ["systems/alias.md"]}))
        with self.assertRaisesRegex(ValueError, "Authority boundary"):
            retrieval.selected_paths(self.root)


if __name__ == "__main__":
    unittest.main()
