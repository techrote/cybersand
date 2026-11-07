# GEN-006 dynamic signed-seam continuation — native full-World stage

**Date:** 7 November 2026
**Status:** Experimental; bounded native implementation; not admitted for selective eviction or production.
**Programme:** #194; dependency and separate exclusive native-source writer #512; independent QA #514.

## Implemented scope and source authority

`gen006_dynamic_full_world_stage.hpp` is additive and header-only. A serialized
host captures a **complete native World** through the existing `save_physical_state`
(CYPS) API, privately validates a `restore_physical_state` instance against the
original physical hash, tick, full material/water ledger and resident chunk count,
then retains it until the owner verifies a byte-exact independently retrieved
copy. At commit the host-supplied **session, recipe, incarnation and mutation
generation fence** must match, the native source pointer must still identify
the same instance and a fresh full CYPS recapture must still have identical
bytes and hash. Exactly one `unique_ptr<World>::swap` publishes the candidate;
all refusals leave the live native owner intact. Clear/replacement is the host's
responsibility and must advance its incarnation; source pointer identity is an
additional, not sufficient, ABA safeguard.

This stage is designed as the initial **executable physical continuation control**
for future contiguous dynamic bundles. It is not an independent per-chunk
serializer, not durable storage, does not evict any individual chunk, and does not
reduce resident memory. External `verified_copy` bytes do not establish fsync,
directory persistence or durable ACK; storage/journal remains #518's lane.
It does not use a hidden gameplay default, change native physics, change CYPS,
change `world.cpp`/`world.hpp`, or alter MAT-AUTH's protected source checker.
The bounded maximum snapshot length is checked after native serialization;
peak serialization allocations are not pre-reserved or a formal memory budget.

## Actual test contract

The independent `native/tests/gen006_dynamic_full_world_continuation.cpp` creates
real signed adjacent native resident chunks `(-2,-2)` and `(-2,-1)` and ticks
Sand at their shared Y seam until actual Sand crosses into the lower chunk. A
separate sealed Water17/temperature417 fixture remains in the same native World.
The test stages and byte-checks a real CYPS image, refuses incorrect bytes,
session, recipe, generation and incarnation without mutating original native
physical hash, ledger, count or clock, then swaps its privately restored World
and advances eight physical ticks against an independently restored uninterrupted
control, comparing exact physical state hash, full quantity ledger and tick.
Further negative controls exercise a stale native tick, stale pointer/owner
replacement, and already-consumed one-shot commit. Configurations 1 and 4 are
executed separately; the test prints maximum **observed**, not configured,
worker participation.

### Reproduce on GitHub-hosted source

`python3 tools/experiments/gen006_dynamic_full_world_qualification.py`

The dedicated workflow `.github/workflows/gen006-dynamic-full-world-continuation.yml`
compiles the production native `World`, material rules, scheduler, generation
sources and this test on Ubuntu 24.04 and Windows Server 2022. Its exact-head
script refuses mismatched commits and retains source/tree, native compiled-binary
SHA-256, original compiler log and per-worker execution stdout/stderr. Hosted
results must be cited by actual workflow run, not inferred from this plan.

## Native integration blocker and next bounded contract

G6KC1 #512 currently rejects adjacent residents, live moving materials, halo
state and solver sidecars. The public World interface provides no atomic
multi-chunk eviction/restoration, owned resident-roster enumeration, boundary
transfer mailbox, or all-or-none commit of native scheduler/quantity state.
Do **not** split the complete CYPS into material-ID-only chunks, or delete a
moving chunk on an inferred quiet frame. After #512 completes and releases
protected source ownership, request a **single serialized-owner native
bundle-preparation/commit API** with complete neighbour/halo/scheduler/ledger
preflight, private staged candidate storage and one all-or-none publication
boundary. Until then this independent full-World fixture establishes the
correctness control, not the desired memory-reclamation capability.
