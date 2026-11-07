# GEN-006 G6J1 — experimental append-only mutation journal

**Scope:** isolated, opt-in storage primitive for GEN-006 #194 (https://github.com/techrote/cybersand/issues/194), **not integrated** with the active PR #486 native controller or the separate shared-World residency engine. Keep this PR Draft and unmerged. No native physics, production storage, World ABI or default runtime is changed.

This is a bounded Python prototype for durable edit logging, not a completed native optimization. It accepts an opaque native baseline (maximum 2 MiB; for source-matched #486 replay this must be the **full G6SLICE1 host carrier**, including the CYPS snapshot and player-edit metadata) and up to 4,096 fixed-size mutation records (48 bytes each). The header carries signed native chunk coordinates, a nonzero residency incarnation, starting mutation generation, fixed native tick and physical hash. Each append validates the next generation, fixed tick, coordinates, edit kind, monotonic chain and CRC, then synchronously flushes/fsyncs the appended record. **Only after a successful append may the native caller issue its durable edit ACK.** The initial checkpoint uses same-directory no-clobber hard-link publication and POSIX parent-directory fsync.

Recovery checks the baseline and each complete record. A torn final unacknowledged record returns the complete valid prefix, clearly marked as torn; opening for subsequent writes refuses until a separately authorized repair/rollover procedure exists. Complete record corruption refuses rather than pretending the data never existed. The digest chain is a bounded accidental-corruption detector, not an authenticated or multi-writer protocol. There is no cross-process lock; a single serialized owner is a **required precondition**.

**Very narrow admitted domain:** a frozen native tick. A caller must restore the actual CYPS snapshot into a private native World, replay each command with the replay_checked function (verifying each resulting physical-state hash), and only then admit the candidate into the live owner. Missing host/Rapier/solver sidecars, tick changes and unmatched physics state are **refusal conditions**, not implicit support. A new durable checkpoint and incarnation are necessary before proceeding into a new tick epoch. Do not replay into a live World or claim preserved simulation activity solely from physical hashes.

## Exact local test

From the tools/experiments directory, run:

    python3 -m unittest -v test_gen006_storage_journal

The independent standard-library tests cover 200 file-synced edits; signed coordinates; incarnation, generation and tick fencing; external file size modification; checked replay hashes; no-clobber creation; torn-tail recovery and write refusal; corrupted complete records; and a child process doing os._exit(0) after a persisted edit, recovered by another process. Tests passed locally with Python 3.13.5 on Linux. Dedicated hosted Windows/Linux results must be inspected before claiming cross-platform acceptance.

The synthetic 512 KiB baseline plus 200 edits uses **533,952 bytes** in total, compared with **104,870,400 bytes** for 200 hypothetical full-record rewrites of the same size (99.49% fewer bytes for this contrived static-edit scenario). This is **not** a measured improvement in PR #486's actual native tick wall time, p50/p95/p99 ACK latency, memory, durable simulation ticks, or sustained gameplay throughput. No source-matched native benchmark was executed.

## Builder handoff

The #486 owner should not adopt this utility as-is for continuous 30 Hz physics. The next substantive integration experiment is to bridge it to a real staged native World under strict frozen-tick admission, test a durable ACK followed by actual process restart and equal physical state, and measure matched baseline-vs-candidate edit latency and write volume on Windows and Linux. The Native Residency Engine separately owns all actual shared-World chunk deletion/restore. Keep all experiments isolated and Draft; do not merge or change default physics.


## 7 November 2026 — interrupted checkpoint-publication recovery

A fixed `<target>.staging` path could be orphaned by a killed publisher and
permanently block subsequent safe `Journal.create()` attempts for that target.
The experimental creator now obtains a unique, exclusively created same-directory
stage using `tempfile.mkstemp`, syncs its contents, publishes using the same
no-clobber hard link, removes only its own stage, and syncs the parent directory
before returning success. A stranded old stage is not treated as permission to
overwrite an existing checkpoint or to assume cross-process exclusive ownership.

The regression leaves both a legacy fixed-name stage and an interrupted unique
stage, injects a failing `os.link`, proves that the failed candidate creates
no destination and cleans its own stage, then retries and proves successful
recovery without changing the old stages. It also verifies destination
no-clobber after publication. No power-loss or multi-writer guarantee is added.

**Exact-head source/test qualification:** `2f7ff2f29e86440f8820632f9dc32d2e918d1323`;
[GitHub Actions run 42353310465](https://github.com/techrote/cybersand/actions/runs/42353310465)
completed **PASS** on both Ubuntu 24.04 and Windows Server 2022 using
Python 3.12. The dedicated native source-scope advisory also passed.
General Native/GDExtension production matrices were Draft-skipped, not passed.
The separate documentation/provenance check must be assessed on the final
documentation commit before any stronger exact-head statement.

## Same-size external replacement guard

A stale open `Journal` handle previously only checked `st_size`. An external
replacement checkpoint of exactly the same length but a different residency
incarnation could accept an edit with the old chain, corrupting the successor's
recovery. The experimental append path now requires the original file identity,
verified header, prior record and expected size on the actual opened descriptor;
it rechecks the path's file identity and resulting length before permitting ACK.
A dedicated negative regression replaces the checkpoint with a different
incarnation of equal length and verifies refusal without modifying the successor.

**Boundary:** This is single-owner protection against accidental stale-handle
reuse, not interprocess synchronization. An adversarial or independently live
writer can still race a path replacement, and same-inode external tampering is
not a supported storage ownership model. No claim of multiwriter safety, power-loss
atomicity, integrated native correctness or improved throughput follows.


## 7 November 2026 — real-native frozen-tick CYPS replay pilot

The new `tools/experiments/gen006_storage_native_pilot.py` exercises the
**actual native C++ World and CYPS serializer** from independently pinned
experimental streaming PR #486, source commit
`876859839df581b400b24a0a182b95d8ed259b1c`, without modifying #486.
The source is checked out separately and compiled for actual Windows/Linux
execution. The dedicated workflow is
`.github/workflows/gen006-storage-native-pilot.yml`.

The pilot generates a real signed chunk, saves the genuine native CYPS checkpoint within its complete G6SLICE1 host carrier,
collects five actual same-tick native edit receipts (Empty, three Walls,
Water17/temperature417), binds a G6J1 checkpoint to the starting native hash
and mutation generation, appends the receipts in a child storage process,
hard-exits that process after durable writes, and recovers the exact records.
`replay_checked` then launches **five fresh native World processes**, each
restoring the original source-matched checkpoint and executing one longer edit
prefix, verifying every intermediate native physical hash, generation and
tick receipt. The final G6SLICE1 carrier and inner CYPS bytes must match the
original staged native result exactly.

**Qualified code/workflow head:** `95be518c34ce78a9e75b7c6aa023aa0725c01241`.
The [actual Linux/Windows workflow #42356905328](https://github.com/techrote/cybersand/actions/runs/42356905328)
passed both platforms with 1 and 4 configured workers; all four cases
returned frozen tick 0, five replayed edits, final generation 5 and identical
final native physical-state hash `8955484617271482506`.
Evidence artifacts include the actual native compiler logs, real native
process stdout/stderr and immutable Git checkout identities.

A following source-only pilot change additionally reports the sum of the
**five actual native-produced complete checkpoint payload lengths** versus
one G6J1 CYPS baseline plus five append frames. This is a payload-size
comparison, not a measured native disk-write count, fsync/ACK latency,
30 Hz tick improvement, memory improvement or CPU speedup; inspect the
new exact-head workflow outcome before accepting its measurements.

**Critical limits:** The process exited abruptly here is the external
G6J1 writer, **not the actual native simulation owner**. The real native
World processes used for candidate execution and replay terminate normally.
The journal is not integrated into #486's live 30 Hz controller and still
does not track arbitrary simulation changes, sidecars or moving tick domains.
This evidence qualifies the bounded *frozen-tick native checkpoint/replay
interface* only. Production physics, GDExtension, default streaming and
shared-World residency remain untouched.

**Next engineering action:** introduce the narrowly scoped journal adapter
into an isolated persistent native staging owner so a native-owner kill
immediately after journal ACK (without normal CYPS save-all) recovers an actual
candidate World. Then benchmark matched durable-ACK p50/p95/p99 latency,
write amplification, and per-tick cost against the original #486 mechanism
on both platforms, preserving full mutation/incarnation fencing. Do not
merge or mark Ready without owner authorization.

## 7 November 2026 — explicit torn-suffix recovery and native replay gate

A killed writer can leave a final *incomplete, unacknowledged* edit frame. The
previous G6J1 reader recovered the valid acknowledged prefix but deliberately
refused to reopen it for appending, without a supported recovery transaction.
`Journal.rollover_torn_tail(source, destination, x, y, incarnation,
expected_generation, verify_staged_replay)` now adds a **manual, opt-in**
continuation route that does **not truncate or overwrite** the crashed source.

The serialized storage owner must first stop all access through old handles,
choose a fresh destination in the same directory, and provide a replay callback
which validates the exact recovered prefix in an **isolated native World**.
The primitive rereads the one bounded source descriptor, validates every full
record/CRC/generation, verifies identity and expected terminal generation,
refuses a non-torn source, calls that native replay gate, rechecks the source
identity/length/mtime, and writes the clean acknowledged prefix through a
uniquely created, fsynced stage. No-clobber link publication and POSIX
directory sync precede returning a new appendable handle. The original torn
file and suffix are preserved for diagnosis.

This is **not silent crash repair, automatic startup rollover, lossless
simulation-tick continuation, multi-writer safety, power-loss recovery or a
Windows directory-durability guarantee**. A torn *complete* record or corrupt
acknowledged prefix fails closed. A different writer replacing a path while
the serialized owner runs is still outside the supported contract. No new
native API or protected World source is changed.

The standard-library regression tests replay veto, stale generation, wrong
incarnation, source mutation during callback, publication failure/retry,
forensic-source immutability, successor reopening and subsequent append, and
refusal to salvage a corrupt complete frame.

The pinned native CYPS pilot now deliberately terminates its separate journal
writer with a partial sixth frame after five fsynced native edit receipts. It
recovers those five, verifies five real native World replay prefixes and exact
final CYPS bytes, then publishes a separate, appendable verified-prefix journal.
The crashed source must remain byte-for-byte unchanged. This exercises genuine
source-matched native replay as the recovery gate but **does not** demonstrate
crashing a journal-integrated native simulation owner or improve measured
native tick/ACK performance. Execute on Linux and Windows with 1/4 workers
using the existing `gen006-storage-native-pilot.yml` workflow, and run
`python -m unittest -v test_gen006_storage_journal` for the standalone
negative controls. Assess the exact-head hosted results before claiming PASS.

**Next dependency-ready action:** wire a durable-write journal adapter to a
privately staged, persistent native World, crash that actual native owner
immediately after journal ACK (without normal save-all), and compare real
recovery state plus matched fsync policy and p50/p95/p99 latency against #486.


## 7 November 2026 — native-owner hard-crash incumbent checkpoint control

The independent tools/experiments/gen006_storage_native_owner_control.py
extends the pinned #486 native qualification without modifying #486 or the
protected World implementation. It runs the **actual long-lived native
--serve owner** at 30 Hz, using the existing file-IPC request/response
protocol. It focuses signed chunk (-1,-3), submits five individual edits,
validates every GEN006_EDIT_DURABLE_ACK, checks that the native G6SLICE1/CYPS
file carries the acknowledged mutation generation, then invokes an actual OS
hard kill on the **native process**, without quit, save_all or graceful exit.
An independently launched native World process reloads that same file and
must reproduce exactly the last acknowledged generation, completed tick,
physical hash, complete native CYPS carrier bytes, Water17, temperature417
and explicit Empty intent.

Execute after compiling pinned native #486 native/tests/gen006_streaming_slice.cpp
with its native World sources as in
.github/workflows/gen006-storage-native-pilot.yml:

    python tools/experiments/gen006_storage_native_owner_control.py --exe build/g6j-native/streaming-slice --root build/g6j-native/owner-control-one --workers 1 --native-sha 876859839df581b400b24a0a182b95d8ed259b1c

Repeat with --workers 4 and a fresh workroot. Windows uses
streaming-slice.exe. The existing native pilot workflow now runs both
worker configurations on Ubuntu 24.04 and Windows Server 2022, preserving
the actual process output, original record, restored record and
native-owner-crash-control.json, including five per-request IPC round-trip
latencies, exploratory nearest-rank p50/p95/p99, saved bytes and SHA-256.
The round-trip includes IPC polling plus the incumbent full-CYPS edit
clone/fsync path. Five observations **do not** provide a stable latency
distribution. Compare only equivalent scenarios, timing scopes and flush
policies.

**Critical distinction:** This is a genuine **native-owner-crash CONTROL
for the existing full-checkpoint mechanism**, not journal-integrated native
owner execution. The current G6J1 journal still runs separately. It probes
whether the incumbent last acknowledged checkpoint survives termination;
subsequent unsaved simulation ticks may be lost. It does not establish
hardware power-loss guarantees, Windows directory metadata durability,
dynamic inter-chunk transport, journal throughput gains, or a no-clone owner.
Do not claim end-to-end journal speedup. Check the exact-head hosted workflow
before declaring platform qualification.

**Next implementation dependency:** builder-owned, narrow non-persisting
staged native edit/owner interface preserving one World owner and current
native hash/receipt policy. Bind journal append and fsync before externally
visible ACK, then repeat this exact owner-crash test with no per-edit full
CYPS publication. Measure matched ACK latency, native tick cost and recovery.
Coordinate with #486; never edit its live branch or use a mock native World.


## 7 November 2026 — complete native-carrier journal recovery (self-contained baseline)

The earlier native pilot stored only the inner CYPS bytes in G6J1 while
silently relying on a **separate `native-base.g6s` file** to restore
#486's host envelope. CYPS does not alone capture the host-owned
chunk/recipe binding and explicit player Empty-intent mask. A standalone
journal therefore could not be sufficient to reconstruct the declared
complete supported state after loss of that auxiliary file.

The source-matched pilot now journals the **entire actual G6SLICE1
record**, not just CYPS. Recovery validates the G6J1 header/checksums
and the G6SLICE1 coordinate/schema/length preflight. It deletes both
auxiliary `native-base.cyps` and `native-base.g6s` working copies
before independently replaying all five edit prefixes into fresh
native processes. Every replay now restores directly from
`recovered.checkpoint`; the original unmodified native baseline
remains under `base/` as forensic evidence, not a runtime dependency.

A negative control creates a structurally valid G6J1 file with the
former CYPS-only baseline. The native adapter must refuse it as
`G6J_NATIVE_OUTER_SCHEMA_REFUSED`, rather than silently dropping
host state. The generic G6J1 storage primitive intentionally accepts
opaque checkpoint bytes; **format/domain admission belongs to its
native host adapter**.

The larger stored baseline increases byte counts relative to the
earlier 81.15% payload-only reduction. Earlier figures must **not** be
reused for the corrected journal format. Inspect the new exact-head
Windows/Linux native-pilot run for observed payload totals; this remains
a serialized-payload comparison, not an fsync, owner-ACK, per-tick,
power-loss, or integrated streaming throughput result.

**Next necessary implementation boundary:** make the builder-owned
native edit owner commit an already staged candidate only after the
complete-carrier journal append is durable, without republishing full
CYPS per edit. Run the actual native-owner hard-kill control on that
isolated adapter and compare source-matched end-to-end ACK latency,
write amplification and tick cost. Keep #518 Draft and unmerged.

## 7 November 2026 — bounded G6J1 group-durability increment

The experimental `Journal.append_batch(edits, expected_generation)` accepts
**1–64** pre-staged, same-tick, consecutive-generation mutations. It validates
the *entire* batch before modifying disk, retains the exact existing 48-byte
EDIT record format, writes one contiguous bounded payload, and performs
**one file fsync before allowing one group ACK**. The original `append` is
a one-element batch and retains its existing interface. Individual edits
within a batch must **not** be acknowledged separately before the barrier.

A write/fsync/postwrite failure returns no group ACK. Complete but unacknowledged
frames may remain visible in the OS cache. This is **not atomic rollback**:
the external native owner must retire the old handle and reconcile the
authoritative state before attempting continuation. Multiwriter coordination,
dynamic native simulation ticks, power-loss guarantees and Windows directory
durability remain unsupported.

Executable unit regressions check one fsync for five records versus five
fsyncs for five independent append calls, exact on-disk byte identity,
late-batch invalid edit/tick/generation refusal without partial publication,
injected fsync failure with no ACK, and hard-exited child group recovery in
a fresh process. The pinned native CYPS pilot now also group-commits its five
source-matched pre-staged edit receipts, retaining all original real-native
replay, Water/temperature/Empty and damaged-sixth-record controls.

**Measured scope:** this removes four of five file fsync calls *inside the
isolated journal writer* on the five-record fixture. It does **not** yet
reduce native owner ACK latency or tick cost: #486 continues to produce
full-checkpoint ACKs independently, and the journal remains outside that
live owner. No production adoption or general 30 Hz state durability claim.
