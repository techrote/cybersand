"""B3-RESEARCH-6: independent model-semantics negative/positive control.

No runtime imports. This is NOT an execution of handoff_contract.py, nor an
engine/native physical-hash test. The authored B3 exact-module tests remain
separate. Refusals model an atomic prepare/commit authorization predicate.
"""
from dataclasses import dataclass, replace


@dataclass(frozen=True)
class Token:
    signed_at_prepare: bool
    caller_signed_permission: bool
    vy: int
    epoch: int = 0
    generation: int = 3


class LegacyWorld:
    def __init__(self, signed: bool):
        self.signed_inertial_world_enabled = signed
        self.epoch = 0
        self.generation = 3
        self.owner = "freemass"


class PinnedWorld(LegacyWorld):
    def __setattr__(self, name, value):
        if name == "signed_inertial_world_enabled" and name in self.__dict__:
            raise AttributeError("construction bound")
        object.__setattr__(self, name, value)


def old_admission(w, token):
    return (token.generation == w.generation and token.epoch == w.epoch
            and (token.vy >= 0 or
                 (token.caller_signed_permission and w.signed_inertial_world_enabled)))


def pinned_admission(w, token):
    if token.signed_at_prepare != w.signed_inertial_world_enabled:
        return "POLICY_DRIFT"
    if not old_admission(w, token):
        return "UNSIGNED_UPWARD"
    return "COMMITTED"


def run():
    counts = {"old_unsigned_upgrade": 0, "setter_rejections": 0,
              "cross_world_refusals": 0, "valid_signed_controls": 0,
              "valid_unsigned_nonnegative": 0, "raw_bypass_negative": 0}
    # Infinite-policy-value grammar is Boolean with unbounded integer vy;
    # this bounded matrix is a test, not a proof of total or native correctness.
    for vy in (-32, -8, -1, 0, 1, 8, 32):
        for caller in (False, True):
            original = LegacyWorld(False)
            token = Token(False, caller, vy)
            original.signed_inertial_world_enabled = True
            if vy < 0 and caller:
                assert old_admission(original, token)
                counts["old_unsigned_upgrade"] += 1
            candidate = PinnedWorld(False)
            try:
                candidate.signed_inertial_world_enabled = True
            except AttributeError:
                counts["setter_rejections"] += 1
            else:
                raise AssertionError("mutable policy escaped ordinary assignment guard")
            assert candidate.signed_inertial_world_enabled is False
            # Deliberately simulate a newly constructed same-epoch World with
            # opposite policy, retaining a previous World's request.
            alternate = PinnedWorld(True)
            assert pinned_admission(alternate, token) == "POLICY_DRIFT"
            counts["cross_world_refusals"] += 1
            if vy >= 0:
                assert pinned_admission(candidate, token) == "COMMITTED"
                counts["valid_unsigned_nonnegative"] += 1
            else:
                assert pinned_admission(candidate, token) == "UNSIGNED_UPWARD"
            genuinely_signed = PinnedWorld(True)
            fresh = replace(token, signed_at_prepare=True)
            if vy < 0 and caller:
                assert pinned_admission(genuinely_signed, fresh) == "COMMITTED"
                counts["valid_signed_controls"] += 1
            # Retain a negative counterexample: a hostile internal rewriter
            # can spoof a World and a *new* token. No native producer attested.
            candidate.__dict__["signed_inertial_world_enabled"] = True
            spoofed = replace(token, signed_at_prepare=True)
            if vy < 0 and caller:
                assert pinned_admission(candidate, spoofed) == "COMMITTED"
                counts["raw_bypass_negative"] += 1
            assert pinned_admission(candidate, token) == "POLICY_DRIFT"
    assert counts == {
        "old_unsigned_upgrade": 3, "setter_rejections": 14,
        "cross_world_refusals": 14, "valid_signed_controls": 3,
        "valid_unsigned_nonnegative": 8, "raw_bypass_negative": 3,
    }, counts
    return counts


if __name__ == "__main__":
    print("B3 model-semantics shadow only:", run())
