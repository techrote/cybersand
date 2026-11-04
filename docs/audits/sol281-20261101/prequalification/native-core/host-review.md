# SOL-281 independent Godot ownership review

Review date: 2026-11-01 UTC. Reviewer: `native_core` agent. This reviewer implemented the recovered native ownership kernel and the native conservative displacement transaction, but did **not** implement the reviewed Godot session, worker extension, render consumer or compound bridge reduction. The native admission policy was also re-read as a self-audit; that part is not presented as independent review of the reviewer's own work.

## Disposition

**Initial review: changes requested.** Two concrete host ownership defects require correction and focused host regressions. A third defensive compound feedback issue was reported with a lower severity because the ordinary single-worker publication path is monotonic. The normal handoff and its generation-fenced continuations otherwise follow the intended material/collision ownership order.

This is source review, not Linux/Windows execution evidence. No new actual Godot/Rapier tests were run by this reviewer during this review. The principal implementer owns final integration acceptance and source-matched execution receipts. The earlier native test receipts in this directory retain their own exact file digests and are not reinterpreted as host qualification.

`host-review-initial-source.json` identifies the 16 files read for the initial review, including SHA-256 for each file and the Git HEAD observed while recording that manifest. The checkout was shared and had a working delta; the file digests, rather than the recorded HEAD alone, identify the reviewed source. Any repaired source requires the follow-up disposition below and its own manifest.

## Findings

### H1 — Active aggregate survives an unrelated native World replacement (P1)

**Initial status: open; assigned to host implementer.**

`SolidPhase::Active` correctly does not count as a native mutation fence: ordinary cellular ticks and edits must continue. However, the inherited `CyberSimulationWorker.queue_reset` path and non-solid `_apply_lab` replacement commands use that narrower fence as their only protection. In the reviewed `solid_detachment_worker.gd`, `_apply_lab` refuses a non-solid command only while `_native_representation_fenced()` is true. `simulation_worker.gd` subsequently handles an ordinary reset by calling `_world.reset_demo_world()`.

`reset_demo_world()` constructs and swaps a replacement native World, discarding the active aggregate store and token. This operation does not close the session's existing Rapier bridge or body. The session can remain `active`, with the old geometry and `physics_epoch`. Its result consumer checks that epoch but has no independent aggregate identity acknowledgement in normal snapshots. The old body can therefore keep moving against a replacement native world after its owned payload was discarded.

The diagnostic scene's R control does use the safe `session.close()` / `open()` route; the defect is the inherited public worker replacement route. It must be refused for this specialized lane, or coordinated through a complete owner teardown. Restricting ordinary active cellular ticks would be the wrong fix.

Required regression: after an actual native-to-Rapier release, request inherited ordinary reset and a non-solid scenario replacement. Verify the existing exact aggregate payload/token, worker health and live body identity remain intact, or verify a complete explicit session replacement with the old body retired before new native authority appears. Also retain existing whole-session replacement-at-await tests.

### H2 — Native failure publication does not stop Rapier (P1)

**Initial status: open; assigned to host implementer.**

`simulation_worker.gd::_publish_failure_snapshot` deliberately copies the last valid publication, sets `simulation_failed`, empties rigid-body results and stops native evolution. The reviewed `solid_detachment_session.gd::_consume_compound_results` checks epoch and terrain but not `snapshot.simulation_failed`. Empty results are rejected by the compound reducer as an ordinary invalid result. `physics_step()` then continues `bridge.step()` and republishes new poses.

Consequently a live aggregate can move indefinitely after the cellular owner has failed, while its native occupancy mask remains frozen at an old pose. `_prime_compound_coupling()` also accepts matching copied epoch and state-array length without first rejecting a failure snapshot.

Required repair: fail/pause the session before another admitted Rapier step when a native failure publication is observed; reject failed snapshots during priming. Retain the real aggregate payload and body for explicit whole-session teardown. Required regression: provoke or publish an actual owner failure, consume it, and verify no subsequent Rapier step and no unintended reset/ownership transfer.

### H3 — Compound API does not reject nonconsecutive repeated samples (P2)

**Initial status: reported; disposition pending.**

`rapier_physics_bridge.gd::apply_compound_cellular_results` rejects old publication serials and equality with the most recently applied sample. It does not require a modular forward delta from the previous applied sample. Given increasing publication serials, sample sequence N, N-1, N can apply N twice when all samples remain inside the eight-sample age window relative to the current sample.

The current single exclusive worker publishes latest snapshots monotonically, so no ordinary session trigger was identified during this review. The risk is at the new public compound-consumer boundary and in its stronger stated duplicate/stale refusal contract. A compound-only modular forward-order check plus a wrap regression would close it without changing the ordinary/GCR body path.

## Ownership paths that passed source review

### Preparation, source retirement and static collider replacement

The native source remains authoritative while the main thread builds one frozen body with disabled shapes and collision layers zero. The body is placed once at the native COM, with exact native mass/inertia and the exact rectangle union. The bridge disables automatic space stepping. Native acknowledgement precedes commit; commit precedes the post-retirement static collider installation. `_install_terrain()` requires a valid copied chunk packet with the exact requested hard-surface revision and drains its bounded chunk work before activation.

After source retirement the native owner remains fenced. The session enables the compound shapes while both clocks remain held, obtains the collision receipt, primes the native proxy masks, and only then releases Rapier motion. There is no per-cell body or scripted transform animation standing in for motion. The new bridge correction helper is the existing cellular correction policy moved into a shared primitive, not a new detachment force law.

### Rollback, cancellation and whole-session replacement

Failure before source commit cancels the native reservation and destroys inactive physics. Failure after commit uses native exact restoration while the body is still inactive; static repair must be installed before the native rollback fence is released. Failed finalization explicitly disables body collision before attempting rollback. A failed rollback leaves the session paused and requires whole-session recovery rather than claiming successful restoration.

Every awaited continuation reviewed in `open`, `command`, `cut_and_release`, `_prepare_body`, `_rollback_inactive`, inspection and mask priming checks its captured generation and exact worker before continuing. `command` does not release a replacement owner's command lock. `close` advances generation, stops/joins the worker, disables the body, tears down the bridge and deactivates its space before replacing the owner. Deferred viewport destruction does not leave an active collider. The lifecycle regression source targets ten real reply/yield stages and replacement workers 1 and 4; execution is owned by the final qualification receipt.

### One aggregate, compound masks and feedback

Proxy records use the exact non-overlapping rectangle union and each rectangle's true local centre and area. Their point velocity includes the aggregate's angular contribution. Six proxies describe one live body; they are not six separately integrated bodies. The native aggregate retains the complete material/state/temperature payload after source cells become Empty.

The compound reducer validates the complete record set before any Rapier mutation, including field finiteness, one record per proxy, identical sample IDs, valid mass/geometry, age bounds, finite correction and impulse budgets. It applies one mass-weighted correction and bounded per-proxy impulses at rotated centre offsets; Rapier derives the corresponding torque. It does not inject a second force per cell moved in a relocation chain. H3 is the remaining feedback-order hardening issue from this pass.

### Render acknowledgement

`solid_detachment_render_consumer.gd` requires a complete baseline on first image, generation or channel change. It validates all patch metadata and byte bounds and constructs every patch before committing the image. Dirty patches appended to a retained full baseline are consumed in order. The scene acknowledges only after successful consumption; malformed packets request a full refresh. A render ACK is material-image consumption, not proof of GPU presentation or frame-rate acceptance. No historical render-copy/coalescing experiment is introduced by this consumer; production publication remains the current-main implementation.

### Ambient Sand/Water structural boundary policy

The native admission self-audit found no new structural ownership defect in the narrow populated-boundary change. It admits only ambient Sand and ordinary FreeMass Water as noncohesive surrounding contact material. Neither enters the component nor proves an anchor. A masked neighbouring cell is refused before material classification; hot surrounding material is refused; reactive/unsupported neighbours still refuse. Pressure/inertial policies are excluded. Homogeneous Wall/RedBrick source membership, bounded four-connectivity, resident/included domain, explicit hard anchors, unknown-edge refusal, capacities and exact tuple ownership remain in force.

This is a classification of structural cohesion, not a claim that Sand/Water has no physical support effect. Existing cellular contact response must still provide resistance. The native regression includes an anchored control, partially embedded boundary, exact 520-member ownership, preserved surrounding tuples and hole material, and thermal/foreign/reactive refusals.

## Qualification limits and acceptance cautions

- The populated host test checks aggregate tuple retention, Sand quantity, Water mass, real contacts and some real motion. It does not impose a penetration bound, bed-resistance threshold, density-dependent response, or adequate rolling outcome. Those physical quality gates must remain explicitly separate.
- The recovered session uses a 3.0 total proxy impulse-magnitude cap and a 0.5 correction cap. These are fixture conventions. Their adequacy for a 520-unit aggregate is not established by conservation or motion alone, especially after native granular bearing has been reduced through that aggregate cap.
- Proxy-centre impulse application provides attributable Rapier torque at compound resolution; it is not an exact per-cell contact-point torque model. GCR owns future normal/friction/yield/torque policy changes.
- Active terrain edits use the ordinary asynchronous hard-surface publication interval. Once a changed packet is received, the session drains collider refresh before another manual physics step. This does not establish zero-latency native-edit-to-collider publication.
- A timed-out or quarantined transaction is a paused recovery case requiring whole-session reset. No general live aggregate restoration, persistent aggregate serialization, arbitrary fracture, reactive Wood/bark, or general gameplay admission is qualified here.
- Frozen deterministic replay is not actual asynchronous host motion. CPU image consumption and headless timing are not representative interactive GPU pacing. Source-matched Linux/Windows hosted-runner results and graphical acceptance must be reported separately.

## Follow-up disposition

Pending receipt and inspection of H1/H2 repairs and any H3 hardening. This initial report must not be read as unconditional host acceptance.
