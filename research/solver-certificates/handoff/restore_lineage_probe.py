"""B3-RESEARCH-8: standalone rollback-lineage falsifier (research only).

No native imports. --selftest exercises an independent finite state machine;
--exact additionally executes pinned B3 handoff_contract.py from this directory.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from enum import Enum
from hashlib import sha1
from pathlib import Path
import importlib.util

PARENT_BLOB = "e8176a1a2a63fdd3edc1b097cf47647a20ff34bf"


class Status(str, Enum):
    COMMITTED = "COMMITTED"
    HISTORICAL_ACK_ONLY = "HISTORICAL_ACK_ONLY"
    UNKNOWN_CUSTODY = "UNKNOWN_CUSTODY"
    WRONG_INCARNATION = "WRONG_INCARNATION"
    STALE_CONTINUATION = "STALE_CONTINUATION"
    STALE_EPOCH = "STALE_EPOCH"
    STALE_SOURCE = "STALE_SOURCE"


@dataclass(frozen=True)
class Stamp:
    incarnation: str
    continuation: int

    def valid(self) -> bool:
        return (type(self.incarnation) is str and bool(self.incarnation)
                and type(self.continuation) is int and self.continuation >= 0)


@dataclass(frozen=True)
class Ticket:
    stamp: Stamp
    epoch: int
    token: str
    source_owner: str
    target_owner: str
    quantity: int


@dataclass
class State:
    stamp: Stamp
    epoch: int = 0
    owner: str = "freemass"
    quantity: int = 256
    accepted: set[str] = field(default_factory=set)


def prepare(state: State, token: str, target: str) -> Ticket:
    # The stamp must be *issued by a trusted owner*, not accepted from a client.
    return Ticket(state.stamp, state.epoch, token, state.owner, target,
                  state.quantity)


def apply(state: State, ticket: Ticket, *, check_continuation: bool) -> Status:
    """Single-owner, full-quantity research transfer; no physical impulse claim."""
    if ticket.token in state.accepted:
        return Status.HISTORICAL_ACK_ONLY  # No operational authority from history
    if not state.stamp.valid() or not ticket.stamp.valid():
        return Status.UNKNOWN_CUSTODY
    if ticket.stamp.incarnation != state.stamp.incarnation:
        return Status.WRONG_INCARNATION
    if check_continuation and ticket.stamp.continuation != state.stamp.continuation:
        return Status.STALE_CONTINUATION
    if ticket.epoch != state.epoch:
        return Status.STALE_EPOCH
    if (ticket.source_owner != state.owner or ticket.quantity != state.quantity
            or ticket.quantity <= 0 or ticket.source_owner == ticket.target_owner):
        return Status.STALE_SOURCE
    # All refusals precede mutation.
    state.owner = ticket.target_owner
    state.epoch += 1
    state.accepted.add(ticket.token)
    return Status.COMMITTED


def restore_precommit(state: State, *, bump_continuation: bool) -> State:
    """Model rollback/fork: precommit value, epoch and token-map restored.

    Correct custody requires trusted monotone continuation bump. This routine
    models the *effect* of that trusted owner; Python clients can forge values.
    """
    new_serial = state.stamp.continuation + (1 if bump_continuation else 0)
    return State(Stamp(state.stamp.incarnation, new_serial), quantity=state.quantity)


def test_standalone() -> dict[str, int]:
    counts = {"same_incarnation_resurrection": 0,
              "serial_refusals": 0, "fresh_success": 0,
              "bad_stamp_refusals": 0, "two_stage_success": 0}
    # Unlimited mathematical family: any positive quantity and any natural
    # continuation serial. Finite representative test is NOT the proof.
    for n in (1, 2, 17, 256, 4096):
        for serial in range(32):
            w = State(Stamp("trusted-world", serial), quantity=n)
            t = prepare(w, "spray", "ballistic")
            assert apply(w, t, check_continuation=True) == Status.COMMITTED
            assert apply(w, t, check_continuation=True) == Status.HISTORICAL_ACK_ONLY
            bad = restore_precommit(w, bump_continuation=False)
            assert apply(bad, t, check_continuation=False) == Status.COMMITTED
            counts["same_incarnation_resurrection"] += 1
            good = restore_precommit(w, bump_continuation=True)
            initial = (good.owner, good.epoch, good.quantity, good.accepted.copy())
            assert apply(good, t, check_continuation=True) == Status.STALE_CONTINUATION
            assert (good.owner, good.epoch, good.quantity, good.accepted) == initial
            counts["serial_refusals"] += 1
            fresh = prepare(good, "fresh-spray", "ballistic")
            assert apply(good, fresh, check_continuation=True) == Status.COMMITTED
            assert good.quantity == n and good.owner == "ballistic"
            counts["fresh_success"] += 1
    # A distinctive ballistic upward spray -> whole-cell inertial reentry
    # sequence. Contact impulse and momentum remain UNKNOWN.
    w = State(Stamp("actor-world", 0), quantity=256)
    assert apply(w, prepare(w, "contact-spray", "ballistic"), check_continuation=True) == Status.COMMITTED
    assert apply(w, prepare(w, "reentry", "inertial"), check_continuation=True) == Status.COMMITTED
    assert w.epoch == 2 and w.owner == "inertial" and w.quantity == 256
    counts["two_stage_success"] += 1
    # Explicit invalid custody and guessed identity cannot authorize.
    w = State(Stamp("owner-A", 7))
    for supplied in (Stamp("", 7), Stamp("owner-A", -1), Stamp("owner-B", 7), Stamp("owner-A", 6)):
        original = prepare(w, "spray", "ballistic")
        fake = Ticket(supplied, original.epoch, original.token, original.source_owner,
                      original.target_owner, original.quantity)
        expected = (Status.UNKNOWN_CUSTODY if not supplied.valid() else
                    Status.WRONG_INCARNATION if supplied.incarnation != "owner-A" else
                    Status.STALE_CONTINUATION)
        assert apply(w, fake, check_continuation=True) == expected
        assert w.owner == "freemass" and w.epoch == 0 and not w.accepted
        counts["bad_stamp_refusals"] += 1
    # A malicious owner can reissue a previous serial, making equality useless.
    w = State(Stamp("owner-A", 7))
    old = prepare(w, "reused", "ballistic")
    assert apply(w, old, check_continuation=True) == Status.COMMITTED
    forged_restore = restore_precommit(w, bump_continuation=False)
    assert apply(forged_restore, old, check_continuation=True) == Status.COMMITTED
    # This deliberate negative control is NOT a safety PASS.
    return counts


def test_exact() -> None:
    """Exercise actual parent B3 code, never silently run a different blob."""
    path = Path(__file__).with_name("handoff_contract.py")
    if not path.is_file():
        raise RuntimeError("exact run unavailable: place pinned handoff_contract.py beside probe")
    content = path.read_bytes()
    blob = sha1(f"blob {len(content)}\0".encode() + content).hexdigest()
    if blob != PARENT_BLOB:
        raise RuntimeError(f"source drift: expected Git blob {PARENT_BLOB}, saw {blob}")
    spec = importlib.util.spec_from_file_location("handoff_contract", path)
    module = importlib.util.module_from_spec(spec)
    import sys
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    w = module.World.start(7, [module.Record("water", module.Owner.FREE_MASS, 256)])
    intent = module.prepare(w, token="rollback-token", source_id="water",
                            target=module.Owner.BALLISTIC, amount=256)
    assert module.commit(w, intent, fenced=True).status == module.ReceiptStatus.COMMITTED
    assert module.commit(w, intent, fenced=False).status == module.ReceiptStatus.HISTORICAL_ACK_ONLY
    # Synthetic precommit restoration preserves generation/source/epoch but drops
    # committed history; actual native rollback semantics are NOT tested.
    restored = module.World.start(7, [module.Record("water", module.Owner.FREE_MASS, 256)])
    assert module.commit(restored, intent, fenced=True).status == module.ReceiptStatus.COMMITTED
    assert restored.epoch == 1 and restored.water_total() == 256


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--exact", action="store_true")
    a = p.parse_args()
    if not a.selftest and not a.exact:
        p.error("select --selftest and/or --exact")
    if a.selftest:
        counts = test_standalone()
        print("PASS: independent lineage controls", counts)
    if a.exact:
        test_exact()
        print("PASS: exact published B3 parent model rollback negative control")


if __name__ == "__main__":
    main()
