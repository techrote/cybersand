# STRATA-THEATRE-WORKBENCH-001 — decision packet

**Disposition: Draft/HOLD.** This is an opt-in implementation in the ordinary
Shared Workbench, under [owner intent #588](https://github.com/techrote/cybersand/issues/588)
and the owner's 24 November 2026 successor execution brief. It is presented for
owner evaluation in [Draft PR #769](https://github.com/techrote/cybersand/pull/769).
No default activation, Ready promotion, merge or native runtime publication is
authorized or performed.

The machine-readable counterpart is [decision-packet.json](decision-packet.json).
The [system contract](../../systems/strata-workbench.md) defines the supported
behavior; the [owner guide](../../operations/strata-workbench-evaluation.md)
provides ordinary launch, scene selection, editing and save/reopen instructions.

## Decision and implementation boundary

The chosen seam adapts the existing depth compositor and material surfaces to
the accepted ordinary Workbench host. It borrows the live Play drawable and
current camera data, while one separate composition owner owns exactly three
static decorative native Worlds. It never mounts the standalone Strata host,
never creates a second authoritative Play World, and never gives a decorative
plane actors or collision authority.

This was simpler and safer than extracting a new shared renderer or mounting the
old four-World demonstration. The compositor's reversible coordinate math,
material-surface behavior and the depth runtime's candidate/copy/generation
patterns were reusable. The standalone host lifecycle, clocks and event routing
were demonstration assumptions and were not adopted as product requirements.

The only shader adaptation is private to the enabled composition: an exact
accepted palette program receives a checked final-output opacity control, and
the existing additive glow receives the corresponding final-RGB gain. The
original shared shader files are unchanged. The adapter refuses an unknown
insertion seam, records original/derived hashes, and restores the exact original
materials and host aliases on disable. Existing camera, worker scheduling,
publication and glow-enable policies keep their owners.

The ordinary default path remains off. Opening the panel alone creates no native
decorative Worlds. The first enable or composition-setting change prepares the
three resources; later view settings reuse them. The existing standalone Strata and Semantic Depth
entry points retain their original capabilities and default surface extent.

## Authoring and ownership contract

| Area | Delivered behavior and boundary |
| --- | --- |
| Four planes | `play`, `scripted`, `effects`, `background`; explicit identity, extent, visibility, lock, opacity and relative depth; decorative authored revisions plus existing Play source/worker revision |
| Play | Existing worker, native simulation, camera correspondence, actor session, collisions and material history remain authoritative |
| Decorative planes | Three independently owned native material Worlds; static, paused, 0 Hz; no actors, collision transfer or physical continuation |
| Presentation | Opt-in Stack, Flat active plane, visibility, Solo, opacity, relative depth, parallax and distance haze; Play depth fixed at zero |
| Human tools | Existing material picker and bounded native Brush/Eraser/Line/Rectangle/Outline/Select/Copy/Paste semantics on each decorative plane; ordinary Play editor preserved |
| Edit refusal | Hidden, zero-opacity, locked and view-excluded targets refuse mutations; a visible locked plane may be copied; outside-bound gestures are refused as a whole |
| History | Existing Play history; up to 32 independent static edits per decorative plane; selection and view changes preserve history |
| Limits | 512–2048 cells per axis, multiples of 64; 16,384 cells per decorative operation; 1,024 sampled brush points; radius 0–24 |
| Reset | Presentation reset changes appearance, not material layouts or the current Play World; explicit ordinary new/load retains its established scene-replacement meaning |
| Persistence | Version 1 `CYSSTRAT` authored-layout envelope at the existing named-start path; four-plane settings/layouts, checksums and strict field/identity validation |
| Flatten | Existing Play material-baseline operation; it never merges visual planes; Play-only Art also keeps its existing scope |

Unsupported clocks, unknown document fields, invalid owners/generations, stale
or malformed publications and unsupported state domains are rejected explicitly.
Saved layouts are not exact physical continuation: evolved Play cells require
the existing explicit Flatten operation if they should become the authored
baseline. Actor velocities, native transient state and Undo stacks are not
serialized. Generated Play sources retain their previously admitted exact bytes
and original provenance; reopen does not invent a fresh generator attestation.

All necessary document, native candidate, publication and presentation resources
are prepared before ordinary Play replacement admission. Invalid candidates
retain the previous valid composition. Failure of a decorative native edit
quarantines that plane. A committed edit whose display publication fails is
reported as committed with stale pixels; Save preserves its actual authored
revision. Neither failure silently resets Play or transfers decorative materials
into its physical World.

## Native reference scenes

All three examples are native 1024×768 material layouts in true straight-on
orthographic side elevation. They are independently selectable in the ordinary
Strata panel and contain an ordinary Midge actor. Their source is retained under
`godot/data/strata/`; no unaccepted Gold nomination or large regenerated corpus
is included.

| Scene | Four-plane purpose | Authored Play geometry observation |
| --- | --- | --- |
| Industrial assembly hall | Hazard-marked routes and pipework, rear trusses/machinery, atmospheric accents and distant architecture | 88.45% Empty interior; substantial lower flight hall, with separate upper chambers |
| Science-fiction arcology | Elevated cyan routes, structural towers, restrained effects and distant building silhouettes | 89.91% Empty interior; 91.48% of Empty cells are point-connected to spawn |
| Organic / industrial cavern | Irregular playable surfaces, rear infrastructure, atmospheric decoration and distant cavern surfaces | 76.85% Empty interior; all Empty cells are point-connected to spawn |

[Independent geometry inspection](strata-scene-inspection.md) records exact
rectangle/mask hashes and its conservative hull assumptions. It found all 3,074
rectangles within the protected interior and all three authored Midge spawn
footprints clear. These are geometric observations, not a claim of complete
physical traversal or playability for every actor. Native readback and actual
actor progress are separate graphical qualification witnesses.

## Source and runtime custody

Accepted baseline: commit `00cdb02f103265b6dc5224c68283e9a0c8cb449f`, tree
`06b62d73138028d1f7615b83edc9810491bf6287`. The implementation uses accepted-main
interfaces. Active PUBPRES #767 and its lineage were inspected for ownership;
their branches were not imported. The [live scope refresh](strata-scope-live-refresh.md)
records four shared runtime/authoring paths and seven documentation paths also
changed by active PUBPRES work. Those future overlaps require reconciliation and
fresh qualification before any accepted union; the packaged adapter uses this
recorded accepted baseline. No native engine source, Main simulation
scheduler, ObjectShard, Equipment, Art Workbench, SWARM, Batch Lab, Gremlin or
Materials Lab branch is included.

The application source, Git tree, official Godot executable, retained native
binary manifests and complete execution-input hashes are bound by the actual
campaign reports. Retained native binaries were built from
`c53fd6f9d3d0f2b3f39396c7e605654f65c17299`; their complete native input set is
unchanged by this mission. This is not a claim of a new native build at the
application commit.

Qualification uses official **Godot 4.7.stable.official.5b4e0cb0f**. Source/tree
equivalence between the local implementation commit and the published Git Data
API commit is verified before moving the Draft branch. Later evidence-only
documentation commits, if present, are distinguished from the qualified
application source in the JSON packet and package manifest.

## Qualification matrix

Both complete application campaigns passed at source
`d365f78190af0e006ee9998a17b453f04f31b3ae`, tree
`4e2e44513355c6f976d6b672d5dc958f20331add`, in
[workflow 45457176340](https://github.com/techrote/cybersand/actions/runs/45457176340).
The local tree-equivalent implementation commit is
`22ff4bdf0251d58164b68ad1f81d0bbf2cdb479c`. Independent admission checked all
1,105 execution-input hashes, twelve original process cases and 136 original
evidence files for each platform. The official engine and retained native
provenance are recorded in the JSON packet and original reports.

| Gate | Actual result and scope |
| --- | --- |
| Retained compositor | PASS, 19 checks per source platform |
| Native layer ownership | PASS, 111 checks per platform, including native candidate lifecycle, authored persistence and refusal |
| Strict document admission | PASS, 149 checks per platform, including 24 invalid candidates and eight corrupt envelopes |
| Existing material-surface dimensions | PASS, 32 actual rendered-pixel checks per platform |
| Three ordinary scene installs | PASS, 880 assertions per scene per platform; actual Main/Shared Workbench and native Worlds |
| Fresh-process reopen | PASS, 162 assertions per scene per platform; distinct actual engine PIDs, identical saved bytes and complete native material hashes for all four planes |
| Actual 2048×2048 ordinary canvas | PASS, 82 assertions per platform; full-size native decorative edits, framebuffer pixels, Play/actor identity and retirement in a separate paused process |
| Mode and actor identity | Existing worker ID, published World generation, physical epoch, actor session and actual body IDs preserved through twelve view transitions and a live toggle; separate ordinary actor stepping progressed Rapier and pose |
| Input and rendered pixels | Same-event pan/zoom/parallax, 1.25 viewport scaling, actual viewport mouse events, panel control signals, per-plane native readback, palette opacity and emissive-halo isolation exercised |
| Failure containment | Invalid document/packet refusal and teardown executed; failed Play ACK while staged, partial native edit quarantine, and committed-edit/failed-publication handling are source-reviewed only, without direct mounted fault injection |
| Pristine Windows evaluator | PASS: complete extracted graphical campaign, all three 880/162 install/reopen pairs, the 82-check maximum probe, actual shipped CMD World admission and post-run payload verification |
| Physical Windows 11 / NVIDIA | Owner appearance, DPI, interaction and performance acceptance remains open |

The assertion counts are counts of checks, not independent human interaction
scenarios. Scripted viewport/control input is not a substitute for the owner's
physical desktop interaction. The cap probe stays paused; it does not establish
sustained 2048² play, dense-map stress or every actor type. Actual resumed actor
progress is established separately in the three reference-scene runs.

## Verified portable Windows evaluator

The final evaluator is **CyberSand-Strata-Workbench-Windows-d365f78190af.zip**,
204,378,995 bytes. Its SHA-256 is:

```text
344ff7de0caf120096baa377967585918fd985fd9d35ad7b7620e1c6c9b03a71
```

The adjacent payload manifest and the identical embedded `evaluation-manifest.json`
enumerate 1,359 payload files. The manifest SHA-256 is
`0b6f88603afa07b6a44f713ab8ac06887db4ad34c91d0e6c153f5a18c01594a8`.
The [independent evaluator audit](evaluator-independent-audit.json) streamed and
verified every payload hash, matched 1,057 archived files to the frozen source,
checked all 17 canonical recipe copies and pinned runtime dependencies, and
re-admitted the exact embedded Linux/Windows source campaigns and extracted run.

The pristine Windows directory was `D:\a\_temp\strata owner package`.
The actual shipped `Open Workbench.cmd` launched ordinary Shared Workbench and
returned success after a native 2048×2048 Play World was admitted, with Strata
off, World generation 2 and worker identity `-9223371959830575630`. The
[original launch receipt](run-45457176340/package/launcher.json) binds that
directory and source; no editor-only or detached demo launch substitutes for it.
The extracted campaign additionally exercised all three layered scenes and
fresh-process persistence. The payload was verified again after execution.

The workflow retains the evaluator transport as artifact **14953297332** and the
complete original package qualification evidence as artifact **14954041935**.
The transport ZIP contains the evaluator, checksum and manifest; its own hash
is distinct from the owner evaluator hash above. [Package custody](evaluator-custody.json)
records both. Original negative campaigns remain separately preserved.

Extract the complete evaluator into a writable directory and run
**Open Workbench.cmd**. Open **Strata Theatre…**, scroll to **Open a complete
example scene**, select a scene and press **Load selected example…**. Move or
close the floating panel to paint the scene. Follow the
[owner guide](../../operations/strata-workbench-evaluation.md) for the concise
edit, actor, mode-toggle and Save/fresh-reopen checks.

## Observed cost and practical limits

The full source-specific tables, original metric definitions and wait overruns
are in [qualification-cost.md](qualification-cost.md) and
[qualification-cost.json](qualification-cost.json). Linux used llvmpipe;
Windows used ANGLE with Microsoft Basic Render Driver. These are software
rendering observations, not physical presented GPU FPS.

Each of the following short sequential mode samples retains the same scene,
camera, Play/actor identity and composition resources. Values are callback
median / p95 milliseconds. The separate pre-Strata 512² startup baseline is not
a matched 1024×768 scene comparison.

| Platform / scene | Disabled | Flat | Stack | Decorative captures / uploads |
| --- | ---: | ---: | ---: | ---: |
| linux / industrial-assembly | 115.539 / 128.002 | 119.243 / 131.139 | 126.723 / 131.107 | 0 / 0 |
| linux / arcology | 115.889 / 128.120 | 119.504 / 130.790 | 127.090 / 131.185 | 0 / 0 |
| linux / cavern | 115.853 / 126.318 | 118.475 / 124.627 | 125.054 / 130.084 | 0 / 0 |
| windows / industrial-assembly | 210.835 / 233.422 | 217.768 / 239.201 | 231.644 / 254.453 | 0 / 0 |
| windows / arcology | 238.234 / 245.347 | 241.389 / 246.948 | 249.906 / 257.187 | 0 / 0 |
| windows / cavern | 210.449 / 224.470 | 211.939 / 219.957 | 220.598 / 248.372 | 0 / 0 |

Static decorative planes generated no new native snapshots or uploads during
any of these samples. Their Worlds and surfaces remain allocated while disabled,
so the comparison measures presentation behavior rather than the cost of freeing
and reconstructing the composition.

| Whole install-process observation | Linux | Windows |
| --- | ---: | ---: |
| Wall time | 89.80–93.59 s | 208.17–227.12 s |
| Observed process-tree CPU | 146.56–150.69 CPU-s | 466.28–511.41 CPU-s |
| Sampled peak RSS / working set | 1321.07–1352.54 MiB | 1078.45–1108.59 MiB |

The separate 2048² cap process peaked at 1923.86 MiB on linux and 1401.43 MiB on windows. These whole-process peaks include startup, fixture work and framebuffers.
CPU counters sum observed user/kernel CPU across the actual engine and discovered
descendants and may exceed elapsed wall time. The 0.5-second observer can miss
short-lived descendants and exit tails; shared pages can be counted more than
once. No incremental native-World RSS or GPU-memory estimate is inferred.

The final Windows source campaign also retained callback wait-budget overruns:

- industrial-assembly: 52.169 seconds before the successful final predicate, against a 45-second wait budget.
- arcology: 56.579 seconds before the successful final predicate, against a 45-second wait budget.
- cavern: 50.789 seconds before the successful final predicate, against a 45-second wait budget.

These operations completed within their separately enforced outer process
bounds. They are functional completions with measured wait-budget misses, not
timing-budget passes. Earlier campaign timings and cold-start overruns are kept
under their original sources. The substantial variation across hosted runs of
unchanged application code prevents a stable desktop performance claim.

The pristine extracted Windows run has its own retained cost observations in
[package-cost.md](package-cost.md) and [package-cost.json](package-cost.json).
Its industrial, arcology and cavern process bootstraps took 68.754, 70.873 and
53.433 seconds respectively. The corresponding composition-admission predicates
were observed at 87.289, 74.863 and 49.164 seconds against the same 45-second
callback wait. Those are additional measured wait-budget misses despite eventual
functional completion. They are not substituted for the source-campaign values
in the tables above.

## Failures retained and repaired

[Original negative campaigns](negative-campaigns.json) and
[local diagnostics](local-diagnostics.json) retain source identities and original
receipts. The first Linux campaign's 569 internal assertions did not establish a
pass: independent admission rejected a valid signed Godot identity, and actual
image review exposed Play material visibility leakage. The current implementation
uses exact signed identity strings and explicit palette/glow pixel witnesses.

The first Windows campaign exhausted its 45-second ordinary bootstrap deadline
before Strata. A larger explicitly measured bootstrap budget and a late-predicate
check were added; this does not establish a performance pass. In the second
Windows campaign, ordinary startup took 56.526–58.095 seconds, and first layer
admission took 54.705–56.026 seconds against a 45-second callback wait. The final
predicate succeeded after control resumed. This is a functional completion with
an observed wait-budget overrun, not a timing-budget pass or an attribution of
the entire delay to shader compilation. Local graphical
attempts killed with signal 9 remain failed observations, without assigning an
unproven OOM cause. The second campaign's maximum probe failed on an output
directory collision on both platforms before launching Godot; its independently reviewed one-line
runner repair does not by itself qualify the maximum extent.

The third source campaign passed both complete platforms, including the maximum
extent, but package admission refused its generator-profile inventory before
producing an evaluator. The stager copied the 17 canonical direct-child profiles;
the verifier incorrectly counted 98 nested JSON assets as profiles as well.
The repaired verifier restricts that comparison to the canonical profile
directory while preserving complete source-asset coverage. Actual archived-source
tests plus omission and tamper refusals accompanied the repair. The failed
package job and original passing source receipts retain their original status;
the final fourth campaign separately passed all source and package gates.

The independent verifier has adverse controls for missing cases, forged source
or process identities, contradictory original/embedded reports, altered saved
bytes, incomplete manifests and premature launch receipts. Synthetic control
successes qualify the verifier's refusal behavior, not product graphics.

## Independent review and owner decision

Implementation and review were split across three isolated specialist branches.
The layer/document architect reviewed the presentation/custody integration; the
presentation architect reviewed the ownership boundary and actual captures; the
qualification specialist reviewed document/native ownership and the process
observer. Review reports and their exact source scope accompany this packet.

- [Layer/document architect review](independent-review-a.md): presentation,
  native ownership, maximum extent, extracted lifecycle and live scope.
- [Presentation architect review](independent-review-b.md): document/owner
  boundary, actual rendered scenes and exact portable owner handoff.
- [Qualification specialist review](independent-review-c.md): independent source
  admission, adverse controls, source-exact package and launch custody.

[Final local gates](local-final-gates.json) passed documentation structure,
repository/runtime identity and historical M11 integrity. The 32 frozen
retrieval questions retain 19 first-position and 30 top-five canonical hits;
the 165-question challenge set has 127 and 163 respectively. The
[retrieval review](final-retrieval-review.json) preserves fixture hashes,
inherited misses and source-fact review without treating lexical rank as runtime
evidence. All 1,105 execution inputs remain unchanged by this evidence-only
documentation update.

The owner evaluation should decide whether the limited static decorative model,
visual depth, edit workflow and authored persistence are useful enough for this
first milestone. Independent decorative simulation and cross-plane transfer are
future decisions, not hidden claims of this delivery. Future accepted PUBPRES or
palette changes require fresh qualification at the documented adapter seam.

The scoped Draft/HOLD implementation and evaluator delivery are complete with
the executed and source-reviewed boundaries recorded above. The remaining owner
decision is whether this static decorative model, its appearance and its
interaction cost are acceptable on the physical Windows 11/NVIDIA machine.
That gate remains open. No Ready promotion, default activation, merge or
acceptance of active PUBPRES work is implied.
