---
title: Status and foundational roadmap
status: Current
document-kind: reference
scope: Accepted-main implementation, separately identified candidates, approved direction and unresolved decisions
canonical-for: [implementation-status, foundational-priorities, open-decisions]
last-reviewed: 2026-11-24
related-documents: [product-intent-and-priorities.md, validation-evidence.md, invariants.md, ../operations/cybersand-codex-development-handover.md, ../operations/documentation-maintenance.md, ../operations/github-development-and-release.md]
---

# Status and foundational roadmap

**Source baseline: accepted main `00cdb02f103265b6dc5224c68283e9a0c8cb449f`,
checked 24 November 2026.** This register answers what is in that source, what
remains a candidate, and where to find the owning contract. It is not a promise
that every feature has passed physical owner evaluation on every platform.

Start with the [documentation portal](../README.md) for practical guides.
[Product intent](product-intent-and-priorities.md) records approved direction;
[validation evidence](validation-evidence.md) explains the evidence boundaries.
Refresh the linked GitHub records before planning integration: their heads and
qualification state can change after this dated snapshot.

## Reading status correctly

| Label or observation | What it establishes |
|---|---|
| **Current** | Behavior inspected in accepted source. Runtime and platform claims need separate evidence. |
| **Approved / Approved design** | Owner-approved direction or requirement; implementation may be incomplete. |
| **Planned** | Intended work that is not available merely because it has a design or issue. |
| **Deferred / Rejected** | Explicit postponement or rejection in the stated scope. Inactivity alone establishes neither. |
| **Ambiguous** | Conflicting or insufficient evidence; do not silently choose a policy. |
| Unmerged implementation candidate | Code exists on another branch; it is not accepted-main behavior. |
| Source-qualified candidate / evaluator | Identified source and artifacts have the reported checks. Packaging and physical owner acceptance remain separate. |
| Historical evidence | A dated observation or instruction with its original scope; it grants no current execution authority. |

The last three are descriptive evidence states, not additional frontmatter
authority values. GitHub `merged`, `state` and `draft` fields establish lifecycle;
words such as “Draft” or “READY” in an old title do not. Merging a child does not
automatically close or satisfy its whole programme.

## Current implementation map

| Area | Available on the accepted source | Canonical route and important boundary |
|---|---|---|
| Shared Workbench | One creative workspace for generated/native material scenes, painting, actor setup, Art and inspection | [First session](../operations/workbench-first-session.md); [authoring contract](../architecture/shared-workbench-authoring-data.md). An acknowledged application is different from a queued request. |
| Painting and history | Native material tools, selection/copy-paste, bounded edit operations, Undo/Redo and explicit Flatten | [Painting](../operations/workbench-painting-and-history.md). Partial operations, cancellation and history limits retain their actual receipt semantics. |
| Architectural generation | GEN-007 project authoring and the accepted 80-Gentek extension alongside established presets | [Generator](../systems/architectural-generator.md); [playtest](../operations/architectural-generator-playtest.md). SWARM negotiation is a separate unmerged programme. |
| Materials and reactions | Native material identities, specialized kernels, generated hard/granular capability consumers and bounded reaction rules | [Materials](../systems/materials-and-rule-kernels.md); [catalogue](../systems/building-material-catalogue.md). A declared field is not necessarily an effective runtime control. |
| Materials Lab | Material inspection, candidate authoring and admitted isolated native comparisons | [Materials Lab](../operations/materials-lab-authoring.md). Current-scene audition is still an unmerged successor. |
| Water | Distinct solver families, unified Water Lab, Wave gameplay profile with spill/ballistic release and accepted Oil interaction work | [Water Lab](../operations/workbench-water-lab.md); [family policy](../architecture/liquid-solver-family-policy.md); [Wave](../architecture/wave-flow-v1.md). Defaults are host/profile specific; the generic native World is not interchangeable with a gameplay preset. |
| Actors and equipment | Independent Workbench actor composition and existing physical actor/control/equipment paths | [Actor guide](../operations/workbench-actor-composition.md); [technical contract](../systems/workbench-actor-composition.md). Continuous-play sandbox/pilot/stack repairs remain candidates. |
| Art Workbench | Provider-assisted conversation, direct native drawing, receipts, Stop/Hide and one traffic audit per game session | [Art guide](../operations/workbench-art.md); [provider contract](../systems/workbench-art-providers.md). Accepted #727 removed cross-session conversation restore. Local-provider and window repairs remain unmerged. |
| Authored persistence | Saved setup/start data and standalone material-baseline files; Flatten captures stored material IDs while preserving the live World | [Saving](../operations/workbench-saving.md); [save/reference formats](level-saves-and-replay.md). Ordinary authored Save is not a complete evolved physical checkpoint. |
| Native runtime | C++20 World, sparse storage, bounded phased workers, desktop owner thread and main-thread Rapier/presentation | [Architecture](../architecture/overview.md); [ownership](../architecture/data-ownership-and-lifetimes.md). Failed-world quarantine, explicit capacity outcomes and immutable handoffs remain essential. |
| Rendering and recording | Native material snapshots and Godot presentation, with existing recording/diagnostic paths | [Rendering](../architecture/rendering-and-gameplay-bridges.md). Render FPS, tick counters and recorded presentation do not by themselves prove physical progression or complete replay. |
| Standalone exhibitions | Deepworks, Blacksite Nine, Neon Reliquary, player playground, Thunderbowl and Strata Theatre retain their own entry points and owners | [Showcases](../operations/showcase-guide.md). Four-layer Strata is not yet ordinary Workbench layer editing. |
| World Art | Accepted shared renderer, viewer, capture tools and source-bound evaluator support | [World Art](../tools/art-pipeline-unification.md). Art-only extents and exports do not raise native simulation/import limits. Hosted graphics do not establish physical NVIDIA acceptance. |

### Accepted foundations behind this map

These live merge records were checked independently of their titles. The list
captures the major documentation transitions; it is not a complete release log.

| Foundation | Accepted record | Documentation consequence |
|---|---|---|
| Generated Shared Workbench | [#542](https://github.com/techrote/cybersand/pull/542) | Ordinary authoring has a common native destination. |
| Materials Lab and native capability consumers | [#562](https://github.com/techrote/cybersand/pull/562), [#563](https://github.com/techrote/cybersand/pull/563) | “Lab unimplemented” and “metadata only/no production consumer” are obsolete blanket claims. |
| Integrated PAINT and Art | [#564](https://github.com/techrote/cybersand/pull/564), [#565](https://github.com/techrote/cybersand/pull/565) | Painting and direct agent authoring are accepted capabilities; newer repairs need their own acceptance. |
| Material-only Flatten | [#572](https://github.com/techrote/cybersand/pull/572) | Flatten is implemented; it does not reset or respawn the running physical World. |
| GEN-007 architecture | [#582](https://github.com/techrote/cybersand/pull/582) | The architecture editor is available, not a proposal awaiting its original implementation. |
| Unified Water and Wave changes | [#672](https://github.com/techrote/cybersand/pull/672), [#677](https://github.com/techrote/cybersand/pull/677), [#678](https://github.com/techrote/cybersand/pull/678), [#679](https://github.com/techrote/cybersand/pull/679) | Wave gameplay, Water Lab and later spill/Oil behavior are current, with their individual source-bound evidence. |
| Workbench landscape admission | [#680](https://github.com/techrote/cybersand/pull/680) | Old host rectangle ceilings must not be confused with unchanged native operation capacities. |
| Actor composition | [#683](https://github.com/techrote/cybersand/pull/683) | The accepted composition contract is distinct from #762's successor. |
| Gentek-80 and Water reconciliation | [#684](https://github.com/techrote/cybersand/pull/684), [#691](https://github.com/techrote/cybersand/pull/691) | The catalogue is accepted even though older donor titles still say HOLD. |
| World Art and physical acceptance harness | [#685](https://github.com/techrote/cybersand/pull/685), [#694](https://github.com/techrote/cybersand/pull/694) | Tool availability is accepted; a harness is not evidence that the owner's GPU passed. |
| Native paint fill | [#690](https://github.com/techrote/cybersand/pull/690) | Native implementation exists; end-to-end latency successors remain separate. |
| CI preflight and compilation reuse | [#714](https://github.com/techrote/cybersand/pull/714), [#722](https://github.com/techrote/cybersand/pull/722), [#723](https://github.com/techrote/cybersand/pull/723) | These source changes are accepted. Other scheduling experiments are not policy. |
| Session-only Art traffic | [#727](https://github.com/techrote/cybersand/pull/727) | One current-session JSONL audit; do not follow the superseded linked-history restore instructions. |

## Active candidates and integration boundaries

**All entries below were unmerged at the snapshot.** The linked principal records
own current source, blockers, evaluator availability and exact qualification. This
register deliberately does not duplicate their changing job lists or PR heads.

| Programme | Principal record | Boundary for accepted-main documentation |
|---|---|---|
| PUBPRES physical progression and presentation | [#717](https://github.com/techrote/cybersand/issues/717), current finisher [#767](https://github.com/techrote/cybersand/pull/767), predecessor [#757](https://github.com/techrote/cybersand/pull/757) | Do not claim publication stalls or physical freezes are resolved by accepted main. |
| ObjectShard moving destructible materials | [#754](https://github.com/techrote/cybersand/pull/754) | Moving native chemistry, mutable body ownership and ordinary Workbench integration are candidate behavior. |
| Actor Compose continuous play and pilot recovery | [#762](https://github.com/techrote/cybersand/pull/762) | Preserve accepted #683 controls and disclose successor repair scope. |
| Equipment recovery | [#724](https://github.com/techrote/cybersand/pull/724) | Historical #561 merge does not prove every later ballistic-solid/equipment path is present or correct. |
| Persistent authored areas / RAMCACHE | [#745](https://github.com/techrote/cybersand/pull/745), [#734](https://github.com/techrote/cybersand/pull/734) | Persistent-area loading, native hot residency, durability and catch-up are not accepted-main save guarantees. |
| Consolidated Gentek SWARM-004/005/006 | [#729](https://github.com/techrote/cybersand/pull/729) | Accepted Gentek generation does not imply accepted reciprocal negotiation/recovery. |
| Gentek Windows owner evaluator | [#758](https://github.com/techrote/cybersand/pull/758) | GitHub reported this PR open and non-draft despite its HOLD title. Evaluator work and physical acceptance remain separate from the accepted catalogue. |
| Art responsiveness, roster and conversation editor | Consolidated finisher [#773](https://github.com/techrote/cybersand/pull/773), owner issue [#744](https://github.com/techrote/cybersand/issues/744); retained donors [#765](https://github.com/techrote/cybersand/pull/765), [#766](https://github.com/techrote/cybersand/pull/766), [#756](https://github.com/techrote/cybersand/pull/756), [#763](https://github.com/techrote/cybersand/pull/763) | Do not promise repaired close/HTTP timing, updated provider presets or bounded editor layout before acceptance. |
| WORLD-STEER / Batch Lab | M6–M7 successor [#777](https://github.com/techrote/cybersand/pull/777), M3–M5 [#770](https://github.com/techrote/cybersand/pull/770), predecessor [#720](https://github.com/techrote/cybersand/pull/720), [#579](https://github.com/techrote/cybersand/issues/579) | Native module harvesting, architectural knowledge retrieval, structural parts and staged construction remain candidate work. |
| Gremlin live testing | Real-game successor [#772](https://github.com/techrote/cybersand/pull/772); retained contract-model prototype [#749](https://github.com/techrote/cybersand/pull/749) | The successor reports actual Workbench integration but remains an unmerged candidate with its own source-bound qualification. The earlier Python contract model is not native runtime evidence. |
| Ambient procedural actors | [#775](https://github.com/techrote/cybersand/pull/775) | Procedural personalities, native perception and Behaviour editing are candidate capabilities. Accepted actor control and its eight-actor limit remain the current contract. |
| Materials Lab current-scene audition | [#768](https://github.com/techrote/cybersand/pull/768) | Approved live-audition intent is not satisfied by advertising the existing isolated Lab as that feature. |
| Workbench Strata Theatre | Layered authoring and atmosphere successor [#776](https://github.com/techrote/cybersand/pull/776), foundation [#769](https://github.com/techrote/cybersand/pull/769), owner intent [#588](https://github.com/techrote/cybersand/issues/588) | Four-plane painting/composition and environmental atmosphere in ordinary Workbench remain unmerged candidates, distinct from the available standalone exhibition. |
| PAINT latency and physical evaluator | [#703](https://github.com/techrote/cybersand/pull/703), [#711](https://github.com/techrote/cybersand/pull/711) | Native fill speed and usable end-to-end responsiveness are separate measurements. |
| CI engineering and publication closure | Consolidated candidate [#771](https://github.com/techrote/cybersand/pull/771), programmes [#706](https://github.com/techrote/cybersand/issues/706), [#761](https://github.com/techrote/cybersand/issues/761) | Candidate coordination/custody helpers and selected scheduling changes do not replace accepted CI policy; retained rejected experiments do not become defaults. |

## Approved direction and unresolved choices

The [14 November owner record](../decisions/2026-11-14-owner-authoring-intent.md)
establishes paint-and-play authoring, convincing physical behavior, useful
prepared destruction, live material experimentation, four-layer presentation and
fixed canvases connected by persistent areas. It also specifies **game-time**
catch-up, not real-world offline elapsed time. These intentions remain separate
from implementation and from permission to resume a held branch.

| Question | Current disposition and owning route |
|---|---|
| Does ordinary Save capture all evolved materials and physical state? | Authored formats and material-baseline capture have distinct semantics. Desired evolved-layout Save must not be described as complete physical continuation. [Save contracts](level-saves-and-replay.md) and [owner intent](product-intent-and-priorities.md#save-flatten-and-compatibility) preserve the difference. |
| Do large scenes and busy physics remain responsive? | This is an active owner-visible problem. PUBPRES, PAINT and actor successors own their repairs; counters and hosted graphical passes do not settle playfeel. |
| Can every material property be edited live? | No such general accepted contract exists. Effective consumers, specialized kernels and safe audition scope must be identified separately. |
| Are rigid-body motion, cutting and chemistry fully unified? | Accepted coupling and actor tools have bounded contracts. ObjectShard owns the unmerged successor; no automatic promotion from an isolated prototype. |
| Is complete replay or cross-platform physical identity available? | No general authored-save promise supplies it. Use [determinism](../architecture/determinism-and-boundary-transfers.md) and the versioned native checkpoint contracts for exact supported scopes. |
| Are wider persistent worlds complete? | Fixed authored canvases are current; general residency/streaming/catch-up remain separately scoped candidate or Planned work. |
| May old material source locks be updated to make validation pass? | No. Preserve frozen evidence and use the existing reviewed transition process for authorized changes. Documentation does not grant a protected-source transition. |
| Is the project publicly licensed or ready for public distribution? | No project license has been selected. [License status](../../LICENSE_STATUS.md) and [third-party notices](../../THIRD_PARTY_NOTICES.md) remain authoritative. |

## Foundational constraints that still matter

Native C++ owns authoritative cells. Desktop workers and Godot/Rapier have
different ownership boundaries; native pool workers do not call Godot APIs.
Rendering consumes owned immutable snapshots. A failed tick is not a rollback
transaction: preserve quarantine until explicit reset or validated replacement.
Phased interest exclusion pauses existing activity and wakes re-entered resident
blocks without supplying persistent-area catch-up. Serial execution retains its
documented differences. See [invariants](invariants.md),
[threading](../architecture/simulation-tick-and-threading.md) and
[storage](../systems/world-storage-and-interest-region.md).

General command backpressure, strict complete replay, field equations/units and
broader body-shape/CCD policy remain partly implemented or Planned in their owning
contracts. Asynchronous Web ownership is Deferred. Erase/restore body authority,
mutable render reads, per-cell physics objects and native worker Godot calls remain
Rejected within the accepted architecture. Approximation must be explicit and
bounded; it does not excuse races, lost accepted commands or false receipts.

Issue numbers are identifiers, not an execution order. The
[MicroScenarios programme](../operations/microscenarios-programme.md),
[architecture programme](../operations/architecture-programme.md),
[development-claims remediation](../operations/development-claims-remediation-programme.md)
and [Water successor programme](../operations/water-hybrid-pressure-extension-programme.md)
retain their separate ownership. In particular, #45's historical NARROW admission
and the separate Liquid Comparison Build are not a blanket rejection of accepted
Wave or ballistic Water. Old negative experiments keep their source-specific
meaning; new product work does not turn them into passes.

## Updating this register after a merge

Follow the [documentation maintenance checklist](../operations/documentation-maintenance.md).
Confirm the actual merge SHA and affected source before moving a candidate into
the implementation map. Update its canonical subsystem contract and practical
guide first, then the portal, README feature sentence if needed, retrieval routes
and affected questions. Preserve the old qualification records and add the new
source/platform evidence. Delete a candidate row only when its surviving scope is
accounted for; an accepted child may leave important programme work open.

## Earlier checkpoints and stable links

<a id="liquid-comparison-build-design-checkpoint--2026-10-23"></a>
<a id="lcb-001-policy-foundation--2026-10-24"></a>
<a id="lcb-001-pressure-reference--2026-10-24"></a>

Older LCB section links arrive here. The [current family policy](../architecture/liquid-solver-family-policy.md)
owns present semantics; the frozen page below preserves the original design,
foundation and pressure-reference checkpoints with their exact dates and scope.

The former page contained a long sequence of September–November development
checkpoints, including instructions to continue branches that have since merged.
Its complete original text and headings remain at
[the frozen accepted-source page](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/reference/status-and-roadmap.md)
and in the [preservation record](../audits/2026-11-24-docs-renaissance/README.md).
Those dated checkpoints are historical evidence. They do not override this
current synthesis or the scoped source/owner decisions in the owning contract.
