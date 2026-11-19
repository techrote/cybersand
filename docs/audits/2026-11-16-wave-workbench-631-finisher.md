---
title: PR 631 Shared Workbench Wave configuration repair
status: Current
document-kind: evidence
scope: Dated starting failure, adapter and Workbench repair, source-bound regression and publication requirements; final run and artifact identities are retained in the PR ledger
canonical-for: []
last-reviewed: 2026-11-16
related-documents: [../architecture/wave-flow-v1.md, ../operations/wave-flow-evaluation.md, 2026-11-15-wave-mt-001-astra-takeover.md]
---

# PR 631 Shared Workbench Wave configuration repair

## Scope and custody

Owner-authorized WAVE-WORKBENCH-631-FINISHER works only on
`astra/wave-mt-001-669-finisher`, [PR #631](https://github.com/techrote/cybersand/pull/631).
Starting source was freshly verified as
`3889cdd52bb5a67bd450d6abc42f0008d58b6cce`, complete tree
`ea0f72e38f72c6d4cfc0ba7ecaf6130996ef24ff`.
Main, PR #617 and PR #618 remain read-only. No merge, auto-merge, Water-default
promotion or physical Windows 11/NVIDIA acceptance is authorized or claimed.
The PR was restored to Draft before implementation. A controlled non-Draft
transition may admit full CI; restore Draft after qualification.

The earlier `d2245ea8` packet covers its dedicated evaluator and its own source.
It does not qualify the newer ordinary Workbench integration. The final PR
ledger must bind this repair's actual source/tree, publication source, runtime
append, immutable runs/jobs/attempts and downloadable artifacts. Source or
test presence alone is not a passing runtime result.

## Starting failure reproduced

[Godot CI 43788284591](https://github.com/techrote/cybersand/actions/runs/43788284591)
failed on Windows shard 14, job `133042731230`, and Linux shard 4,
job `133042938339`. Both original logs report **192 checks, two failures** in
`test_workbench_canvas.gd`. Wave requested two rounds and gain 48; native readback
reported disabled, substeps 1, ticks/rounds 0, gain 32, despite completed native
tick 60. The remaining parameters also retained their defaults.

An isolated local checkout of the exact starting source reproduced the same
**192 checks, two failures**, exit 1, before implementation changes. It used
official Godot 4.7 on Linux and the materialized retained libraries:

| Runtime | SHA-256 |
|---|---|
| Native Linux | `7a408bd9285451a3c03b40a25ad0451b5ed8ffde90e890352310d489601a6963` |
| Rapier Linux | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |

A separate probe retained the actual refusal:
`malformed_policy: wave_flow does not support custom cellular transport policies`.
The replacement receipt reported `scenario_request_applied: false`. The old
native World was correctly preserved. The test's former pending-empty predicate
could mean either acceptance or refusal, so it did not establish installation.
The original assertions exposing disabled Wave and default tuning are retained.

## Root cause and repair boundary

Ordinary Workbench constructors resolve the Baseline transport table and decode
it through `TransportPolicy::unpack`, which marks that table explicitly
configured. The Wave adapter formerly refused every configured table as custom,
even the exact baseline. Thus the Wave request reached native admission but never
became the live World. Native diagnostic readback was truthful.

The repair belongs to the prepared-World adapter and Workbench request/receipt
path. It admits only the exact unchanged Baseline table as the default native
transport, including the native Mercury cadence. Custom transport and malformed
Wave options still refuse before replacing or mutating the running World.
Worker configuration is a typed, bounded construction setting. Requested UI
values and native applied values remain distinct. Rebuilding resets retained
Wave momentum; it does not pretend to continue the old physical state.

The wider real-tick regression exposed a second independent construction
failure. Wave legitimately retains uint16 Water mass above 255, but the generic
prepared final-cell constructor accepted only the nominal fractional byte
domain. Live retuning consequently refused after actual Wave evolution. The
explicit `WaveStored16` setup domain now admits exactly coherent-zero Water
mass 1–65,535 with the existing eight-bit quantity scale, only when Wave is
enabled. It forbids normalization. The constructor retains the full cell payload
and ledger. Its prepared-population ledger check uses the uint16 carrier bound
only for Wave; generic fractional and whole-cell admission are unchanged. Native
regressions exercise 1, 255, 256 and 65,535 units, invalid zero/coherence/settings,
exact prepared identity and real ticks. No numerical flux rule changes.

An overfilled live Wave World cannot always be represented by an existing
Water law. Such a switch refuses explicitly and preserves the current World,
rather than truncating quantity. The comparison scene reset reconstructs the
same authored fixture under the requested law. This negative result remains
part of the regression and the owner guide. Unsubmitted tuning is also kept
separate from accepted construction options, including unrelated authoring
actions and recovery after a failed simulation owner.

The Wave numerical law, version-2 constants, native cell authority, conservation
rules, physical identity and unsupported-save behavior remain unchanged by this
finisher. Existing Water laws retain their own settings and default selection.

## Protected consumer transition

Source anchor `1ca6da11427291a87409f7583df8cb4831a03bca` retains the two narrowly
changed material consumers for PR/issue #631. The immutable catalogue lock and
identity inputs are unchanged. The compatibility table authenticates this exact
commit, its ancestry and the following LF-normalized bytes:

| Protected path | Previous SHA-256 | Reviewed SHA-256 |
|---|---|---|
| `native/src/world_pressure.inc` | `ccd3c773992560a22989a3009c5dc383e4a16cc83d6dd21be0ca4b5111a842b4` | `9ee31ffc4ea89b50f78e39eecc8f5c9be5944bcbc2f6ead48698c714564b7067` |
| `native/src/world_quantity.inc` | `1dc5ac99aacb1bac6a41edb0aa7479ed4dbef2b493e1d26b02e185aaff9c3e1d` | `75f9743ee614fd6e5ee6ae96d3f35445b3162e19c9f7686b9eefc29f97e52dae` |

The pressure source changes only retained construction transfer: source Wave to
non-Wave conversion scans interior and halo Water before normalization or
clipping and refuses overfill outside the target carrier. When source Wave is
off, the prior skip condition and every old-law arithmetic branch are unchanged.
No pressure or Wave tick kernel changes.

The quantity source changes only the prepared-population validation ceiling.
An enabled Wave owner uses 65,535 per prepared Water cell, with checked uint64
multiplication. Non-Wave Worlds still use the exact previous nominal maximum.
Quantity scale, ledger schema, counters, serialization and physical hash streams
are unchanged. Dedicated native boundary/identity/refusal tests and the real
Workbench fullmass retune regression cover these changes; full default-off,
material-parity, sanitizer and platform gates remain mandatory.

## Qualification contract

`test_workbench_canvas.gd` retains the original two activation/tuning checks and
requires successful installation. `test_workbench_wave.gd` adds real ordinary
Workbench activation, all exposed parameter readbacks, workers/substeps,
runtime replacement, regeneration, scenario change, pause/resume, invalid-setting
recovery, solver switching, comparison scenes and native admission validation.
Its unique `WORKBENCH_WAVE_RESULT` must contain positive assertions, no failures,
all required completed sections and authoritative observations of enabled Wave
with advancing native ticks/rounds. A UI label or cleared pending queue cannot
qualify this contract.

The runtime publisher retains the old Wave, LiquidSolverPolicy and PressureFlow
controls and additionally requires both Workbench suites on Linux and Windows.
The extracted Windows package independently executes Wave, both Workbench suites
and the actual `Open Workbench.cmd` launcher, then rechecks every original payload
hash. The publisher retains source/build input ledgers and only appends the two
runtime libraries and their two provenance manifests after both platforms pass.
Full Native, Godot, Wave, Water, renderer, material and provenance gates remain
required for the resulting source, followed by independent GPT-6 Astra review.

## Retained Q qualification and independent-review correction

Candidate `93a5e85dc9d5459a5f9cce00839b64090a1a0573`, complete tree
`1035c8ae3c30fb50dafd483916f1c21b59200e2d`, completed its full controlled Ready
qualification and returned to Draft. All six Native families, Wave's complete
Linux/Windows/default-off matrix, Windows Godot, Water, material/provenance and
palette gates passed. Linux Godot retained one failure in the existing Deepworks
render fixture: three visible atmosphere pixels in D1 against its unchanged
minimum of four. [Run 43831136663](https://github.com/techrote/cybersand/actions/runs/43831136663)
and its original logs remain failed; the original runner did not retain that
RGB frame. This source was not delivered as a qualified owner candidate.

A fresh independent GPT-6 Astra review also reproduced a shared-status defect:
staging Ballistic Water left the native owner unchanged, correctly, but the
new main status still said `APPLIED`. Its comparison covered Wave, policy and
workers while omitting other construction controls. An unchanged asserting
probe against Q recorded twenty checks with four failures, one each for
Ballistic Water, IN signed, Face release and Fine cores. The corrected development
runtime/UI recorded twenty checks with zero failures using the same probe.

The native diagnostic now copies these flags, actual scheduling geometry,
face-release parameters and compartment capacity from the authoritative World.
The panel compares every applicable staged construction value, including its
type, and identifies differences. Dormant law preferences do not become active
requests. The Workbench regression additionally exercises real replacement and
ticks, each face control, fine-core reset, same-law capacity refusal, fresh
capacity application and return to a non-pressure law. This changes diagnostics
and presentation only; the native solver arithmetic remains unchanged.

An interim independent review identified two further omissions in the same
status contract: the visible geometry selector and one-shot Water rounding.
A separate unchanged-Q probe recorded fourteen checks with two failures while
the native radius, owner and normalization state remained unchanged. The status
now compares the exact effective radius consumed by Apply, including the
policy's minimum, with native `maximum_rule_radius`; its tooltip exposes both
the raw selection and effective value. Checked one-shot normalization remains
staged until successful construction clears it, even for zero net mass change.
The regression applies radius three, executes a native tick, applies and reads
the normalization receipt, then restores radius two without repeating rounding.
It also checks an Inertial minimum-radius no-op without false staging.

The review additionally found that formatting a malformed container-valued
rounds request through `int(...)` could abort the refresh and retain stale
`APPLIED` text. The formatter now identifies invalid types without conversion.
The regression stages Dictionary and Array values, requires truthful status,
and exercises native typed refusal with unchanged ownership and state.
A separate unchanged-Q probe first enabled Wave and completed one native tick
with two rounds, then reproduced both malformed-type failures: eighteen checks,
two failures. The same three external probes passed unchanged against the
corrected development runtime/UI: construction toggles 20/0, geometry/one-shot
rounding 14/0, and malformed rounds 18/0. These are local red/green controls,
not substitutes for publication-source or final-head qualification.

The independent review separately verified all Q package payload hashes,
runtime input ledgers and the complete Native aggregate, and exercised retained
uint16 Water on all four halo sides through a real conserving tick and atomic
non-Wave refusal. Its Q verdict remained HOLD. Later corrected source requires
fresh publication, full qualification and a final independent verdict; the Q
results are historical evidence rather than substitutes for that work.

## Retained Deepworks failure and corridor repair

The failed Q frame was not captured, so its exact three-pixel result cannot be
reconstructed from the original run. Native comparison instead established that
the starting runtime and Q produced identical four-layer RG8 packets at the
first D1 pulse, effects tick 46; the other three Worlds remained at tick zero
and Wave was disabled. Six actual Smoke cells existed. Two, at (234,930) and
(234,931), projected behind foreground Steel Plate relief. The other fifteen
districts had no corresponding first-pulse obstruction.

A single [hosted diagnostic, run 43837114552](https://github.com/techrote/cybersand/actions/runs/43837114552),
used immutable Q and two explicitly declared scene variants: the authored source
at x235 and a D1-only counterfactual at x238. Each used all sixty-one effects
presentation phases from 0 through 60 seconds, Hybrid and Stack controls, and
one unchanged set of native packets. All 488 original PNGs were independently
decoded; all 1,464 sampled on/off pairs matched their recorded values.

| Diagnostic observation | Authored Q | D1 source x238 |
|---|---:|---:|
| Visible native cells, Hybrid | 4 at every phase | 5–6 |
| Visible native cells, Stack | 6 at every phase | 5–6 |
| Signed RGB contribution differences between modes | 122 of 366 | 0 of 366 |

The authored differences were exactly the two obstructed cells at every phase;
the other four cells matched. Both corrected modes retained five visible cells
at phases 10 and 12 because one cell was naturally below the original channel
threshold. These results prove the relief obstruction and its clearance, but do
**not** reproduce or explain the additional missing pixel in the original Q
failure. That failed result remains retained without relabelling it as a pass.

The original diagnostic archive was 1,127,610,664 bytes, SHA-256
`d869c6f262eff3d827eb46439abc3740d479a087573ead1c8abbc29ffee261df`.
A separate [read-only byte-transfer run 43838931542](https://github.com/techrote/cybersand/actions/runs/43838931542)
partitioned that existing archive to satisfy the connector transfer limit;
reassembly reproduced its exact digest before extraction. It did not rerun any
simulation or rendering. Temporary diagnostic and transfer workflows are
removed from the candidate source; the original runs and evidence remain.

The permanent scene repair moves only D1's six-cell source three cells right,
without changing material, quantity, source timing or native laws. The rendered
regression keeps all original district checks and thresholds, pins presentation
phases for reproducibility, and adds all sixty-one same-packet Hybrid/Stack
comparisons. Every native cell's signed on/off RGB contribution must match the
unobstructed control. Native ownership, state, ticks, packet bytes and serials
must remain unchanged. Full normal district frames, all phase witness crops,
first-phase/first-failure full context and raw packets are retained through the
standard CI artifact directory. This new source requires a fresh published
runtime, full final-source qualification and independent review.

## Documentation and remaining limits

Current contracts live in the [Wave reference](../architecture/wave-flow-v1.md)
and [owner guide](../operations/wave-flow-evaluation.md); roadmap, handover,
navigation and focused retrieval questions route to them. This dated record
remains historical evidence, outside ordinary retrieval. Existing inherited
failure/performance evidence is preserved, not relabelled as this source.

Wave remains experimental, opt-in and default off. It has no PressureFlow
pressure/gas model, full buoyancy, retained falling-Water lateral momentum or
exact physical persistence. More rounds increase work and may make some scenes
slower. Tuning is for owner experimentation, not a claim of better aesthetics,
kinetics or performance. Headless Windows and software-rendered Linux execution
do not establish physical NVIDIA or human gameplay acceptance.
