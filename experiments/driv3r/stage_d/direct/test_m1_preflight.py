"""No-network M1 contract preflight tests, including hostile catalog mutations."""
import copy
from pathlib import Path
import tempfile
import unittest

from experiments.driv3r.stage_d.direct import m1_preflight as m
from experiments.driv3r.stage_d.direct import offline as d


class CatalogPreflightTests(unittest.TestCase):
    def setUp(self):
        self.f = d.routing_fixture("gate", "development")
        self.before = self.f.start
        self.options = d.candidates(self.f, self.before, (1, 2, 4, 8))

    def catalog(self, opts=None):
        return m.legal_catalog(self.before, self.options if opts is None else opts,
                               width=self.f.width, height=self.f.height,
                               legal_cell=self.f.legal)

    def test_frozen_m1_identity_and_no_native_claim(self):
        self.assertEqual(m.M1_SOURCE_COMMIT, "8fa90de6be209ed0b7bd125039e6ec8b332fb1a6")
        self.assertEqual(m.M1_SCHEMA_SHA256, "ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d")
        result = self.catalog()
        self.assertIsNone(result["native_legal_catalog_sha256"])
        self.assertTrue(all(x["material_effect"] == "none" and x["brush_state"] == "up"
                            for x in result["catalog"]))

    def test_native_candidate_legality_digest_excludes_presentation_order(self):
        result = self.catalog()
        shuffled = self.catalog(list(reversed(self.options)))
        self.assertEqual(result["synthetic_legal_catalog_sha256"],
                         shuffled["synthetic_legal_catalog_sha256"])
        self.assertEqual(result["catalog"], shuffled["catalog"])

    def test_annotation_or_display_order_changes_only_presentation(self):
        result = self.catalog()
        h = result["synthetic_legal_catalog_sha256"]
        ids = [x["id"] for x in result["catalog"]]
        a1 = m.model_presentation_hash(result)
        a2 = m.model_presentation_hash(result, {ids[0]: {"soft_attraction": 0.75}})
        a3 = m.model_presentation_hash(result, order=list(reversed(ids)))
        self.assertNotEqual(a1, a2)
        self.assertNotEqual(a1, a3)
        self.assertEqual(h, result["synthetic_legal_catalog_sha256"])
        with self.assertRaises(m.PreflightError):
            m.model_presentation_hash(result, {"FORGED": 1})
        with self.assertRaises(m.PreflightError):
            m.model_presentation_hash(result, order=ids[:-1])
        with self.assertRaises(m.PreflightError):
            m.model_presentation_hash(result, {ids[0]: float("nan")})

    def test_stop_is_inert_and_unique(self):
        stop = next(o for o in self.catalog()["catalog"] if o["id"] == "STOP")
        self.assertEqual(stop["swept_xy"], [])
        self.assertEqual(stop["mode"], "stop")
        self.assertEqual(stop["cursor_before"], stop["cursor_after"])
        for opts in ([o for o in self.options if not o.stop],
                     list(self.options) + [self.options[0]]):
            with self.assertRaises(m.PreflightError):
                self.catalog(opts)

    def test_endpoint_valid_but_middle_crosses_material_z(self):
        pos = self.f.start
        # Construct a blocked swept cell. Whole-segment legality, rather
        # than merely endpoint-range checks, must reject it.
        selected = None
        for p in self.f.material_z:
            for q in ((p[0]-1,p[1]), (p[0]+1,p[1]), (p[0],p[1]-1), (p[0],p[1]+1)):
                if self.f.legal(q):
                    selected = (q, p)
                    break
            if selected:
                break
        self.assertIsNotNone(selected)
        origin, blocked = selected
        options = [{"candidate_id": "STOP", "path": [], "stop": True},
                   {"candidate_id": "BAD", "path": [blocked], "stop": False}]
        with self.assertRaisesRegex(m.PreflightError, "Swept segment"):
            m.legal_catalog(origin, options, width=self.f.width, height=self.f.height,
                            legal_cell=self.f.legal)

    def test_noncardinal_jump_and_invalid_bounds_rejected(self):
        p = self.before
        opts = [{"candidate_id": "STOP", "path": [], "stop": True},
                {"candidate_id": "TELEPORT", "path": [(p[0]+2,p[1])], "stop": False}]
        with self.assertRaisesRegex(m.PreflightError, "Noncardinal"):
            self.catalog(opts)
        with self.assertRaises(m.PreflightError):
            m.legal_catalog(p, self.options, width=True, height=self.f.height,
                            legal_cell=self.f.legal)

    def test_schema_digest_checks_actual_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/"experiments/driv3r/d_common/v1/interface.schema.json"
            path.parent.mkdir(parents=True)
            path.write_text("{}")
            with self.assertRaisesRegex(m.PreflightError, "SHA-256 mismatch"):
                m.assert_approved_schema(Path(temp))

    def test_replay_bound_episode_and_all_null_native_evidence(self):
        for fixture in (d.wall_fixture("step", "development"), self.f):
            policy = "contour_astar" if fixture.task == "wall_offset" else "astar"
            for lengths in ((1,), (1, 2, 4, 8)):
                with self.subTest(fixture=fixture.fixture_id, lengths=lengths):
                    record = d.run_episode(fixture, policy, lengths=lengths)
                    report = m.preflight_episode(fixture, record)
                    self.assertEqual(len(report["decision_preflights"]), len(record["events"]))
                    self.assertFalse(report["d_common_record_emitted"])
                    self.assertIsNone(report["native_world_ref"])
                    self.assertEqual(report["native_receipts"], 0)
                    self.assertTrue(all(x["native_receipt_ref"] is None and
                                        x["native_legal_catalog_sha256"] is None
                                        for x in report["decision_preflights"]))

    def test_tampered_offline_trajectory_refused(self):
        record = d.run_episode(self.f, "astar")
        forged = copy.deepcopy(record)
        forged["events"][0]["choice_id"] = "FORGED"
        with self.assertRaises(ValueError):
            m.preflight_episode(self.f, forged)

    def test_heldout_policy_outcomes_remain_sealed(self):
        heldout = d.wall_fixture("switchback", "heldout")
        with self.assertRaisesRegex(m.PreflightError, "Held-out"):
            m.preflight_episode(heldout, {"events": []})


if __name__ == "__main__":
    unittest.main()
