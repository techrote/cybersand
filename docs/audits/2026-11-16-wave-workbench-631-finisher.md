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
