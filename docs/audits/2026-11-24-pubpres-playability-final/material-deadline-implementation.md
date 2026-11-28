# Explicit material deadline arm — 24 November 2026

Status: **implemented diagnostic arm; Draft/HOLD; graphical and performance
qualification pending**. This follows the earlier
[read-only feasibility assessment](presentation-coalescing-assessment.md), whose
source identity and original conclusions remain unchanged. The recoverable
implementation is on `codex/pubpres-final-material-deadline-20261124`, based on
`bbcb19da2214098a4b57bf86ce19c470822a90d4`. The accompanying
[local receipt](material-deadline-local-receipt.json) binds all five changed
script bytes rather than claiming the base commit contains the uncommitted
implementation used by the local screen.

## Decision and scope

The existing worker already publishes one latest immutable snapshot and retains
ordered unacknowledged material changes. This arm therefore tests an explicit
material consumption interval, not elimination of an application upload FIFO.
The selector is `CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ=30` or `60`, with every other
value off. No production default, renderer ownership, native law, callback,
Rapier step or terrain/body-sample gate changes.

Main offers the cumulative snapshot before touching the CPU material image,
byte histories, GPU resources, timeline or uploaded World/revision. The policy
retains one immutable reference. A newer eligible snapshot replaces it while
keeping the deadline fixed. After a successful actual upload, the next deadline
is its completion plus 33,334 or 16,667 microseconds. Every ordinary `_process`
turn drains an expired offer even if a paused World produces no newer snapshot.
Main blocking can overrun that deadline and remains measurable as a real delay.
If other Main/renderer work already takes longer than the selected interval,
the next offer is immediately due. This completion-plus-interval rule cannot
improve that run by suppressing an upload; it does not remove drawing or the
engine's renderer rendezvous.

An identity key contains the actor session, epoch and authoritative World
generation. A pending physical replacement/reset, owner closure, native failure,
texture recreation or upload rejection cancels the retained offer. Transition
transactions use the original immediate path. A different World requires a
complete cumulative frame and bypasses the old deadline. A structurally invalid
offer invokes the existing rejection/full-refresh request; a stale or already
uploaded serial gives no ACK and no new accepted-upload count.

Actual consumption reuses `consume_render_snapshot` without modifying its
payload validation, fallback, history rotation, World blending, timeline or ACK
code. The latest worker snapshot may describe a later physical state while an
older material plane remains displayed; `workbench_display_frame` and the existing
pose coherence guards retain the real uploaded identity. The policy confers no
permission to step Rapier against old terrain or an uncompleted body sample.

## Regression and independent review

`test_material_publication_deadline.gd` runs without any native extension. Its
57 checks cover explicit selector admission, rounded intervals, first/new-World
full frames, immutable one-offer replacement, fixed deadlines, paused drains,
refused and duplicate completion, recovery, session/epoch retirement, new-World
partial refusal, native failure, identity disagreement and teardown. Its clocks
are synthetic and it explicitly records no physical credit.

`test_material_deadline_main_history.gd` is a graphical correctness fixture,
not a timing benchmark. It creates the actual Main upload owner and derives
its cumulative packets from the production worker journal. For both 30 and
60 Hz it first uploads20, defers/replaces21/22 with24, then drains24 without
another mailbox arrival. The first actual GPU reads must show current24 and
previous20. ACK24 is deliberately not yet observed by the worker owner when
delta25 is appended, so replay includes21/22/24/25; the first GPU histories must
then be current25 and previous24. A same-size new World30 bypasses pending26,
retains the physical old texture bytes but grants them no cross-World blend
authority. Teardown discards pending31. Actual ACKs are exactly20/24/25/30 and
actual manual Rapier steps remain zero. The independently replayed patch ledger
includes overlapping rectangles and NPOT RG8 dimensions33×19.

The rendering specialist independently confirmed the accumulated-journal and
delayed-ACK proof, then identified that a refused new-World partial offer needed
an explicit full-refresh request. That finding is repaired through the existing
Main rejection path. The fixture includes the requested delayed-ACK prefix
replay. Subsequent source review found no blocking authority/history defect but
identified missing tests for the actual owner-class identity branch.

`test_material_deadline_main_identity.gd` resolves that gap with actual Main,
PhysicalSession and WorkbenchBridge objects, copied identity fields and no
configured bodies. Its 25 checks exercise 11 cancellation cases: changed actor
epoch/session, incomplete frame identity, authoritative World disagreement,
pending actor reset, physical replacement or World transaction, failed worker
status, failed latest snapshot, failed offer and actual physical-owner closure.
All cancel before consumption, byte-history mutation or ACK. The real worker's
protected `has_failed` path reads a separate failed publication; the pending
healthy packet is not mutated. Copied fields and zero configured/stepped bodies
make this authority testing, not physical gameplay proof. Independent graphical
result-oracle review remains separate from the implementer's local results.
The rendering specialist reviewed the added identity fixture and confirmed the
coverage gap resolved, with no remaining source-review blocker. That review does
not substitute for exact GPU reads or real off/30/60 physical comparisons.

## Exact local execution and remaining gates

The receipt records official Linux Godot `4.7.stable.official.5b4e0cb0f`, SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
The policy process exits0 with57 passing checks. The Main fixture's headless
`--check-only` process also exits0 without script errors. Both commands have
45-second timeouts and their complete short output, UTC times, command arrays,
script hashes and log hashes are retained in the receipt.
The additional actual-Main identity process exits0 with25 passing checks under
the same engine and 45-second timeout. Its completion log timestamp is recorded
as filesystem mtime; an unobserved process-start timestamp is not invented.

The Main syntax stage uses the independently hosted native artifact built at
`b21dca8fd6bd30bed9c19ce84601f85050405bed`, SHA-256
`aeb83dc3795b8010437e8bbba037053aff6cf5b5c928d60e0eeedef6b6eb6bd1`.
Every native source input in its build receipt matches this worktree. Its source
identity is retained separately from the changed script overlay. The exact
Rapier library hash is also recorded. This is syntax screening, not a new native
build or graphical execution. The local workspace's earlier Unix-socket refusal
prevents an owned X display; the actual GPU fixture must run hosted.

Required next evidence includes first GPU reads with slot2 and slot3 on the
selected graphical engines, malformed packet/full recovery, real owner reset,
save/reopen and ordinary mixed Workbench execution. Matched off/30/60 comparisons
must hold native source, renderer owner, publication mode, slot count, workload
and timestep constant. Report actual accepted Rapier steps and completion gaps,
material upload spacing/age, pose age/withholding, application-input admission
latency, CPU/memory costs and visual history together. Retain adverse rates and
controls. Neither a skipped material publication nor a policy acceptance counter
is a physical completion witness.

The subsequent [controlled timing registration](material-deadline-timing-registration.md)
defines the fixed off/30/60/60/30/off arm order, original graphical prerequisites,
independent physical oracle and additive bounded material-age observations. It
registers apparatus, not a favorable timing result.

## Documentation change map

| Canonical home | Change or unchanged boundary |
|---|---|
| Rendering and gameplay bridges | Describes explicit presentation scheduling, identity, actual history and recovery. |
| Data ownership and lifetimes | Adds the one retained immutable Main reference and preserves journal/ACK ownership. |
| Configuration reference | Owns exact selector strings, intervals, off behavior and pending capacity. |
| Validation evidence | Routes the local policy/parse screen and unexecuted graphical/performance gates. |
| Interfaces, invariants and tick contract | Native/body/terrain wire layouts, authoritative ownership and physical admission are unchanged. |
| Roadmap and programme runbook | The root integration records the experiment beside native, ring and engine arms; no acceptance/default promotion follows. |
| Retrieval corpus | Existing canonical pages retain their ownership and routes; this dated execution record stays historical. |
| User controls and save format | No ordinary UI control, level key or persisted setting is added. |

The bounded commands for the two focused fixtures are `godot --headless --path
<policy-stage> --script res://tests/test_material_publication_deadline.gd` and,
with an actual graphical display and explicit Full selection, `godot --path
<verified-project> --rendering-method gl_compatibility --script
res://tests/test_material_deadline_main_history.gd -- --receipt=<new-file>`.
The hosted driver must supply exact source/runtime identities and own the child
process lifetime; merely running the command is not provenance qualification.

Local repository checks retain their real scope. Historical M11 integrity passes
18 records/28 source hashes. Documentation structure reports six missing companion
workspace expected-fact sources; its changed links and metadata produce no new
error. Repository provenance also reports the already divergent retained native
Windows/Linux inputs (adapter `.cpp`, `.hpp` and `world_wave.inc`); the independent
hosted native artifact used for syntax screening does not rewrite those published
runtime records. These are **failed gates**, not a repository pass. The unchanged
32-question lexical retrieval set gives 19 canonical hits at 1, 30 at 5 and MRR
0.7318; this does not test gameplay or qualify the new experimental arm.
`git diff --check` passes. Exact report hashes, results and error lists are retained in the local
receipt. Root integration must retain its own final source-bound gate outcomes.
