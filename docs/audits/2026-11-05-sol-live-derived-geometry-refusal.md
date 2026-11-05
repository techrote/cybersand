# SOL live contact: derived-geometry representability guard (5 November 2026)

**Status:** Draft / HOLD. Narrow dependent source-safety repair only; not a SOL physical penetration clearance, production-default change, or original SOL ownership admission.

## Frozen identities and ownership

- Accepted main at intake: ba9cbc89029be88b812af59b19e5c59829bbcd90.
- Existing #429 experimental live owner head: 275ce1ee692739b35f400adcf9532f7e89284cfb (untouched).
- This lane is stacked on #441 exact head 3eb07e6616798dda49083858e5549aec4c8d0cd7; its source header blob was a25710443f16e96a0ff02d8a4c0e7f734ca466f2.
- New header blob 0ed9e410a332baa56c5549ab6af7025fc24bcb83; regression blob 8ab53237a048ccc63f253df109ed4110301ff5ef.
- Refs #441/#433/#429/#411/#364/#281. No #429 branch edits, physics promotion or merges.

## Reproducer and cause

The #441 guard checks individually finite Body and Bin data, but cannot guarantee representability of derived geometry. An individually finite body COM (+1e308, 0) and a finite one-point Bin position sum (-1e308, 0) produce an infinite lever arm on subtraction. The original solver then forms NaN contact impulses and raw torque, and the late passivity guard clears the applied impulse while retaining nonfinite raw diagnostics. This violates clean refusal even though it rejects passivity.

The independent fixture covers four opposing-sign COM/point axes and one separately finite but overflowing angular contact velocity, under Original and ActiveNormal001 (10 malformed-derived cases total). Two standard controls per policy check an ordinary contact and empty-bin semantics (4 valid checks). The parent #441 header fails all 10 malformed-derived checks, preserving the exact symptom instead of changing tests.

## Narrow repair

After quadrature, before contact iterations, reject the whole batch when contact position, relative arm, initial angular/local velocity or projected normal/tangent speed is nonfinite. At return, refuse if any exported impulse, torque, energy or raw diagnostic is nonfinite. Refusal is zero-initialized with passive_rejected=true and scale=0. Valid normal-policy arithmetic, capacity allocations, material state, impulses, ownership and response selection are unchanged. No global correction, detachment, clearance policy or new material handling is introduced.

## Local executed results

- GCC 14.2 / Clang 17 (C++20, O2, Wall, Wextra, Werror): derived regression parent RED 10/10; repaired GREEN 10/10, valid controls 4/4.
- Existing #441 32-invalid/6-valid two-policy bin-domain test: PASS both compilers.
- Existing #433 30-invalid/4-valid two-policy body-domain test: PASS both compilers.
- Existing deterministic valid-copy parity probe: 120,000 cases per compiler, no rejected/nonfinite/nonpassive results, unchanged full-Result fingerprint b1349b7c934248a2.
- GCC and Clang AddressSanitizer/UndefinedBehaviorSanitizer targeted derived regression: PASS (LeakSanitizer disabled).
- Small 100,000-call microbenchmark (single fixed setup, two order reversals): elapsed baselines and candidates overlap; not an isolated engine performance conclusion or accepted SOL CPU gate.
- Exact local header and test file Git blobs independently match the published blob IDs above.

The reported inputs are extreme, synthetic copied values outside the bounded normal live workbench producer; this demonstrates defensive safety of the copied-value API, not an observed real-world penetration improvement or a source-producer defect.

## Remaining gates

Hosted actual Windows/MSVC red/green and Linux workflow on this exact head must complete; the updated workflow pins both Git blobs and retains logs. The original 520-member World/Rapier chamber, mixed-body regression, material/ownership conservation and independent audit remain unexecuted for this candidate. #429's mixed-body motion regression, original #364 strict clearance, multi-source SOL ownership and source ZIP gates are unresolved.

**Decision: HOLD.** Do not merge or mark the stacked chain Ready. Next: inspect exact-head hosted Windows/Linux logs and then integrate this guard only into a separately qualified active-normal composition if the owning #429 branch is reconciled and physical gates satisfied.
