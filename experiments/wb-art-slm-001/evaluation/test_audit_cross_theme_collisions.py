"""Adversarial, model-free tests for native-output cross-theme collision audit."""
import importlib.util
from pathlib import Path
import unittest

MODULE = Path(__file__).with_name("audit_cross_theme_collisions.py")
spec = importlib.util.spec_from_file_location("cross_theme_audit", MODULE)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def fixtures():
    themes = sorted(audit.THEMES)
    # 23 structural groups, 34 requests, 5 incorrect AI labels.
    theme_groups = {t: (1 if t == "coral" else 2) for t in themes}
    # Produce 23 groups: one theme has one group; other eleven have two.
    items = []
    for theme, n in theme_groups.items():
        for j in range(n):
            items.append(dict(id=f"q{len(items)+1:03d}", theme=theme,
                              group_id=f"{theme}:g{j}", seeds=[17, 73],
                              png_sha256=["a", "b"], readback_sha256=["c", "d"],
                              symbolic_theme_correct=True, symbolic_motif_correct=True))
    # 23 items so far: add 11 duplicates of groups to reach 34.
    for i in range(11):
        old = items[i]
        items.append({**old, "id": f"q{len(items)+1:03d}"})
    rows = [{"id": z["id"], "label": z["theme"], "quality": "", "variety": ""} for z in items]
    # Two doubled structural groups and one singleton fail: 29/34 and 20/23.
    # Two doubled groups have exactly 2 rows; first item group repeats as item[23], second as item[24].
    for i in (0, 1, 23, 24, 12):
        z = rows[i]; z["label"] = next(t for t in themes if t != items[i]["theme"])
    pair_ids = [("q001", "q024"), ("q002", "q025"), ("q003", "q026")]
    near = [dict(cards=list(p), seed_17_jaccard=0.95,
                 seed_73_jaccard=0.97, exact_png_pair=False) for p in pair_ids]
    # Make only q001/q024 an explicit cross-theme pair, others same themes.
    near[0]["cards"] = ["q001", "q012"]
    return (
        dict(schema_version=1, candidate="LFM350-step400", original_requests=36,
             first_pass_rejected=2, native_admitted_requests=34, model_adapted=True,
             review_token="tok", excluded=[{"theme": "coral", "failure": "first-pass-invalid"}]*2,
             items=items),
        dict(review_token="tok", reviewer_type="AI visual review", stimulus_sha256=audit.HTML_SHA256, rows=rows),
        dict(html_sha256=audit.HTML_SHA256, labels_opened=False,
             cards=34, displayed_native_images=68, admitted_display_cards=34, host_seeds=[17, 73],
             per_card_blind_metrics=[{"id": z["id"]} for z in items], cross_request_near_pairs=near)
    )


class Tests(unittest.TestCase):
    def setUp(self):
        self.k, self.r, self.p = fixtures()

    def test_valid_group_aware_score_and_cross_theme_detection(self):
        result = audit.analyze(self.k, self.r, self.p)
        self.assertEqual(result["ai_correct_admitted"], 29)
        self.assertEqual(result["group_macro_admitted"], round(20/23, 6))
        self.assertEqual(len(result["cross_theme_near_collisions"]), 1)
        self.assertEqual(result["same_theme_near_pairs"], 2)
        self.assertEqual(result["decision"], "HOLD")

    def test_changed_frozen_review_refused(self):
        self.r["rows"][12]["label"] = self.k["items"][12]["theme"]
        with self.assertRaisesRegex(ValueError, "independently scored"):
            audit.analyze(self.k, self.r, self.p)

    def test_missing_card_refused(self):
        self.r["rows"].pop()
        with self.assertRaisesRegex(ValueError, "missing, added"):
            audit.analyze(self.k, self.r, self.p)

    def test_duplicate_card_refused(self):
        self.r["rows"][0]["id"] = self.r["rows"][1]["id"]
        with self.assertRaisesRegex(ValueError, "duplicate blind-review"):
            audit.analyze(self.k, self.r, self.p)

    def test_token_mutation_refused(self):
        self.r["review_token"] = "fabricated"
        with self.assertRaisesRegex(ValueError, "frozen AI-only"):
            audit.analyze(self.k, self.r, self.p)

    def test_invalid_seeds_refused(self):
        self.k["items"][0]["seeds"] = [17, 17]
        with self.assertRaisesRegex(ValueError, "unqualified native"):
            audit.analyze(self.k, self.r, self.p)

    def test_invented_human_ratings_refused(self):
        self.r["rows"][0]["quality"] = 5
        with self.assertRaisesRegex(ValueError, "fabricated human"):
            audit.analyze(self.k, self.r, self.p)

    def test_similarity_below_cutoff_refused(self):
        self.p["cross_request_near_pairs"][0]["seed_17_jaccard"] = 0.8
        with self.assertRaisesRegex(ValueError, "below the declared"):
            audit.analyze(self.k, self.r, self.p)

    def test_missing_refused_original_records_refused(self):
        self.k["excluded"].pop()
        with self.assertRaisesRegex(ValueError, "refused original"):
            audit.analyze(self.k, self.r, self.p)

    def test_source_file_tampering_refused(self):
        from tempfile import TemporaryDirectory
        with TemporaryDirectory() as d:
            path = Path(d) / "fake.json"
            path.write_text('{"a": 1}')
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                audit.load_pinned(path, audit.KEY_SHA256)


if __name__ == "__main__":
    unittest.main()
