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
**moving Sand and Water** on non-overlapping parts of their shared Y seam until
both materials are observed in the lower chunk. A separate sealed Water17 and
temperature417 fixture remains in the same native World.

**Corrected control:** a completely independent native `World` is constructed
from the same explicit initial fixture *before any ticks*, and then kept running
without CYPS save/restore. Source and control must match before staging and at
every pre-stage native tick. The candidate stages and byte-checks a real CYPS
image, refuses incorrect bytes, session, recipe, generation and incarnation
without mutating original native physical hash, ledger, count or clock, then
swaps its privately restored World and advances eight physical ticks against
that genuinely uninterrupted control, comparing exact physical state hash,
full quantity ledger and clock. Comparing two independently deserialized Worlds
would not detect jointly lost scheduler/sidecar authority; this stronger control
is specifically intended to detect that mistake.
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

## 7 November follow-up: actual moving Water and uninterrupted-source control

The original first-stage fixture had proved genuine **Sand** seam motion, but
kept Water17 sealed and compared the candidate after restore to another World
created by the same restoration path. This revision strengthens the test instead
of widening production scope. Five additional Water source cells now start on
the upper signed seam and are required to appear with positive native quantity
below the seam; the sealed Water17/temperature417 state remains a separate check.
A fresh native control is initialized independently and never serialized or
restored during the comparison. This catches loss of activity/timing sidecars
which could be invisible when both sides use the same broken restore path.

This is still complete-World CYPS continuation, not multi-chunk selective
release. The specific signed-seam Water workload is a bounded test only;
regressions on the actual candidate must be reported by exact-head hosted CI,
not inferred from these written expected outcomes.

## 7 November follow-up: complete resident-set bundle admission (experimental)

An additive `gen006_dynamic_bundle_admission.hpp` now implements a
conservative complete-residency preflight for the real signed Sand/Water
frontier, without touching protected World or G6KC1 #512 source. It requires
2–8 unique signed chunk coordinates, an exact resident-count witness, and a
canonical exhaustive list of every internal orthogonal seam. Duplicated or
omitted seams and nonadjacent edges are explicitly refused.

The stage privately restores an actual complete CYPS native World and uses
`install_generated_chunk(...)` on this **disposable** World to attest
`AlreadyResident` for every supplied coordinate. This also invokes the
canonical native signed-multiplication/rule-radius preflight, refusing
overflow. A missing coordinate may be installed into that disposable probe,
which is then destroyed without touching the live World; it can never be a
positive witness. The complete private probe must match the original
source's CYPS bytes, physical hash, native tick and quantity ledger before
an atomic owner-swap stage is returned.

The existing genuine Sand/Water signed-seam fixture now includes negative
controls for a partial roster, repeated chunk, missing seam, invalid seam,
repeated seam, phantom resident and signed-coordinate overflow. Every
refusal checks the unchanged original World pointer, physical hash, full
quantity ledger, completed tick, resident count and resident bytes.
The admitted complete-roster positive stage is followed by the original
eight physical ticks against the independently uninterrupted native World.

**What this does not do:** release selected chunks, reclaim resident memory,
prove exterior halo demand, transfer partial native scheduler/pressure/ballistic
sidecars or write durable multi-chunk checkpoint files. Full native CYPS
retains those states only as a *whole World*. Host persistence is #518's
responsibility. This is the first bounded executable resident-bundle
admission/negative-control layer, not the native selective transaction.

**CI qualification:** Pending this revision's exact-head Linux/Windows
workflow. Earlier #523 runs apply to earlier heads, not this revision.

### Signed seam overflow negative control

Independent static review caught a false-adjacency possibility in the first
unsigned-distance test: `INT64_MIN` and `INT64_MAX` are not consecutive
signed chunk coordinates even though one modular subtraction can equal 1.
The corrected predicate first establishes signed ordering, then computes
unsigned positive distance without overflow. The native test now requires a
manifest claiming that extreme seam to fail at the seam-admission gate,
without touching the original World. Normal signed `(-2,-2)` to `(-2,-1)`
adjacency is still the positive execution control.

This correction supersedes the first bundle-admission CI result; the new
exact-head CI must pass independently before claiming qualification.

## 7 November follow-up: one-swap native cross-resident input transaction

The same additive full-resident-set stage now supports a strictly bounded
**owner-side in-memory native input batch** (1–64 material commands, restricted
to Empty/Wall/Sand/Water) spanning multiple signed resident chunks. Every
command's resident identity, local coordinate and material is preflighted
before touching a PRIVATE deserialized native World. Duplicate targets,
out-of-roster targets and bad local coordinates are explicit refusals with
unchanged live World. The batch becomes visible in one existing full-World
owner-pointer swap only after the source CYPS byte witness, exact original
session/recipe/incarnation/generation fence and separately supplied canonical
edit-list witness agree. Failed private edits discard the private candidate;
they cannot partially change live native authority.

The updated actual-native regression stages a Water edit in resident
`(-2,-2)` and a Sand edit in `(-2,-1)`; the independent uninterrupted World
applies the same edits directly. It requires state-hash/quantity parity at
commit and after eight additional real ticks, with 1/4 configured workers
on both Windows/Linux. Invalid duplicate/out-of-bundle/out-of-bounds commands,
a missing edit witness and a wrong material witness must all refuse without
changing the live native World.

**Durability limit:** This edit batch is NOT a journal, fsync, storage protocol,
new per-chunk ABI, selective dynamic eviction or memory reclamation. The
independently retrieved base CYPS plus canonical edit-intent bytes must BOTH
be durably published by a separate storage owner before any durable ACK.
This prototype does not produce that ACK and does not integrate #518 or #486.
It is opt-in code on a Draft branch, with no protected native source change.

**CI status:** This new source revision requires its own exact-head
Linux/Windows native and documentation/provenance qualification; prior
a5625bab results do not qualify these added edits.

## 7 November same-run follow-up: private native tick transaction

The additive full-resident-set transaction can now advance **1–16 real native
ticks in the privately restored World**, optionally after the earlier bounded
cross-resident material edits. It records a native receipt with exact completed
tick, physical-state hash, complete quantity ledger, resident memory/count and
**observed** worker participation. The original World is neither ticked nor
modified during this speculative computation. Any new native resident discovered
during private ticking refuses the transaction and destroys the private World:
the 2–8-resident manifest does not license additional halo ownership.

Commit requires independently supplied original CYPS bytes, a canonical
material-edit list (possibly empty), and an exact private native-tick receipt.
Neither legacy no-tick overload may publish a ticked candidate. The test rejects
zero/over-budget ticks, double staging, edits after ticks, wrong receipt, wrong
edit witness and stale fence without changing original native bytes or identity.

The real native signed-seam Sand/Water fixture stages two different material
edits, advances six PRIVATE native ticks, and compares its receipt to the
completely independent never-restored reference World, then publishes with one
owner-pointer swap and compares eight further REAL native ticks. This is
non-durable speculative **whole-World** execution, not selective chunk removal
or physical parallelism evidence. Sidecars remain preserved only through full
CYPS. Neither fsync nor independent edit-intent durability is claimed.

**Qualification:** Exact source-head Windows/Linux and documentation/source
CI must pass before this revision can be called qualified. The protected
#512 native World files, MAT-AUTH locks and gameplay defaults remain untouched.


## 7 November same-run post-execution CYPS publication and cold-process control

The additive full-resident coordinator now seals a real post-edit, post-private
native-tick CYPS image with a source/post physical state receipt. A second
native World restores and validates post ticks, hash, quantity ledger, memory,
resident count and exact bytes. Legacy commit cannot bypass a sealed publication.
The native fixture publishes those bytes to a local test file (NOT fsync or
durability proof), rereads them, validates original base, canonical edit and
preview-tick witness plus the new post-byte witness, and atomically swaps the
whole live native owner. Premature, oversized and repeated seals, altered
post-copy, altered post-tick receipt and stale fence all refuse unchanged live
native state. An independently uninterrupted native control proves continuation.

A second operating-system process is launched using only the post-CYPS file,
restores production World and physically executes eight more Sand/Water ticks,
comparing original source final tick, hash, Water quantity and resident count.
A damaged native CYPS and forged expected physical hash are rejected by
separate negative processes. Original compiled binary, hashes, source metadata,
file images and stdout/stderr are retained in dedicated Windows/Linux artifacts.
Configured 1 and 4 workers are tested separately; actual participants are
reported, never inferred from configuration.

This is a complete-World *post-execution* publication/readback control, not
selective dynamic chunk eviction, capacity recovery, a disk-durable journal,
host identity attestation or an admitted MAT-AUTH source transition. Source
protected by #512 is unchanged. Check the exact-head hosted results before
accepting this revision.

## 7 November — chronological cross-resident native command replay (candidate pending hosted qualification)

The additive `FullResidentBundleStage::stage_replay_script()` supports a **single bounded, ordered native transaction with several material-edit phases separated by actual native ticks**, unlike the older one-time pre-tick edit batch. The script uses `BundleReplayStep::material_edit` and `native_ticks`, max 64 steps/32 edit commands/16 real ticks, and requires an actual edit plus tick. Full input preflight rejects invalid material/local resident/coordinate, duplicate cell within the same tick epoch, invalid/excessive budgets, and mixed legacy/edit/tick transactions. The same cell can be edited again only after at least one native tick epoch. All original native scheduling, thermal, Water, granular and quantity state remains inside the privately restored **complete** World; newly created residents during replay cause refusal, not silent halo omission.

`BundleReplayReceipt` records the exact native completion tick, state hash, full quantity ledger, resident count/bytes, command and edit counts and observed worker participation. The existing checked post-state CYPS seal now carries explicit chronological-script count; `commit_replay_published` demands the *ordered full script*, exact replay receipt, independently reread POST CYPS, receipt and BASE CYPS, plus the original external owner fence. All legacy commit overloads refuse script authority. A single native owner-pointer swap is the only publication mutation, and the original World remains unchanged on refusal. Native cannot certify host durability or lease/session correctness by itself.

The extended real-native test starts from the prior actual Sand/Water negative-coordinate seam, alternates **three edit phases** on both signed residents and **2+3+1 live native ticks**, edits a target again in a later epoch, stages a full-World post image, and verifies one owner swap plus **eight additional ticks** against an independently constructed, genuinely never-restored World applying the same commands directly. An entirely separate native process loads the replay post-CYPS file and repeats eight ticks, with corrupt-CYPS and forged-physical-hash refusals on each configured worker count. Negative cases check empty and zero-tick scripts, duplicate same-epoch edits, phantom residents, excessive ticks, wrong chronological order, wrong receipt, wrong POST copy, wrong fence, legacy bypass and double commit. Existing single-phase and process-cold fixtures remain intact.

**Source / scope:** Changes confined to `native/include/cybersand/gen006_dynamic_bundle_admission.hpp`, `native/tests/gen006_dynamic_full_world_continuation.cpp`, the experiment qualification runner and this dated note. No `native/src/world.cpp`, `world.hpp`, MAT-AUTH protected source or #512/#514/#486/#518 branch changes. This is a full-World transaction only, not selective Sand/Water eviction, partial memory reclamation, cross-World halo transfer, or fsync durability. Native signed seam and activity sidecars are preserved by CYPS **as a whole**, not independently checkpointed as a partial bundle.

**Qualification requirement:** The exact resulting Git commit must pass the dedicated real production-native Windows and Linux jobs with configured workers 1/4, actual worker participation reported (not inferred), all existing legacy fixture markers, the new `GEN006_DYNAMIC_ORDERED_REPLAY_PASS`, the new `GEN006_DYNAMIC_REPLAY_EXPECTED`, and independent process-cold replay/corrupt/forged receipt controls. Also require source-scope and documentation/provenance checks on the same head. General production Native/GDExtension/Godot/Water/palette skipped due Draft do not count as accepted. Preserve raw compiler/source, executable SHA-256 and original stdout/stderr artifacts.

**Remaining protected-source dependency:** true partial native multi-chunk stage+commit+reinstall with resident/halo/scheduler/solver/quantity authority requires an explicit serialized release of the #512 protected World implementation. The separate active owner may continue adding independently testable full-World controls without crossing that boundary. Draft, opt-in, no merge.
