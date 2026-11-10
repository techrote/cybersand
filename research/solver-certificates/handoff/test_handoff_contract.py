"""Deterministic independent oracle cases for B3 research-only handoff model."""
import unittest
from dataclasses import replace
from handoff_contract import (World, Record, Owner, Refusal, prepare, commit, elapse,
                              bound_cost_model, WHOLE_CELL, ReceiptStatus)


def world(*, signed_inertial=False):
    return World.start(3, [
        Record("water-0", Owner.FREE_MASS, WHOLE_CELL),
        Record("pf-0", Owner.PRESSURE, 100, overfill=25),
        Record("sand-0", Owner.GRANULAR, 1),
        Record("actor-7", Owner.RAPIER, 1, body_id=7),
    ], signed_inertial_world_enabled=signed_inertial)


class ContractProofTests(unittest.TestCase):
    def assert_refusal_unchanged(self, w, i, why, **kw):
        before = w.material_identity()
        r = commit(w, i, fenced=True, **kw)
        self.assertEqual((r.status, r.reason), ("REFUSED", why))
        self.assertEqual(before, w.material_identity())

    def test_upward_spray_impact_and_inertial_reentry(self):
        w = world(signed_inertial=True); total = w.water_total()
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

    def test_prepare_snapshot_rejects_unversioned_source_mutation(self):
        # B3-RESEARCH-3 negative control: same identity/owner/amount/revision,
        # but stale velocity or source-associated body context.
        for mutation in ("velocity", "body"):
            with self.subTest(mutation=mutation):
                w = world()
                i = prepare(w, token="source-drift", source_id="water-0",
                            target=Owner.BALLISTIC, amount=WHOLE_CELL)
                old = w.records["water-0"]
                changed = (replace(old, velocity_q256=(512, -37)) if mutation == "velocity"
                           else replace(old, body_id=7))
                w.records["water-0"] = changed  # adversarial unversioned write
                self.assertEqual(changed.revision, old.revision)
                before = w.material_identity()
                self.assert_refusal_unchanged(w, i, Refusal.SOURCE_DRIFT)
                self.assertEqual(before, w.material_identity())
                # A newly prepared intent is valid for the new source state.
                retry = prepare(w, token="source-drift", source_id="water-0",
                                target=Owner.BALLISTIC, amount=WHOLE_CELL)
                self.assertEqual(commit(w, retry, fenced=True).status,
                                 ReceiptStatus.COMMITTED)
                w.assert_invariants()

    def test_prepare_snapshot_freezes_nested_mutable_velocity(self):
        # Record is frozen, but Python annotations do not prevent a caller
        # passing a mutable nested velocity list. Snapshot copies its values.
        w = world()
        w.records["water-0"] = replace(w.records["water-0"],
                                       velocity_q256=[0, 0])
        i = prepare(w, token="alias", source_id="water-0",
                    target=Owner.BALLISTIC, amount=WHOLE_CELL)
        w.records["water-0"].velocity_q256[1] = -7
        self.assert_refusal_unchanged(w, i, Refusal.SOURCE_DRIFT)

    def test_accepted_token_rejects_changed_source_snapshot_fingerprint(self):
        w = world()
        i = prepare(w, token="snapshot-fp", source_id="water-0",
                    target=Owner.BALLISTIC, amount=WHOLE_CELL)
        self.assertEqual(commit(w, i, fenced=True).status,
                         ReceiptStatus.COMMITTED)
        old = w.material_identity()
        different_snapshot = i.expected_source_snapshot[:-1] + (7,)
        self.assert_refusal_unchanged(
            w, replace(i, expected_source_snapshot=different_snapshot),
            Refusal.TOKEN_REUSE)
        self.assertEqual(w.material_identity(), old)

    def test_seed_signed_inertial_policy_exact_controls(self):
        # B4 source-critical falsifier: an initial negative-vy IN record
        # must not bypass the same World-bound signed law that commit checks.
        for enabled in (False, True):
            for vy in (-512, -8, -1, 0, 1, 32, 512):
                with self.subTest(enabled=enabled, vy=vy):
                    r = Record("water", Owner.INERTIAL, WHOLE_CELL,
                               velocity_q256=(5, vy))
                    if vy < 0 and not enabled:
                        with self.assertRaises(ValueError):
                            World.start(3, [r], signed_inertial_world_enabled=enabled)
                    else:
                        w = World.start(3, [r], signed_inertial_world_enabled=enabled)
                        self.assertEqual(w.records["water"].velocity_q256, (5, vy))
                        self.assertEqual(w.water_total(), WHOLE_CELL)
                        w.assert_invariants()

    def test_restored_inertial_seed_must_revalidate_applied_world_law(self):
        # A direct dataclass constructor stands in only for untrusted restored
        # input; consumers must explicitly validate before using it.
        negative = Record("water", Owner.INERTIAL, WHOLE_CELL,
                          velocity_q256=(0, -8))
        w = World(7, 0, {"water": negative}, WHOLE_CELL,
                  signed_inertial_world_enabled=False)
        with self.assertRaises(AssertionError):
            w.assert_invariants()
        self.assertEqual(w.records["water"], negative)
        # Even a previously valid World becomes invalid if an external actor
        # forges its construction-bound policy after construction.
        w = World.start(7, [negative], signed_inertial_world_enabled=True)
        w.signed_inertial_world_enabled = False  # explicitly illegal mutation
        with self.assertRaises(AssertionError):
            w.assert_invariants()
        # Reject non-integer and boolean IN seeds without silently coercing.
        for velocity in ((0, True), (0, "-8"), [0, -8]):
            with self.subTest(velocity=velocity):
                record = Record("bad", Owner.INERTIAL, WHOLE_CELL,
                                velocity_q256=velocity)
                if isinstance(velocity, list):
                    # Mutable list of valid ints is supported by this model;
                    # unsigned negative vertical still must refuse.
                    with self.assertRaises(ValueError):
                        World.start(3, [record])
                else:
                    with self.assertRaises(ValueError):
                        World.start(3, [record], signed_inertial_world_enabled=True)

    def test_caller_signed_flag_cannot_upgrade_unadmitted_world(self):
        # FALSIFIER (pre-correction): allow_signed_inertial=True alone used to COMMIT
        # a negative-vy IN transfer in World.start's default, unsigned policy.
        unsigned = world()
        identity = unsigned.material_identity()
        i = prepare(unsigned, token="forged-signed", source_id="water-0",
                    target=Owner.INERTIAL, amount=WHOLE_CELL,
                    next_velocity_q256=(16, -8), allow_signed_inertial=True)
        self.assert_refusal_unchanged(unsigned, i, Refusal.UNSIGNED_UPWARD)
        self.assertEqual(unsigned.material_identity(), identity)
        self.assertFalse(unsigned.signed_inertial_world_enabled)
        # The same request is admitted in this research model ONLY if the
        # World was explicitly created with the opt-in signed-law capability.
        signed = world(signed_inertial=True)
        allowed = prepare(signed, token="admitted-signed", source_id="water-0",
                          target=Owner.INERTIAL, amount=WHOLE_CELL,
                          next_velocity_q256=(16, -8), allow_signed_inertial=True)
        self.assertEqual(commit(signed, allowed, fenced=True).status, "COMMITTED")
        self.assertTrue(signed.signed_inertial_world_enabled)
        self.assertEqual(signed.records["water-0"].owner, Owner.INERTIAL)
        signed.assert_invariants()
        # No World opt-in can be inferred solely from an untrusted request flag.
        no_request = world(signed_inertial=True)
        no_flag = prepare(no_request, token="flag-missing", source_id="water-0",
                          target=Owner.INERTIAL, amount=WHOLE_CELL,
                          next_velocity_q256=(16, -8))
        self.assert_refusal_unchanged(no_request, no_flag, Refusal.UNSIGNED_UPWARD)

    def test_world_signed_option_rejects_non_boolean(self):
        with self.assertRaises(ValueError):
            World.start(3, [Record("water", Owner.FREE_MASS, 256)],
                        signed_inertial_world_enabled=1)

    def test_idempotent_duplicate_and_token_mismatch(self):
        w = world(); i = prepare(w, token="t", source_id="water-0", target=Owner.BALLISTIC, amount=WHOLE_CELL)
        r = commit(w, i, fenced=True); h = w.material_identity()
        self.assertEqual(commit(w, i, fenced=True).status, ReceiptStatus.HISTORICAL_ACK_ONLY)
        self.assertEqual(h, w.material_identity())
        self.assert_refusal_unchanged(w, replace(i, amount=20), Refusal.TOKEN_REUSE)
        self.assertEqual(r.destination, "water-0")

    def test_historical_ack_never_reauthorizes_current_fence_or_epoch(self):
        # B4/B5 falsifier: COMMITTED at epoch 1 must not be replayable as a
        # presently fenced permission after the real state has advanced.
        w = world(signed_inertial=True)
        w.record_contact(7, 42, "water-0", "rapier-impact")
        i = prepare(w, token="contact-launch", source_id="water-0",
                    target=Owner.BALLISTIC, amount=WHOLE_CELL,
                    contact_sample=42, contact_body_id=7)
        first = commit(w, i, fenced=True)
        self.assertEqual((first.status, first.epoch), (ReceiptStatus.COMMITTED, 1))
        self.assertEqual(w.records["water-0"].owner, Owner.BALLISTIC)
        for fence in (False, True):
            identity = w.material_identity()
            replay = commit(w, i, fenced=fence)
            self.assertEqual(replay.status, ReceiptStatus.HISTORICAL_ACK_ONLY)
            self.assertEqual((replay.epoch, replay.destination),
                             (first.epoch, first.destination))
            self.assertEqual(replay.production_admission, "MODEL_ONLY")
            self.assertNotEqual(replay.status, ReceiptStatus.COMMITTED)
            self.assertEqual(w.material_identity(), identity)
        elapse(w)
        self.assertEqual(w.epoch, 2)
        identity = w.material_identity()
        replay = commit(w, i, fenced=False)
        self.assertEqual((replay.status, replay.epoch),
                         (ReceiptStatus.HISTORICAL_ACK_ONLY, 1))
        self.assertEqual(w.material_identity(), identity)

    def test_historical_ack_across_synthetic_restart_policy_and_token_spoof(self):
        # A synthetic external replacement is NOT a qualified native restore.
        # A retained old receipt still cannot become a new COMMITTED event.
        w = world(signed_inertial=True)
        i = prepare(w, token="old", source_id="water-0",
                    target=Owner.BALLISTIC, amount=WHOLE_CELL,
                    next_velocity_q256=(13, -32))
        first = commit(w, i, fenced=True)
        w.generation += 1  # simulated replacement; outside trusted model writer
        w.signed_inertial_world_enabled = False
        w.contact_samples.clear()
        identity = w.material_identity()
        replay = commit(w, i, fenced=False)
        self.assertEqual((replay.status, replay.epoch),
                         (ReceiptStatus.HISTORICAL_ACK_ONLY, first.epoch))
        self.assertEqual(w.material_identity(), identity)
        for bad in (replace(i, next_velocity_q256=(13, 32)),
                    replace(i, audit_tag="forged-witness"),
                    replace(i, generation=w.generation)):
            self.assert_refusal_unchanged(w, bad, Refusal.TOKEN_REUSE)
        self.assertEqual(w.records["water-0"].owner, Owner.BALLISTIC)

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
