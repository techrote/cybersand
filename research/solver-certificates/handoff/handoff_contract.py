"""Research-only B3 source-typed handoff state machine. No CyberSand runtime imports.

This is a small EXPLICIT MODEL, not a producer or replacement for native World.
Integer quantity is a fictional Water quantum; momentum observations use q256.
"""
from __future__ import annotations
from dataclasses import dataclass, field, replace
from enum import Enum
from hashlib import sha256
from json import dumps
from typing import Optional

BASELINE = "d4b18e7f06839b35c8f6a66195206da0f33c5fa3"
MODEL_VERSION = "B3-RESEARCH-1"
WHOLE_CELL = 256
MAX_TX = 4096


class Owner(str, Enum):
    FREE_MASS = "freemass"
    PRESSURE = "pressure"
    INERTIAL = "inertial"
    BALLISTIC = "ballistic"
    GRANULAR = "granular"
    RAPIER = "rapier"


class Refusal(str, Enum):
    NONE = "NONE"
    STALE_EPOCH = "STALE_EPOCH"
    STALE_REVISION = "STALE_REVISION"
    BAD_GENERATION = "BAD_GENERATION"
    BAD_FENCE = "BAD_FENCE"
    TOKEN_REUSE = "TOKEN_REUSE"
    CAPACITY = "CAPACITY"
    UNSUPPORTED = "UNSUPPORTED"
    BAD_QUANTITY = "BAD_QUANTITY"
    PRESSURIZED = "PRESSURIZED"
    FRACTIONAL_CELL = "FRACTIONAL_CELL"
    UNSIGNED_UPWARD = "UNSIGNED_UPWARD"
    SOURCE_ABSENT = "SOURCE_ABSENT"
    EXPIRED = "EXPIRED"
    BAD_SAMPLE = "BAD_SAMPLE"


WATER_OWNERS = frozenset({Owner.FREE_MASS, Owner.PRESSURE, Owner.INERTIAL, Owner.BALLISTIC})


@dataclass(frozen=True)
class Record:
    identity: str
    owner: Owner
    amount: int
    revision: int = 0
    overfill: int = 0
    velocity_q256: tuple[int, int] = (0, 0)
    body_id: int = 0

    def valid(self) -> bool:
        return bool(self.identity) and self.amount > 0 and self.revision >= 0 and self.overfill >= 0 and len(self.velocity_q256) == 2


@dataclass(frozen=True)
class Intent:
    token: str
    generation: int
    epoch: int
    expected_revision: int
    expected_owner: Owner
    expected_amount: int
    source_id: str
    target: Owner
    amount: int
    next_velocity_q256: tuple[int, int]
    max_age_epochs: int = 0
    contact_sample: int | None = None
    contact_body_id: int | None = None
    allow_signed_inertial: bool = False
    audit_tag: str = ""

    def fingerprint(self) -> tuple:
        return (self.token, self.generation, self.epoch, self.expected_revision, self.expected_owner.value, self.expected_amount,
                self.source_id, self.target.value, self.amount, self.next_velocity_q256,
                self.max_age_epochs, self.contact_sample, self.contact_body_id, self.allow_signed_inertial,
                self.audit_tag)


@dataclass(frozen=True)
class Receipt:
    token: str
    status: str
    reason: Refusal
    epoch: int
    source: str
    destination: str
    water_before: int
    water_after: int
    momentum_before_q256: tuple[int, int]
    momentum_after_q256: tuple[int, int]
    momentum_status: str = "UNVERIFIED"
    production_admission: str = "MODEL_ONLY"


@dataclass
class World:
    generation: int
    epoch: int
    records: dict[str, Record]
    initial_water: int
    external_produced: int = 0
    external_consumed: int = 0
    source_epoch: int = 0
    contact_samples: set[tuple[int, int, int, str]] = field(default_factory=set)
    accepted: dict[str, tuple[tuple, Receipt]] = field(default_factory=dict)
    contact_observations: list[tuple[int, int, int, str, str]] = field(default_factory=list)

    @classmethod
    def start(cls, generation: int, records: list[Record]) -> World:
        if generation < 1 or len(records) != len({r.identity for r in records}) or not all(r.valid() for r in records):
            raise ValueError("invalid initial records")
        for r in records:
            if r.owner == Owner.INERTIAL and r.amount != WHOLE_CELL:
                raise ValueError("IN requires whole-cell Water")
        w = cls(generation, 0, {r.identity: r for r in records}, 0)
        w.initial_water = w.water_total()
        w.assert_invariants()
        return w

    def water_total(self) -> int:
        return sum(r.amount + (r.overfill if r.owner == Owner.PRESSURE else 0)
                   for r in self.records.values() if r.owner in WATER_OWNERS)

    def water_momentum_q256(self) -> tuple[int, int]:
        return tuple(sum(r.amount * r.velocity_q256[i] for r in self.records.values()
                         if r.owner in WATER_OWNERS) for i in (0, 1))

    def assert_invariants(self):
        assert len(self.records) == len(set(self.records))
        assert all(k == r.identity and r.valid() for k, r in self.records.items())
        assert all(r.owner != Owner.INERTIAL or r.amount == WHOLE_CELL for r in self.records.values())
        assert all(r.owner == Owner.PRESSURE or r.overfill == 0 for r in self.records.values())
        assert self.water_total() + self.external_consumed == self.initial_water + self.external_produced
        assert len(self.accepted) <= MAX_TX

    def material_identity(self) -> str:
        # Not CyberSand's physical hash; model-only source-bound state identity.
        visible = (MODEL_VERSION, BASELINE, self.generation, self.epoch,
                   [(k, r.owner.value, r.amount, r.revision, r.overfill, r.velocity_q256, r.body_id)
                    for k, r in sorted(self.records.items())], self.external_produced,
                   self.external_consumed, sorted(self.contact_samples), self.source_epoch,
                   sorted((token, fp) for token, (fp, _) in self.accepted.items()),
                   self.contact_observations)
        return sha256(dumps(visible, separators=(",", ":")).encode()).hexdigest()

    def record_contact(self, body_id: int, sample: int, source_id: str, kind: str):
        if (body_id < 1 or body_id > 64 or sample < 0 or source_id not in self.records
                or not any(r.owner == Owner.RAPIER and r.body_id == body_id for r in self.records.values())):
            raise ValueError("invalid contact")
        if self.records[source_id].owner == Owner.RAPIER:
            raise ValueError("contact must reference material payload")
        if len(self.contact_observations) >= MAX_TX:
            raise ValueError("contact capacity")
        self.contact_samples.add((self.epoch, body_id, sample, source_id))
        self.contact_observations.append((self.epoch, body_id, sample, source_id, kind))
        # Observations are not authority transfers; no claimed physical impulse conservation.


def prepare(w: World, *, token: str, source_id: str, target: Owner,
            amount: int, next_velocity_q256: tuple[int, int] = (0, 0),
            contact_sample: Optional[int] = None, contact_body_id: Optional[int] = None,
            allow_signed_inertial: bool = False,
            max_age_epochs: int = 0, audit_tag: str = "") -> Intent:
    if source_id not in w.records:
        raise KeyError(source_id)
    r = w.records[source_id]
    return Intent(token, w.generation, w.epoch, r.revision, r.owner, r.amount, source_id, target,
                  amount, next_velocity_q256, max_age_epochs, contact_sample,
                  contact_body_id, allow_signed_inertial, audit_tag)


def commit(w: World, intent: Intent, *, fenced: bool, now_epoch: int | None = None) -> Receipt:
    """Atomic transition model: all refusal checks occur before the first mutation."""
    before = w.water_total()
    moment_before = w.water_momentum_q256()
    now = w.epoch if now_epoch is None else now_epoch

    def refused(cause: Refusal) -> Receipt:
        return Receipt(intent.token, "REFUSED", cause, w.epoch, intent.source_id, "",
                       before, before, moment_before, moment_before)

    fp = intent.fingerprint()
    if intent.token in w.accepted:
        old_fp, old_receipt = w.accepted[intent.token]
        if fp != old_fp:
            return refused(Refusal.TOKEN_REUSE)
        return replace(old_receipt, status="IDEMPOTENT")
    if not fenced:
        return refused(Refusal.BAD_FENCE)
    if intent.generation != w.generation:
        return refused(Refusal.BAD_GENERATION)
    if now < intent.epoch or now > intent.epoch + intent.max_age_epochs:
        return refused(Refusal.EXPIRED)
    if now != w.epoch or intent.epoch != w.epoch:
        return refused(Refusal.STALE_EPOCH)
    src = w.records.get(intent.source_id)
    if src is None:
        return refused(Refusal.SOURCE_ABSENT)
    if (src.revision != intent.expected_revision or src.owner != intent.expected_owner
            or src.amount != intent.expected_amount):
        return refused(Refusal.STALE_REVISION)
    if (intent.contact_sample is None) != (intent.contact_body_id is None):
        return refused(Refusal.BAD_SAMPLE)
    if (intent.contact_sample is not None and (w.epoch, intent.contact_body_id,
            intent.contact_sample, intent.source_id) not in w.contact_samples):
        return refused(Refusal.BAD_SAMPLE)
    if src.owner not in WATER_OWNERS or intent.target not in WATER_OWNERS or src.owner == intent.target:
        return refused(Refusal.UNSUPPORTED)
    if not intent.token or len(w.accepted) >= MAX_TX:
        return refused(Refusal.CAPACITY)
    if type(intent.amount) is not int or intent.amount <= 0 or intent.amount > src.amount:
        return refused(Refusal.BAD_QUANTITY)
    if src.owner == Owner.PRESSURE and src.overfill:
        return refused(Refusal.PRESSURIZED)
    if (src.owner == Owner.INERTIAL and intent.amount != src.amount) or (
        intent.target == Owner.INERTIAL and intent.amount != WHOLE_CELL):
        return refused(Refusal.FRACTIONAL_CELL)
    if intent.target == Owner.INERTIAL and intent.next_velocity_q256[1] < 0 and not intent.allow_signed_inertial:
        return refused(Refusal.UNSIGNED_UPWARD)

    if (not isinstance(intent.next_velocity_q256, tuple) or
            len(intent.next_velocity_q256) != 2 or
            any(type(v) is not int for v in intent.next_velocity_q256)):
        return refused(Refusal.UNSUPPORTED)

    # Build a *candidate*, then commit all mutable state after its full validation.
    split = intent.amount < src.amount
    dest_id = (intent.source_id + "/" + intent.token) if split else intent.source_id
    if split and dest_id in w.records:
        return refused(Refusal.TOKEN_REUSE)
    candidate = dict(w.records)
    if split:
        candidate[intent.source_id] = replace(src, amount=src.amount-intent.amount, revision=src.revision+1)
    candidate[dest_id] = Record(dest_id, intent.target, intent.amount,
                                revision=src.revision+1, velocity_q256=intent.next_velocity_q256,
                                body_id=src.body_id)
    trial = World(w.generation, w.epoch+1, candidate, w.initial_water,
                  w.external_produced, w.external_consumed, w.source_epoch,
                  set(w.contact_samples), dict(w.accepted), list(w.contact_observations))
    after = trial.water_total()
    moment_after = trial.water_momentum_q256()
    if after != before:
        raise AssertionError("internal conservation error")
    # The momentum delta is observed, not an assertion of physical conservation;
    # an operator tag is NOT independent evidence that an impulse was measured.
    mstatus = "UNVERIFIED_INPUT_DECLARED" if intent.audit_tag else "UNVERIFIED"
    result = Receipt(intent.token, "COMMITTED", Refusal.NONE, trial.epoch, src.identity,
                     dest_id, before, after, moment_before, moment_after, mstatus)
    trial.accepted[intent.token] = (fp, result)
    trial.assert_invariants()
    # Atomic swap at an exclusive phase barrier (Python model is single-threaded).
    w.records, w.epoch, w.accepted = trial.records, trial.epoch, trial.accepted
    return result


def elapse(w: World):
    """A tick barrier invalidates all old prepared intents; no physics advances here."""
    w.epoch += 1
    w.contact_samples.clear()


def bound_cost_model(transitions: int, active_records: int, checks: int) -> dict[str, int]:
    """Count logical operations, not machine cycles; excludes hashing and model Python costs."""
    return {"transaction_checks": transitions*checks,
            "authority_lookup_upper": transitions*2,
            "bookkeeping_entries_upper": transitions,
            "live_record_upper": active_records + transitions,
            "full_world_scans_added": 0}
