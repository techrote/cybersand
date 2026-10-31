"""Pre-acquisition identity and sampling gates; no A2 outcomes are assumed."""
import copy
import json
from pathlib import Path
import random
import sys
import subprocess
import tempfile
import os
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ejection_a2 as a2

ROOT = Path(__file__).resolve().parents[2]
CAPSULES = json.loads((ROOT / "docs/audits/physical-detachment-2026-10-31/stage-a-corpus.json").read_bytes())["capsules"]


class A2Tests(unittest.TestCase):
    def setUp(self):
        self.c = copy.deepcopy(next(c for c in CAPSULES if c["target"][0] < 0))

    def unread(self, capsule, ring=False):
        grid = a2.topology.Grid(capsule)
        consulted = a2.production_identity(capsule)[3]
        return next(p for p in grid.points(ring=True)
                    if p not in consulted and grid.interior(p) != ring and grid.void(p))

    def replace(self, capsule, point, row):
        g = a2.topology.Grid(capsule)
        capsule["cells"][(point[1]-g.top)*g.width+point[0]-g.left] = row

    def test_original_production_hash_and_trace_all_80(self):
        for c in CAPSULES:
            actual, target, trace, _ = a2.production_identity(c)
            self.assertEqual((actual, target, trace), (c["replay_hash"], c["target"], c["trace"]))

    def test_unread_interior_and_ring_topology_split_same_search(self):
        for ring in (False, True):
            c = copy.deepcopy(self.c)
            p = self.unread(c, ring)
            self.replace(c, p, [2,0,0,200,0,False,True,0,"0000000000000002"])
            self.assertEqual(a2.production_identity(c)[0], self.c["replay_hash"])
            self.assertNotEqual(a2.topology_hash(c), a2.topology_hash(self.c))
            self.assertNotEqual(a2.structural_hash(c), a2.structural_hash(self.c))

    def test_hard_and_own_foreign_masks_change_topology(self):
        p = self.unread(self.c)
        for row in ([1,0,0,200,0,True,False,0,"0000000000000001"],
                    [0,0,0,200,1,False,False,0,"0000000000000000"],
                    [0,0,0,200,2,False,False,0,"0000000000000000"]):
            c = copy.deepcopy(self.c)
            self.replace(c, p, row)
            self.assertNotEqual(a2.topology_hash(c), a2.topology_hash(self.c))

    def test_material_quantity_persistent_state_and_temperature(self):
        g = a2.topology.Grid(self.c)
        source = (g.source[1]-g.top)*g.width+g.source[0]-g.left
        c = copy.deepcopy(self.c)
        row = c["cells"][source]
        row[0:4] = [3,73,11,777]
        row[7], row[8] = 73, f"{3 | (73 << 16) | (11 << 32):016x}"
        self.assertEqual(a2.production_identity(c)[0], self.c["replay_hash"])
        self.assertNotEqual(a2.topology_hash(c), a2.topology_hash(self.c))
        for field in (1,2,3):
            altered = copy.deepcopy(c)
            altered["cells"][source][field] += 1
            self.assertNotEqual(a2.topology_hash(c), a2.topology_hash(altered))
        altered = copy.deepcopy(c)
        altered["cells"][source][8] = f"{int(row[8],16) ^ (1 << 40):016x}"
        self.assertNotEqual(a2.topology_hash(c), a2.topology_hash(altered))

    def test_irrelevant_provenance_epochs_ids_and_unused_body_fields(self):
        c = copy.deepcopy(self.c)
        for key in ("tick", "revision", "sample_serial", "event_ordinal"):
            c[key] = 17
        c["instance_id"], c["reset_generation"] = "other", "reset"
        c["body_id"] = 7
        for body in (c["current_body"], c["previous_body"]):
            body[0], body[8], body[9], body[10] = 7, 123, 999, 314
        for row in c["cells"]:
            if row[4] == self.c["body_id"]:
                row[4] = 7
            row[8] = f"{int(row[8],16) ^ (1 << 56):016x}"
        self.assertEqual(a2.production_identity(c)[0], self.c["replay_hash"])
        self.assertEqual(a2.topology_hash(c), a2.topology_hash(self.c))
        self.assertEqual(a2.structural_hash(c), a2.structural_hash(self.c))

    def test_reporting_geometry_and_normal_changes_are_not_ignored(self):
        for key, index in (("current_body",1),("current_body",3),("current_body",4),
                           ("current_body",6),("previous_body",1)):
            c = copy.deepcopy(self.c)
            c[key][index] += .125
            self.assertNotEqual(a2.topology_hash(c), a2.topology_hash(self.c))
        c = copy.deepcopy(self.c)
        c["normal"][0] += 1e-12
        self.assertNotEqual(a2.topology_hash(c), a2.topology_hash(self.c))
        # Continuous geometry is intentionally separate from structural classes.
        self.assertEqual(a2.structural_hash(c), a2.structural_hash(self.c))

    def test_structural_identity_is_translation_invariant_away_from_edges(self):
        c = copy.deepcopy(self.c)
        for key in ("source", "bounds"):
            c[key][0] += 1
        for body in (c["current_body"], c["previous_body"]):
            body[1] += 1
        for row in c["trace"]:
            row[0] += 1
        if c["target"][0] >= 0:
            c["target"][0] += 1
        self.assertNotEqual(a2.topology_hash(c), a2.topology_hash(self.c))
        self.assertEqual(a2.structural_hash(c), a2.structural_hash(self.c))

    def test_identical_capsules_repeat_and_no_input_mutation(self):
        before = copy.deepcopy(self.c)
        self.assertEqual(a2.topology_hash(self.c), a2.topology_hash(copy.deepcopy(self.c)))
        self.assertEqual(a2.structural_hash(self.c), a2.structural_hash(copy.deepcopy(self.c)))
        self.assertEqual(before, self.c)

    def test_reservoir_order_independent_and_duplicate_neutral(self):
        names = [f"state-{n}" for n in range(100)]
        first, second = a2.Reservoir(7), a2.Reservoir(7)
        for name in names:
            first.add("early/shallow/right", name)
        shuffled = list(names)
        random.Random(17).shuffle(shuffled)
        for name in shuffled+shuffled:
            second.add("early/shallow/right", name)
        self.assertEqual(first.selected(), second.selected())
        self.assertEqual(len(first.selected()), 7)
        self.assertEqual(second.events["early/shallow/right"], 200)

    def test_late_better_score_replaces_and_strata_are_independent(self):
        r = a2.Reservoir(2)
        key = "late/deep/down"
        names = sorted([str(i) for i in range(20)], key=lambda x:r.score(key,x), reverse=True)
        for name in names:
            r.add(key, name)
        self.assertEqual(r.selected(), set(names[-2:]))
        self.assertGreater(r.replacements[key], 0)
        r.add("early/shallow/right", "different-stratum")
        self.assertIn("different-stratum", r.selected())

    def test_phase_penetration_and_direction_bins(self):
        c = copy.deepcopy(self.c)
        for tick, expected in ((0,"early"),(199,"early"),(200,"middle"),(399,"middle"),(400,"late"),(599,"late")):
            c["tick"] = tick
            self.assertEqual(a2.stratum(c).split("/")[0], expected)
        for p, expected in ((.5,"shallow"),(1.5,"moderate"),(2.99,"moderate"),(3,"deep")):
            c["penetration"] = p
            self.assertEqual(a2.stratum(c).split("/")[1], expected)
        for normal, expected in (((1,0),"right"),((0,1),"down"),((-1,0),"left"),((0,-1),"up")):
            c["normal"] = normal
            self.assertEqual(a2.stratum(c).split("/")[2], expected)
        c["tick"] = 600
        with self.assertRaises(ValueError):
            a2.stratum(c)

    def population_fixture(self):
        failure = copy.deepcopy(self.c)
        positive = copy.deepcopy(next(c for c in CAPSULES if c["target"][0] >= 0))
        events = [failure, copy.deepcopy(failure), positive]
        for ordinal, (c, tick) in enumerate(zip(events, (0,400,200)),1):
            c.update(event_ordinal=ordinal, tick=tick, instance_id="owner", reset_generation="generation")
        acquisition = {"complete":True,"fixture":{"ticks":600},"native_counters":{
            "dropped":0,"attempts":3,"stream_emitted":3,"owner_current":True,
            "capture_instance_id":"owner","capture_reset_generation":"generation",
            "relocation_refused":0,"searched_no_target":2,"target_found":1,"dropped_capacity":0}}
        return events, acquisition

    def test_complete_builder_two_outcomes_and_cross_stratum_repeat(self):
        events, acquisition = self.population_fixture()
        corpus, population, stats = a2.build_corpus(events, acquisition)
        self.assertEqual(len(corpus["capsules"]),2)
        self.assertEqual(len(population["capsules"]),2)
        self.assertEqual(sorted(population["event_multiplicities"].values()),[1,2])
        self.assertEqual(stats["identical_under_both_repeat_events"],1)
        self.assertEqual(stats["unique_production_failure_classes"],1)
        self.assertEqual(stats["unique_production_success_classes"],1)
        self.assertEqual(stats["retained_failures"],1)
        self.assertEqual(sum(v["retained"] for v in stats["strata"].values()),2)

    def test_builder_refuses_losses_fences_incomplete_ticks_and_ordinal_gaps(self):
        for change in ("loss","fence","ticks","ordinal","relocation"):
            events, acquisition = self.population_fixture()
            if change == "loss": acquisition["native_counters"]["dropped"] = 1
            if change == "fence": events[1]["reset_generation"] = "other"
            if change == "ticks": acquisition["fixture"]["ticks"] = 599
            if change == "ordinal": events[1]["event_ordinal"] = 7
            if change == "relocation": acquisition["native_counters"]["relocation_refused"] = 1
            with self.subTest(change=change), self.assertRaises(ValueError):
                a2.build_corpus(events, acquisition)

    def test_cli_preflights_aliases_before_any_write(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            events, acquisition = self.population_fixture()
            source, receipt = folder/"events.jsonl",folder/"acquisition.json"
            source.write_text("\n".join(json.dumps(c) for c in events)+"\n",encoding="utf-8")
            receipt.write_text(json.dumps(acquisition),encoding="utf-8")
            originals = source.read_bytes(),receipt.read_bytes()
            outputs = folder/"out"
            outputs.mkdir()
            for filename, target in (("population.json",source),("sampling.json",receipt)):
                alias = outputs/filename
                os.link(target,alias)
                run = subprocess.run([sys.executable,str(ROOT/"tools/experiments/ejection_a2.py"),
                    "--events",str(source),"--acquisition",str(receipt),"--output-directory",str(outputs)],capture_output=True)
                self.assertNotEqual(run.returncode,0)
                self.assertEqual((source.read_bytes(),receipt.read_bytes()),originals)
                self.assertFalse((outputs/"corpus.json").exists())
                alias.unlink()

    def test_incomplete_stream_blocks_interpretation(self):
        with self.assertRaises(ValueError):
            a2.build_corpus([], {"complete":False})


if __name__ == "__main__":
    unittest.main()
