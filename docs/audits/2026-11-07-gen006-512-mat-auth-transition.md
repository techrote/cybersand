---
title: GEN-006 #512 reviewed native World source transition
status: Current
document-kind: evidence
scope: Independent source-authority admission on Draft #512 only; not a GEN-006 production merge
last-reviewed: 2026-11-07
related-documents: [2026-11-07-gen006-shared-world-pristine-release.md, 2026-11-07-pr405-current-main-reconciliation.md]
---

# GEN-006 #512 — protected World source admission

Independent [MAT-AUTH source-owner decision](https://github.com/techrote/cybersand/issues/352#issuecomment-6707252033)
and [separate read-only #512 review](https://github.com/techrote/cybersand/pull/512#pullrequestreview-5812330994)
approve this *one exact* opt-in static-domain protected `world.cpp` change for
an append-only `REVIEWED_TRANSITIONS` admission. They do **not** authorize a
production GEN-006 merge, a default gameplay change or selective dynamic Water
and Sand eviction.

## Source and ancestry

- Protected path: `native/src/world.cpp`.
- Accepted source baseline: merge of PR #405, `81bbd5ff5cf366159e2b8a630609359c13560080`.
- From LF SHA-256: `b6cedf52e795073630f12f77668a461b6f9c3bb5fe02c64e7b6649bee4a6239a`.
- To LF SHA-256: `0d9bbc5c394a17ee378c73679e600f84b6b7a286644442f68053c1055e499889`.
- Source commit: `7b366c201fd521a7b9bfc21fe7a9b2485f456828` (native source Git blob
  `ac2ef2e65f2baf4ef0799f2be93de872bc7e9dfd`).
- Programme issue: #194. Change PR: #512.
- Existing baseline `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` and immutable
  `materials/catalogue/compatibility-lock.json` are unchanged. Historical
  transitions, including #405's `e77ca847` World source, are preserved.
- #395 MoltenGlass changes are independent and **not** imported or approved.

The reviewed changes supply opt-in generated-pristine Empty release, explicit
edit-intent/tombstones, monotonic native admission incarnation and generation-
fenced staged G6KC1 static Wall/Empty capture, durably ACKed eviction and
re-admission, signed-coordinate preflight and conservative exclusion of dynamic
materials, neighbours and externally owned simulation state. The admission
incarnation does not reset at `World::clear()`. Historical CYPS save bytes,
PressureFlow C1024/C2048 default and #405 camera-cache retention are preserved.

## Independent executable evidence

- Original real ABA negative, [Windows/Linux #42345975023](https://github.com/techrote/cybersand/actions/runs/42345975023):
  a stale original ACK erased a new same-coordinate residency. Retained as RED.
- Corrected #512 [native Windows/Linux #42364417967](https://github.com/techrote/cybersand/actions/runs/42364417967):
  2/2 PASS, configured 1/4 workers; exact Wall/Empty temperature417 and edit-
  intent continuation, signed-coordinate rehashed refusals, native quantity,
  same-World eviction/restart and the ABA fence positive.
- Independent #514 original negative [Windows/Linux #42366945069](https://github.com/techrote/cybersand/actions/runs/42366945069):
  2/2 PASS. Stale ACK A cannot evict B; fresh B ACK works; after clear, old B ACK
  cannot evict C, whereas fresh C ACK succeeds. Default-off native physical
  parity and genuine pristine re-admission also pass.

Actual worker participation in these small static fixtures is 1/2 for configured
1/4; four configured workers are **not** four observed participant threads.

## Strict scope and pending release gates

This source transition authenticates reviewed bytes and preserving ancestry,
not general physical acceptance. Unsupported dynamic Water/Sand, gas,
PressureFlow, IN, ballistic, neighbour halo, actors, pending work and sidecars
stay pinned/refused. The host separately owns world/session/recipe checks and
real file fsync durability before issuing a native ACK. A caller-supplied
`durable=true` is not an independent durability proof.

General Native, ASan/UBSan/TSan, full Linux/Windows GDExtension/Godot,
material/documentation and independent integration review are still distinct
final-head qualifications. The default-off candidate has no independently
admitted CPU speedup claim. Keep #512 Draft/unmerged, and preserve its source
commit through normal merge ancestry only; never squash/rebase this entry.
