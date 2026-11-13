from copy import deepcopy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from compiler import canonical_json, digest, structural_signature
from corpus import build_candidates, validate_splits


class CorpusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = build_candidates()

    def test_pilot_counts_and_entire_structural_group_partitions(self):
        m = self.manifest
        self.assertEqual(m["native_case_count"], 30)
        self.assertEqual(m["distinct_program_count"], 15)
        self.assertEqual(m["split_counts"], {"TRAIN": 12, "DEVELOPMENT": 12, "FINAL": 6})
        self.assertEqual(m["group_counts"], {"TRAIN": 6, "DEVELOPMENT": 6, "FINAL": 3})
        self.assertEqual(m["state"], "native-admission-pending")
        for family in ("greebles", "pipework", "architecture"):
            groups = [g for g in m["groups"] if g["family"] == family]
            self.assertEqual(len(groups), 5)
            visible = [g for g in groups if g["split"] != "FINAL"]
            self.assertEqual(len(visible), 4)
        for group in m["groups"]:
            rows = [e for e in m["examples"] if e["group_id"] == group["group_id"]]
            self.assertEqual(len(rows), 2)
            self.assertEqual({r["split"] for r in rows}, {group["split"]})

    def test_generation_is_deterministic_and_never_self_admits(self):
        self.assertEqual(self.manifest, build_candidates())
        for row in self.manifest["examples"]:
            self.assertFalse(row["native_qualified"])
            self.assertNotIn("native_admission", row)
            self.assertEqual(row["completion"], canonical_json(row["program"]))

    def test_final_is_excluded_from_public_gallery_selection(self):
        m = build_candidates(include_final=False)
        self.assertEqual(m["native_case_count"], 24)
        self.assertNotIn("FINAL", m["split_counts"])
        self.assertTrue(all(r["split"] != "FINAL" for r in m["examples"]))

    def test_seed_or_paraphrase_cannot_cross_partition(self):
        rows = deepcopy(self.manifest["examples"][:2])
        rows[1]["split"] = "DEVELOPMENT"
        rows[1]["prompt"] = "A different paraphrase does not create a new structural group."
        with self.assertRaisesRegex(ValueError, "partition"):
            validate_splits(rows)

    def test_new_id_or_style_tuning_cannot_launder_heldout_structure(self):
        row = deepcopy(next(r for r in self.manifest["examples"] if r["split"] == "FINAL"))
        copy = deepcopy(row)
        copy.update(id="invented-new-id", group_id="invented-new-group", structural_group="invented-new-group", split="TRAIN", prompt="New words.")
        copy["program"]["variation"] = 0
        for panel in copy["program"]["components"]:
            panel["density"] = 1
        copy["completion"] = canonical_json(copy["program"])
        copy["program_sha256"] = digest(copy["program"])
        copy["structural_signature_sha256"] = digest(structural_signature(copy["program"]))
        with self.assertRaisesRegex(ValueError, "partition"):
            validate_splits([row, copy])

    def test_bindings_duplicate_ids_and_aliases_are_checked(self):
        row = deepcopy(self.manifest["examples"][0])
        with self.assertRaisesRegex(ValueError, "duplicate"):
            validate_splits([row, deepcopy(row)])
        for key, bad in (("program_sha256", "0"*64), ("structural_group", "wrong"),
                         ("completion", "{}"), ("family", "pipework"), ("split", "test")):
            changed = deepcopy(row); changed[key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_splits([changed])


if __name__ == "__main__":
    unittest.main()
