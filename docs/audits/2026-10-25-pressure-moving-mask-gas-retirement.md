---
title: Pressure gas retirement beneath moving body masks
status: Current
document-kind: evidence
scope: Preserved ordinary-play and six-arm native failure, reviewed gas-label repair, local/native cost proof and actual source-matched Windows/Linux scoped publication; full ready-PR acceptance pending
canonical-for: [pressure-moving-mask-gas-retirement-evidence]
last-reviewed: 2026-10-25
related-documents: [../architecture/pressure-flow-v1.md, ../architecture/pressure-optimization.md, ../reference/invariants.md, ../reference/validation-evidence.md, ../reference/status-and-roadmap.md, 2026-10-25-lcb002-pressure-variants.md]
---

# Pressure gas retirement beneath moving body masks

## Blocking finding and source boundary

On 2026-10-25 an additional ordinary Main/worker play regression for the unchanged
registered `supported-body-water` recipe found a real native failure. Moving
reference bodies with pressure Water quarantine the World around completed
tick45–47 with `pressure gas label refers to a retired compartment`. The earlier
manually paired Rapier fixture and scoped solver regressions had passed without
exercising this asynchronous trajectory. Neither their scope nor their results
are rewritten.

The failing application uses native union source
`713ee3abd093bf52ca1e02796e996d7017a51d95` through application checkpoint
`9229fe029ac6d53ccfb38bd7d5e16cd4cad668a6` plus the separately captured, uncommitted
reference-body host candidate. Its local, non-release DLL is SHA-256
`cd3fcdd1407a61208ab820b20f277f6a8d026957738dd94ca662000c5cc2a6a3`.
The v7 failing raw log is retained outside Git at
`C:/Users/_/.codex/tmp/lcb202-water-reference-body/test_liquid_water_reference_body-v7.log`,
SHA-256 `c0a1dd618f34d70a74f1d6ed48d167c7d4c621411722f253e2c3c36ee301bf60`.
The later bounded body-input observer also reproduces at attempt51/completed50;
its one-time initial CYPS capture changes timing, so it is separate evidence.

Initial Water is exactly `332 × 50 × 224 = 3718400` quanta and stays exact;
the gas ledger also closes. A quarantined World remains a failed outcome.
PF `contact_loss` is lost motion at a closed face, not a Water sink. Legitimate
stale asynchronous feedback is rejected rather than applied; total stale count
need not be zero. Earlier fixture-premise errors and all failing attempts remain
retained; correcting them did not remove the native failure.

Both [PR #253](https://github.com/techrote/cybersand/pull/253) and
[PR #250](https://github.com/techrote/cybersand/pull/250) returned to draft.
Previously completed CI/publication results retain their exact older source and
coverage; they do not accept the moving-body path or a later native repair.

## Deterministic native reduction

The isolated repair branch `codex/lcb-pressure-moving-body-gas` starts at
`c03011a1320fde7360a7ee3c28570f53d4a05856`, tree
`f8be5e8097ac73313c18dd9e3c184641ff7aac03`, in managed worktree
`C:/Users/_/.codex/worktrees/lcb-pressure-moving-body-gas/khybersand`.
The reviewed native repair and registered regression are recoverable together
at commit `7ebcd0e9228692d7f175d4ed8ce23d5be470e8e1`; the later documentation
checkpoint changes no compiled input.
The original dirty `C:/khybersand` checkout is untouched.

One resident8×8 chunk contains a sealed12-Empty-cell pocket above four full
Water cells. After three warm ticks, gas ID1 has volume12. Mask all12 Empty
cells and tick once: the compartment retires, `collapsed=12` and live amount0,
but every covered label still says ID1. Removing the mask and ticking throws
the exact ordinary-play error. Water remains1020 and the gas ledger closes.
This reproduces independently for reference, cached and dormant pressure at
configured1 and4 workers: all six controls fail.

Raw command, binary, dependency/object identities and unchanged before/after
source fences are retained at
`C:/Users/_/.codex/tmp/lcb-pressure-moving-body-gas-reduction/`.
`BASELINE-RECEIPT.json` binds executable SHA-256
`cb1e8ad79a4e8b00733c44d11d76aea7536879e56b27ddfb4891ef20209dceb0`.
The probe's exit7 deliberately means that all six failures reproduced; it is
not a passing product test. The baseline uses the pinned LLVM-MinGW20260826
UCRT/Clang23.1.0 toolchain, C++20 `-O1 -g`, on Windows x86_64.

## Repair semantics and limits

In `World::resolve_gas_topology`, BFS and seeding exclude transient-masked
pixels. The identity reducer can retire their compartment through merge,
split, vent or collapse, while the old final relabel skipped every pixel
outside the current visit stamp. Thus a completed state could contain a label
whose live table entry was gone; strict CYPS restore already refuses it.

The repair extends the existing bounded resident relabel pass. After installing
the next live table, an unvisited positive non-sentinel label absent from that
table becomes `kVacuumLabel`. Still-live masked labels keep their continuity.
No gas amount, ancestry, history, monotonic ID allocation or ledger is inferred
from that hidden label: the reducer already assigned the full amount to live
successors or explicit vent/collapse sinks. Unresolved0 would manufacture
atmospheric gas later; successor remapping would invent overlap identity.
Sanitation contributes to `labels_changed`, so it prevents a false gas fixed
point. Reference, cached and dormant variants consume the same operator.

There is no new buffer, allocation, counter, capacity, policy field, parameter,
Cell ABI, codec version, control or default change. The existing charged
`gas_relabel_cells` scan gains bounded live-table membership checks for unvisited
positive labels. Updated source-specific total-cost evidence is still required;
old timings are not relabelled as measurements of the repair.

Read-only design review is retained at
`C:/Users/_/.codex/tmp/lcb201-moving-body-gas-independent-design/SEMANTICS-REVIEW.json`,
SHA-256 `9d74ca3b0ff9d7cb885f9d02fb00a60dac881222d306d19ab17d31fb72f6d62e`.
That reviewer participated in the design assessment; a later source/adversarial
review must record its actual independence and scope.

The exact-body-input trace is retained as a reduction aid. CYPS intentionally
omits host-owned transient masks, so restoring its bytes without separately
restoring the mask configuration and sampled body inputs is not an exact host
continuation. The adapter physical-import route has no complete prepared body
owner restoration; that remains #202/#203 scope rather than expanding this fix.

## Fresh ordinary application execution

The same narrow native repair is also applied to the separately fenced
application candidate, retaining its IN extension and seven GDScript body-host
files. A fresh local non-release DLL, SHA-256
`acf7a84150328b68610d769dee8d8a5874ad0ca6c8162d7e44c1373d4140e04f`,
builds in56.469s under600s with all133 captured native/adapter inputs unchanged.
Its normal `test_liquid_water_reference_body.gd` execution passes75 assertions,
zero failures in30.156s under180s; raw log SHA-256
`b3faf21b708413372128eaad29d6ae0ce69b6aef104ffef6a37ddcf342eca90e`.
The candidate and exact delta are retained at
`C:/Users/_/.codex/tmp/lcb202-water-reference-body-fixed/candidate-v11.json`.

All four fresh cohorts use actual Main/worker pacing, the adopted permanent
Rapier body graph and accepted cellular feedback. PF reference/cached/dormant
complete97/98/98 native ticks, the explicit FreeMass control97. Their actual
manual Rapier step counts are136/124/124/97, with positive contacts, applied
signed impulses and body translation. Every cohort retains Water3718400;
all PF gas ledgers close and no World quarantines. Accepted feedback obeys the
age bound; rejected stale feedback applies no impulse. These asynchronous
trajectories establish functional execution, not inter-arm bitwise parity,
timing comparisons, human feel acceptance or release runtime provenance.

## Qualification still pending

The registered native
regression covers collapse, split, merge and vent with covered old labels,
still-live overlap continuity, immediate save/restore before uncover, no gas
resurrection and exact quantity/history/three-variant/worker parity. Frozen local
ordinary execution passes141/141 in35.406s under600s, plus all15 filtered
LCB-002 groups. The ordinary executable retains its1MiB PE stack. Focused
ASan/UBSan execution passes16 groups in37.610s under600s: fifteen registered
LCB-002 groups and a separate head-API group. Leak detection is disabled on
Windows; this is not full-suite sanitizer or TSan evidence.

The full local proof index at
`C:/Users/_/.codex/tmp/lcb-pressure-moving-body-gas-reduction/FINAL-NATIVE-REGRESSION-PROOF.json`
has SHA-256 `061a9a6f0220dbcc944b8491d85edd161bf2d70466ca2c68d3e42e9f0f41bd32`.
Ordinary and focused-sanitizer receipts are respectively SHA-256
`26a2b418a01a9990bed695e95d796a67ae580d1415b110dfcaf86babf58f0aee`
and `caaf02c81af0a5f5f8ceca972f757f3eca92174de14da2eacc835a6697f16085`.
Complete raw/canonical/local-delta, dependency/object, compiler and executable
fences remain unchanged. Reused objects require complete dependency/hash matches.

Fresh review by a lane that did not author or design the repair finds no
remaining blocking finding. It independently reruns the frozen five-mode,
six-arm matrix in0.235s under120s. Its final receipt is
`C:/Users/_/.codex/tmp/lcb-moving-mask-fresh-review/FINAL-REVIEW.json`, SHA-256
`9673a768bfcecafdeb8207548e1a6c31e66ad2a16a15c9247a74b15058843a25`.
The review preserves its initial launcher failure from a missing LLVM DLL path.
Test development also retains the initial incorrect complete-hash comparison
without host-mask restoration, and a fixed-volume assertion contradicted by
real Water relief. Final tests keep native byte equality, restore identical
caller-owned masks with matching wake effects, and observe actual tick-entry
Empty geometry rather than overriding real transport.

Full platform/sanitizer gates, total optimization cost, fresh source-matched Windows
and Linux runtime publication, exact-head required CI and adversarial review
remain required before either solver PR merges.

## Documentation change map

The gas contract, optimization fixed point, `WATER-020`, roadmap, validation
ledger, handover, retrieval route and supplementary `LCB-MASK-GAS-01` question
describe the changed behavior and acceptance boundary. Existing frozen retrieval
questions and old evidence remain intact; the current corpus already contains
both canonical contracts, while this dated record remains an explicit evidence
route. Ownership stays native World-owned; the host mask distinction is made
explicit in persistence/interface documentation. Build/test registration is
updated with the regression. Configuration, ADR decisions and user controls
need no new format or policy because the repair enforces the existing live-label
and gas-conservation invariants. Final documentation/provenance/M11/retrieval
and whitespace checks will be recorded with the measured checkpoint.

First documentation checks run directly from the managed checkout retain the
six expected missing companion-workspace reference errors. A fresh isolated
mirror under the pinned companion workspace materializes and verifies all18
LFS payloads, preserves five companion inputs, and passes Documentation,
historical M11, provider policy, whitespace and all14 contract/registry generation
checks. The repository checker correctly fails exactly two source-sensitive
runtime comparisons, `native/src/world_pressure.inc` on Windows and Linux;
publication is required, not waived. Frozen retrieval retains20/32 top1 and
32/32 top5, MRR0.7729. The129-question supplementary set has98 top1 and129 top5,
MRR0.8605; new `LCB-MASK-GAS-01` reaches the canonical gas contract at rank2.
Manual review confirms the retrieved canonical gas section contains retained
live identity, vacuum/no invented amount, fixed-point and pending acceptance
qualifiers. The dated record remains outside the default current-answer corpus.
The initial mirror validation receipt is SHA-256
`e080f296fb26e1708a2e03aa02831d0d2d7d0a559aacba1abfc2a6dbf8a4b054`;
this additive outcome section receives a subsequent final documentation check.

## Post-repair Windows/Linux publication and final cost repeat

The repair's native/test commit is `7ebcd0e9`, its pure documentation successor
`3ff685ed`, and request sequence2 source
`eebd0c981508f18cabc7b19b474f3207f7293446`. Actual publication run
[`40157133977`](https://github.com/techrote/cybersand/actions/runs/40157133977)
passes all six jobs. Single-parent bot append
`65f1f3b575694b23f1327afe197585bcdb083b89` changes exactly two LFS runtime
pointers and their two matching manifests. This is fresh publication after the
native change; earlier publication1 stays historical.

| Actual target | Runtime SHA-256 | Bytes | Execution |
|---|---|---:|---|
| Windows x86_64 | `1985f3746ff4b3a92d4812cae951351a438c29259fd19b4c3226caad92e48d30` | 4496896 | Import +13 scoped cases |
| Linux x86_64 | `83722be933d4407e91dd57c9faadd1dc37005d535151e2a3244dfe0616afd0f8` | 3877008 | Import +13 scoped cases |

Every native74 and build/test481 canonical input perOS is independently checked
against the built Git source. Windows built and executed DLL bytes agree;
Linux passes the unchanged GLIBC2.34 bundle floor (CyberSand GLIBC2.32,
GLIBCXX3.4.30/CXXABI1.3.9; Rapier GLIBC2.34). Both actual OS reports pass
optimization4152 assertions/all6 groups, reference1934/all12, policy385,
worker29 and all16 WEX cases, with no engine error, warning or skip.
The actual job labels remain GitHub-hosted Ubuntu24.04 and Windows2022.
API archive digests, extracted logs/receipts, binary formats, manifests, committed
LFS pointers and four-path parent/source lease are verified separately.

The publication review is retained at
`C:/Users/_/.codex/tmp/lcb201-publication2-review/FINAL-PUBLICATION2-INDEPENDENT-REVIEW.json`,
SHA-256 `775840df7e08a164800faa4b5c9e0a846d4e17a2019b107d73e810be50800bfe`.
Its bundle/source receipt is `114695c9712be084b5dbb81eb6a3235d917eac4ff7b0fcb088b65969dc1d4325`;
the bot-append receipt is `cf420491c761670f6eb7c7617134ff0c7bc426b304c592592f490aff54674cbd`.
These28 actual Godot processes do not replace the new full exact-head matrix
or the separately qualified normal-application body branch.

An additional fresh MSVC19.38 Windows native build passes141/141 in272.430s
under600s, retaining the ordinary1MiB/4KiB PE stack and unchanged source fences
at `3ff685ed`. Executable SHA-256 is
`4f31cbed6b0a63c2dee44b992e90b68d22370d96367d24744f58ad6decbff158`;
receipt SHA-256 `0f5488567769fc0a16db83208507d0fb82babd8c22090fabfaa8374ede7290ca`.
The existing `getenv` deprecation compiler warning is preserved; no warning
suppression, stack enlargement or assertion/deadline reduction was introduced.

The new source-specific cost registration, before compilation, is SHA-256
`2265e89d34520991fc419c3da3d95380338cb6914b375f0ab515ae6cdc2f6a94`.
LLVM-MinGW optimized executable `7f4c245bed09690de073f0417419e373004be625a36fa60eaa0d9fd9520a24a3`
at clean `3ff685ed` first passes18 qualification children, then90 final children
and23760 timed per-arm ticks. Final summary is
`C:/Users/_/.codex/tmp/lcb-moving-mask-cost/campaign/summary.json`, SHA-256
`944aba68981b09a0e34b93ffa0b209afaa11b4506ae9be85a60af6a4d1f84f6d`.
Profiles, workers1/4, five rotated replicates, geometry, credits and phases are
unchanged. The actual relabel scan and bounded live-table lookups are inside
tick timers; the counter counts cells, not individual membership comparisons.

| Phase/control | Cached/reference, workers1 /4 | Dormant/reference, workers1 /4 |
|---|---|---|
| Awake warm | 0.901167 /0.768600 | 0.364115 /0.409259 |
| Disturbed topology churn | 1.081488 /1.038242 | 1.074618 /1.043574 |

Ratios above1 remain slower results. Head fallback is also slower; ordinary
sleep has zero Water/certificate work and zero saved calls. Awake dormancy saves
737280 reference motion calls per worker setting across five replicates while
3840 Oil updates continue. No speed threshold is fitted or universal benefit
claimed. The campaign ran after the competing local native/Godot/build work
ended, while desktop background scheduling remains uncontrolled.

Fresh independent reduction verifies442 artifact hashes/sizes,62 immutable
source inputs, all108 qualification/final children,54 phase comparisons,
53 counters/work-credit equations, capacities, resident heads and net ROI
observations with no exported parity discrepancy. Review receipt is
`C:/Users/_/.codex/tmp/lcb-moving-mask-cost-independent/REVIEW-RECEIPT.json`,
SHA-256 `5f78c1b249210ab559a32c8fe04e16507f0d084a3c2b58f8dce524472a4a6cc7`;
primary reduction is `d78a8f0d30ee8fbb8eb27ff0da408fab08f24415fc2c331e4b3f1f0feb990448`.
Raw rows do not dump complete gas tables/ledgers again; the native apparatus
compares them. Prepared heads are last-pre-kernel diagnostics, net ROI is not
gross face flux, configured workers are not task participants, and process RSS
includes three Worlds/pools/apparatus with incomplete component attribution.
The source-specific local repeat grants no target-PC, cross-platform, browser
or owner-feel acceptance. Full required exact-head CI remains pending.
