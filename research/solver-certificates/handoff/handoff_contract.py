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
MODEL_VERSION = "B3-RESEARCH-6"
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
    SOURCE_DRIFT = "SOURCE_DRIFT"
    POLICY_DRIFT = "POLICY_DRIFT"
    EXPIRED = "EXPIRED"
    BAD_SAMPLE = "BAD_SAMPLE"


class ReceiptStatus(str, Enum):
    """Research receipt type; only commit() itself performs a transition.

    A historical acknowledgement never carries current worker/epoch permission.
    Even COMMITTED is evidence of a completed *model* transition, not permission
    for a later force, parcel spawn, native operation or Rapier body mutation.
    """
    REFUSED = "REFUSED"
    COMMITTED = "COMMITTED"
    HISTORICAL_ACK_ONLY = "HISTORICAL_ACK_ONLY"


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
        # Public input can be list-backed, but admitted World records cannot.
        # Reject nested booleans/nonintegers before any ownership handoff.
        return (type(self.identity) is str and bool(self.identity)
                and isinstance(self.owner, Owner)
                and type(self.amount) is int and self.amount > 0
                and type(self.revision) is int and self.revision >= 0
                and type(self.overfill) is int and self.overfill >= 0
                and type(self.body_id) is int and self.body_id >= 0
                and type(self.velocity_q256) in (tuple, list)
                and len(self.velocity_q256) == 2
                and all(type(v) is int for v in self.velocity_q256))


def inertial_seed_admissible(r: Record, signed_world_enabled: bool) -> bool:
    """Research-model IN seed/restoration predicate, not a native policy receipt.

    Non-IN records are outside this particular predicate. A signed World may
    admit negative vertical IN velocity; ordinary Worlds must not. The model
    deliberately does not claim native q16 velocity-range or policy parity.
    """
    if r.owner != Owner.INERTIAL:
        return True
    velocity = r.velocity_q256
    return (r.amount == WHOLE_CELL and isinstance(velocity, (tuple, list))
            and len(velocity) == 2 and
            type(velocity[0]) is int and type(velocity[1]) is int and
            (signed_world_enabled or velocity[1] >= 0))


def source_signature(r: Record) -> tuple:
    """Bounded *value* snapshot, not a physical hash or authenticated producer pin.

    The q256 pair is copied so a mutable nested caller-provided velocity cannot
    silently change an already prepared intent's source witness.
    """
    return (r.identity, r.owner.value, r.amount, r.revision, r.overfill,
            tuple(r.velocity_q256), r.body_id)


@dataclass(frozen=True)
class Intent:
    token: str
    generation: int
    epoch: int
    expected_revision: int
    expected_owner: Owner
    expected_amount: int
    expected_source_snapshot: tuple
    source_id: str
    target: Owner
    amount: int
    next_velocity_q256: tuple[int, int]
    max_age_epochs: int = 0
    contact_sample: int | None = None
    contact_body_id: int | None = None
    allow_signed_inertial: bool = False
    audit_tag: str = ""
    # Policy of the World at prepare. A value pin, NOT native applied-policy provenance.
    applied_signed_policy: bool = False

    def fingerprint(self) -> tuple:
        return (self.token, self.generation, self.epoch, self.expected_revision, self.expected_owner.value, self.expected_amount,
                self.expected_source_snapshot, self.source_id, self.target.value, self.amount, self.next_velocity_q256,
                self.max_age_epochs, self.contact_sample, self.contact_body_id, self.allow_signed_inertial,
                self.audit_tag, self.applied_signed_policy)


@dataclass(frozen=True)
class Receipt:
    token: str
    status: ReceiptStatus
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
    # Research-only immutable-at-World-construction option. NOT native source authentication.
    signed_inertial_world_enabled: bool = False

    def __setattr__(self, name: str, value: object) -> None:
        # For ordinary model clients, applied policy is a World-construction option.
        # Direct __dict__/object.__setattr__ rewriting and invented World instances
        # remain explicitly UNTRUSTED; no native applied-policy receipt is proved.
        if name == "signed_inertial_world_enabled" and name in self.__dict__:
            raise AttributeError("World applied signed-IN policy is construction-bound")
        object.__setattr__(self, name, value)

    @classmethod
    def start(cls, generation: int, records: list[Record], *,
              signed_inertial_world_enabled: bool = False) -> World:
        if type(signed_inertial_world_enabled) is not bool:
            raise ValueError("signed-IN World option must be boolean")
        if generation < 1 or len(records) != len({r.identity for r in records}) or not all(r.valid() for r in records):
            raise ValueError("invalid initial records")
        for r in records:
            if not inertial_seed_admissible(r, signed_inertial_world_enabled):
                raise ValueError("inadmissible initial IN state for World signed policy")
        # World.start is the trusted admission boundary. A frozen dataclass
        # does NOT freeze a nested caller-owned list. Materialise an owned tuple
        # before installing any seed, so later caller mutation cannot change
        # its velocity, epoch, applied law, or source signature behind our back.
        # No per-tick or per-transfer copying is added.
        owned = [replace(r, velocity_q256=(r.velocity_q256[0], r.velocity_q256[1]))
                 for r in records]
        w = cls(generation, 0, {r.identity: r for r in owned}, 0,
                signed_inertial_world_enabled=signed_inertial_world_enabled)
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
        assert all(k == r.identity and r.valid() and
                   type(r.velocity_q256) is tuple for k, r in self.records.items())
        # A directly constructed/restored World containing list-backed values
        # is untrusted even if its current numerical values look admissible.
        # An explicitly validated restore must obey the same applied World
        # signed-law admission as start(); direct dataclass construction alone
        # is not a trusted or validated native restoration.
        assert all(inertial_seed_admissible(r, self.signed_inertial_world_enabled)
                   for r in self.records.values())
        assert all(r.owner == Owner.PRESSURE or r.overfill == 0 for r in self.records.values())
        assert self.water_total() + self.external_consumed == self.initial_water + self.external_produced
        assert len(self.accepted) <= MAX_TX
        assert type(self.signed_inertial_world_enabled) is bool

    def material_identity(self) -> str:
        # Not CyberSand's physical hash; model-only source-bound state identity.
        visible = (MODEL_VERSION, BASELINE, self.generation, self.epoch,
                   self.signed_inertial_world_enabled,
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
    return Intent(token, w.generation, w.epoch, r.revision, r.owner, r.amount, source_signature(r), source_id, target,
                  amount, next_velocity_q256, max_age_epochs, contact_sample,
                  contact_body_id, allow_signed_inertial, audit_tag,
                  w.signed_inertial_world_enabled)


def commit(w: World, intent: Intent, *, fenced: bool, now_epoch: int | None = None) -> Receipt:
    """Atomic transition model: all refusal checks occur before the first mutation."""
    before = w.water_total()
    moment_before = w.water_momentum_q256()
    now = w.epoch if now_epoch is None else now_epoch

    def refused(cause: Refusal) -> Receipt:
        return Receipt(intent.token, ReceiptStatus.REFUSED, cause, w.epoch, intent.source_id, "",
                       before, before, moment_before, moment_before)

    fp = intent.fingerprint()
    if intent.token in w.accepted:
        old_fp, old_receipt = w.accepted[intent.token]
        if fp != old_fp:
            return refused(Refusal.TOKEN_REUSE)
        # Deliberately before the current fence/epoch checks: exact retries can
        # retrieve history, but they cannot acquire *new* operational authority.
        # Keep the original commit epoch and payload; do not touch World state.
        return replace(old_receipt, status=ReceiptStatus.HISTORICAL_ACK_ONLY)
    if not fenced:
        return refused(Refusal.BAD_FENCE)
    if intent.generation != w.generation:
        return refused(Refusal.BAD_GENERATION)
    if now < intent.epoch or now > intent.epoch + intent.max_age_epochs:
        return refused(Refusal.EXPIRED)
    if now != w.epoch or intent.epoch != w.epoch:
        return refused(Refusal.STALE_EPOCH)
    # A same-incarnation World reconstruction with a different applied policy
    # must not consume a token prepared against another law. This remains a
    # model value pin, not an authenticated native World/source-hash witness.
    if (type(intent.applied_signed_policy) is not bool or
            intent.applied_signed_policy != w.signed_inertial_world_enabled):
        return refused(Refusal.POLICY_DRIFT)
    src = w.records.get(intent.source_id)
    if src is None:
        return refused(Refusal.SOURCE_ABSENT)
    if (src.revision != intent.expected_revision or src.owner != intent.expected_owner
            or src.amount != intent.expected_amount):
        return refused(Refusal.STALE_REVISION)
    if source_signature(src) != intent.expected_source_snapshot:
        return refused(Refusal.SOURCE_DRIFT)
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
    if (not isinstance(intent.next_velocity_q256, tuple) or
            len(intent.next_velocity_q256) != 2 or
            any(type(v) is not int for v in intent.next_velocity_q256)):
        return refused(Refusal.UNSUPPORTED)
    if (intent.target == Owner.INERTIAL and intent.next_velocity_q256[1] < 0 and
            (not intent.allow_signed_inertial or not w.signed_inertial_world_enabled)):
        return refused(Refusal.UNSIGNED_UPWARD)

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
                  set(w.contact_samples), dict(w.accepted), list(w.contact_observations),
                  w.signed_inertial_world_enabled)
    after = trial.water_total()
    moment_after = trial.water_momentum_q256()
    if after != before:
        raise AssertionError("internal conservation error")
    # The momentum delta is observed, not an assertion of physical conservation;
    # an operator tag is NOT independent evidence that an impulse was measured.
    mstatus = "UNVERIFIED_INPUT_DECLARED" if intent.audit_tag else "UNVERIFIED"
    result = Receipt(intent.token, ReceiptStatus.COMMITTED, Refusal.NONE, trial.epoch, src.identity,
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
