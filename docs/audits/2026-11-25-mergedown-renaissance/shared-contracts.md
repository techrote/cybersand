# Shared contracts at the mergedown checkpoint

This is the integration decision map for MERGEDOWN-RENAISSANCE-001, not a
replacement architecture specification. Accepted main is
`c8421a81b8f7f61516ed055f3200b49aee57bd65`. Prepared candidates below remain
unmerged unless the [decision register](decisions.json) records a later merge.
The original path-level overlap inventory and mechanical merge probes are
retained in [advanced-conflict-map.json](advanced-conflict-map.json).

## Ownership decisions

| Shared responsibility | Authoritative owner and integration rule | Actual finding and disposition |
| --- | --- | --- |
| Ordinary Workbench and scene replacement | `Main` and `SharedWorkbench` install one acknowledged scene, native World, simulation worker and physical actor session. Optional tools use those owners. | AMBIENT, Material and Art additions are compatible only when their completion metadata and scene lifecycle are all preserved. Material's actor-free demo deliberately has no Rapier session; requiring one was a defective integration-test assumption, now repaired. |
| Native simulation and material edits | Native C++ owns cells; `SimulationWorker` and the established transaction paths own access, pauses and acknowledgements. | Material Apply/Revert, native construction and painting may not introduce a parallel writable World. Prepared Material source `2e0233f8` exercises paused/live Apply, Revert, stale-World refusal and scene replacement against the real owner. |
| Actor bodies, controls and policy leases | `PhysicalActorSession` retains Rapier bodies, run/epoch/generation identities and control ownership. AMBIENT produces normalized policy commands through the existing lease contract. | Goblin pilot/drive/hand-back must change control authority without replacing the World, worker, session or body RIDs. Prepared source `21c9a667` passed 447 checks independently. Issued commands are fenced immediately; cache retirement follows the ordinary owner's process acknowledgement. |
| Actor capacity | The accepted physical host and AMBIENT foundations retain eight logical actors. | #762's separate capacity implementation is not imported by #775/#779. Its native input map differs even where the input count is also 105. Its adoption needs shared manipulation/control ownership and bounded sensing work, not merely a larger constant. |
| AMBIENT configuration and lifetime | Profiles and assignments are authored data; transient policy intentions, RNG and perception state are runtime data. Ordinary disabled paths do not start ambient activity or construct its editor. | The 68-check default-OFF case covers four producers, explicit on/off, continued play, stale leases and human hand-back. Small existing pure-data adapters/scans remain; no zero-allocation claim is made. AMBIENT002's group application separately preserves unrelated manual/passive actors. |
| Goblin automation | The opt-in Goblin harness invokes typed ordinary Workbench operations and observes their acknowledgements. | Goblin001 does not alter ordinary startup. Goblin002 remains a separate successor, with the original four long-horizon timeouts retained. The new mixed-control test does not credit its one explicitly inapplicable full material-reopen oracle as a pass. |
| Art provider and Architecture authoring | One Art request/configuration/credential/audit owner supplies an explicitly disclosed context. Architecture retains native staged preview, per-stage approval, transaction execution and Undo. | Prepared source `97585a0a` implements a real lazy ordinary-Workbench mount. Exact outgoing request values, source/session/World/provider/settings/serial identities and scoped Stop are checked. A successful textual merge alone had not provided that workflow. |
| History and persistence | Existing native transactions and authored save contracts remain the authorities; saving a start does not promise exact evolved physical continuation. | Material session state resets on authored reopen while profiles persist. Art reopen starts a fresh conversation while retaining historical audit. ULTIMA's independently observed export truncation is an open engineering gate; its active storage repair is coordinated for narrow shared adoption. |
| Rendering and decorative planes | Ordinary Play World authority remains distinct from Strata's independently owned decorative planes. PUBPRES retains ownership of its active physical progression/presentation recovery. | #776's extracted Windows admission exceeded the unchanged 45-second gate. No measured causal repair is claimed yet. No alternative renderer, publication scheduler or frozen PUBPRES comparison is imported or modified. |
| Structural bodies and body/world exchange | ObjectShard's native structural and Rapier ownership must be reconciled with ordinary painting, actor physics and scene teardown. | #754 has both semantic Main/Workbench conflicts and a retained-production-runtime mismatch: the source-built evaluator's 117 inputs cannot be substituted by the older 105-input retained production runtime. Frozen evaluator validity does not make the PR Ready. |
| Runtime selection and publication | Exact native input maps, compiler/dependency identities, LFS object hashes and actual bytes determine validity. | SWARM, Actor Compose and Material each retain their own source-matched runtimes. They are not interchangeable with one another or main. Combined native inputs require appropriate rebuilding and publication; timestamps and input counts do not establish compatibility. |
| CI coverage and acquisition | Planning defines the actual case inventory; reducers require complete same-source/same-attempt coverage. Dependency acquisition may retry only a recognized service timeout inside an existing bound. | The accepted #771/#778 fixes preserve missing-plan refusal and scalable matrix coverage. The current #775 LFS helper retains every failed attempt and refuses unavailable or mismatched bytes. Incomplete campaigns remain failures. |

## Implementation and evidence joins

The decisions above are backed by the following prepared implementations and
original evidence. They do not combine all outstanding programmes into one
application or transfer a frozen evaluator's qualification to a new source.

| Prepared combination | Source | Evidence and remaining qualification |
| --- | --- | --- |
| Goblin002 plus AMBIENT001 | `21c9a6670e05cfb8b8eeb76d02b03fb75019468f` | [Independent review](goblin002-independent-review.md), [complete original packet](goblin-successor-evidence-manifest.json); final accepted-main reconciliation and current hosted source gates remain. |
| AMBIENT002 plus foundations | `7c64874553f711121f2f5eeb01b8689e16d38bd3` | [Integration](ambient002-integration.md), [independent group/control review](ambient002-independent-review.md); 11 cases / 4,505 assertions locally, current Windows/full-source and owner gates remain. |
| Art plus Architecture and AMBIENT001 | `97585a0af02f1534eb254adf2d2fbe9036a281b2` | [Implemented seam](art-architecture-integration.md), [current 15-case packet](art-current-evidence-manifest.json), [independent review](art-architecture-independent-review.md); storage correction, current Windows/graphics, genuine-model creative evaluation and owner gates remain. |
| Material Audition plus AMBIENT001 | `2e0233f808e6e9c76aac897593bc88d6ca357b95` | [Independent 61-check interaction review](material-ambient-independent-review.md), [original failed/passed packet](material-ambient-evidence-manifest.json); exact 108-input native map preserved, current Windows/full-source and owner gates remain. |

The [source-history index](integration-source-history.json) preserves the exact
local Git objects in incremental bundles. If publication produces a different
commit identity through the GitHub API, the registered exact tree join and
original ancestry remain mandatory. Neither history rewriting nor a silent
qualification-source substitution is permitted.

## Protected integration order

Finish the AMBIENT001 resulting-source gate before treating its foundation as
accepted. Reconcile the existing successor PRs against the actual merge commit,
not a predicted SHA. Keep one authoritative implementation per responsibility;
preserve the qualified predecessors as ancestry and evidence. Native-changing
programmes are separate integration candidates, with their own runtime and
owner gates. Later PUBPRES adoption requires explicit reconciliation of Main,
SimulationWorker, presentation, actor progression and publication boundaries.
