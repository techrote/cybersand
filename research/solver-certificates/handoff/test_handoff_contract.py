"""Deterministic independent oracle cases for B3 research-only handoff model."""
import unittest
from dataclasses import replace
from handoff_contract import (World, Record, Owner, Refusal, prepare, commit, elapse,
                              bound_cost_model, WHOLE_CELL)


def world():
    return World.start(3, [
        Record("water-0", Owner.FREE_MASS, WHOLE_CELL),
        Record("pf-0", Owner.PRESSURE, 100, overfill=25),
        Record("sand-0", Owner.GRANULAR, 1),
        Record("actor-7", Owner.RAPIER, 1, body_id=7),
    ])


class ContractProofTests(unittest.TestCase):
    def assert_refusal_unchanged(self, w, i, why, **kw):
        before = w.material_identity()
        r = commit(w, i, fenced=True, **kw)
        self.assertEqual((r.status, r.reason), ("REFUSED", why))
        self.assertEqual(before, w.material_identity())

    def test_upward_spray_impact_and_inertial_reentry(self):
        w = world(); total = w.water_total()
        w.record_contact(7, 42, "water-0", "rapier-impact")
        launch = prepare(w, token="launch", source_id="water-0", target=Owner.BALLISTIC,
                         amount=WHOLE_CELL, next_velocity_q256=(+32, -256),
                         contact_sample=42, contact_body_id=7, audit_tag="contact-launch-impulse-unverified")
        r = commit(w, launch, fenced=True)
        self.assertEqual(r.status, "COMMITTED")
        self.assertEqual(r.momentum_status, "UNVERIFIED_INPUT_DECLARED")
        self.assertEqual(w.records["water-0"].owner, Owner.BALLISTIC)
        self.assertEqual(w.water_total(), total)
        self.assertEqual(w.contact_observations[0][:4], (0, 7, 42, "water-0"))
        # On reentry upward inertia into signed-vertical variant requires explicit opt-in.
        i = prepare(w, token="land", source_id="water-0", target=Owner.INERTIAL,
                    amount=WHOLE_CELL, next_velocity_q256=(16, -8))
        self.assert_refusal_unchanged(w, i, Refusal.UNSIGNED_UPWARD)
        i = replace(i, allow_signed_inertial=True)
        landing = commit(w, i, fenced=True)
        self.assertEqual(landing.status, "COMMITTED")
        self.assertEqual(w.records["water-0"].owner, Owner.INERTIAL)
        self.assertEqual(w.water_total(), total)
        self.assertEqual(w.records["sand-0"].owner, Owner.GRANULAR)
        self.assertEqual(w.records["actor-7"].owner, Owner.RAPIER)
        self.assertEqual(len(w.records), 4)

    def test_idempotent_duplicate_and_token_mismatch(self):
        w = world(); i = prepare(w, token="t", source_id="water-0", target=Owner.BALLISTIC, amount=WHOLE_CELL)
        r = commit(w, i, fenced=True); h = w.material_identity()
        self.assertEqual(commit(w, i, fenced=True).status, "IDEMPOTENT")
        self.assertEqual(h, w.material_identity())
        self.assert_refusal_unchanged(w, replace(i, amount=20), Refusal.TOKEN_REUSE)
        self.assertEqual(r.destination, "water-0")

    def test_partial_water_launch_split_without_duplicate_ownership(self):
        w = world(); total = w.water_total()
        i = prepare(w, token="split", source_id="water-0", target=Owner.BALLISTIC, amount=96)
        r = commit(w, i, fenced=True)
        self.assertEqual(r.destination, "water-0/split")
        self.assertEqual(w.records["water-0"].amount, 160)
        self.assertEqual(w.records[r.destination].amount, 96)
        self.assertEqual(w.water_total(), total)
        self.assertEqual(len(set(w.records)), len(w.records))

    def test_reject_inertial_fractional(self):
        w = world()
        i = prepare(w, token="fraction", source_id="water-0", target=Owner.INERTIAL, amount=128)
        self.assert_refusal_unchanged(w, i, Refusal.FRACTIONAL_CELL)

    def test_pressurized_source_guard(self):
        w = world(); i=prepare(w,token="p",source_id="pf-0",target=Owner.BALLISTIC,amount=100)
        self.assert_refusal_unchanged(w, i, Refusal.PRESSURIZED)

    def test_no_water_transfer_to_rapier_or_granular(self):
        for t in (Owner.RAPIER, Owner.GRANULAR):
            w=world(); i=prepare(w,token="bad",source_id="water-0",target=t,amount=256)
            self.assert_refusal_unchanged(w,i,Refusal.UNSUPPORTED)

    def test_contact_required(self):
        w=world(); i=prepare(w,token="hit",source_id="water-0",target=Owner.BALLISTIC,
                             amount=256,contact_sample=11,contact_body_id=7)
        self.assert_refusal_unchanged(w,i,Refusal.BAD_SAMPLE)
        w.record_contact(7,11,"water-0","sweep")
        self.assertEqual(commit(w,i,fenced=True).status,"COMMITTED")

    def test_contact_sample_not_transferable_to_another_payload(self):
        w=world(); w.record_contact(7,12,"water-0","sweep")
        forged=prepare(w,token="forged",source_id="pf-0",target=Owner.BALLISTIC,
                       amount=100,contact_sample=12,contact_body_id=7)
        self.assert_refusal_unchanged(w,forged,Refusal.BAD_SAMPLE)

    def test_contact_sample_not_transferable_to_another_body(self):
        w=world(); w.record_contact(7,12,"water-0","sweep")
        forged=prepare(w,token="forged",source_id="water-0",target=Owner.BALLISTIC,
                       amount=256,contact_sample=12,contact_body_id=8)
        self.assert_refusal_unchanged(w,forged,Refusal.BAD_SAMPLE)

    def test_malformed_velocity_must_not_mutate(self):
        w=world(); i=prepare(w,token="badvel",source_id="water-0",target=Owner.BALLISTIC,amount=256)
        self.assert_refusal_unchanged(w,replace(i,next_velocity_q256=(1,)),Refusal.UNSUPPORTED)
        self.assert_refusal_unchanged(w,replace(i,next_velocity_q256=(1,"2")),Refusal.UNSUPPORTED)
        j=prepare(w,token="bad-in",source_id="water-0",target=Owner.INERTIAL,amount=WHOLE_CELL)
        self.assert_refusal_unchanged(w,replace(j,next_velocity_q256=(1,)),Refusal.UNSUPPORTED)

    def test_fence_and_epoch_timeout_and_generation(self):
        w=world(); i=prepare(w,token="t",source_id="water-0",target=Owner.BALLISTIC,amount=256)
        h=w.material_identity()
        self.assertEqual(commit(w,i,fenced=False).reason,Refusal.BAD_FENCE)
        self.assertEqual(h,w.material_identity())
        elapse(w)
        self.assert_refusal_unchanged(w,i,Refusal.EXPIRED)
        future=replace(i,epoch=w.epoch,generation=w.generation+1)
        self.assert_refusal_unchanged(w,future,Refusal.BAD_GENERATION)

    def test_stale_revision_and_retry(self):
        w=world(); i=prepare(w,token="stale",source_id="water-0",target=Owner.BALLISTIC,amount=256)
        w.records["water-0"] = replace(w.records["water-0"],revision=1)
        self.assert_refusal_unchanged(w,i,Refusal.STALE_REVISION)

    def test_stale_reuse_after_split(self):
        w=world(); i=prepare(w,token="a",source_id="water-0",target=Owner.BALLISTIC,amount=128)
        i2=prepare(w,token="b",source_id="water-0",target=Owner.BALLISTIC,amount=128)
        self.assertEqual(commit(w,i,fenced=True).status,"COMMITTED")
        self.assert_refusal_unchanged(w,i2,Refusal.EXPIRED)

    def test_source_absent_and_immutable_prepare(self):
        w=world(); i=prepare(w,token="t",source_id="water-0",target=Owner.BALLISTIC,amount=256)
        h=w.material_identity(); self.assertEqual(w.material_identity(),h)
        w.records.pop("water-0")
        # Represents an illegal external mutation of World: invariant must fail, and commit refuses.
        self.assertEqual(commit(w,i,fenced=True).reason,Refusal.SOURCE_ABSENT)

    def test_invalid_start_and_overfill(self):
        with self.assertRaises(ValueError):
            World.start(3,[Record("a",Owner.INERTIAL,100)])
        with self.assertRaises(ValueError):
            World.start(3,[Record("a",Owner.FREE_MASS,1),Record("a",Owner.RAPIER,1)])

    def test_granular_rapier_contact_is_not_material_handoff(self):
        w=world(); identity=w.material_identity(); quantity=w.water_total()
        w.record_contact(7,5,"sand-0","granular-bearing")
        self.assertEqual(w.records["sand-0"].owner,Owner.GRANULAR)
        self.assertEqual(w.records["actor-7"].owner,Owner.RAPIER)
        self.assertEqual(w.water_total(),quantity)
        self.assertNotEqual(w.material_identity(),identity) # observation participates in model identity
        i=prepare(w,token="sand-transfer",source_id="sand-0",target=Owner.RAPIER,amount=1)
        self.assert_refusal_unchanged(w,i,Refusal.UNSUPPORTED)

    def test_infinite_integer_family_sampled_bounded(self):
        # Test is finite (n=1..256), but its transfer law is formulated for any integer n>0.
        for n in range(1,257):
            w=World.start(10,[Record("water",Owner.FREE_MASS,WHOLE_CELL+n)])
            r=commit(w,prepare(w,token="out",source_id="water",target=Owner.BALLISTIC,
                               amount=n),fenced=True)
            self.assertEqual(r.status,"COMMITTED")
            self.assertEqual(sum(v.amount for v in w.records.values()),WHOLE_CELL+n)
            # Re-enter each parcel into FreeMass without any need for all-Water family switching.
            if n < WHOLE_CELL+n:
                parcel=w.records["water/out"]
                r=commit(w,prepare(w,token="in",source_id=parcel.identity,target=Owner.FREE_MASS,
                                   amount=n),fenced=True)
                self.assertEqual(r.status,"COMMITTED")
                self.assertEqual(w.water_total(),WHOLE_CELL+n)
                self.assertEqual(len(w.records),2)
                w.assert_invariants()

    def test_cost_model_is_not_runtime_benchmark(self):
        self.assertEqual(bound_cost_model(200,3000,14),{
            "transaction_checks":2800,"authority_lookup_upper":400,
            "bookkeeping_entries_upper":200,"live_record_upper":3200,"full_world_scans_added":0})

if __name__ == "__main__":
    unittest.main()
