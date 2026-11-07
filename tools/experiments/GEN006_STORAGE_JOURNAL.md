# GEN-006 G6J1 — experimental append-only mutation journal

**Scope:** isolated, opt-in storage primitive for GEN-006 #194 (https://github.com/techrote/cybersand/issues/194), **not integrated** with the active PR #486 native controller or the separate shared-World residency engine. Keep this PR Draft and unmerged. No native physics, production storage, World ABI or default runtime is changed.

This is a bounded Python prototype for durable edit logging, not a completed native optimization. It accepts an opaque real CYPS checkpoint (maximum 2 MiB) and up to 4,096 fixed-size mutation records (48 bytes each). The header carries signed native chunk coordinates, a nonzero residency incarnation, starting mutation generation, fixed native tick and physical hash. Each append validates the next generation, fixed tick, coordinates, edit kind, monotonic chain and CRC, then synchronously flushes/fsyncs the appended record. **Only after a successful append may the native caller issue its durable edit ACK.** The initial checkpoint uses same-directory no-clobber hard-link publication and POSIX parent-directory fsync.

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

The pilot generates a real signed chunk, saves the genuine CYPS checkpoint,
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
