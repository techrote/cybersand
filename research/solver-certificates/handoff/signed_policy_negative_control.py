"""Independent negative control for B3 signed-IN policy admission.
This does NOT import native CyberSand or the PR model; it isolates the guard
predicate at CyberSand main d4b18e7f and B3 draft parent cee5f399.
"""
from dataclasses import dataclass

@dataclass(frozen=True)
class World:
    signed_inertial_world_enabled: bool
    water: int = 256

@dataclass(frozen=True)
class Intent:
    next_vertical_velocity_q256: int
    allow_signed_inertial: bool
    amount: int = 256

# Original B3 model guard at parent cee5f399: caller flag alone elevates law.
def prior_admission(w: World, i: Intent) -> bool:
    return i.amount == w.water and not (i.next_vertical_velocity_q256 < 0 and not i.allow_signed_inertial)

# Revised B3 model guard: requires both original caller flag and World binding.
def revised_admission(w: World, i: Intent) -> bool:
    return i.amount == w.water and not (i.next_vertical_velocity_q256 < 0 and
                                    (not i.allow_signed_inertial or not w.signed_inertial_world_enabled))

checks = 0
for signed_world in (False, True):
    for caller_opt_in in (False, True):
        for vy in (-8, 0, 8):
            w = World(signed_world)
            i = Intent(vy, caller_opt_in)
            old = prior_admission(w, i)
            new = revised_admission(w, i)
            expected = (vy >= 0 or (caller_opt_in and signed_world))
            assert new == expected, (w, i, old, new, expected)
            if vy < 0 and caller_opt_in and not signed_world:
                assert old and not new
                print("FALSIFIER legacy=True, guarded=False", w, i)
            if vy >= 0:
                assert new == old
            checks += 1
assert checks == 12
print(f"Independent predicate truth-table checks: {checks}/12 PASS")
print("Scope: predicate arithmetic only, no native runtime or published module execution")
