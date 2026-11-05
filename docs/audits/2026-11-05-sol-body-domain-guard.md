# SOL copied rigid-body input-domain refusal (5 November 2026)

**Status: bounded, experimental / DRAFT / HOLD.** Refs #364, #281, #411, #413, #418 and #423. This is a dependent safety correction above #423, not a fix for buried solids, chamber penetration, restoration, LA-Selective, or material ownership.

## Source custody and non-conflict

Accepted main at intake: `ba9cbc89029be88b812af59b19e5c59829bbcd90`. Dependency #423 exact head: `bd15df28ef8bf94d0cb65c7ad705769db3ff66b9`, original header blob `33a80df91d0205d947e5d80a7c2930801362d6dc`.

One header in `native/include/cybersand/granular_contact_response.hpp` is updated; this is the copied-value `gcr::solve_compound` interface, not a Godot/Rapier or World-authoritative caller. New header Git blob: `b8f5ff8aafe6ae5998e6a4c5029940e2f83ece24`. One additive regression source: `tools/experiments/sol_body_domain_regression.cpp`, blob `0921351126e67c2b4b9821f0120fadc558f6c847`. Neither parent nor sibling branch was modified. The candidate is stacked above #423 to avoid a competing change to the same experimental header.

## Reproduction and correction

Parent #423 accepts negative/NaN/infinite friction instead of failing before contact arithmetic. With a single normal contact, `Body{velocity=(-1,0), mass=1, inertia=1, mu=-1}` produces a spurious tangent impulse `(1,-1)` despite zero initial tangent speed and a reversed `std::clamp` bound. `mu=NaN` produces a non-refused `(1,0)` response. Zero mass or inertia can emit NaNs in `raw_impulse` even where the final applied impulse is later refused. Negative mass/inertia are also not consistently rejected.

The patch places one **pre-solve input-domain refusal** ahead of contact-capacity and division logic. It checks finite velocity, COM, angular velocity, mass, inertia, friction, strictly positive mass/inertia, nonnegative friction, representable inverse mass/inertia, and finite initial kinetic energy. Invalid states return `passive_rejected=true`, `scale=0`, no candidate work, no raw impulse, no historical fallback. It does not change the normalizer, four passes, capacity shares, friction rules, energy guard, fallback, or any valid-input response path.

This is intentionally limited to **Body** fields, not all possible malformed bins or geometry. It does not introduce any positional correction, native mutation, material displacement, or new recovery policy. Valid entrapment is not treated as a defect.

## Commands actually executed (Linux)

The tested header and regression source have Git blob identities equal to the committed code. Tests were compiled under GCC 14.2 and Clang 17:

```sh
g++ -std=c++20 -O2 -Wall -Wextra -Werror -I<source-include-dir> tools/experiments/sol_body_domain_regression.cpp -o /tmp/sol-body
/tmp/sol-body
# repeat with clang++, and run the same program against parent #423's original include tree

# existing parent programs, unchanged:
g++ -std=c++20 -O2 -Wall -Wextra -Werror -I<source-include-dir> source/sol_active_normal_fallback_gate.cpp -o /tmp/sol-gate
g++ -std=c++20 -O2 -Wall -Wextra -Werror -I<source-include-dir> source/sol_active_normal_fallback_properties.cpp -o /tmp/sol-properties
/tmp/sol-gate
/tmp/sol-properties

# targeted sanitizer:
g++ -std=c++20 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined \
    -Wall -Wextra -Werror -I<source-include-dir> tools/experiments/sol_body_domain_regression.cpp -o /tmp/sol-body-san
ASAN_OPTIONS=detect_leaks=0 /tmp/sol-body-san
```

The `source/` prefix in the commands above denotes the locally extracted, source-verified #423 evidence-bundle copies of the unchanged parent programs. In a checked-out dependent branch, the corresponding tests are `tools/experiments/sol_active_normal_fallback_gate.cpp` and `tools/experiments/sol_active_normal_fallback_properties.cpp`; adjust the include directory to `native/include`.

### Measured outcomes

| Test | Parent #423 | Guarded candidate |
| --- | --- | --- |
| 30 invalid Body input checks (15 cases × 2 modes), GCC/Clang | 30 fail to refuse cleanly per compiler | **30/30 pass per compiler** |
| 4 valid-body checks per compiler | not used as a red gate | **4/4 pass** |
| Original nine-check fallback provenance | previously passed | **9/9 pass** |
| Unmodified million-case opt-in properties | previously passed | **1,000,000 per compiler pass**; 27 fallback labels, 0 mismatch, 0 candidate-only refusals, 0 nonfinite, 0 excess energy |
| 240,000 additional valid calls, complete-field deterministic fingerprint | `1451a4c5af1e1657` | **identical** fingerprint under GCC and Clang |
| GCC ASan+UBSan targeted invalid test and extended valid probe | not a new parent gate | **pass** (LeakSanitizer disabled) |

The 240,000-call comparator includes both normalization modes, all returned scalar/impulse/counter fields, and passivity/fallback flags. These are synthetic contact values, not World/Rapier measurements. A matched fingerprint proves only the registered deterministic cohort, not arbitrary valid-state equivalence. The sanitized run is not an end-to-end allocation or lifecycle test.

## Unqualified gates and disposition

No actual Windows/MSVC compilation or gameplay/runtime execution; no authoritative World/Rapier 520-member chamber, conservation readback, contact/CPU hot-path timing, current-main integration, complete CI, or independent admission review. This guard has not been demonstrated to resolve #364's penetrations or detachment behavior. It also does not establish bounded solver cost in live production.

**Decision: DRAFT / HOLD / DO NOT MERGE.** Next: independently review this input-domain contract and run a Windows/MSVC exact-head regression, then qualify the opt-in #423 stack against unchanged #411 real chamber fixtures before considering any live adapter or integration.
