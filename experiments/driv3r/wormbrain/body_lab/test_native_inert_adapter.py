"""Body Lab external-source native-inert adapter: pure mock-fixture tests only.

No test starts Godot, downloads an SLM or authenticates native receipts.
"""
from dataclasses import replace
import unittest

from experiments.driv3r.wormbrain.body_lab.body_v2 import BodyOptions
from experiments.driv3r.wormbrain.body_lab.native_inert_adapter import (
    ExternalSnapshot, offered, prepare, check_fixture_transcript,
)
from experiments.driv3r.wormbrain.body_lab.preflight import (
    FourSlotPreflight, HostView, Lease, Refusal, INK,
)

SOURCE = "b4079e74207d7a70992c48ebd70e9c7b2016f463"


def lease(name="a", runner="runner-0", world=None):
    return Lease(name, "wrangler", runner, world or f"world-{name}", "NO_MODEL", 570)


def blank(protected=()):
    return HostView((0,) * (96 * 96), protected)


def snapshot(l, *, mat=None, logical=0, cursor=(12, 24), epoch=(1, 2, 3),
             retired=False):
    return ExternalSnapshot(
        l.id, l.runner, l.world, SOURCE, epoch, cursor, logical,
        mat or blank(), retired)


def actions(l, original, snap, action, *, options=BodyOptions(4, True, True),
            decisions=0):
    menu = offered(l, original, snap, options=options,
                   expected_source_sha=SOURCE, decisions=decisions)
    plan = prepare(l, original, snap, action, menu["offer_token"],
                   options=options, expected_source_sha=SOURCE,
                   decisions=decisions)
    return menu, plan


def mock_host_step(s, op):
    """Mock transition, *never* an actual Godot/native PAINT response."""
    kind = op["kind"]
    target = tuple(op["target"])
    values = list(s.material.material)
    cursor = s.cursor
    logical = s.logical_moves
    retired = s.retired
    changed = 0
    if kind == "PAINT_ONE":
        values[target[1] * 96 + target[0]] = INK
        changed = 1
    elif kind == "CURSOR_ONE":
        cursor = target
        logical += 1
    elif kind == "STOP":
        retired = True
    else:
        raise AssertionError(kind)
    after = replace(s, material=HostView(tuple(values), s.material.protected),
                    cursor=cursor, logical_moves=logical,
                    epoch=(s.epoch[0], s.epoch[1] + 1, s.epoch[2]),
                    retired=retired)
    return (kind, changed, after)


def transcript(snap, plan):
    rows = []
    for op in plan["operations"]:
        row = mock_host_step(snap, op)
        rows.append(row)
        snap = row[2]
    return rows


class NativeInert(unittest.TestCase):
    def test_four_cells_compile_to_eight_one_cell_operations(self):
        l = lease()
        before = snapshot(l)
        menu, plan = actions(l, before.material, before, "INK_E_4")
        self.assertEqual(len(plan["operations"]), 8)
        self.assertEqual([r["kind"] for r in plan["operations"]],
                         ["PAINT_ONE", "CURSOR_ONE"] * 4)
        self.assertEqual(menu["already_inked_cells_this_run"], 0)
        self.assertFalse(plan["native_execution"])
        self.assertFalse(plan["native_receipts_authenticated"])
        rows = transcript(before, plan)
        checked = check_fixture_transcript(plan, before, rows)
        self.assertFalse(checked["native_authenticated"])
        self.assertEqual(rows[-1][2].cursor, (16, 24))
        self.assertEqual(rows[-1][2].logical_moves, 4)
        self.assertEqual(sum(x == INK for x in rows[-1][2].material.material), 4)

    def test_penup_over_owned_ink_preserves_material_and_paint_count(self):
        l = lease()
        original = blank()
        start = snapshot(l)
        _, ink = actions(l, original, start, "INK_E_4")
        painted = transcript(start, ink)[-1][2]
        menu, lift = actions(l, original, painted, "LIFT_W_4", decisions=1)
        self.assertEqual(menu["already_inked_cells_this_run"], 4)
        self.assertEqual(len(lift["operations"]), 4)
        self.assertTrue(all(op["kind"] == "CURSOR_ONE" for op in lift["operations"]))
        after = transcript(painted, lift)[-1][2]
        self.assertEqual(after.material, painted.material)
        self.assertEqual(after.cursor, (12, 24))
        self.assertEqual(after.logical_moves, 8)

    def test_swept_cannot_cross_obstacle_or_protection(self):
        l = lease()
        mat = list(blank().material)
        mat[24 * 96 + 14] = 61
        initial = HostView(tuple(mat), ((10, 23, 1, 3),))
        s = snapshot(l, mat=initial)
        menu = offered(l, initial, s, options=BodyOptions(4, True, True),
                       expected_source_sha=SOURCE, decisions=0)
        self.assertIn("INK_E_1", menu["legal_ids"])
        self.assertNotIn("INK_E_2", menu["legal_ids"])
        self.assertNotIn("LIFT_E_2", menu["legal_ids"])
        self.assertNotIn("LIFT_W_2", menu["legal_ids"])
        with self.assertRaises(Refusal):
            prepare(l, initial, s, "INK_E_4", menu["offer_token"],
                    options=BodyOptions(4, True, True),
                    expected_source_sha=SOURCE, decisions=0)

    def test_stale_same_menu_different_epoch_refused(self):
        l = lease()
        s = snapshot(l)
        menu = offered(l, s.material, s, options=BodyOptions(4, True, True),
                       expected_source_sha=SOURCE, decisions=0)
        later = replace(s, epoch=(1, 3, 3))
        self.assertEqual(
            offered(l, s.material, later, options=BodyOptions(4, True, True),
                    expected_source_sha=SOURCE, decisions=0)["legal_ids"],
            menu["legal_ids"])
        with self.assertRaises(Refusal):
            prepare(l, s.material, later, "INK_E_1", menu["offer_token"],
                    options=BodyOptions(4, True, True),
                    expected_source_sha=SOURCE, decisions=0)

    def test_cross_world_and_unpinned_source_and_retirement_refuse(self):
        l = lease()
        s = snapshot(l)
        for broken in (replace(s, world="other"),
                       replace(s, source_sha="a" * 40),
                       replace(s, retired=True)):
            with self.subTest(broken=broken.world), self.assertRaises(Refusal):
                offered(l, s.material, broken, expected_source_sha=SOURCE, decisions=0)
        with self.assertRaises(Refusal):
            offered(l, s.material, s, expected_source_sha="not-a-source", decisions=0)

    def test_near_ink_ceiling_filters_longer_strokes(self):
        l = lease()
        initial = blank()
        cells = list(initial.material)
        for i in range(35):
            cells[i] = INK
        s = snapshot(l, mat=HostView(tuple(cells)))
        menu = offered(l, initial, s, options=BodyOptions(4, False, False),
                       expected_source_sha=SOURCE, decisions=12)
        self.assertIn("INK_E_1", menu["legal_ids"])
        self.assertNotIn("INK_E_2", menu["legal_ids"])
        self.assertEqual(menu["already_inked_cells_this_run"], 35)

    def test_decision_and_logical_cursor_hard_caps_fail_closed(self):
        l = lease()
        s = snapshot(l)
        menu = offered(l, s.material, s, expected_source_sha=SOURCE, decisions=36)
        self.assertEqual(menu["legal_ids"], ["STOP"])
        with self.assertRaises(Refusal):
            prepare(l, s.material, s, "INK_E_1", menu["offer_token"],
                    expected_source_sha=SOURCE, decisions=36)
        full = snapshot(l, logical=64)
        menu = offered(l, full.material, full, options=BodyOptions(4, True, True),
                       expected_source_sha=SOURCE, decisions=25)
        self.assertEqual(menu["legal_ids"], ["STOP"])
        with self.assertRaises(Refusal):
            offered(l, s.material, s, expected_source_sha=SOURCE, decisions=128)

    def test_stop_requires_retirement_in_fixture(self):
        l = lease()
        s = snapshot(l)
        _, plan = actions(l, s.material, s, "STOP")
        success = check_fixture_transcript(plan, s, transcript(s, plan))
        self.assertFalse(success["native_authenticated"])
        wrong = [( "STOP", 0, replace(s, epoch=(1, 3, 3)) )]
        with self.assertRaises(Refusal):
            check_fixture_transcript(plan, s, wrong)

    def test_adversarial_partial_foreign_material_and_cursor_receipts(self):
        l = lease()
        s = snapshot(l)
        _, plan = actions(l, s.material, s, "INK_E_2")
        rows = transcript(s, plan)
        with self.assertRaises(Refusal):
            check_fixture_transcript(plan, s, rows[:-1])
        bad = list(rows)
        bad[0] = (bad[0][0], 0, bad[0][2])
        with self.assertRaises(Refusal):
            check_fixture_transcript(plan, s, bad)
        bad = list(rows)
        bad[1] = (bad[1][0], bad[1][1],
                  replace(bad[1][2], world="other-world"))
        with self.assertRaises(Refusal):
            check_fixture_transcript(plan, s, bad)
        bad = list(rows)
        broken = list(bad[0][2].material.material)
        broken[24 * 96 + 13] = 61
        bad[0] = ("PAINT_ONE", 1,
                  replace(bad[0][2], material=HostView(tuple(broken))))
        with self.assertRaises(Refusal):
            check_fixture_transcript(plan, s, bad)
        bad = list(rows)
        bad[1] = ("CURSOR_ONE", 0,
                  replace(bad[1][2], logical_moves=0))
        with self.assertRaises(Refusal):
            check_fixture_transcript(plan, s, bad)

    def test_option_and_lease_bindings_reject_unoffered_actions(self):
        l = lease()
        s = snapshot(l)
        menu = offered(l, s.material, s, options=BodyOptions(1, False, False),
                       expected_source_sha=SOURCE, decisions=0)
        for action in ("INK_E_4", "LIFT_E_1", "SAVE_ANCHOR", "RETRACE_1",
                       "INK_E_1;rm -rf /"):
            with self.subTest(action=action), self.assertRaises(Refusal):
                prepare(l, s.material, s, action, menu["offer_token"],
                        options=BodyOptions(1, False, False),
                        expected_source_sha=SOURCE, decisions=0)

    def test_four_isolated_stub_transcripts_not_four_live_models(self):
        roster = FourSlotPreflight()
        originals = {}
        for i in range(4):
            l = lease(f"worm-{i}", runner=f"runner-{i//2}")
            roster.register(l)
            s = snapshot(l)
            _, plan = actions(l, s.material, s, "INK_E_1")
            checked = check_fixture_transcript(plan, s, transcript(s, plan))
            self.assertEqual(checked["operations_checked"], 2)
            self.assertFalse(checked["native_authenticated"])
            originals[l.id] = (s, plan)
        self.assertEqual(roster.summary()["registered"], 4)
        self.assertEqual(roster.summary()["verified_active_model_processes"], 0)
        foreign_s, foreign_plan = originals["worm-0"]
        s, own_plan = originals["worm-1"]
        with self.assertRaises(Refusal):
            check_fixture_transcript(own_plan, foreign_s,
                                     transcript(foreign_s, foreign_plan))


if __name__ == "__main__":
    unittest.main()
