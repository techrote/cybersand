---
title: SOL-DETACH-001 ejection-search A/B exact-source negative result
status: Current
document-kind: audit
scope: Source 2d623e1034075f26b5443997781a267f16eeee85 read-only host-sampled diagnostic policy experiment and artifact re-hash; no production admission or independent full review
canonical-for: [sol281-ejection-search-ab-evidence]
last-reviewed: 2026-10-28
related-documents: [../systems/solid-detachment.md, 2026-10-28-sol281-ejection-search-preregistration.md, sol281-2026-10-28/ejection-search-ab-receipt.json, 2026-10-28-sol281-unresolved-cause-characterisation.md]
---

# SOL-DETACH-001 — bounded ejection-search A/B negative result (2026-10-28)

## Frozen hypothesis, execution identity and decision

The [preregistration](2026-10-28-sol281-ejection-search-preregistration.md)
was published at `e9edddee33e91b5380d6c752fe265ae7c66621d0`,
**before candidate implementation**. It froze the production-default A search
(81 candidate locations, unchanged) and diagnostic-only B, which inspects at
most 208 further locations **only if A fails** (289 total). It specified a
**20 absolute percentage-point reduction** in live no-target attempt rate
**on each Linux and Windows host**, plus conservation, owner/hole, motion,
protocol, cost and source-identity gates.

Actual scoped [GitHub Actions run 40632031064](https://github.com/techrote/cybersand/actions/runs/40632031064)
completed **successfully** on 2026-10-28, on exact executable source
`2d623e1034075f26b5443997781a267f16eeee85`, tree
`cfbbc0cfe385a5905886dfc44b94ada463565ac3`. The selected candidate
**fails the preregistered efficacy threshold on both hosts** and must **not**
be promoted. Policy 0 remains ordinary/default; policy 1 remains an explicit
isolated diagnostic choice. **Issue #281 remains open and PR #283 remains draft.**
Passing experiment integrity tests is not positive efficacy.

## Live paired compound fixture

| Metric | Linux A (81) | Linux B (289 max) | Windows A (81) | Windows B (289 max) |
|---|---:|---:|---:|---:|
| Displacement attempts | 743 | 717 | 2,438 | 1,545 |
| Successful displacements | 31 | 33 | 34 | 31 |
| No-target refusals | 712 | 684 | 2,404 | 1,514 |
| No-target fraction | 95.8277% | 95.3975% | 98.6054% | 97.9935% |
| Absolute rate reduction | — | **0.4302 pp** | — | **0.6119 pp** |
| Main-thread step p95 | 207 μs | 209 μs | 254 μs | 279 μs |
| Main-thread step p95 ratio | — | 1.010× | — | 1.098× |
| Maximum body rotation | 1.143 rad | 1.032 rad | 1.066 rad | 1.000 rad |
| Maximum translation | 32.52 cells | 31.59 cells | 31.69 cells | 31.59 cells |

Each main-thread p95 comes from 360 manual Rapier-step call timings;
the native asynchronous worker runs independently. Thus these readings
**do not qualify native-worker total cost or full-frame pacing**. Every run
maintained 520 exclusively aggregate-held members, six nonoverlapping
compound proxy rectangles, holes `[2,0,0,6]`, exact Sand count 104,
Water mass 1,020, nonzero actual Rapier contact/displacement, and zero
stale/unclassified/immovable/relocation-refused counter values. The observed
moving body toppled and translated; no new world mutation owner was added.

Async sample counts and repeated contact attempts are not held constant:
raw totals are not paired per-cell identities and do not form a
deterministic cross-run regression comparison. The explicitly registered
**within-run attempt-level proportions** are the bounded comparison.
The historical 97.8015% Linux and 97.4043% Windows rates at `756ae488`
remain separate evidence, not matched A values for this experiment.

## Controlled protocol and regression gates

Actual Godot 4.7 with Rapier2D 0.35.2 executed on Ubuntu 24.04 and
Windows Server 2022, with a pinned native extension built from the same
source. The new native/fallback diagnostic comparison passed
**470 checks per platform** over **40 cases** (five geometries, A/B,
one-/four-worker settings and native/fallback). It demonstrated the exact
baseline-first winner, extended lateral/forward target success, saturated
and Wall-blocked refusals, deterministic worker parity, source mass
conservation, original 12-float result ABI offsets, invalid-construction
refusal and ordinary-reset return to policy 0.

The original real Rapier motion 21/0, failure-paths 20/0,
lifecycle 296/0 over 18 replacement cycles, unresolved-cause 43/0 and
compound Sand/Water 36/0 **for each A and B run** passed on both hosts.
The Linux native precursor again passed eight groups / 13,074 checks.
The full ordinary PR Native/GDExtension/Water matrices remained skipped
under the existing draft PR policy; scoped green does not replace them.

## Source/runtime provenance and integrity

The [machine-readable receipt](sol281-2026-10-28/ejection-search-ab-receipt.json)
identifies all artifacts, source/runtime SHA-256 hashes, per-host counts
and negative decision.

| Artifact | ID | Download ZIP SHA-256 |
|---|---|---|
| Exact source, git-archived tree | `12791614053` | `1c0fb486dcfa395f40c71acc7abd33b07b9cdf726488f2dd40f0456a5e441c53` |
| Linux actual execution | `12792007599` | `a55ea59246137cd3edb694688093318c051c77932f4e33249ee8f78e26a8756e` |
| Windows build | `12792395728` | `ab36a83dff5e35328cb02ff8f8dbed65ba64637aebb3cd4695a62aa6c78c0ab3` |
| Windows actual execution | `12792615804` | `764305a6c30429787726927eef098add9739878a5dc8e3679888e9c8d201fe4b` |

Independently re-read artifact ZIP members and checked their CRCs,
source archive SHA-256 `b528a567f86571e583d4e21fe857a60abb7ebf2110a0c4c26d18689d2874f751`,
**all 549 archived source-path hashes** against the Windows build
manifest (zero mismatches), identical source SHA in both reports,
matching Windows DLL build/execution digest
`287095fa7e235471a7ad63c20acf58a0b41688974b2274b3c3da84cc731b86a7`,
and all eight Windows execution log hashes. Windows normalized 92
pure EOL-differing checkout files back to the recorded Git bytes.
Linux runtime SHA-256 was
`af47683036a32e58ae049c836b323bfb715d7c86f5c8a8b29747c376669d53be`.

These are **author-performed readback and secondary reduction**, not a
distinct independent code reviewer or full merged-release qualification.
All negative rates and baseline records remain preserved.

## Disposition and next bounded gate

**No-go on B.** The modest 0.43 and 0.61 percentage-point reductions
are far below 20 pp; retaining policy A avoids trading potentially
nonlocal material displacement and worker cost for unproven benefit.
Before exploring a different algorithm, distinguish **legitimate
incompressible-bank contact** from search deficiencies: characterize
per-attempt outward normals, hard-contact/path blockage and actual
reachable-void topology, then preregister a physically plausible
bounded correction/compaction candidate on fresh source. Do not widen
unboundedly, erase rejected contacts, or relabel dense-bank jamming as
a conservation failure. Separate native-worker p95/overrun and
representative frame-pacing evidence is needed for any future
candidate.

Reactive Wood/bark, heterogeneous bonds, multiple aggregates, general
desoliding/fracture, persistence/residency, normal-app integration,
published runtime and independent/full review all remain open. No
native-cell material policy or per-liquid construction policy changed.
