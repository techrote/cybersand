---
title: Current-scene material audition
status: Current
document-kind: contract
scope: Existing-ID numeric material controls in the current Workbench World
canonical-for: [current-scene-material-audition, material-profile-transaction, material-profile-retention]
last-reviewed: 2026-11-27
related-documents: [material-audition-consumers.md, ../operations/materials-lab-authoring.md, ../architecture/material-authoring-catalogue-plan.md, ../architecture/shared-workbench-authoring-data.md, ../operations/material-catalogue-shadow.md]
---

# Current-scene material audition

Live audition extends the Materials Lab (#562) and its generated capability
catalogue (#563). In the integrated Windows evaluator, extract the complete ZIP
and launch the ordinary Workbench using its supplied launcher.

Open ordinary **Workbench → Materials Lab → Current scene**, select a material,
edit an admitted value, then **Apply draft**. The same native World receives an
immutable profile between ticks. Its cells, clock and physical actors are not
replaced by this operation. The Lab's existing Inspect, candidate authoring,
reaction diagnostics, Try originals and Compare edits tabs remain available.
The [consumer map](material-audition-consumers.md) is authoritative for individual
fields, actual consumers, solver applicability and unsupported domains.

## Authority and ownership

| Layer | Owns | Does not own |
|---|---|---|
| Existing Lab plus `material_lab_audition_panel.gd` | Draft, selection, explicit Apply/Revert/Reset, pending UI and named profiles | Live World storage or native success |
| `material_audition_controller.gd` | Main-thread Workbench association and observed runtime file identity | Native calls from the UI thread |
| `material_audition_mailbox.gd` | One bounded pending immutable request and sixteen copied terminal receipts under the existing worker mutex | A new thread, scheduler or World |
| `CyberSimulationWorker` | Serial lifecycle admission and existing between-tick activation boundary | New engine pacing or rendering policy |
| `CyberNativeCellWorld` | Strict wire decoding and copied native effective readback | Canonical catalogue changes |
| `World` and `world_material_audition.inc` | Identity/revision, final validation, fixed numeric overlay, effective consumers and bounded activation wake | Global process material behavior |

Inspection is lazy. An unopened Lab does not build a capability catalogue each
frame. Once requested, readback refreshes on native generation change and profile
transactions. The normal worker turn reuses its existing locked completion
boundary. Pool workers read fixed arrays; they never interpret string properties,
allocate profile data, acquire a profile lock or call Godot.

## Admission and transitions

The main-thread request is exactly:

```json
{
  "session_id": "host-assigned-session",
  "world_id": "native-issued-decimal-identity",
  "expected_revision": 0,
  "profile": {
    "schema_version": 1,
    "profile_id": "sand-light-trial",
    "materials": [{"material_id": 2, "density": 500}],
    "reactions": []
  }
}
```

The profile is a **complete replacement**, including inherited accepted values
for omitted fields. It is not an incremental patch. Identity is 1–64 ASCII
letters, digits, dot, hyphen or underscore. Materials are bounded to the existing
132 slots and reaction records to the existing 56 slots. Empty/reserved or
inapplicable material edits, unknown fields, duplicates, invalid numeric types,
fractions and out-of-range values are refused before publication.

The session token belongs to the host; the World token is issued by native
construction. A native clear or replacement retires it. A retained-terrain Workbench edit that must build a new World (including actor placement or a capacity change) refuses while effective material overrides are active. Reset the overrides in Materials Lab before retrying. Live grabbing and pilot handoff continue to use the existing owner. Native move transfers
the token and leaves the moved-from object unable to accept the old token.
Every successful configuration transaction advances its own revision, including
a repeated or explicitly equivalent profile. Ordinary simulation ticks do not
advance this configuration revision. Equivalent values cause no activation scan
or scheduling wake and preserve the existing physical hash and save-byte stream.

Admission is checked when queued and again by the exclusive native owner. An
already pending request causes a bounded busy refusal; slider movement does not
queue intermediate transactions. Stop, reset and scene-control commands retire
pending intent with explicit receipts. Cancellation and commit share the same
worker critical section. If cancellation arrives after commit, the receipt says
the configuration is already active and directs the user to Revert. It never
claims that a committed operation was cancelled.

Native validation/allocation and the finite scan-capacity check precede the
single profile swap. Only affected resident material/reaction blocks and their
immediate boundary neighbours are awakened. A transition scans at most 16 Mi
resident cells in nonempty chunks, once per changed profile; exceeding this
capacity leaves the prior profile active. No cell payload or renderer dirty
rectangle is manufactured to make a parameter change appear effective.

Copied readback is the active-state authority. If bridge receipt construction
fails after native activation, it reports activation with failed readback rather
than a false refusal; the worker obtains fresh native state before a subsequent
edit. A terminal receipt always identifies the request, including retirement
and expired-receipt errors. Late receipts cannot overwrite a newer UI draft.

## Supported controls and honest alternatives

| Control | Admitted range | Current-scene interpretation |
|---|---|---|
| Density | Integer 1–65535 on admitted movable exchange participants | Directional native cell exchange; not real-world density units, Rapier mass, collision impulse or all solver density laws |
| Viscosity | Integer 0–255, generic IDs 20, 21, 24, 30, 32, 33, 36 when their active consumer permits | Generic yielding gate; inertial assignments and conflicting Mercury diagnostics refuse this control |
| Existing reaction probability | Integer threshold 0–255 for a rule with a possible current native initiator | Retains `roll <= threshold`, so probability is `(threshold+1)/256`; zero is **not disabled** |

All products, endpoint roles, matching order, state effects and quantity laws
remain canonical. Wave Water does not execute the ordinary Water cell kernel;
an otherwise authored pair with two inactive endpoints therefore cannot acquire
a live probability slider. An active Salt endpoint can still initiate an
admitted Water–Salt contact. The UI reports actual current-solver availability.

The capability classes are live, paused transition, isolated comparison,
rebuild/restart, unsupported and descriptive metadata. This first subset has no
separate paused-only configuration mechanism. Showing a class does not imply
that every operation in that class has a new button. Existing isolated candidate
comparison remains the alternative for admitted nonlive fields. In particular,
specialised Water, Lava, Acid and Oil descriptor viscosity is not presented as
an effective current-scene control. Stable IDs and hard/granular collision
capabilities remain outside this profile.

Inspection of an authored reaction, eligible participants or a predicted roll
is not a witnessed contact or execution. The native tests separately check
actual cell motion, native pair event counters and resulting products.

## Reversibility and retention

**Revert configuration** reinstalls the previous acknowledged profile.
**Reset to accepted defaults** installs an empty override profile. Neither
operation restores consumed material, displaced cells, burned structures,
temperature, simulation time or Paint history. No simulation-state Undo is
advertised. Loading a demonstration is a separate confirmed scene replacement.

Named profiles have a strict versioned JSON envelope with name, optional
description, canonical profile, semantic native compatibility fingerprint,
observed native-file SHA-256 identity and content digest. Loading validates and
prepares a draft; the user explicitly applies it to the current session/World.
Session and World tokens are never persisted as reusable authority. Unknown
keys, duplicate JSON keys, altered digests and mismatching runtime identities
are refused without replacing the active configuration or current draft.

The observed file digest is the same honest evidence boundary used by the
existing Lab: it does not independently fingerprint the mapped native module.
Evaluator manifests bind exact source and binary bytes. A profile from another
build or operating-system binary is refused; unrestricted cross-version or
cross-platform profile migration is not claimed.

Workbench **Save start** retains its existing authored scene semantics. It does
not retain the material profile, and its status warns when a changed profile is
active. Save the named profile separately and reapply after reopening. This does
not alter the two-byte-per-cell material baseline or global material catalogue.

A behavior-changing profile enters physical hash version 7. Equivalent defaults
retain the prior version/hash bytes. Existing CYPS physical serialization cannot
retain the new configuration, so its format version is explicitly unavailable
and exact physical save refuses while a changed profile is active. Ordinary
content/state hashes keep their established narrower domains. Reverting restores
the old configuration's save availability; it does not restore old cell bytes.
Gameplay recording does not yet serialize profile transactions as replay events.

The future RAMCACHE/persistent-area seam is a copied validated profile plus its
runtime compatibility/source provenance, stored separately from cell payloads.
Restoration must create a fresh World/session binding, validate the profile and
obtain a new native acknowledgement before continuation. No RAMCACHE branch,
area scheduler, multi-plane propagation or new persistent-state format is
implemented by this mission.

## Concurrent-programme reconciliation

The implementation was isolated from accepted main. It does not contain the
active PUBPRES, ObjectShard, Art or SWARM candidates. Their actual changed-file
lists were checked on 24 November 2026; file overlap is an integration gate,
not permission to replace their implementations.

| Shared file | This mission's bounded change | Reconciliation requirement |
|---|---|---|
| `native/src/world.cpp` | Density/viscosity/pair consumer calls and lifecycle/module inclusion | Preserve PUBPRES scheduling and ObjectShard occupancy/effect changes; replay exact default controls on the combined source |
| `native/include/cybersand/world.hpp` | Owned profile API, token/revision and nondefault hash/save availability | Preserve independent native APIs and identity semantics |
| `native/src/world_pressure.inc` | Nondefault configuration hash identity and explicit unsupported physical-save refusal | Preserve existing pressure/Wave laws and their source transitions |
| Native adapter `.hpp/.cpp` | Two methods and one material-only included module | Combine declarations/bindings; do not replace coupling/render/publication code |
| `simulation_worker.gd` | A value-only mailbox, retirement hooks and one existing boundary service | Place on the final PUBPRES/ObjectShard serialized owner boundary; no scheduling policy from this branch supersedes theirs |
| `shared_workbench.gd` | Existing Lab bind, explicit demo load and Save start note | Retain other programmes' UI and authored-install ownership |
| `Makefile`, docs/indexes | Focused tests and material documentation routes | Mechanical additive reconciliation; preserve other gates |

The immutable catalogue, generated hard/granular maps, reaction declarations and
frozen compatibility lock remain unchanged. Protected source changes require
their exact committed hashes, reachable source commit, dated evidence and
independent review through the existing reviewed-transition mechanism. Hashes
must never be refreshed just to make a checker pass.

## Qualification and remaining gates

The source includes native transaction/effect tests, current-scene Godot tests,
profile/import/UI tests, compact-window geometry checks, accepted-source matched
performance/parity probes, a target-OS qualification runner and a portable
interactive Windows evaluator packager. The dedicated workflow runs only on an
explicit `.github/material-audition-run.json` request or manual dispatch; normal
Draft iteration does not launch the expensive matrix.

Executed evidence and exact identities are recorded in the
[definitive decision packet](../audits/material-audition-live-20261124/decision-packet.md):
qualified source `5f73b0ae`, its four-path runtime publication `206f14da`, actual
Linux/Windows and extracted-evaluator execution, exact archive verification and
independent review. The frozen shared ledger remains a build-input checkpoint;
the decision packet owns the final qualification disposition.
Source implementation, native simulation evidence, graphical automation,
extracted-package execution and physical owner acceptance remain separate
claims. The original standalone evaluator was held for physical owner review.
The later integration added shared authoring admission. An active Art stroke
or Architecture operation must finish before a material demo replaces the scene.
Live material configuration uses its own native acknowledgment. See the
[integrated source and regression](https://github.com/techrote/cybersand/commit/687b8872d2f7ccc6c935fd3ea447e89a1fe2cc20)
and [PR #768 qualification](https://github.com/techrote/cybersand/pull/768/checks).
