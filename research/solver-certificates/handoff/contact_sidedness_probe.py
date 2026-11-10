"""B3-RESEARCH-9: independent exact-integer contact-evidence adversary.

Research only. This does not authenticate a Rapier producer, prove a native
impulse, or impose an impact precondition on authored jets/face release.

Run --selftest for the independent finite oracle, --exact only in the cloned
B3 PR directory beside the published pinned handoff_contract.py.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
from dataclasses import dataclass
from pathlib import Path
import sys

PARENT_BLOB = "e8176a1a2a63fdd3edc1b097cf47647a20ff34bf"
Key = tuple[int, int, int, str]


@dataclass(frozen=True)
class Contact:
    epoch: int
    body: int
    sample: int
    source: str
    kind: str
    normal: tuple[int, int]
    relative_velocity: tuple[int, int]
    producer: str = "rapier-main"

    def key(self) -> Key:
        return self.epoch, self.body, self.sample, self.source


class ContactLedger:
    """A trusted owner's ledger is a PREMISE, not a signed provenance system."""

    def __init__(self) -> None:
        self.membership: set[Key] = set()  # shape of current B3 contact_samples
        self.typed: dict[Key, Contact] = {}

    def record(self, event: Contact) -> None:
        self.membership.add(event.key())
        self.typed[event.key()] = event

    def presence_only(self, key: Key) -> bool:
        return key in self.membership

    def impact_evidence(self, key: Key, *, producer_authenticated: bool) -> str:
        # Never infer authority from an untrusted string inside the event.
        if not producer_authenticated or not isinstance(key, tuple) or len(key) != 4:
            return "UNVERIFIED"
        epoch, body, sample, source = key
        if (type(epoch) is not int or type(body) is not int or type(sample) is not int
                or type(source) is not str):
            return "UNVERIFIED"
        event = self.typed.get(key)
        if event is None or event.kind != "impact" or event.producer != "rapier-main":
            return "UNVERIFIED"
        if (type(event.normal) is not tuple or len(event.normal) != 2
                or type(event.relative_velocity) is not tuple
                or len(event.relative_velocity) != 2):
            return "UNVERIFIED"
        nx, ny = event.normal
        vx, vy = event.relative_velocity
        if any(type(v) is not int for v in (nx, ny, vx, vy)):
            return "UNVERIFIED"
        if nx * nx + ny * ny != 1:  # exact signed axial normal in this grammar
            return "UNVERIFIED"
        return ("SIGNED_IMPACT_VERIFIED" if nx * vx + ny * vy < 0
                else "UNVERIFIED")


def selftest() -> dict[str, int]:
    counts = {"presence_only_admissions": 0, "typed_admissions": 0,
              "typed_unknown": 0, "nonimpact": 0, "nonclosing_impact": 0,
              "wrong_key_refusals": 0, "other_refusals": 0}
    ledger = ContactLedger()
    command: Key = (13, 7, 42, "water")
    for normal in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for vx in range(-8, 9):
            for vy in range(-8, 9):
                for kind in ("impact", "separating", "telemetry-only", "unknown"):
                    ledger.record(Contact(*command, kind, normal, (vx, vy)))
                    assert ledger.presence_only(command)
                    counts["presence_only_admissions"] += 1
                    closing = normal[0] * vx + normal[1] * vy < 0
                    qualified = kind == "impact" and closing
                    observed = ledger.impact_evidence(command, producer_authenticated=True)
                    assert (observed == "SIGNED_IMPACT_VERIFIED") == qualified
                    if qualified:
                        counts["typed_admissions"] += 1
                    else:
                        counts["typed_unknown"] += 1
                        counts["nonimpact" if kind != "impact" else "nonclosing_impact"] += 1
    assert counts["presence_only_admissions"] == 4624
    assert counts["typed_admissions"] == 544
    assert counts["typed_unknown"] == 4080
    assert counts["nonimpact"] == 3468 and counts["nonclosing_impact"] == 612

    command = (18, 7, 53, "water")
    accepted = Contact(*command, "impact", (1, 0), (-7, 3))
    ledger.record(accepted)
    assert ledger.impact_evidence(command, producer_authenticated=True) == "SIGNED_IMPACT_VERIFIED"
    for wrong in ((17, 7, 53, "water"), (18, 8, 53, "water"),
                  (18, 7, 54, "water"), (18, 7, 53, "sand"),
                  (18, True, 53, "water"), (18, 7, 53, 123)):
        assert ledger.impact_evidence(wrong, producer_authenticated=True) == "UNVERIFIED"
        counts["wrong_key_refusals"] += 1
    assert ledger.impact_evidence(command, producer_authenticated=False) == "UNVERIFIED"
    counts["other_refusals"] += 1
    for event in (
        Contact(*command, "impact", (0, 0), (-1, 0)),
        Contact(*command, "impact", (2, 0), (-1, 0)),
        Contact(*command, "impact", (1, 0), (0, 3)),
        Contact(*command, "impact", (1, 0), (1, 0)),
        Contact(*command, "telemetry-only", (1, 0), (-1, 0)),
        Contact(*command, "impact", (1, 0), (-1, 0), "caller-supplied"),
    ):
        ledger.record(event)
        assert ledger.presence_only(command)
        assert ledger.impact_evidence(command, producer_authenticated=True) == "UNVERIFIED"
        counts["other_refusals"] += 1
    assert counts["other_refusals"] == 7
    return counts


def exact_parent() -> dict[str, int]:
    path = Path(__file__).with_name("handoff_contract.py")
    if not path.is_file():
        raise RuntimeError("exact parent unavailable; copy this script beside pinned handoff_contract.py")
    content = path.read_bytes()
    blob = hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest()
    if blob != PARENT_BLOB:
        raise RuntimeError(f"wrong parent blob: expected {PARENT_BLOB}, got {blob}")
    spec = importlib.util.spec_from_file_location("handoff_contract", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    result = {"different_contact_kinds_accepted": 0, "absent_contact_refused": 0}
    for kind in ("impact", "separating", "telemetry-only", "unknown"):
        w = module.World.start(3, [module.Record("water", module.Owner.FREE_MASS, 256),
                                   module.Record("actor", module.Owner.RAPIER, 1, body_id=7)])
        w.record_contact(7, 42, "water", kind)
        intent = module.prepare(w, token="launch", source_id="water", target=module.Owner.BALLISTIC,
                                amount=256, next_velocity_q256=(4, -256),
                                contact_sample=42, contact_body_id=7,
                                audit_tag="unverified-contact")
        receipt = module.commit(w, intent, fenced=True)
        assert receipt.status == module.ReceiptStatus.COMMITTED
        assert receipt.production_admission == "MODEL_ONLY"
        assert w.water_total() == 256 and w.records["actor"].owner == module.Owner.RAPIER
        result["different_contact_kinds_accepted"] += 1
    w = module.World.start(3, [module.Record("water", module.Owner.FREE_MASS, 256),
                               module.Record("actor", module.Owner.RAPIER, 1, body_id=7)])
    intent = module.prepare(w, token="launch", source_id="water", target=module.Owner.BALLISTIC,
                            amount=256, contact_sample=42, contact_body_id=7)
    before = w.material_identity()
    receipt = module.commit(w, intent, fenced=True)
    assert receipt.status == module.ReceiptStatus.REFUSED
    assert receipt.reason == module.Refusal.BAD_SAMPLE and w.material_identity() == before
    result["absent_contact_refused"] += 1
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--selftest", action="store_true")
    parser.add_argument("--exact", action="store_true")
    args = parser.parse_args()
    if not args.selftest and not args.exact:
        parser.error("choose --selftest and/or --exact")
    if args.selftest:
        print("PASS independent signed-contact model", selftest())
    if args.exact:
        print("PASS pinned B3 parent negative control", exact_parent())
