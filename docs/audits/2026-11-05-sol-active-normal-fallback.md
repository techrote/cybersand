# SOL active-normal passive fallback — bounded follow-on to #413

**5 November 2026 UTC.** This is a *dependent draft experiment*, not a production solver/default change. Parent #413 is `95d7bf1e3b5a7125d257717f11874b023bb23b77`; parent `main` was `ba9cbc89029be88b812af59b19e5c59829bbcd90` at the recorded intake. The parent contact-header blob is `f3f81040b019c6b0af16a322b5d505046efd9a9e`.

## Causal defect

Opt-in active-normal normalization adjusts an otherwise dissipative multi-contact impulse. With friction and offset COM/lever arms, the *proposed* normalized impulse can increase kinetic energy. The existing final passivity guard correctly rejects that proposal and returns zero applied impulse; it is not an energy-injection vulnerability. But zero is an avoidable loss of a valid contact response when the unchanged default weighting produces a finite, passive, dissipative impulse.

Fixed two-bin four-sample witness: `initial E=1.2432118560527596`, default `E=1.2235598165052963`, original normalized proposal `E=1.2493635245087755` (rejected). The new regression fixture must **fail on the parent** and pass on this branch.

## Bounded correction

On the **opt-in** normalized solver path only, if the final candidate energy is finite and fails the unchanged passivity test, recompute with the **unchanged historical weighting** and return that result. The historical solver independently retains all original budget, capacity, friction and passivity checks. Nonfinite energies remain rejected rather than retried. Default `normalize_active_normal=false` is unchanged; no production caller enables the experimental path. An admissible normalized candidate is returned untouched. No material ownership, position correction, support detachment, World/Rapier bridge or default physics changes.

Costs: the exceptional rejected opt-in case recomputes the response once; no extra computation for default mode or accepted candidates. The safety fallback can itself refuse, correctly, if historical weighting fails passivity. No claim of positive impulse for every input.

## Executed source-specific C++ checks, Linux only

Compile from repo root using, for each available compiler `g++` (GCC 14.2) and `clang++` (Clang 17):

```
$CXX -std=c++20 -O2 -Wall -Wextra -Werror -pedantic -I native/include tools/experiments/sol_active_normal_weight.cpp -o /tmp/sol-original && /tmp/sol-original
$CXX -std=c++20 -O2 -Wall -Wextra -Werror -pedantic -I native/include tools/experiments/sol_active_normal_fallback.cpp -o /tmp/sol-fallback && /tmp/sol-fallback
$CXX -std=c++20 -O2 -Wall -Wextra -Werror -pedantic -I native/include tools/experiments/sol_active_normal_differential.cpp -o /tmp/sol-differential && /tmp/sol-differential
```

- Exact parent header + new regression test: **FAIL** as expected: `both contact responses should be passive`.
- Modified header + five original controls: **PASS**, `SOL_ACTIVE_NORMAL controls=5 failures=0`, on GCC and Clang.
- Modified header + new five-check witness: **PASS**, `SOL_ACTIVE_NORMAL_FALLBACK checks=5 failures=0`, both compilers, repeated same result.
- Fixed-seed (`0x534f4c343133`) 300,000-contact native C++ differential, GCC and Clang: parent had baseline refusals **2**, opt-in refusals **4**, candidate-only **4**; this branch baseline refusals **2**, opt-in refusals **0**, candidate-only **0**. Every returned energy respects the unchanged passivity limit; returned states finite. **Synthetic distribution** only, not gameplay prevalence.
- GCC AddressSanitizer + UndefinedBehaviorSanitizer: original controls and new witness **PASS**.

These runs validate copied-value C++ in isolation, not actual world sand yield. Windows/MSVC, Godot, native World, Rapier, #411 exact 520-member chamber, physical conservation/penetration and full runtime performance remain **UNEXECUTED**. Do not infer that an embedded but physically supported body should be spontaneously ejected; the unresolved forced Sand penetration observed in #411 remains.

## Admission

**HOLD / DRAFT / DO NOT MERGE.** Review parent #413 and this dependent repair together. Require actual #411 World/Rapier A/B on untouched geometry, per-step energy/cost budget (including fallback incidence), CI on exact proposed final source, and independent owner/reviewer acceptance before admission or opt-in activation. If parent changes, reconcile rather than forcing this branch into main.
