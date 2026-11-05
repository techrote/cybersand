# SOL live active-normal: copied rigid-body input-domain gate

**5 November 2026 · Draft / HOLD · no merge or default promotion.**

## Sources and independent scope

Accepted `main` at intake: `ba9cbc89029be88b812af59b19e5c59829bbcd90` (tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`). This branch is based exactly on open Draft [#429](https://github.com/techrote/cybersand/pull/429) at `dfc2833eab5b8e3f81e2f2798b0066562ed41e0b`; source header Git blob `c9af2c0aac1efb1ac271897d2c29120c8c81566c`.

The defect and candidate input-domain refusal were originally reproduced with Linux GCC/Clang in the separate *copied-value* [#427](https://github.com/techrote/cybersand/pull/427) (parent header absent in #429's ancestry). Its baseline tests failed on malformed friction/mass/inertia, while the body-domain guard passed; #427 was not merged, and its standalone experimental normal algorithm differs from #429. This new branch ports **only its narrowly checked Body predicate** into #429's `NormalPolicy` interface, without changing either normal-weighting policy.

No alterations to the owning #429 branch, original SOL #347, MAT-AUTH, native material field, Rapier transforms, fixtures, or diagnostic response selection. The real chamber remains a surrogate for original SOL authority.

## Correctness mechanism

On #429's unchanged solver header, `solve_compound` immediately enters capacity/geometry arithmetic without checking copied Body mass, inertia, friction, COM, velocity or angular velocity. A negative friction coefficient can produce reversed `std::clamp` limits, NaN friction need not be refused, and nonpositive mass/inertia can produce nonfinite raw diagnostics. The only added behavior is **pre-solve refusal** for nonfinite/negative friction, nonfinite/nonpositive mass or inertia, nonfinite velocity/omega/COM, nonrepresentable inverse mass/inertia, and nonfinite initial kinetic energy.

On refusal: `passive_rejected=true`, `scale=0`, all impulses, torques, energy and capacity observations left at the zero-initialized default. The unchanged normal/tangent, four-pass, sample-capacity, friction, energy guard and caller path runs for valid Body inputs. Domain enforcement is necessary safety, **not** evidence that valid closed-driven penetration improves.

## Source and tests committed

- One isolated change to `native/include/cybersand/granular_contact_response.hpp`.
- `tools/experiments/sol_active_normal_live_body_domain_regression.cpp`, adapted from #427's source-verified test blob `0921351126e67c2b4b9821f0120fadc558f6c847` to test both `NormalPolicy::Original` and `ActiveNormal001`. 15 malformed copied-body states × 2 policies = 30 invalid checks; two valid Body variants × 2 policies = four valid controls. Test asserts clean zero-energy/impulse/counter refusal for invalid inputs and nonrefusal for controls. The test is **committed but has not been compiled or executed during this session**.

Proposed independent red/green qualification:

```sh
# Repeat on the exact parent #429 header to establish the RED reproduction.
g++ -std=c++20 -O2 -Wall -Wextra -Werror -I native/include \
  tools/experiments/sol_active_normal_live_body_domain_regression.cpp -o /tmp/sol-live-domain
/tmp/sol-live-domain

# On this branch the same test must become GREEN; repeat with clang++.
# Separately compile/run on actual Windows MSVC, and ASan/UBSan where available.
```

**Execution status:** current session's container/Python runtime returned a system-level error and could not execute C++ or obtain runtime binaries. GitHub source reads, copy adaptation and publication succeeded. No new Linux, Windows, ASan/UBSan or World/Rapier test result is claimed. Previously reported #427 results are inherited *hypothesis support*, not qualification of this #429-descended branch.

## Admission gates

1. Require source-matched independent **red on #429 / green on this exact head** for the 30 malformed and four valid checks with GCC, Clang and actual MSVC; confirm sanitizer and finite-return controls.
2. Execute unchanged #429 native value, 98 lifecycle, runtime and chamber smoke suites; compare valid-input result records bitwise against #429, both normal policies and both actual hosts.
3. Requalify 520-member chamber with all original invariants and material tuple conservation. Existing #429 peak-area reduction is real only within its eight-episode surrogate smoke. Strict clearance still fails; full registered 240/192/72 matrices remain outstanding.
4. Resolve #429's existing frozen runtime/provenance mismatches and oversized source ZIP before any admission. Obtain independent review of the combined exact head.

**Disposition: Draft/HOLD/NO MERGE.** No changes to original SOL detachment/embedded-body positional policy. Valid static entrapment remains allowed. This is a live-adapter safety prerequisite only.
