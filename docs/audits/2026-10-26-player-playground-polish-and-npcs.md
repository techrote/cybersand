---
title: Distinct playground districts, live NPCs and responsive Afterimage
status: Current
document-kind: audit
scope: Branch-local Windows headless district exits, shared NPC and prop host, stationary neutral fields and real Rapier player controls; hosted, interactive and other platforms separately gated
last-reviewed: 2026-10-26
related-documents: [../systems/player-control-playground.md, ../reference/configuration-reference.md, ../architecture/data-ownership-and-lifetimes.md, 2026-10-26-player-playground-expanded-and-usables.md]
---

# District polish and live NPC checkpoint — 2026-10-26

## Identity and acceptance boundary

Source checkout is the isolated `codex/player-playground-maps` branch for PR
[#262](https://github.com/techrote/cybersand/pull/262), starting this change at
`875d09d3f1db05d45bdb419a8a888c5bececb43c`. Accepted main remains
`9e53a5b1b501e0667037b8502d3c1d15089211f5`. The adjacent Windows packet records
the complete canonical-LF changed script/test identity at execution, source base,
engine/library hashes, exact process arguments, timeouts and log digests. The
dirty primary `C:/khybersand` material branch is untouched.

Native80 inputs, C64/E8, dependency pins and both published native libraries are
unchanged. Windows DLL SHA-256 is
`e3f17363d21260690682dfaa9e5e118253544c1b9b19e69e50c03af567712343`;
Linux SO is
`02ea0661d3a62e2ab346c3fe46f9f85b808c6a0099c639144f053dc70a5c3d46`.
Both manifests must still match all80 actual source inputs and materialized
library bytes. Local execution is Windows x86_64, Godot
`4.7.stable.official.5b4e0cb0f`, Rapier2D0.35.2, one native worker. No Linux,
rendered/shader, Web, interactive feel or full-route completion claim follows.

## Implemented and locally exercised

Eight 1024×768 public maps now have distinct topology and architecture: Flood
Market, Quarry Rally, Terraced Aqueduct, Textile Mill, Crater Port, Inverted
Foundry, Filtration Cathedral and Silo Facility. Each has243–403 rectangles,
33–43 material IDs, at least16,992 deep Water cells and16,008 other-liquid cells.
The initial promenade has112-cell headroom; six maps retain a28-cell lower dry
bypass while quarry/aqueduct use shallow authored ramps/steps. Both real buggy
and bike leave every start under ordinary throttle, exceeding174cells from
spawn without tools, jumps or pose assignment. Both wheel rigs also complete all
four baseline gates on Quarry/Aqueduct (1,078/1,121 and985/1,064ticks respectively).
The buggy clears the real44-cell quarry gap with one supported hop. The mounted
Afterimage clears the12-cell mill vent from a fresh local approach spawn; main
road access to that elevated approach remains a next-pass gap. Actual Glass
Scorer operations open all eight reservoir valves with exact Water quantity;
the foundry cut feeds1,626 powder samples through its first slotted comb. Other
complete routes and all-player laps remain outside this proof.

Three ordinary rectangular Rapier props per public map share the same private
space/native body coupling as the player. An optional starting NPC and live
stage/click spawning offer Runner, Skimmer and Crawler. NPCs reuse local demo
controllers; this is not general navigation AI. All seven public presets share
one native tick and one Rapier step. Material players retain their separate
leased material command identity and real cell representation, with no dummy
physical player. The body-free `legacy` material fixture is intentionally kept.

Append is bounded and staged: actual full bounds, stored native material and
current existing OBBs admit a candidate before publishing bridge/session arrays.
Old IDs, run/epoch, commands, observations, feedback history, terrain owner and
clocks remain. New equipment offsets count props. Eight actor/64-body limits
include equipment and props; no removal/compaction occurs before reset. Initial
construction receipts remain immutable; later copied roster revisions and
body-state packets describe live additions. Installing a new mask deliberately
wakes/invalidate native caches, so success is not identical full physical
continuation. Refusals retain exact old state. Material fields/tools install
current actual poses before writes, including after the preceding Rapier move.

Afterimage jumps94/double84 instead of78/69, with acceleration760 and air drive300,
opposed hips, counter-rotated feet and stronger bounded upright/motor control.
Per-joint finite command slew is2–120, default20 preserved; Afterimage uses90.
The bare-rig full apex changes18.935→27.477px (1.451×), early speed106.46px/s,
65/65 supported running ticks and bounded recovery. Mounted retained course
tests still complete the actual12-pixel tunnel. Ctrl supplies auxiliary
cancel/brake/glide in both playground and F5 SetP. Shift/S+Space still bullet
jumps; other players retain C and gamepad X is unchanged. Air inventory is not
replenished by cancellation.

Neutral swarms hold the anchor exactly fixed. Five bounded existing native
fields compensate satellite loft/pull instead of applying repeated upward
motion. The independent360-tick full-window census passes Sand and all six actual
prepared/readback Water selections. Maximum radius is41.0 Sand,41.304 FreeMass,
40.012 CY,41.012 PFreference/cached/dormant and19.698 IN. All Water cohorts retain
65,280 integer quantity; PF finishes65,211 visible plus69 hidden overfill. These
seeded fixtures stay within the60 circle on every tick with real local movement.
Radius60 is a bounded influence envelope, not universal containment of arbitrary
painted/reacting/obstructed material or persistent parcel ownership. Ordinary
chemistry and lease expiry remain authoritative.

## Final scoped local result

The frozen second cohort passes **23 suites, 28,143 assertions/checks,
zero failures**, with every child process exiting0 and no script/parser errors.
This includes all336 actual map/player/Water setup+tick combinations, complete
4,400-assert district mechanics and12,733-assert all-solver neutral-field census,
the284-assert actor append/refusal proof,277 actual NPC UI checks and32 fresh-mask
effect-entry checks. All changed script/test canonical hashes held through the
cohort. Both Native80 manifests and actual materialized libraries still match.
Packet SHA-256: `befd8050680f64622fbedc18c06c865ab49748a99f29a7b0231158f0a9b48d43`.
Raw logs remain at `C:/Users/_/.codex/tmp/playground-polish-validation-v2`.
This local result does not replace exact-head hosted gates or manual feel.

## Preserved failures and independent review

- Earlier geometry allowed a17–22cell lower gap beneath some cisterns. The final
  authored routes raise the structures and test the actual continuing bypass.
- A180-tick exit window saw only150/170cells under the unchanged vehicle
  acceleration law. The final window is300ticks and retains the174-cell target;
  actual exits occur by207/184ticks.
- The first live-spawn tests incorrectly demanded unchanged full physical hash
  after successful mask installation. The full identity includes mask wake/cache
  state. Replaced only this success premise with exact material bytes/quantity,
  held clocks/owner/IDs/receipts; all refusal hash comparisons remain exact.
- The first root quantity reader requested a1024-wide diagnostic snapshot although
  that API caps width512, causing a script error. Two legal half-world reads
  replaced the test reader; process/script errors are never accepted as green.
- First all-solver swarm reduction used visible state-a and falsely reported1,068
  conservation failures for PF hidden overfill. The corrected reader uses native
  Water integer quantity including overfill, preserving the original threshold.
- An initial F5 test tried configuring an already-live Session and received five
  valid refusals. The fixture now retires its prior owner before reconstruction.
- Independent review found stale masks before material effects and a stale native
  mask veto during spawn. Current-mask preparation now precedes material writes;
  spawn uses current actual OBBs and authoritative stored material without
  changing masks on a refused admission. Actual vacated-footprint regression
  covers this seam. A separate reviewer found F5 Ctrl text/input mismatch; actual
  desktop input/rearm/edge checks now cover the mapped key.

The source/runtime identity and final scoped results are in
`2026-10-26-player-playground-polish-windows.json`. Earlier audit/result packets
are retained as historical evidence. Exact-head Documentation/provenance and
every applicable hosted Native/GDExtension/Water gate plus final independent
review remain required before merge. Queued/skipped jobs are not successes.

## Script-resource cleanup correction

The initial combined actor process printed284/0 but exited3221225477 after the
footer; it is retained as failure. Debugger/minidump investigation reproduced
the cleanup fault with only the Runtime script loaded, with no World or actors.
Plain SceneTree, Arena alone and field alone exited cleanly. The minimal eager
Arena plus usable-runtime preload reproduced the fault: the physical usable
engine inherits that same generic base script. Deferred-quit and unrelated
type/import test edits did not repair it and were reverted.

Runtime now loads that exact pinned generic usable implementation at instance
creation after module parsing, removing the eager dependency diamond. Full
external Runtime A/B/A controls produced fault/clean/fault. The actual named
Runtime-only control exits cleanly; the original unchanged284-assert actor test
passes three debugger processes and three ordinary processes, all exit0. This
is a bounded Godot script-resource lifetime correction; no Native/usable law or
fallback was changed. The adjacent
`2026-10-26-player-playground-polish-import-lifetime.json` retains source hashes,
controls, failed candidates and dump/log identities. No dumps or logs are
committed as build output. The final full cohort still requires clean process
exit, not only a passing footer.

## Documentation and recovery

Canonical changes map to the player guide/README (controls/maps/NPCs),
configuration (limits/defaults), interface (append and readback), ownership
(World/space/mask lifetime), roadmap/handover (branch scope), validation/build
guide (new suites), retrieval manifest/index and new independent PLAY08 question.
Existing native invariants/body ABI and ADRs require no semantic change; this
extends the existing main-thread adapter owner. Historical result hashes and the
frozen32 retrieval fixture are preserved. Repository/doc/M11/retrieval checks
remain distinct from runtime acceptance.

Resume from this PR branch and its committed packet; verify main and exact head
before using old CI. User's subsequent request is a second seven-map collection,
then a review and a third seven-map cyberpunk collection. Keep additions within
existing gameplay/authoring APIs. Web/browser/shader testing, MAT230/231 and
material-fidelity work remain deferred. This task does not close202/203 or launch
another scientific campaign.
