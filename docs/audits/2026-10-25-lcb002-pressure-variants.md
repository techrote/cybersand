---
title: LCB-002 pressure optimization implementation and qualification
status: Current
document-kind: evidence
scope: Source-qualified cached and dormant pressure branch, preserved failures, exact native/readback tests, complete optimization-cost campaign and actual Windows/Linux scoped publication; full ready-PR acceptance remains pending
canonical-for: [lcb002-pressure-qualification]
last-reviewed: 2026-10-25
related-documents: [../architecture/pressure-optimization.md, ../architecture/pressure-flow-v1.md, ../reference/status-and-roadmap.md, ../reference/validation-evidence.md, ../operations/local-build-and-validation.md]
---

# LCB-002 pressure optimization implementation and qualification

## Source and current acceptance boundary

This is the isolated `codex/lcb002-pressure-variants` branch based on accepted
main #246, `ec58d919b3d904fbd338eaccc25de35782c41a24`. Water's pressure reference,
cached and cached+dormant variants execute with identical physical laws and
explicit native variant admission. Current defaults are unchanged. The
[canonical optimization contract](../architecture/pressure-optimization.md)
owns mechanisms, limits, storage, identity and readback; the
[pressure reference](../architecture/pressure-flow-v1.md) owns physics.

Recoverable checkpoints include core `23a55d04`, integrated core `8c679e3d`,
broader acceptance `a0f1348a`, original cost apparatus `be78f758`, accepted-main
merge `1df42306`, isolated vent regression `a8df13cb`, execution2 proof-cost
admission `4edbfa42`, and scoped-publisher preparation `52ac25a4`.
Prepared-head measurement/readback were sealed at `65482ca5`; the actual-resident
roster correction and remaining independent-World negative were sealed at
`05d784cc948322a8e59f7427c07999cb25eb234c`. Those execution2 proofs remain
source-bound; the execution3 freeze and fresh qualification are recorded below.
Source-matched Windows/Linux scoped publication now passes at `8354e3a6`, with
single-parent bot append `d726bf34`, as recorded in the final section. Exact-head
full ready-PR CI, actual Rapier acceptance and Web remain separate pending gates.

The original `C:/khybersand` checkout and earlier Claude worktrees are preserved.
Build products, raw logs, receipts and failed controls remain outside Git under
`C:/Users/_/.codex/tmp/`; no runtime/build output is committed as source.

## Preserved defects and their controls

1. **Atmosphere-prefix fixed point.** After an explosion-mode control at tick19,
   Water and the gas table agreed but two final labels differed (49 versus14).
   The cache now requires final gas-label fixed point as well as table/topology
   equality and zero discovery allocation. The failed control is retained at
   `lcb201-cache-initial/gas-prefix-failing-control/`.
2. **Remote gas invalidation.** A remote sealed volume expansion39→40 produced
   gauge−204. Reference/cached acquired flow3 while a dormant target retained
   flow0 and skipped seven motion calls. Gas resolution now revokes all motion
   certificates. The independent failing/fixed receipt is SHA-256
   `5df09b6121e4077e45e61c15e03ebd095e8e1a391c1c2640903548e0972923b5`.
3. **Successful retry allocation.** An internal stale-discovery restart originally
   used an exception, which can allocate. An explicit retry flag now selects one
   complete reference discovery before the authoritative reducer. Two deliberate
   stale-member probes observe exactly one restart.
4. **Proof overhead.** Execution1 always retried a failed local certificate.
   Original cost measurements retain slower churn/fallback outcomes. Execution2
   adds one ordinary warmup visit and eight eligible ordinary visits after a
   failed proof, with independently recalculated identity known answers. No
   timing threshold or physical tolerance was tuned to make the benchmark pass.

Fixture development failures are also retained. The first communicating-head
positive assertion lacked its second free head endpoint; correcting the geometry
exercised genuine transmission. The isolated-vent setup first wrote duplicate
Water at a shaft/row intersection, then erased old gas labels while compressing,
correctly creating vacuum pockets instead of precompressed sealed gas. The final
fixture preserves old labelled members and opens only one remote vent. These are
fixture corrections, not silently discarded solver failures.

## Native checkpoints before final execution2 measurement

Pinned local compiler: LLVM-MinGW20260826 UCRT, Clang23.1.0, C++20 `-O1 -g` on
Windows x86_64. Ordinary PE executables retain a 1MiB stack. Focused sanitizer
builds use `-fsanitize=address,undefined -fno-omit-frame-pointer`; Windows
LeakSanitizer is unavailable. Full hosted Linux ASan/UBSan/TSan remains required.

| Source / scope | Actual result and retained receipt |
|---|---|
| Integrated core `8c679e3d` | 134/134 native, seven freshly compiled byte-oracle groups and120 Python tests; `lcb201-integrated-core/receipt.json` |
| Gas component repair source fence | 133 ordinary cases, seven focused groups and seven focused ASan+UBSan groups; two stale-discovery controls; `lcb201-gas-component-cache/final-receipt.json`, SHA `d0b7782f5005629687702f8dfeed57610348da63363641c85cc7484d5e296dd5` |
| Four broader acceptance groups on frozen core | 138/138 full ordinary, 27.344s; `lcb201-acceptance-audit/full-normal/verified-receipt.json`, SHA `068b5ce03638d5339158da8a0fc04636661be4929ccc3f8456d66e901735621e` |
| Same four acceptance groups, focused sanitizer | 4/4 ASan+UBSan; `lcb201-acceptance-audit/focused-sanitized/receipt.json`, SHA `c5229c0cad10b174dfde0a8c5b4eaafe97fe56642f220f2457d4479eeaac0f78` |
| Five groups including isolated vent, frozen `8c679e3d` core | 5/5 ordinary and5/5 ASan+UBSan; `lcb201-acceptance-audit/frozen-8c-vent-v3/receipt.json`, SHA `d9bfad492e818595cd365793f5261b9ea810260b35247e65803656cd69b8f8c3` |
| Final execution2 / actual-resident roster at `05d784cc` | **140/140 ordinary**,31.844s, plus14/14 filtered LCB-002 groups;59 actual compiled inputs and all source before/after fences unchanged, ordinary1MiB PE stack. `lcb201-final-native-proof/normal/receipt.json`, SHA `5a7ba24ab940834265f2a4d65ed02f997c1ec3565374e6ba90879dd369c1cef9`. Final focused sanitizer result is recorded after completion. |

The broader cases cover remote heads/drains, sparse negative-coordinate seams,
narrow→broad interest, communicating narrow/broad passages, real incoming
momentum and overfill, rotating/moving native masks, cadence, chemistry and Steam
conversion, pending explosions, cold reconstruction, and a remote vent acting on
an already certified target. Tests use configured1/4 workers and compare actual
state, gas identity/history/ledgers, Water quantity and signed native contacts.
Configured worker count is not evidence of four actual participants.

The first local full sanitized link collided with the policy test's custom
allocation hook on Windows. The focused sanitized runner excludes that separate
translation unit and executes the pressure tests unchanged. That focused result
is not a substitute for the full hosted Linux sanitizer matrix.

## Retained execution1 total-cost campaign

The prospective six-profile plan is retained at
`lcb201-total-cost/prospective-plan.json`, registered before the final campaign.
One immutable optimized binary ran reference/cached/dormant with rotated order,
workers1/4 and five replicates. Eighteen fixture qualification children passed,
then all90 campaign children completed **23,760 timed ticks**. Verification,
hashing and log formatting occurred outside every tick timer. Host edits,
constructor/setup and edit+tick totals are separately charged. All44 cumulative
work counters, allocation counts, actual task-claiming participants, requested
identity/budgets and declared memory are retained.

| Execution1 observation | Cached/reference | Dormant/reference |
|---|---:|---:|
| Awake stationary Water, warm, workers1 | 0.906 | 0.363 |
| Awake stationary Water, warm, workers4 | 0.774 | 0.414 |
| Continuous topology churn, disturbed, workers1 | 1.084 | 1.075 |
| Continuous topology churn, disturbed, workers4 | 1.032 | 1.038 |
| Forced head fallback, warm, workers1 | 1.096 | 1.101 |
| Forced head fallback, warm, workers4 | 1.117 | 1.114 |

These are five-replicate median complete-tick ratios for that source, not
execution2 results or universal speedups. Ordinary sleeping Water already visits
zero cells; dormant/cached ratios0.999/1.002 at workers1/4 show no additional
gain. Tiny sleeping ticks are about1.5µs and noisy. Background Firefox/Waterfox
CPU and HWiNFO activity are recorded rather than represented as an idle machine.

The awake workers4 cohorts observe four actual task-claiming participants on all
240 warm ticks per arm. Dormant saves737,280 motion calls across five replicates
while retaining all737,280 Water material calls and3,840 Oil calls. The paused
gas profile configured for four workers observes only one participant; no
four-worker speed claim follows there.

Peak RSS is for the process containing all three simultaneous Worlds/pools,
apparatus and allocator, not per-arm memory. Declared component capacities
exclude shared storage/allocator overhead. Global gas census, membership
validation/stamping and final relabelling remain charged even when discovery BFS
is reused. No zero-cost or O(affected-region) whole-operator claim follows.

| Immutable execution1 artifact | SHA-256 |
|---|---|
| Optimized executable | `a7910cbfb90ff0dd9574b987a67c52bbe2cf8386f5b1cbaa240dff16e7b768b6` |
| `lcb201-total-cost-evidence.zip`, 574files /3,295,004bytes | `31b7ecf56228af64d9fe0e1f59c7d1502bc2b0d5729b6a01b0fe7d671319bcbe` |
| Delivery receipt | `c06ec3f3cee8cfca55ed005627c992053c8e70aacb37bbf6a0b0e8e6dc91f79c` |
| Original `REPORT.md` | `d4fb803665af59359d93a3e8edd0b25260319212e709ac775141172f6b79a6be` |
| Final summary | `212611df14534b0465cd29193dd9b5f2e389591899a83505a838e8f6803a607d` |

Execution1 lacked explicit numerical prepared-head discrepancy and declared
boundary-flux observations. Exact physical projection/ledger parity is retained
as such; it is not relabelled as those unrecorded measurements. The additive
execution2 apparatus measures prepared-head status/value error outside all
timers and a declared-region **net** boundary Water balance with source/sink
causes checked. It does not measure gross per-face directional flux.

## Publication and remaining gates

The branch-scoped workflow
[`lcb002-pressure-variants-runtime-publication.yml`](../../.github/workflows/lcb002-pressure-variants-runtime-publication.yml)
and [profile helper](../../tools/ci/lcb002_pressure_runtime_publication.py) reuse
the accepted shared publisher's exact source lease, matching input bundles,
actual target-OS execution and four-path runtime append. They require a separate
explicit LCB-002 request; preparing them does not publish a runtime. Local checks
pass11 profile tests,30 shared-engine tests and the GitHub-hosted provider policy.
The six new native Godot helper groups must all report actual completion.

At that preparation point, final execution2 proof/campaign and source-matched
publication were pending. The later sections retain its completed correctness
proof and explain why the final campaign instead targets execution3. The final
section records actual Windows/Linux scoped publication; the full ready-PR
exact-head matrix remains pending. This branch does not claim full normal-app constructors,
actual Rapier movement, browser execution, owner feel or #203 packaging. Those
checks continue in the separate application/integrated lanes.

## Local adapter proof and observation correction

The local non-release DLL built at `65482ca5` has SHA-256
`0dae1d6436fed613eb5a0922b2f8eceb2bfbb0dd2d18cfbf01c2b9f68cc38129`,
4,487,168bytes, with128 fenced build/source inputs. Build45.953/600s.
Its real Windows/Godot4.7 optimization regression passes3,492 assertions,
all six sections, in8.719/360s. The pressure reference passes1,934 assertions
across all twelve sections; policy385 and worker29 preserve11/3 refusal cases.
The policy test additionally needed the independent-World negative changed from
now-supported Water/PF2 to unsupported Oil/PF2. Its original two failures remain
at `lcb201-readback-final/changed-legacy-tests/`; the exact repaired test delta
is bound in the receipt rather than attributed to the earlier source commit.

`lcb201-readback-final/qualified-checkpoint.json`, SHA
`569f8c77f98349ace9650b84a877726d0a316d83192777d8f9642435a2b57648`,
binds the DLL, cached pinned godot-cpp library, Godot executable,128 committed
input correlations, scripts and raw logs. Mixed working-tree LF/CRLF bytes are
verified against normalized Git blobs explicitly. This is a local proof before
the additive resident-roster diagnostic, not the final published runtime.

The first staged import contained an unmaterialized Rapier LFS pointer and
correctly failed strict log acceptance despite engine exit0. That log is kept
as `import-lfs-pointer-failure.log`. The staged payload was replaced from the
accepted cache only after checking SHA-256
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`;
a fresh import passed with no errors/warnings. No dependency identity changed.

The first execution2 qualification stopped at the sealed-room profile after the
four boxed/sleep controls passed: gas discovery made additional chunks resident
outside the original88×8 rectangle. The complete-coverage assertion exposed this
apparatus error. Its original raw logs remain in
`lcb201-total-cost/execution2-qualification/`. The observer now copies the actual
native chunk roster into a preallocated span, sorts/checks it against every arm,
and samples every cell in that roster; short spans are untouched and return the
required count. Both head and coordinate buffer capacities are charged. Authored
rectangles remain explicitly labelled hints. No physics/state/format law changed.

The corrected apparatus at `05d784cc` passes all18 qualification children,
including member/pair/index/head fallback. Qualification summary SHA-256
`34316d4bf877d33d0e25d91859cc634cc636f257c061331585cb5ac5a251165f`
is retained in `lcb201-total-cost/execution2-roster-qualification/`. This is
fixture qualification, not the five-replicate performance campaign.

## Execution2 final correctness boundary and execution3 follow-up

Frozen `05d784cc` also passes15/15 focused ASan+UBSan groups: all14 registered
LCB-002 groups plus a separate status/roster/cold-restore readback probe. Runtime
34.203s, ordinary1MiB stack,48 actual compiled inputs, empty stderr and unchanged
source fences. Receipt `lcb201-final-native-proof/sanitized-retry2/receipt.json`,
SHA `71d3dc717b846cead93aacceee1f9ea5d85812bdfcf9f0ae044426f427180d9f`.
Two external harness controls are retained: absolute-path string normalization
initially refused before link; then the extra probe used initial reserve64 with
maximumchunks32 and correctly refused. Only external path handling/configuration
changed. Seven fresh sanitized objects were reused only after full dependency,
source and object hashes matched. The complete ordinary/sanitizer/review index is
`FINAL-REVIEW-AND-NATIVE-PROOF.json`, SHA
`46c09e477db1f5f4706653c4e76e6f99c6307db2862aa9b72c8aae39b40859b1`.

The source-matched local Windows DLL at that checkpoint is
`79dde63edb44a9c87d4d6c41a5b4067a40379c8c10514f40b9a133a2046bd1ce`.
Build52.234/600s with128 fenced inputs. Actual Godot4.7 headless import and
all13 publisher cases pass, including the new3492-assertion/six-section test,
retained1934-assertion/twelve-section pressure control and all sixteen WEX cases.
The strict profile verifies every ordered case, marker and completed section;
staged inputs remain unchanged. Receipt
`lcb201-roster-final/scoped-godot/receipt.json`, SHA
`611f59237093450c1cf8d1f0111d465b5e5c9f50c78ecd4461687db8314964d0`.
This is actual local non-release Windows execution, not Linux or final CI.

Independent cost review then identified a remaining execution2 requirement gap:
head/index fallback cannot save motion, yet certificate arrays were still filled,
and churn could pay certificate maintenance with little/no savings. The review
addendum is SHA
`4dc12331f1e9a602f7594db112ffa1bde03e8a4d25769bf54cd42b5db067b7d4`.
The execution2 five-replicate campaign was therefore not run as final acceptance.
Its18 fixture qualifications and earlier execution1 timings remain intact.

Execution3 is being implemented before publication: whole-layer off-state for
unusable heads, constant-time cold invalidation while off, actual prior Water
work before activation, and bounded8-tick work-credit trials/32-tick suspension.
The fixed model charges1 per invalidated cell,40 per full proof and1 per reuse,
credits8 per saved motion call, and includes cold resets. This is deterministic
work admission, not universal wall-clock break-even. The seven-word worker record
is retained; nine owner counters and copied admission state expose the decisions.
Fresh final-source native/Godot/cost/platform qualification is required after this
change; no earlier result is reattested as execution3 evidence.

## Execution3 source freeze and prospective cost registration

The execution3 implementation and copied adapter/measurement wiring are committed
at `68991f1463a91c7ff0e78809c36be0a13ab045b2`. Independent root review binds the
worker's eight-file source-ready manifest and examines whole-layer admission,
owner reduction after successful tick completion, constant-work cold invalidation,
stale-tag reset, saturating cost uncertainty and unchanged physical authority.
Receipt `lcb201-execution3/root-review.json` SHA
`05a83d08cc6543fdefac171b514912d2946a9fd8fde6dbe8760a85933bde2220` has no
unresolved findings; it explicitly leaves fresh runtime/total-cost gates pending.

The original body fixture's geometry, contact timing, both signed impulses and
mandatory material/authority comparisons are retained. Its resident maintenance
cost legitimately suspends execution3: 182 saved calls,156 reuses,1,280 reference
motion calls versus1,098 actual dormant calls and four suspensions; the last trial
charges16,852 against448 credits. The obsolete universal motion-halving expectation
is replaced by exact saved/ordinary-call accounting and zero stamping/proof/skip
while suspended. A separate dense four-job fixture retains strict motion reduction
and ongoing admitted reuse. Earlier sparse-positive and attempted body-positive
fixture failures remain in `lcb201-execution3/`; unrelated dense padding is not
used to disguise the body fixture's negative cost result.

Before any execution3 timing, the six original profiles,1/4 configured workers,
five rotated replicates and fixed work model were registered at
`2026-10-25T01:31:57.009520+00:00` in
`lcb201-total-cost/execution3-plan.json`, SHA
`26f48ede75b432aca3609526181ef66f2a7b24eefddec64dec8a172addf9ffaa`.
No weights or fixture thresholds are fitted to timing. The fresh optimized binary
SHA is `19060678e546d6b928960f76c9442b5433ab38e7045fb9b6fac20bb18a0538a4`.
All18 preliminary qualification children pass; summary SHA
`20f58e0b5090aa42cba12e7b4c4f60220313698276ccd7d3333b7d1c7a4b1f9c`.
Qualification is separate from the pending90-child final campaign.

Full ordinary native validation passes140/140 plus14/14 filtered groups at this
source with all59 compiled-input raw fences held and the ordinary1MiB PE stack.
Receipt `lcb201-execution3-final-native/normal/receipt.json` SHA
`15429b732edc47d260aeb10e2ae93629c3a99561544e21dceafbf07aff5a5378`;
executable SHA `968d0992a2f003da58077e653f008732069bde96d3ede05cf5907ab9f54d2bde`.
Fourteen reused objects are accepted only after complete dependency/hash agreement.
Fresh focused ASan/UBSan, actual MSVC, fresh DLL/Godot and final cost execution are
still in progress; no earlier result is substituted for those gates.

## Execution3 fresh compiler and adapter proof

The same frozen source passes140/140 under actual MSVC19.38, with default1MiB
reserve/4KiB commit PE stack,262.709s/600s test bound and all native source fences
unchanged. `lcb201-execution3-msvc/validation-receipt.json` SHA
`5339721452a893e337816ad42e1b99140448e9b9306847f599b02f47bb6c3120`;
executable SHA `e5de937e14cc2ede9397fb5cc19da77b8f09fe1525b5da3e9ea30ae50c5f9482`.
The fresh focused15-group ASan+UBSan run passes36.750s with all48 compiled inputs
fenced, eight freshly compiled sanitizer objects and no stderr/findings. Receipt
`lcb201-execution3-final-native/sanitized/receipt.json` SHA
`1c7973430f90aa2d389d19c57c86ef22f4e282dd901b150f137c573cb3308866`;
executable SHA `4182987b11b8b02dcc133a1cad9cb9f7b734a1f22d11a1aa8162c72c09b85efd`.
This is focused Windows ASan/UBSan, with leak detection disabled, not full-suite
Linux sanitizer/TSan acceptance. The combined ordinary/sanitized receipt SHA is
`c8c7a1230c9a568f504a00ea84f6d7af3c665dc06f420f9e17be254238136ee0`.

A separate fresh local non-release Windows DLL SHA
`557901274d1c9fdeffe9a0c4dce654f41f6957b7b4fae6062b39ca7e7805f8dc`
builds49.469s/600s with128 native/adapter/dependency input fences unchanged.
Build receipt SHA `78107c1e00406a9b821dd042e19ab2379bea9cfdd1b8836dfe76e428a2508d4f`.
An immutable stage passes import plus all13 scoped publisher cases, using the
unchanged runner flags, process monitors, deadlines and strict markers/sections;
only `--path` points to the staged project. New optimization4152/0 completes all
six groups; pressure1934/0 completes all12, policy385/0 retains11 transactional
refusals, worker29/0 retains3, and WEX completes16. No errors/warnings/skips.
`lcb201-execution3-adapter/scoped-godot/receipt.json` SHA
`06526b264f4c79f08c7d97b63ae753c8bb577766a0eb840a875beffab529bd5c`.
That stage retains the old generated scenario registry. A later source-derived
registry repair changes only capability metadata/executable variant declarations;
measured ledger statuses and historical controls remain unchanged. The original
stage is not overwritten; a separately fenced affected-case followup is required
and recorded separately. At that local checkpoint actual final Windows/Linux
publication was still pending; the final section records its complete scoped rerun.

Independent documentation review identified three corrections: distinguish the
old05d execution2 proof from current68991 execution3, qualify execution2 in corpus
metadata, and state that the extra common-job pointer capacity is excluded from
both the56-byte worker record and owner `common_counter_bytes`, rather than
claiming an unexposed separate field. These edits are applied. Review receipt
`lcb201-execution3/independent-doc-review.json` SHA
`1e8824f74e5575a59bbeefa1917e3d617c7523649bdd20cce839d3240a5bc1ea`.

## Execution3 final total-cost campaign

All90 children and23,760 timed ticks complete with source/executable fences held.
The original six profiles, four fallback subcases,1/4 configured workers and five
rotated replicates remain unchanged. Summary
`lcb201-total-cost/execution3-campaign/summary.json` SHA
`a3f080ecd282846bacf9f244fa695cc4f1cd176899c376ebfd99f6d4166ccc04`;
its per-artifact index retains every raw timing/counter/head/ROI result and host
process-name/CPU inventories. Other agent compiler/test processes were held for
this short campaign; desktop background scheduling remains uncontrolled.

Warm awake-boxed cached/dormant median complete-tick ratios to reference are
0.895/0.362 at configured1 worker and0.773/0.426 at4. Ordinary sleeping Water
performs zero cell visits; both optimized variants are about0.493 in this local
preparation-dominated control. Slower outcomes remain: disturbed membership churn
cached/dormant ratios are1.103/1.086 at1 worker and1.071/1.053 at4; head-budget
fallback is about1.10–1.11. Edit-plus-tick ratios are retained separately, not
substituted for complete-tick results. These are bounded local profile outcomes,
not universal speedups, cross-platform performance, actual Rapier displacement
or a proof that the deterministic credits equal wall-clock break-even.

The separate regenerated-registry stage passes fresh import and both affected
fixture-manifest/catalogue cases with the same immutable DLL and unchanged strict
runner:26/0 manifest assertions and27 scenarios/774 catalogue assertions, with
no errors/warnings/skips. Receipt
`lcb201-execution3-registry/scoped-godot/receipt.json` SHA
`36b31095d5a74d56b61ea58c001423f9fee952c98a47825917cddb31c32c39cd`.
The capability/policy/native generators, scenario definitions, current registry,
physics fixtures and retained v2–v6 ledger producers all match;81 registry and24
inertial-oracle Python contract tests pass. Initial module-style publisher unit
invocation failed import because those scripts require their own directory on
`sys.path`; the supported direct-file invocations then pass11 profile+30 shared
publisher tests. No test or source change was made for that command error.

## Source-matched Windows/Linux publication — 2026-10-25

**Passed scoped runtime publication; full ready-PR acceptance pending.**
[Run `40152121412`](https://github.com/techrote/cybersand/actions/runs/40152121412),
attempt1, built exact source `8354e3a6424ad80d4a5a82647ef78d1681a92e3c`, tree
`ddab93af973e13226403fb688681627fd2b61cda`. All six jobs passed, including actual
Linux and Windows headless execution. The explicit source-bound request passed
the recorded source-lease checks and atomic final push lease. The publisher appended
`d726bf34edcc9da96e918fd2fd88786937e4015a` with exactly that one source parent
and only the two runtime LFS pointers plus their two matching provenance manifests.
No native, policy, default, physics, workflow or request bytes changed in the append.

| Published target/runtime | Bytes | SHA-256 |
|---|---:|---|
| Windows x86_64 DLL | 4,496,384 | `2c49158cb659dc22d6685ad75528cc8958cd1de38d691bc457008f722fbb80c7` |
| Linux x86_64 ELF shared object | 3,877,008 | `21dc5434b82ce770410ed97b339084c97a42fd1fd6774c2d1f27a7373d177bc7` |

Windows was cross-built on GitHub-hosted Ubuntu24.04 using LLVM-MinGW20260826
UCRT, Clang/LLD23.1.0, archive SHA
`cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65`, then
executed on GitHub-hosted Windows2022. Linux was built and executed on
GitHub-hosted Ubuntu24.04 with GCC13.3.0. Both builds use SCons4.10.1 and
godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`; exact compiler/linker and
static-library identities remain in each runtime manifest. Linux's actual floor
check passed: bundle GLIBC2.34, CyberSand GLIBC2.32/GLIBCXX3.4.30/CXXABI1.3.9,
Rapier GLIBC2.34. Both execute official Godot4.7 `4.7.stable.official.5b4e0cb0f`
with its pinned platform archive. Accepted patched Rapier hashes remain Windows
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` and Linux
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.

**Actual execution:** import plus all13 required cases perOS, 28 real processes
total, every returncode0, no launch/capture/diagnostic/timeout failure and no
skipped/error log. Both platforms complete optimization4152 assertions/all six
strict helper sections, pressure reference1934/all twelve sections, policy385
(including11 refusals and W-CY admission/isolation), worker29 (including3
refusals), MicroScenarios/controllers/native observation, all four LCB contract
controls, Water Feel, and WEX16 body-mask baseline cases. The optimization test
also checks execution3 identity, 53 u64-safe decimal counters, copied admission
state, exact projections, cold restore and mandatory material behavior. Its
logged work distinguishes configured1/4 workers; it does not record four distinct
observed participants. The separately fenced cost campaign owns that evidence.

| Real process | Windows seconds / timeout | Linux seconds / timeout |
|---|---:|---:|
| Optimization | 7.617 /360 | 11.420 /360 |
| Pressure reference | 19.038 /900 | 39.874 /900 |
| MicroScenarios | 71.518 /180 | 143.267 /180 |
| WEX body baseline | 91.937 /600 | 156.410 /600 |

Independent read-only verification downloaded all three artifact ZIPs, checked
their API archive digests, then checked every case log digest and strict completed
section. Each platform's same74 native and480 build/test inputs were independently
hashed against the selected canonical Git blobs. The built Windows DLL equals
the executed bytes; both runtime/report/manifest chains match, and the bot's
committed manifest bytes and canonical LF LFS pointers identify those exact
payloads. The tools/engine binaries themselves are not bundled for independent
local rehashing; their pins and identities are recorded by the source-bound
workflow and build/execution receipts, rather than claimed as a separate local
toolchain execution.

| Retained artifact ZIP | SHA-256 |
|---|---|
| `lcb002-pressure-variants-build-windows-40152121412` | `64c45e4c7f6a5df415c4171e3e3495f20dd3405eb103cfe7255d5e03a7c1bb8c` |
| `lcb002-pressure-variants-runtime-windows-40152121412` | `ec4cf25e0621391e31aac4fdcd0f02fbaaf4daa212c6afb6ca86731e35d1f310` |
| `lcb002-pressure-variants-runtime-linux-40152121412` | `3d6dba2a497c652e927f5e817aca2627b973541bc96fc08469d266a15d41af13` |

Independent receipt
`lcb201-publication1-review/FINAL-PUBLICATION1-INDEPENDENT-REVIEW.json`, SHA
`34cb625bae646cbca960522eb46d03b4cead08465de54297869dbe149e998a71`, binds
the raw archives/files, immutable API snapshots, complete workflow log, both
target-OS jobs and final append. No actionable finding remains. One reviewer-only
assertion expected redirected step-summary echo text to appear expanded in the
workflow log; the corrected check uses actual commit/push output plus the
immutable commit API. The initial script/evidence remain retained. This was no
publisher/runtime failure. Earlier solver, local import-pointer, observation and
cost-control failures above remain historical and unchanged.

The reviewed two-page canonical reconciliation is independently bound by patch
SHA `87d49fbb70a2c91e235991b39d2ea458dd5b389873c7141edf4466c066699f41` and
`lcb201-canonical-followup-independent/FINAL-DOC-RECONCILIATION-RECEIPT.json`, SHA
`3aa20960a81d7a38535799bc7ef0a6f84473a4beeddbe71facd66666f03f4e90`.
It was committed as `5fbfe7ba`; normal merge `689e7589` combines it with the
verified runtime append without changing the runtime inputs. Its pre-publication
20 stale-native-input errors were expected then, not a post-publication waiver.

The draft PR's earlier [Documentation run `40152144867`](https://github.com/techrote/cybersand/actions/runs/40152144867)
passed at source `8354e3a6`. It does not attest later documentation or replace the
remaining ready transition. **Still pending:** the full exact-head ready-PR Documentation/provenance, Native
(including full Linux sanitizers/TSan), GDExtension/Godot and applicable #49 Water
matrix. This scoped publisher does not establish main acceptance, graphical
pixels, browser/WebAssembly, owner feel, target-PC performance, pressure-to-Rapier
movement, full normal-app constructors or #202/#203 completion. Registry campaign
statuses and historical source-matched controls remain unchanged.

## Publication documentation checkpoint

The source/behavior map is unchanged: no native authority, ownership/lifetime,
ABI, physical policy, execution identity, capacity, user control or dependency
changes. The two operational routes, optimization/reference contracts, roadmap,
handover, validation ledger and retrieval-corpus evidence qualifier now separate
actual scoped publication from pending full acceptance. Existing indexes and
retrieval questions already route to those canonical homes; no new canonical
topic or historical result is introduced.

A fresh detached companion-backed mirror, `source201-publication-docs`, uses the
five unchanged materialized companion files pinned at
`6a58311982941b75f46e22109a0829e5acb83c7e`. The parent is not a Git repository.
All18 required LFS payloads are checked against committed size/SHA identities;
the two native bytes come from the independently reviewed publication bundles.
Documentation, retained M11 integrity, `check_repository.py --require-materialized`,
provider policy and whitespace checks pass with **zero stale provenance entries**.
Frozen retrieval retains20/32 top1,32/32 top5,MRR0.7729; the128-question challenge
retains98/128 top1,128/128 top5,MRR0.8633. The1558 tracked raw files and all five
companion files are fenced before/after. Raw commands/results, initial/final
document overlays and source binding remain in `lcb201-publication-docs/`.
These documentation/materialization gates do not replace the pending ready-PR
runtime matrix or independently reproduce the recorded compiler toolchains.

## Moving-body lifecycle repair and second publication

A later actual ordinary-play regression found a retired gas label retained under
a moving body mask. The [separate dated repair record](2026-10-25-pressure-moving-mask-gas-retirement.md)
preserves the failed native/application controls, narrow reviewed repair,
141-case LLVM/MSVC and focused sanitizer proofs, fresh source-specific90-child
cost repeat and actual second Windows/Linux publication `40157133977`.
Its source is `eebd0c98`, runtime-only bot append `65f1f3b5`. Earlier source,
publication1, costs and CI remain their own historical evidence. The repaired
final head still needs its complete required ready-PR matrix before merge.
