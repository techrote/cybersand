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

    def test_presentation_hash_binds_world_context_not_just_local_moves(self):
        # Candidate membership can be identical for different World bounds.
        # The model-facing hash must nevertheless distinguish those contexts.
        original = self.catalog()
        wider = m.legal_catalog(
            self.before, self.options,
            width=self.f.width + 1, height=self.f.height,
            legal_cell=self.f.legal,
        )
        self.assertEqual(original["catalog"], wider["catalog"])
        self.assertEqual(
            original["synthetic_legal_catalog_sha256"],
            wider["synthetic_legal_catalog_sha256"],
        )
        self.assertNotEqual(m.model_presentation_hash(original),
                            m.model_presentation_hash(wider))
        self.assertEqual(m.model_presentation_hash(original),
                         m.model_presentation_hash(copy.deepcopy(original)))

    def test_presentation_rejects_stale_and_counterfeit_catalog_custody(self):
        good = self.catalog()
        self.assertEqual(m.model_presentation_hash(good),
                         m.model_presentation_hash(copy.deepcopy(good)))
        modified = copy.deepcopy(good)
        move = next(row for row in modified["catalog"] if row["id"] == "E1")
        move["cursor_after"] = list(self.before)
        with self.assertRaisesRegex(m.PreflightError, "digest"):
            m.model_presentation_hash(modified)
        forged_native = copy.deepcopy(good)
        forged_native["native_legal_catalog_sha256"] = "f" * 64
        with self.assertRaisesRegex(m.PreflightError, "native"):
            m.model_presentation_hash(forged_native)
        forged_field = copy.deepcopy(good)
        forged_field["native_receipt"] = {"accepted": True}
        with self.assertRaisesRegex(m.PreflightError, "envelope"):
            m.model_presentation_hash(forged_field)
        wrong_dimensions = copy.deepcopy(good)
        wrong_dimensions["world_size"][0] = True
        with self.assertRaisesRegex(m.PreflightError, "dimensions"):
            m.model_presentation_hash(wrong_dimensions)

    def test_presentation_rechecks_sweep_even_with_rehashed_digest(self):
        # A caller can always recompute a synthetic hash. The presentation
        # helper must still reject contradictory candidate geometry.
        for corrupt in ("sweep", "stop", "cursor_origin"):
            modified = copy.deepcopy(self.catalog())
            move = next(row for row in modified["catalog"] if row["id"] == "E1")
            if corrupt == "sweep":
                move["swept_xy"][0] = list(self.before)  # zero-length cardinal step
            elif corrupt == "stop":
                stop = next(row for row in modified["catalog"] if row["id"] == "STOP")
                stop["brush_state"] = "down"
            else:
                move["cursor_before"][0] += 1  # mixed pre-decision cursor
            modified["synthetic_legal_catalog_sha256"] = m._hash(modified["catalog"])
            with self.subTest(corrupt=corrupt):
                with self.assertRaises(m.PreflightError):
                    m.model_presentation_hash(modified)

    def test_legality_authority_must_return_real_booleans(self):
        # A truthy string such as "DENY" must never admit a cell.
        with self.assertRaisesRegex(m.PreflightError, "boolean"):
            m.legal_catalog(self.before, self.options, width=self.f.width,
                            height=self.f.height, legal_cell=lambda _: "DENY")
        with self.assertRaisesRegex(m.PreflightError, "boolean"):
            m.legal_catalog(self.before, self.options, width=self.f.width,
                            height=self.f.height,
                            legal_cell=lambda p: "ALLOW" if p != self.before else True)
        self.assertIsInstance(self.catalog()["synthetic_legal_catalog_sha256"], str)

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
        # Both start and endpoint are legal, but one intermediate cell is Z.
        # This must fail despite a legal destination (endpoint-only trap).
        selected = None
        for blocked in sorted(self.f.material_z):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                start = (blocked[0] - dx, blocked[1] - dy)
                end = (blocked[0] + dx, blocked[1] + dy)
                if self.f.legal(start) and self.f.legal(end):
                    selected = (start, blocked, end)
                    break
            if selected:
                break
        self.assertIsNotNone(selected)
        origin, blocked, endpoint = selected
        self.assertTrue(self.f.legal(origin) and self.f.legal(endpoint))
        options = [{"candidate_id": "STOP", "path": [], "stop": True},
                   {"candidate_id": "BAD", "path": [blocked, endpoint], "stop": False}]
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
