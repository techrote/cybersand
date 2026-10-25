---
title: LCB-004 native observation apparatus checkpoint
status: Current
document-kind: evidence
scope: Local Windows O1 short apparatus qualification, complete resident accounting, preserved premise/schema failures and corrected retained-report reduction; Linux and Release CI and scientific acceptance remain pending
canonical-for: [lcb004-native-observation-apparatus-evidence]
last-reviewed: 2026-10-25
related-documents: [../operations/lcb-native-scientific-apparatus.md, ../operations/lcb-water-comparison-and-fixtures.md, ../architecture/lcb-pressure-inertial-handoff.md, ../operations/local-build-and-validation.md, ../operations/source-checkpoint-and-recovery.md, ../operations/current-and-historical-validation.md]
---

# LCB-004 native observation apparatus checkpoint

## Scope and exact source

This is a **local, unmerged apparatus checkpoint**, not a scientific campaign
or acceptance of a liquid family. Source base is
`dc2eee9408b959956153608a7ee6d212a5d21672`, branch
`codex/lcb004-science`, checkout
`C:/Users/_/.codex/worktrees/lcb004-science/khybersand`. The source remote is
`https://github.com/techrote/cybersand.git`; no tag identifies this local overlay.
The [canonical guide](../operations/lcb-native-scientific-apparatus.md) owns
the method and commands. Native World, Cell ABI, laws, defaults, protected
fixtures,117 registry classifications and publication requests remain unchanged.
No new native runtime is published for this apparatus-only delta.

The implementation changes only a standalone bench consumer, Godot
preparation script, Python producer/reducer and portable qualification runner
with their pure tests and a Makefile entry. Godot still owns fixture validation
and the controlled constructor; the standalone consumer restores their exact
CYPS bytes and reads public authority. It does not build a substitute fixture,
expose mutable World storage, introduce per-cell Godot calls or inject velocity.
The source-bound fixed-interest wording correction preserves the original
fixture and historical results rather than changing the selected region.

The checkpoint remains uncommitted here. Recoverable external source copies,
raw commands, build inputs, logs, snapshots and outputs are under
`C:/Users/_/.codex/tmp/lcb004-science-native-v1`. The final portable freeze is
`portable-harness-v1/final-freeze-coverage-corrected-v2/SOURCE-FREEZE.json`.
These local paths are evidence/recovery locations, not files to commit.

| Source file | Final raw/LF SHA256 |
|---|---|
| `native/bench/lcb_science.cpp` | `21f5a5f28b5e37c94af1d58ffb1ae991167d96acd2774a56e3165e4cfbca6baa` |
| `godot/tests/lcb_science_prepare.gd` | `786df51d2b2b31edd57d4772f612b882c9b0c263425fe8dc3ebbe0d93d8db7cb` |
| `tools/lcb/science_apparatus.py` | `1544c22e543c3e591eefd29f5108feddb3081e928adff0b8d0924f7445d4590b` |
| `tools/lcb/test_science_apparatus.py` | `4ccf6e9aeb198d59cb6bd958166067109845a5c5b3296b7d357e10c88778926e` |
| `tools/lcb/qualify_science_apparatus.py` | `4643dc6c91f2c6c3b62b52d07d3dea21df290a0d2ef21eac5a5ade6c92eea46f` |
| `tools/lcb/test_qualify_science_apparatus.py` | `81b6fecc689b51a2b136df8cfdb894014bc60583abfb1884083c33055e6619c2` |

The last reader/harness pair adds an exact integer coverage check and its25th
hostile raw-report mutation. The actual fresh six-child run used reader
`3cee14aa2653685536ca39abf9a5e2620407fe96f085d4bc52a649fea96b7695`
and harness
`abb43bac902c4de68b48e2c6d11aa014eb561eb17319db9e7c3831a58d3b523a`.
The later source pair **re-reduces those outputs**; it is not a new execution
of the engine or Godot.

The independent corrected-reader/portable-harness review is separately sealed
at `lcb004-science-harness-independent-v1-20261025/REVIEW-RECEIPT.json`,
SHA256 `c18a9433976cc17f5da3433760d144f65e2b8f8f1e6561a603b019f4ad05bd93`.
It authenticates the final source bindings,21 pure tests and independently
replays six retained positives/25 negatives with no open bounded finding.
It performs no duplicate engine execution and excludes full scientific or
platform acceptance. A later separate CLI semantic review is sealed in
`lcb004-science-cli-independent-v1-20261025/REVIEW-RECEIPT.json`, SHA256
`b93499ef9d0dd2be1b01c0b88b62d77a92c1e82d12e6d324eee0932f0c03c71e`.
It checks the exact21f5 CLI and Makefile target, actual CYPS2/3 serializer
widths/roster, bounded inputs, complete public census, ordered event/no-op and
thermal semantics, quantity/nineteen-ledger signed/L1 closure, exclusive
output/footer and timer separation. It binds38 compiled inputs/five objects
and independently reduces the retained ten positive and39 negative controls
without a new engine/build execution. No bounded semantic finding remains;
Linux/Release CI, full scientific and final merge gates remain separate.

## Actual build, runtime and bounded commands

The actual standalone Windows x86_64 build uses pinned LLVM-MinGW
`llvm-mingw-20260826-ucrt-x86_64`, clang23.1.0, compiler SHA256
`bf58cf0e544a308660645aad1fe65ae9cbc44b0871e4010278f3d9551f86a690`.
Flags are `-std=c++20 -O1 -g -Wall -Wextra -Wpedantic -Wconversion -Wshadow
-Inative/include`. Four existing simulation objects and the new bench consumer
link into an8,523,776-byte executable, SHA256
`4c4068ed9731f45bbe0220e6b1df549c67c324ddc505244f221f4f12956157c7`.
All38 actual standalone compiler inputs are hashed, with reuse allowed only
after complete compiler/flags/dependency/object equality. The first build's
three bench warnings were corrected before runtime; four pre-existing World
sign-conversion warnings remain recorded without a core edit.

Godot is4.7 stable (`5b4e0cb0f`) at the recorded actual executable path.
Preparation uses published Native Windows DLL SHA256
`e3f17363d21260690682dfaa9e5e118253544c1b9b19e69e50c03af567712343`
and selected Rapier v0.35.2 cooperative-join backport SHA256
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
It verifies all80 current published-native source inputs. Those80 manifest
inputs, the38 standalone compiler inputs and historical535 publication build
inputs are different ledgers. This checkpoint does not call every historical
build input current, nor grant verified mapped-module/executed-script/full-host
identity. Actual runtime/file equality keeps those existing qualifications.

The portable actual command is retained verbatim in
`portable-harness-v1/ACTUAL-RUN-COMMAND.json`; its shape is:

```text
python -B tools/lcb/qualify_science_apparatus.py run
  --godot GODOT --native-runtime PUBLISHED_NATIVE --rapier-runtime SELECTED_RAPIER
  --consumer LCB_SCIENCE --compiler PINNED_COMPILER
  --build-receipt BUILD_JSON --compiler-source-map COMPLETE_MAP_JSON
  --consumer-library FILE ... --out NEW_EXTERNAL_DIRECTORY
```

The runner calls the real `science_apparatus.prepare` path for each arm.
Godot import retains240s and preparation180s bounds. Each Native child is:

```text
lcb_science initial.cyps events.txt WORKERS 30 OUTPUT.ndjson
```

Native workers are1 or4, each child bound120s. Every successful Native process
has exit0 and empty stdout/stderr. The outer recorded Windows invocation has
a2100s bound and completed in63.328s; that elapsed apparatus time is not an
isolated solver benchmark. No retry or timeout increase is used. The standalone
Makefile target is `-O3 -DNDEBUG -flto`; **that Release target was not built or
executed by this O1 record**.

## Fresh three-precursor and six-child result

The fixed fixtures are the checked-in fully resolved
`lcb.dam.water.freemass.reference.v1.json` and
`lcb.mixed.water-oil-brine.v1.json`. Their actual canonical definition hashes
start `494a017b` and `208d488f`; the real validator and independently recomputed
canonical SHA bind the exact definitions and native prepared setup identity.
All three arms explicitly use radius3, seed0, fixed actor-free execution,
Baseline transport and their actual requested/readback policy. Water IN requests
initial `water-normalize-v1`; it does not authorize later fractional sources.

| Fresh arm | Host preparation | Native workers | Observation rows per child | Ordered events within30 | Actual maximum participants | Worker-parity projection SHA256 |
|---|---|---|---|---|---|---|
| Water FM dam | workers1,30 ticks plus actual restore0 | 1 / 4 | 32 / 32 | gate erase0 | 1 / 4 | `fb9bf49e8e59b065f55efe182928d9493943871b9b4105c0aabbc0b8978b237c` |
| Water IN dam | workers1,30 ticks plus actual restore0 | 1 / 4 | 32 / 32 | gate erase0 | 1 / 4 | `2b5098e3ee6ab32bfec596f5f2f8d273da22cb6ee558a781769529154b18ec54` |
| Mixed Water/Oil/Brine, Brine IN | workers1,30 ticks plus actual restore0 | 1 / 4 | 31 / 31 | none | 1 / 4 | `2fd3a32e96a444e4469ca3430976985f73e23792e07e821b55acb5c800afa7e0` |

These are six actual Godot processes (three imports and three preparation
children), then six fresh Native children. Each compares31 completed host
baselines. At zero, byte-identical re-export and original physical/content/two
comparison projections are mandatory, while Native legacy state hash equals
the separately observed **actual Godot-restored** zero hash. At completed1..30,
all five original prepared-host hashes agree. A workers4 restore does not
relabel the immutable workers1 construction receipt.

Every observation covers100 resident chunks, all1,638,400 coordinates in
chunks−1..8 on both axes, including Empty, inactive and outside-interest slots.
The real host enables fixed region `[16,16,992,272]`, selecting core64 range
x0..15/y0..4; applied cores latch at tick entry. This is not a window-off or
unrestricted-world run. The pressure-only roster getter returns0 without
pressure; the bench's bounded CYPS roster parser and authoritative restore/
roundtrip obtain the complete all-family roster without a new native API.

All phases have exact global species/Water quantity closure, all19 IN ledger
fields and independent signed-x/signed-y/L1 adjacent-phase accounting. Foreign/
Empty IN lanes are0, velocities and accumulators are bounded, and scheduled
post-event rows retain edit-time retirement. All observed tick chunk/thermal
allocation counters are0 and the roster remains unchanged. This is not a claim
of zero total heap allocation, per-worker utilization, render/Rapier cost or
complete process memory.

The first portable run binds834 source files, the80 published-native inputs,
38 standalone compiler inputs, actual compiler/consumer/shared libraries and
runtime bytes before output and after every child. Final source/runtime/input
fences remain exact. The complete pathsets are retained, not inferred from
these counts. Subsequent code/docs/CI changes require their own exact-source
validation; the old834 map must not be relabelled current.

## Preserved initial legacy-hash premise failure

The original six short Native children preceded the stronger precursor-v2
check. Root's comparison found all six differ only in legacy state hash at
completed0: the four other zero hashes and all five completed1..30 hashes
already agree. CYPS restore/re-export bytes are exact. The initial condition
had demanded all five zero hashes, so this remains a failed apparatus premise.

Independent little-endian FNV re-encoding of each13,170,562-byte legacy hash
stream reproduces **both** values by changing only aggregate chunk quiet time
on inactive empty reserved chunks, fresh0 versus restored3:

| Arm | Resident / active / inactive empty chunks | Active blocks | Original prepared legacy0 | Actual restored legacy0 |
|---|---|---|---|---|
| Water FM and Water IN | 100 / 35 / 65 | 207 | `9468ff82edce4922` | `c4c4213e638b27fb` |
| Brine IN | 100 / 39 / 61 | 271 | `37fbee3b607e4628` | `7e8998ea727cc361` |

Exactly65/61 bytes differ, one low byte in each four-byte aggregate quiet
field. `World::state_hash` hashes it (`world.cpp:4767`); fresh chunks initialize
it to0. CYPS serializes block activity/quiet/deadlines but reconstructs aggregate
quiet (`world_pressure.inc:2035`). `finish_tick` recomputes it for every resident
chunk (`world.cpp:4104`). The source search finds no simulation decision reading
aggregate chunk quiet; per-block quiet is distinct and serialized. Aggregate
active and nonempty counts are identical. No engine/CYPS/protected-golden change
is made to force the hashes equal.

Protocol v4, SHA256
`7a8e7479b872664b562efa590faf1b4ab6a4a5ee87774bc8e6c63224b0bca8ec`,
explicitly records the correction **after** those six short children and
**before** any full campaign. It strengthens the real Godot precursor with the
independent restore-zero check described above; it does not silently skip zero,
discard either value, waive continuation or alter a physical threshold.
Original outputs remain original executions; later strong sidecar provenance
and reduction never relabel them as newly run children.

## Preserved schema findings and corrected reduction

P2 found that a substituted normalized event program could retain an old
definition label. The corrected producer/reader binds original versus resolved
values, canonical definition SHA and the existing native receipt setup-hash
encoder (descriptor2/schema2/seed/full1024/coverage2/gaps63/prepared payload).
Three actual raw-sidecar mutations independently refuse original/normalized
substitution, both-text substitution with old hash, and a new definition hash
with old native setup identity.

P3 found Python numeric equality could accept bool/float header or quantity
integers. Exact type checks now cover workers/backend/CYPS, actual configuration,
quantity schema/mass bits, and census chunk size. The original portable run
passes six actual same-input positive reports before24 intended negative
replays. A later probe changes only coverage chunk size128 to128.0 and is
accepted by reader3cee14aa; that raw report and accepted reduction are retained.
Root adds one exact integer check. Harness4643dc6c adds the25th mutation, which
now refuses specifically `invalid integer census chunk side`.

Final reader1544c22e re-reduces the same original63.328s six-child cohort:
all six positives pass first, all25 hostile raw cases fail their intended
checks, and14 producer/reducer plus7 runner pure tests pass. **Zero new Native
or Godot executions** are claimed for this reader-only correction. Missing
ledger/phase/footer, substituted wire, invalid schema/quantity/worker bounds
and post-footer data refuse; an unrelated bad sidecar cannot satisfy a negative.
The old24-proof and accepted coverage counterexample remain immutable.

## Other retained failures and bounded controls

- The first staged import contains a Rapier LFS pointer, causing actual
  extension-load errors (Win32 error193) and warnings despite process exit0.
  The strict wrapper marks that import failed. Later staging verifies/materializes
  the selected B54 payload; no fallback or exit-zero acceptance hides the failure.
- The first standalone helper launch exits0xC0000135 before World execution
  because its runtime DLL directory is absent from the child path. The next
  helper binds the pinned libraries/path explicitly; the failed attempt remains.
- The next natural-motion helper omits the real dam gate erase0 and explicitly
  refuses because no moving Water exists at completed2. The corrected helper
  applies the exact registered gate event in warmup and every compared wire;
  it does not inject momentum or search/tune a physical threshold.
- A later controller filename collision stops before an empty-snapshot negative.
  Only the ten unexecuted negatives continue under a new directory. No previous
  file is overwritten or successful command re-labelled.

Additional external O1 controls pass10 positive and39 negative children. Positive
workers1/4 pairs cover empty, negative-coordinate/thermal Wall plus full Water,
natural Water IN motion, repeated same-visible fill and changed fill/erase.
At naturally selected `(231,96)` after completed2, `vx3,vy4,ax5,ay6`; two repeated
fills preserve all observations, while changed fill then erase books retired
x3/y4/L1=7 and Water−255 at post-event2. Negative controls include39 malformed,
overflow, existing-output and valid-checksum structural CYPS refusals. Actual
empty participation is0, small thermal1, and natural paired controls1/4.
These controls remain external apparatus evidence, not portable CI case counts
or a scientific campaign. The portable runner does not compile a second fixture
generator or duplicate core ownership.

## Retained packet identities

All paths below are relative to `C:/Users/_/.codex/tmp` and remain outside Git.

| Record | SHA256 |
|---|---|
| `lcb004-science-native-v1/build-v2/RECEIPT.json` | `4a13d62acf36ca9427c36f562df035c29f56a71de14dbc32742570eb1c833382` |
| Original six short children `qualification-v1/RECEIPT.json` under that root | `07e25005b3b98e7f1461e24954b3bacc8391374c0bfc77763cd0846ea96d15c2` |
| `initial-state-hash-diagnosis-v1/RECEIPT.json` under that root | `0fa2ad1fea084800a089e6dd839e376810d68db97c024acc9091e06a30973179` |
| `selfchecks-v3/RECEIPT.json` under that root | `3399f276cd79b69050628c56908148778fc4bcdd64a81a1f7250b211da9d5ecd` |
| `selfchecks-v3/structural-v1/RECEIPT.json` under that root | `5900d02d4b67fb6ed06ef6638adc9aabc8a227ee5d40ffaad4430b8edb232be0` |
| `portable-harness-v1/actual-run-v1/QUALIFICATION-RECEIPT.json` under that root | `61ffa22bd2354ae08056a5c6cc5b5a75f55af2e72406046ae3c44f2149a7ecc6` |
| `portable-harness-v1/coverage-type-probe-v1/FINDING.json` under that root | `f1bfdcdf1a6aa9bd9e58d27c0a38568fb5d493b3e3884be0862e841446ff7ffb` |
| `portable-harness-v1/replay-coverage-corrected-v2/REPLAY-RECEIPT.json` under that root | `5ebbf04716c0abe23a2f4676273d79baaa02fc6817b5cf35a193f6ca62e6713c` |
| `portable-harness-v1/final-freeze-coverage-corrected-v2/SOURCE-FREEZE.json` under that root | `fe892f4e88b8f7187ba6ff6d55775cde6c3a87121129208a85dedd46fe5dabbe` |

## Documentation checklist and remaining gates

The method guide owns apparatus interfaces, phase/lifetime/identity, complete
coverage, configuration and refusal. This record owns dated execution and
failures. Build/recovery/handover/roadmap/index/corpus routes are updated together.
One supplementary apparatus question is added; all151 prior challenge objects
and the separate frozen32 fixture remain unchanged. The new dated audit stays
outside the default retrieval corpus. Native ownership/Cell/ADR/law/defaults,
user controls and117 registry records do not change, so their canonical
requirements remain in force rather than receiving duplicate contracts here.

Current source inspection and local Windows O1 short qualification do not close
the apparatus merge gate. Actual **Linux and Windows Release scoped CI**, exact
source/runtime/build identities, current documentation/provenance and independent
review remain required. The O3 target has not yet been executed in this record.
Actual documentation validation is recorded below with its prose/input boundary.

The first proper-companion documentation validation is now retained in
`lcb004-science-docs-v1/checks-v1/VALIDATION-RECEIPT.json`, SHA256
`804fc0778d25ff9cb6ff5ef4511298a13af27bec8dca3b52d9f2684a348bc6f1`.
All seven checks pass: documentation, historical M11 integrity, materialized
current repository/provenance, frozen and supplementary retrieval, CI provider
policy and diff whitespace. The captured mirror has1665 source files, five
unchanged companion files at pin6a583119 and18 verified materialized payloads;
input fences hold and repository/provenance has0 errors. Frozen retrieval is
19/32 at rank1 and32/32 within5. Supplementary retrieval is117/152 at rank1
and151/152 within5; the missed existing query is LCB03, and the new apparatus
question ranks1. This is a lexical development-set route check, not a claim
of complete answer sufficiency, held-out quality or improved old queries.

That receipt precedes this additive results paragraph; a final prose/input
seal remains separately reviewable. The route-writing attempt first inherited
Windows cp1252 and stopped on a UTF8-only byte. Failed intermediate bytes are
retained externally; each affected route was reconstructed from its exact
pre-edit UTF8 baseline plus its sole new section. Existing body text was then
checked equal to baseline with the addition removed. All151 prior challenge
objects, frozen32 raw bytes and six protected code files remain exact. No
encoding failure or pending platform/Release/scientific gate is called a pass.

Before a full campaign, separately preregister/review fixture set, requested and
readback policies, normalization/quantity, geometry/body scope, seeds, events,
observer phases, horizon, repeats and child/full budgets. The residual-tail/step
witness must fix N/stop schedule/window/gravity-only stopping line before output;
no new numeric residual threshold is selected here. Preserve protected radius2
FM versus matched radius3 controls, PF implementation equivalence versus distinct
family differences and static rest versus continuation. Full-host/performance/
human-feel/packaging and #203 acceptance remain Planned. Additional Web testing
is owner-deferred until after the epic.

## Additive Release infrastructure checkpoint, 2026-10-25

Source base is apparatus checkpoint `e98d2b15801c67ec6bfa6db32d79242fea53842b`
plus exactly three infrastructure files: the Linux-host five-TU Release builder,
its pure guards and the scoped GitHub-hosted workflow. The existing six apparatus
code files, Makefile, all80 published Native source bindings, runtime payloads,
profiles, requests, defaults, fixtures and117 historical registry records remain
unchanged. The earlier O1 engine executions and every prior failure/receipt keep
their original scope; none is relabelled Release execution.

The new helper records `-O3 -DNDEBUG -flto`, all five actual per-object depfiles,
complete input union, object/executable/compiler-driver/library hashes, commands,
deadlines, logs and exact bundle identity. Source changes, incomplete maps,
changed transfer bytes, missing dependencies and existing/in-repository outputs
refuse. Linux180s compile/link timeouts kill the compiler process group. The
Windows PE is built on Linux with the existing locked archive and runs only
after the actual Windows LF checkout matches its complete raw compiled-input
map. The selected Linux-host compiler/driver file is hash-only identity data in
that execution job; its hash alone does not bind every compiler transitive input.
Pinned archive/version and explicit dependency file identities remain separate.

Local qualification consists of **34 pure tests**,13 new builder controls and21
retained producer/runner controls, plus provider policy and workflow structure
checks. The final command is `python -B -m unittest discover -s tools/lcb -p
'test_*science*.py' -v`, exit0 in0.609s. The new tests include complete five-TU
orchestration with synthetic object bytes, exact map/bundle transfer and hostile
changes, failed compile partial evidence, source mutation, toolchain member
binding, Linux dependency refusal, child failure/timeout cleanup and separate
Linux=true/Windows=false compiler-execution metadata. No actual native physics
compiler or engine is invoked by these tests. Workflow YAML, read-only hosted
routing, draft/dispatch conditions and always-on partial uploads are checked.

The initial pure test fixture accidentally contained a literal plus after a
Make continuation (seven passes/one error). A later Linux-timeout mock on the
Windows host omitted the platform-specific SIGKILL constant (nine passes/one
error). Both failed apparatus attempts remain in the external packet/transcript;
only those fixtures were corrected. Root review then required the target-specific
compiler-execution flag and compiler/driver wording, with explicit controls for
both values. The initial33-test proof remains immutable beside the corrected
34-test proof.

Evidence is outside Git at `C:/Users/_/.codex/tmp/lcb004-science-release-infra-v1`:
`final-proof-v1/RECEIPT.json` SHA256
`8a2c06bdf5325a9fafec7891f0534eac5cb1b3c63d77a2388ce22afd0556a56d`,
and corrected `final-proof-v2/RECEIPT.json` SHA256
`d42e7f077c1bed5b4ee163ec98a94448d4c6091e3a2615151fe531c2e0142bd3`.
Both retain exact source copies and raw stdout/stderr. The corrected builder is
`b4a1606ddd2763b3277337a10f5ab1c003de0bdc73ef3c22867fb3a6815a9f4b`,
test `5569bf80b1d5e702ea800e405e192acbff1c6407383a29d13ec813ca5b0940ef`,
workflow `21f401ab185dfa14c2ca56bd4d8e20bbdf53b348c68ebb59b397f8b166fe4605`.

At this checkpoint the new workflow has not executed, and the O3 target/build
helper has not compiled an actual consumer. Actual Linux and Windows Release
three-precursor/six-child30-tick/25-guard jobs and independent exact-source review
remain required before apparatus merge. A newly introduced workflow may need
the ready-PR event before default-branch dispatch is available. No timeout is
raised and no full campaign, residual threshold, long-horizon, browser, visual,
whole-application or #203 acceptance is claimed. Current documentation validation
for this additive infrastructure prose is recorded separately after its freeze.

The additive infrastructure prose has now passed all seven proper-companion
checks: documentation, historical M11, current materialized repository/provenance,
frozen and supplementary retrieval, provider policy and whitespace. Receipt
`lcb004-science-release-infra-v1/docs-checks-v1/VALIDATION-RECEIPT.json`, SHA256
`3b20b6c5dd250eaef58d4e37301da01ed546280ac843e3a1fc820f98363a1080`,
binds1668 source inputs, five unchanged companion files at pin6a583119 and18
verified actual payloads; all fences hold and repository errors are0. Retrieval
remains32/32 frozen and151/152 supplementary routes within5, retaining the
existing LCB03 miss. Independent source review of the three new infrastructure
files closes with no open bounded finding in
`lcb004-science-release-infra-independent-v1-20261025/REVIEW-RECEIPT.json`,
SHA256 `19ab806f240566d76ac4fbf8a924128cb95bd88197a6c5d0a65e64f8278a2bee`.
It independently passes13 helper guards and authenticates the34-test/provider
streams, unchanged seven apparatus paths and published Native80. Neither this
review nor documentation validation executes the pending Release/platform jobs.

## First actual hosted scope failure and bounded repair

Actual run40243375312, source `baab6d75143bbdfd4bd409238f5525f6aeda6c6c`,
finishes failure at23:09:29UTC. Independent capture retains fresh run/three-job
APIs, all three raw job logs and all three artifact ZIPs authenticated against
GitHub's API SHA256 digests. Packet
`lcb004-science-release-infra-failure-40243375312/CAPTURE-RECEIPT.json`, SHA256
`a8777b560963b9615c4e371760a59c5bea4d01b9ff10e9bdb06479caf3c69f37`,
preserves the complete first attempt. The gh client initially refuses raw
terminal-escape bytes; archival `--allow-escape-sequences` captures those logs,
with that capture-apparatus failure retained and no test/source change.

- Linux job121319740243 fails compile4 of the apparatus consumer. GCC13 parses
  `Reader in(std::span(bytes).first(...))` as a declaration and reports the
  missing template argument/placeholder error. The first four core objects
  compile; no Linux link, runtime import or qualification follows.
- Windows cross-build job121319740078 succeeds, including all five actual
  compilations, O3/LTO link, PE/import inspection, locked archive/member bindings
  and38-input source verification. Its actual consumer SHA256 is
  `af5fcb28b00bbbdba1dcc82e1cf1ca8b50f326d91d782d83402123175764a2c4`. This is a successful build of the prior consumer, not successful
  Windows physics qualification or proof of the later correction.
- Actual Windows job121319939960 refuses `native/src/world_inertial.inc` raw
  equality before runtime/Godot/preparations/Native children. Other scopes are
  skipped, not green. `*.inc` has text=auto; native Windows eol remains CRLF
  despite the preceding global autocrlf=false setting.

The bounded consumer repair uses explicit `std::span<const std::uint8_t>` and
brace initialization with the same checksum-excluding bounds. Five warning-only
statement line breaks remove GCC misleading-indentation diagnostics. No World,
header, ABI, codec, law, fixture or published Native80 input changes. The original
21f5/O1/CLI semantic review and63.328s engine cohort remain historical and intact.

The Windows setup repair authenticates the complete bundle, actual Git HEAD,
unchanged index and every compiled Native text Git blob. It sets local
`core.autocrlf=false`, extracts only those paths with scoped `core.eol=lf`
`checkout-index --temp --stdin -z`, authenticates every temporary byte sequence,
and atomically replaces the corresponding paths. It records each before raw,
canonical-LF and Git blob identity plus after raw SHA. Canonical hashes are
diagnostic only: final complete raw source-map equality is unchanged. No broad
checkout, LFS smudge or data-parser normalization is used. Always-upload also
retains this separate setup evidence/partial failure directory.

Real temporary-Git controls caught and preserve intermediate setup premises:
plain forced checkout can skip a stat-cached file; refreshing the fixture index
stops before restoration; temporary extraction without explicit core.eol=lf
still produces native CRLF and correctly fails exact hashes. The final positive
control starts with actual CRLF, restores exact Git LF, leaves an unrelated file
unchanged and passes the original verifier. Non-Native and changed-Git map
mutations refuse before restoration. These controls execute Git only, not World.

Corrected source proof is
`repair-proof-v1/REPAIR-FREEZE.json` under the capture root, SHA256
`0fc237952dca835338eb5d43cb8848567ae27931e16f81023107b49bb7b5196f`.
All36 pure controls pass in2.403s, provider/whitespace pass, and actual pinned
Windows Clang23 syntax-only exits0 in6.640s with empty streams. The four source
hashes are builder4af40379, testa3ee62cc, workflowb7eb6a16 and consumer075bb236;
full hashes/copies/commands are retained externally. Both published Native80
sets and the other six apparatus/Makefile paths remain unchanged. There is no
repaired GCC build, newly linked consumer, new physics execution or actual
corrected platform CI result in this local proof. No retry, raised deadline or
full scientific campaign is implied. Exact corrected-head platform qualification
and independent review remain required; current proper documentation validation
will be bound separately after this additive prose freeze.

## Second hosted attempt and test-fixture root correction

Run40244829655 at `7ebadf1e9d6c009e77604104ab2e177ee4bc65a6` reports a
successful Linux job, including actual GCC13 Release build and the three
precursors/six bounded children; detailed artifact acceptance remains separate.
Its Windows cross-build also succeeds. Actual Windows then authenticates all38
compiled raw source inputs, demonstrating the Git LF restoration, but stops in
two Python refusal-test fixtures before runtime/Godot/physics qualification.
The failed Windows job121324281108 and skipped physics steps remain failures.
Independent raw log SHA256 is
`3b5f7bd1fca12ac94c5accf3df49574aa8c0e42c42b83530163c0c67991b8474`,
retained under `lcb004-science-fixture-alias-failure-40244829655` outside Git.

Both failed fixtures mocked ROOT with an unresolved temporary path, unlike the
production `Path(__file__).resolve()` root. Their output paths are resolved
before the existing inside-repository refusal check. An independent real Windows
GetShortPathNameW counterexample proves a short/long alias can therefore bypass
that fixture comparison; packet
`lcb004-science-release-corrected-independent-v1-20261025/WINDOWS-PATH-ALIAS-COUNTEREXAMPLE.json`,
SHA256 `9c4ea3d28a802a4e915358555796cdda044e07b14553abdd67a9f99fdf5d4350`.
The hosted log does not print its TEMP spelling, so the particular hosted alias
is inferred from the matching source/behavior, not directly observed.

The bounded correction adds `.resolve()` only to the two mocked root initializers
in `test_build_science_consumer.py` and `test_qualify_science_apparatus.py`.
Every output-admission/refusal/error assertion remains unchanged. The production
builder, qualifier, workflow, consumer, World/law/API, runtime and thresholds do
not change. All36 local guards pass in2.551s; provider and whitespace pass.
Source proof `correction-proof-v1/SOURCE-FREEZE.json` under the failure root,
SHA256 `87fd223c941ed910820b00cf7a42da03eb79b13489d43910865a76b45e923efd`,
binds the exact two-line delta and unchanged production hashes. This local
fixture correction is not a new compiler/physics execution or corrected Windows
qualification. Both earlier failed runs, actual Linux results and old O1 source
proofs retain their own identities; final exact-head gates remain required.
