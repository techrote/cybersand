---
title: SOL opt-in opposing-normal dilution experiment
status: Current
document-kind: evidence
scope: Single bounded value-only passive-contact experiment on accepted main; no production-mode or SOL-restoration admission
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../architecture/rigid-body-and-cellular-coupling.md]
---

# SOL active-normal dilution experiment — 5 November 2026

## Source and nonoverlap

Accepted source at intake: `main` `ba9cbc89029be88b812af59b19e5c59829bbcd90`, which already contains the ordinarily merged #394 LA-SELECTIVE response. The separate active drafts #400 (LA physical response), #411 (exact 520-member chamber evidence) and #407 (historical SOL GDScript energy precision) own distinct changes. No changes were imported from or pushed into those branches. This new branch alters only the *existing* value-only GCR passive helper, adds a test harness and this handover. It does **not** edit native World material ownership, displacement, protected MAT-AUTH consumers or Rapier application.

The original implementation in `native/include/cybersand/granular_contact_response.hpp` iterates four passes with per-node requested normal impulse multiplied by **each node's fraction of all granular samples**. Opposing, separating and perpendicular nodes contribute equally to that fraction even though the latter two cannot arrest the current approach. #411 independently measured residual-speed fractions 0, 0.0625, 0.31640625 and 0.586181640625 for selected approaching fractions 1, 1/2, 1/4 and 1/8. These are source-qualified synthetic measurements, **not** original SOL geometry recovery.

## Registered mechanical control and change

The standalone control was committed first at `9212767a27c0f91bb4a7ef755c5f79f6436bf954`; the implementation followed at `1aa519974434d2536600fa25062991b79575828e`. The candidate adds a trailing, default-`false` `normalize_active_normal` argument to `gcr::solve_compound`. On each normal pass it sums weights for nodes with an *approaching relative normal speed* and unused normal capacity. A requested positive normal impulse is distributed by each active node's share of that opposing weight instead of its fraction of all samples. The four passes, per-node capacities, tangential path, final kinetic-energy rejection and default call sites remain unchanged. No code enables the option on a live Workbench actor.

The fixed standalone C++ fixture `tools/experiments/sol_active_normal_weight.cpp` exercises: (1) one opposing and one perpendicular normal; (2) two opposing normals; (3) departing motion; (4) limiting capacity; (5) deterministic repeated workspace. Its intended full-header build command is:

```sh
g++ -std=c++20 -O2 -Wall -Wextra -Werror -pedantic -I native/include tools/experiments/sol_active_normal_weight.cpp -o /tmp/sol-active-normal
/tmp/sol-active-normal
```

## Executed local evidence and explicit limits

The local tool environment could not resolve GitHub hosts for `git clone`, and did not have the full repository, Godot or a Windows runner. **No actual full-header, exact-branch, Rapier/World, Windows, sanitizer or CPU qualification was executed.** The above committed full-header test is therefore **UNEXECUTED**, rather than marked passing.

A separate locally compiled, manually transcribed **normal-axis mathematical surrogate** was executed with Debian g++ 14.2.0, `-std=c++20 -O2 -Wall -Wextra -Werror -pedantic`. For the fixed two-normal, unit-mass, zero-arm specimen it measured residual velocity **0.0625 baseline / 0 candidate**, with two equally opposing normals arresting both ways and separating velocity remaining untouched. Its transcript reported `micro assertions passed (surrogate normal-axis subset only)`. An additional locally executed seeded Python transcription of the four-pass value update with 6,000 random two-to-eight-node cases had **0 passive-energy rejections in both modes**; this is an exploratory screen, not a substitute for C++ parity, full scientific qualification or simulation. Neither transient local tool artifact has been represented as a retained source-matched campaign.

## Decision and next gate

**HOLD — Draft/unmerged experimental candidate.** The original #411 closed driven chamber still showed 38.76508869923395 cell² of peak overlapping Sand and a 1.3963688876541198-cell depth, with exact material tuple conservation. This experimental normalization neither resolves geometric occupancy nor guarantees reduction of that overlap, permission to move embedded bodies, conservation of grain/body mechanical energy, a production CPU budget or an application path. Do not enable or merge it on the strength of the surrogate.

**Next precise gate:** compile and execute the committed C++ fixture against this exact branch/head on a real Linux compiler and MSVC host; then construct a source-pinned actual World/Rapier comparison using #411's identical closed driven, open and unforced cases, with impulse, overlap, energy and CPU ledgers. A regression or new passivity rejection means restore Draft/REPAIR, not promote the new option. Do not reinterpret valid static entrapment as failed clearance.
