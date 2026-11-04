---
title: Workbench 394 protected material-source transition
status: Current
document-kind: evidence
scope: Reviewed three-consumer technical MAT admission for the retained workbench native source; frozen identities and historical compatibility evidence remain unchanged
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md, 2026-11-04-mat-auth-reviewed-transitions.md, 2026-11-04-workbench-consolidation.md, 2026-11-04-workbench-boundary-and-pacing.md]
---

# Workbench 394 material-source transition — 4 November 2026

## Decision and limits

**Independent scoped technical admission: GO for the three exact entries below.** The owner asked
to clean up Draft [PR #394](https://github.com/techrote/cybersand/pull/394), work
through MAT admission and preserve the current flight/contact feel, with the PR
unmerged. This record retains the reviewed candidate; it does not assert owner adoption,
merge authorization, a catalogue cutover or completed gameplay qualification.

The [original MAT handoff](https://github.com/techrote/cybersand/issues/391#issuecomment-6640737890)
requested a separately reviewed source/interface transition, with protected
Current material/capability/quantity controls. The later
[owner-approved mechanism](https://github.com/techrote/cybersand/issues/353#issuecomment-6642966578)
is implemented by [PR #396](https://github.com/techrote/cybersand/pull/396) at
`4aeac7071d1446e33bce7ccda0eafaeae7077847`. Cleanup merge
`972616ef3d5fc1d476a3fcc5c0ea13fb7057dcf9` preserves that implementation and its
independent review in ancestry. Its checker rules are unchanged here; this
candidate adds only the three code-pinned entries and this review record.

The [canonical transition rules](../operations/material-catalogue-shadow.md#reviewed-per-file-transitions)
apply. Each target must match its retained source commit exactly, all other
protected files must retain their baseline bytes, and all twelve identity inputs
are refused as per-file transitions. The guard authenticates identities and
records; it cannot prove behavioural equivalence. Independent review of the actual source changes and controls completed as recorded below; owner production adoption and final integration remain separate.

**Keep PR #394 unmerged.** Any eventual entry-adding integration must preserve
`source_commit` in history through a merge commit. A squash or rebase that drops
it is refused by the guard. Reverting these source changes requires reverting
their entries together; old source bytes do not pass an admitted target entry.

## Exact source checkpoint and protected inventory

The accepted-main starting point is
`751edc0b495dc85484ad5509a7c95f863651c76b`. The frozen compatibility oracle remains
`0fd4af5987e77db4da3e37c757cf2c0917ae9e15`. All three targets are the LF-normalized
bytes at retained native build source
`1ca90de5181953f9ebd95ef19c920d8dee7e17e2`, and independently match original
PR #394 head `1f968fa2ab403aa564aa6c816e60bf6c572b27a5`.

| Protected consumer | Frozen/from LF SHA-256 | Candidate/to LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1` | `a47955f79ed5fbc8bc0ca8e2892ed4eb0ddbd728b841bc08ccee14a4c239e4a7` |
| `native/src/world_pressure.inc` | `c8cb11512e935d05e099d8f155c1659473a7f61aa301e2e4900e55bdcfe4024b` | `a1dd5c486dad16f114cce3b38d292407edb91e5bbaf03d0193dcc4ecd7338e62` |
| `native/src/world_inertial.inc` | `f9e891dafa9c61e76460b5b3a720e3e522e7b63c381e81539e5e508b2719a0dd` | `8a5d3680e96ca47a3f496be5a8b953084d2c6d2e0bd723c3214b87bdbc3580b5` |

An LF-byte inventory at cleanup merge `972616ef` found exactly **3 changed and
24 unchanged** protected consumers. All **12 identity inputs are unchanged**.
The compatibility lock itself is unchanged, file SHA-256
`8b4d3351cbe4380e976655d10dc34c4bf9e81d95442719a53770b62d219183dc`.
Catalogue digest remains
`82b5ab9a6e87ae817072390105052f8a5ac6d0ee22b3301cd973efdfc7fdbad3`;
capability digest remains
`33c608f875e3d8b5730f1d3b81a54dbeff9579b433e061535610a8bfa276e237`.
The unchanged files include the material and reaction headers, quantity codec and
ledger schema, policy identity generators and retained wire/normalization/receipt
vectors, and fallback identity, granular-policy and appearance definitions.

The raw local inventory is `build/cleanup394-mat/protected-inventory.json`,
file SHA-256 `3475135880a816c507dd518845c512f10a08b8a173e59d3be7b941440252b21d`.
It is reproducible from the unchanged lock, `SOURCE_ROLES`, `IDENTITY_INPUTS`
and the three retained commits using the checker's LF normalization. Generated
raw receipts remain local; the exact source checkpoints above retain every
material claim's inputs.

Before adding entries, the inherited #396 guard correctly refused World.cpp's
drift with exit 1. The local original stream is
`build/cleanup394-mat/pre-transition-refusal.log`, SHA-256
`f3b8b9e8d2cc16ffef48f8fe4fcfb171840e132cbb6717c51e4450aab2a03c26`.
That refusal and the earlier documented refusals remain valid evidence; no
baseline hash was refreshed to erase them.

## Source review boundary

Against accepted main, the protected diff is World.cpp 275 additions/32
deletions, world_pressure.inc 214/18 and world_inertial.inc 1/1. Review the full
diff, including inactive paths, rather than treating the pressure include as
only a contact-signature edit.

- **World.cpp:** extracts the existing stable-grain support predicate, adds the
  bounded side-contact admission query, supplies native contacting coordinates
  to contact observations, and adds opt-in granular wrench/arrival accounting.
  Arrival storage is disabled on ordinary construction and allocated only by
  explicit pre-tick enablement; non-transport writes retire provenance. Existing
  raw blocked-contact counters and impulses remain available. Explicit workbench
  mask reservation and external-coupling quarantine are separate bounded owner
  operations. Material cells remain native-owned; this introduces no cell erase
  or body-to-material conversion.
- **world_inertial.inc:** supplies the already known source coordinates to the
  same contact observation; the IN movement and state-update law is retained.
- **world_pressure.inc:** supplies those coordinates on Water contact, adds an
  explicit prepared-destination workbench liquid/state transfer with quantity,
  overfill, gas, exterior inventory, IN and loss receipts, and adds opt-in
  reference pressure-column dispatch. Ordinary hosts keep their existing
  execution policy. Column tasks join before row repair/wake processing. The
  pressure hash, policy identity and physical save codec stay under their
  retained contracts; exact parity controls are needed for execution changes.

The intended active workbench granular response is the previously reviewed
LA-SA route. The source transition does not authorize changing its coefficients,
material laws, flight control forces or sleep behaviour. It also does not
admit an unbounded body/material carrying guarantee: the earlier measured
Scooper drips and carry limits remain qualified as recorded.

## Qualification and review ledger

Preparation used Windows 11, PowerShell, Python 3.13.16 and retained Git objects.
The three entries and initial record were committed at
`d008b292e51754a4a3e4995aaaddfe08a7987d99`. Fresh focused MAT checks ran at that
commit. Linux execution used WSL, Python 3.12.3 and GCC 13.3.0, with a genuine
shared Git clone at `/tmp/cleanup394-mat-d008b292` from the same retained object
store. This avoids interpreting a Windows worktree pointer as a Linux Git path;
it changes no source or checker rule.

| Gate | Current result |
|---|---|
| Three retained blobs, other 24 owners, 12 identity inputs, lock and digests | PASS at cleanup merge `972616ef`; hashes above |
| `python tools/material_catalogue/compatibility.py --check` | PASS at `d008b292`, both Windows checkout and Linux clone; identical receipts with exactly three entries, 180 s bound |
| `python tools/material_catalogue/compiler.py --check` | PASS; authored source and generated shadows unchanged, 120 s bound |
| `python -m unittest discover -s tools/material_catalogue -p 'test_*.py'` | Linux PASS, 118 tests, 99.325 s test time, 900 s bound; includes real-history transition and existing adverse controls |
| `python tools/material_catalogue/check_native_parity.py --output build/cleanup394-mat/native-parity.json` | Linux PASS, 13.635 s process time, 600 s bound; metadata/pure-query scope only |
| Inactive accepted-main/candidate native differential | PASS in the bounded four-arm control described below; no universal equivalence claim |
| Native core, arrival and pressure-head controls | PASS: core 165 tests, arrival 196 checks, head 827,303 checks; details below |
| Quantity/inheritance and pressure-capacity controls | PASS in the 165-test native core; pressure-capacity control reports 52 assertions |
| ASan/UBSan active arrival and pressure-head controls | PASS: 196 and 827,303 checks respectively |
| ASan/UBSan full native core | PASS: 165 tests, exit 0, 680.042 s / 900 s, detect_leaks and halt_on_error enabled; no sanitizer diagnostics |
| Godot integrated host controls | PASS at `a393a797`, all twelve scoped fixtures on each Windows/Linux runtime, plus imports; no error/leak diagnostics |
| Independent exact-entry/source review | GO for these three exact transitions and cleanup runtime at `a393a797`; no owner production adoption or merge authorization |

Local focused receipts under `build/cleanup394-mat/` authenticate the literal
commands, committed source and timeouts. Their content hashes are:

| Evidence | SHA-256 |
|---|---|
| `windows-guard.log` and identical `guard-linux-clone.log` | `a9ff16a5b850fbbf3c6ea77e13b58d30782fb58ef3d653bf6252a5eb40f91412` |
| `compiler.log` | `d645a144c75f3517397c704fe81a8efb86fd092f64d93147bcfa35a1afc8bd3b` |
| `catalogue-linux-clone.log` | `b17273793ad048f22e5736a318b0f36d1c0f9909edbb6ba75a874a925fb115e1` |
| `native-parity.json` | `fe7ca82434f747b9752ebe6bcc383b89b78430a31af0b94eaa8fb778429238d0` |

The table hashes the retained file bytes. Windows writes of captured text use
CRLF; the runner's `captured_lf_sha256` separately authenticates the normalized
captured stream. Those two identities are deliberately distinguished rather than
mislabelled as the same file hash.

Compiled native parity retained 132 slots, 15 descriptor fields, 256 byte IDs,
56 pair rules and 19 specialized records. Exhaustive pure-query checks passed
16,777,216 cases each for pair resolver, wrapper and viscosity, and 17,170,432
appearance/projection cases. The report includes the three transition entries;
its retained `source_commit` is the original metadata oracle identity, not a
claim that this run executed that historical World or the workbench physics.

**Preserved failed attempts.** The first three Linux commands ran directly in
the Windows worktree. Linux Git interpreted its `C:/...` worktree pointer as a
relative Linux path and could not authenticate the retained baseline. Guard and
parity exited 1; discovery ran 77 tests with two class-setup errors and exited 1.
The original local streams remain `guard.log`, `parity-linux.log` and
`catalogue-linux.log`. The intermediate guard also refused the uncommitted
record, as required (`precommit-guard.log`). These are environment/record
admission failures, not passing executions; the successful clone runs above are
separate retries. Neither expected hashes nor authentication rules were changed.

### Inactive Current-behaviour differential

The retained [probe source](workbench-391/material_source_probe.cpp) builds
against the complete accepted-main `751edc0b` native headers/objects and against
the current `1ca90de5` native source, separately. It leaves arrival witnesses,
granular wrench accounting and workbench pressure-column dispatch inactive.
Both executable arms run the same mixed-material/transient-mask setup at default ambient temperature
for 48 ticks in each of four configurations: Water FreeMass and PressureFlow
reference, each at one and six requested workers.

All **192 observations** match. The complete serialized CYPS byte streams total
**25,478,922 bytes**, equal SHA-256
`902dc1c553e6f49d6694c55c875143fd07c164e0d8452e5158beda3e9b7fa519`.
Per-tick physical hashes, visited/active work and legacy contact counts plus X/Y
impulses also match, output SHA-256
`8a2e89744abfd937ebdc31e182a8597c55baa73dbe8a8d58f97654b6882cb01d`.
Literal build/run commands, compiler flags, timeouts and result fields remain in
`build/cleanup394-native/differential-receipt.json` and
`build/cleanup394-native/differential-result.json`.

This is a bounded regression control of the two selected Water families and
fixture. It does not execute an IN-policy differential, every possible material
state, or active workbench conversion/response. The active fixtures and broader
native suite remain separate gates.

### Fresh native execution

The source-matched Linux objects were rebuilt with GCC 13.3.0 using
`-std=c++20 -O1 -g1 -pthread -Inative/include`; the sanitizer objects add
`-fsanitize=address,undefined -fno-omit-frame-pointer`. No native production input
changed from `1ca90de5`. The full core executable passed **165/165** tests,
including the quantity-ledger control's workbench IN inheritance, exterior
inventory and clipped pressure/gas-sidecar cases, and the prepared initial
pressure-capacity control (**52 assertions**). These functions are registered in
the core suite; the pressure-capacity file's standalone main is conditional.
Both the normal and ASan/UBSan executables passed
`native/tests/test_workbench_arrivals.cpp` (**196 checks**) and
`native/tests/test_workbench_pressure_heads.cpp` (**827,303 checks**).

The active arrival control covers genuine scheduled grain transport, once-only
admission, retirement by identical paint/non-transport writes and relocation,
mask refresh, separated distant proxies, density-specific impulse/moment, Water
exclusion and explicit stamp exhaustion. Its isolated mechanism probes are
labelled in source and supplement the real tick arms.

The head fixture compares one/six requested workers with dispatch off/on,
including signed chunk boundaries, missing columns, lids, moved masks, sealed
gas and venting. It verifies CYPS bytes, physical state, quantities, per-cell
heads, wake/work counters and scheduling. Normal and sanitized streams match:
head log SHA-256 `0c0273e071ea87bcaa12d9727126db4c98823b88c585edd0e28f1abbaeb8c3c8`;
arrival log SHA-256 `f4cf3e9ccfc7e4dd82164ea314df9f88b38ec1d9d6b33e19ee966a85b2acb9d3`.
Literal object/link/run commands and measured times remain in
`build/cleanup394-native/core-receipt.json`, `scoped-receipt.json` and
`san-scoped-receipt.json`; original output remains alongside them.

The first local native build attempt found `make` unavailable. Its failed logs
remain retained; the successful controls use the direct compiler commands in
those receipts. Full-core sanitizer and Godot host results completed successfully as recorded above.
Earlier ThreadSanitizer evidence stays
historical; this checkpoint does not claim a fresh TSan run.

Earlier source-matched execution is retained in the
[boundary/pacing audit](2026-11-04-workbench-boundary-and-pacing.md) and
[consolidation audit](2026-11-04-workbench-consolidation.md). In particular, the
four-arm pressure-head fixture compares per-cell heads, physical hash, CYPS2
bytes, quantity ledger, diagnostics, wakes and scheduling over 42 ticks. That
within-candidate parity does not by itself prove accepted-main equivalence.
Native query parity likewise does not execute World ticks or certify gameplay.

PR #384 remains a separate generated-display consumer admission. Its current
`3d537d1a62e9b7eca546c63ffd4ec6e7654d5957` executable-inventory guard does not admit
these World changes and is not imported. Its behavioural interaction with the
new transition mechanism is recorded by
[the MAT owner](https://github.com/techrote/cybersand/issues/353#issuecomment-6643681542).
Future reconciliation must preserve both programmes' explicit boundaries.

## Final scoped independent review

An independent Codex reviewer authenticated all three entries, retained ancestry and blobs, the unchanged lock/24 consumers/12 identity inputs and digests, and the bounded source/evidence controls. The final full-core ASan/UBSan log is `build/cleanup394-native/run-core-asan-ubsan.log`, raw SHA-256 `7348fff54dbcac0003e4ebfab79d8a0860a1ffd820ed23a735cb39f9cbe7f605`, 165 tests, exit 0 in 680.042 seconds within 900 seconds. The reviewer found no AddressSanitizer, UndefinedBehaviorSanitizer or leak diagnostic. All 26 integrated Windows/Linux host processes authenticate against runtime/test checkpoint `a393a797ad7c535fdf177143e660838726ad9ba2` with unchanged inputs and clean shutdown.

**GO for this exact three-entry technical compatibility/runtime admission on the Draft branch.** No source blocker remains within that scope. This grants no catalogue cutover, production-default change, subjective gameplay acceptance, broad material-carry guarantee, Web/full hosted-release qualification or merge authorization. Keep #394 Draft and unmerged. The original frozen refusal, failed environment/teardown attempts and historical workbench limits remain retained. See the [cleanup qualification](2026-11-04-workbench394-cleanup.md) and its [compact result manifest](workbench-391/cleanup-results.json).
