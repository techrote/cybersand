# Isolated eight-map correctness apparatus — implemented, unexecuted

Contract: [reviewed plan](../../../docs/research/mat003-correctness-only-plan.md)
at `1bbbec9580f9a3e9e6a6f9136503f873ede0f254`, canonical LF SHA-256
`f134267c2304cc03974605595089cced53f03a09918e097681ae3f6bf11c0b23`.
The [source-review closure](../../../docs/audits/2026-10-23-mat003-apparatus-source-closure.md)
supersedes the earlier partial implementation disposition without rewriting it.
Production has no include/build route into this directory. No new workflow is
installed. R16 is opaque neutral storage; R16-T1 is conditional and unimplemented.

**Source implementation is complete for review. It has not been compiled,
imported for qualification, run or admitted for qualification execution.** Source
review establishes no platform feasibility, sanitizer success or runtime
correctness. There is no tick-timing apparatus or production adoption here.

## Exact maps and independent checks

All arms retain material0–15/state_a16–31/state_b32–39. E8 uses epoch56–63 and
R40–55. Expanded E16 uses epoch40–55 and R56–71. K64-E16 uses epoch48–63,
raw-unused40–47 and refuses every nonzero R request. Schema-valid publications
set unused bits to zero; separately labelled raw probes exercise them nonzero.

| Arms | Storage | Intended size / alignment / stride |
|---|---|---|
| K64-E8 / K64-E16 | uint64 word | 8 / 8 / 8 bytes |
| K72-E8 / K72-E16 | compact bytes, memcpy head and byte tail | 9 / 1 / 9 bytes |
| K80-E8 / K80-E16 | compact bytes, memcpy head and byte tail | 10 / 1 / 10 bytes |
| D128-E8 / D128-E16 | two uint64 lanes; high at byte8 | 16 / 8 / 16 bytes |

`maps.hpp` supplies full/partial checked writes and epoch-only clear. Compact
memcpy is endian-qualified with a bytewise fallback; there is no unaligned typed
pointer. Static assertions and future endpoint readback both enforce ABI.
`oracle.py` independently enumerates explicit positions. `storage_oracle.py`
replays65536 operations/1024 slots without importing the C++ schedule or packer,
checking every pre/post byte, refusal, ordered field pair, boundary and accepted
one-hot, plus meaningful copy/swap/replacement/clear/unused-bit transport.
`world_oracle.py` decodes full bytes and models R/U transport from source-bound
copy/construction and masked partial-write receipts. Future retained fixtures
cross-check its mathematical decoder against the bit oracle for every physical
one-hot, zero and all-ones record.

Generated-source reproduction in `provenance.py` is an integrity check using the
shared generator, not an independent semantic oracle. Independent logical
encoding/decoding, transition checks, exact endpoints and common-control joins
provide the separate semantic checks. Collector success cannot substitute them.

## World coverage and source owner inventory

`overlay.py` checks frozen S1 inputs and creates generated World-only copies;
accepted source is not edited. `world.cpp`, `probe.inc`, `lifecycle.hpp` and the
adapter exercise actual World ticks and the real clear path. Fixtures include
nonzero R/U, high/nonzero Empty state, temperature extremes, Water/Sand ledgers,
whole move/swap, partial transfer/drain/conversion and declared replacement.

| Source owners | Retained proof and applicability |
|---|---|
| `chunks_`, cells, optional `temperatures` | Sorted owner/address/stride registry; every carrier byte plus signed16 temperature; ambient value and presence flag when absent. |
| Chunk activity/dirty bounds/all16 blocks | Nonempty counts, quiet state, next-interaction deadlines and complete activity metadata. |
| `config_`, rule flags, interaction/Water/transport/physics policies | All scalar and array metadata checked against scoped Current configuration. |
| Attempted/completed clocks, epoch, failed/in-progress flags | Exact clocks/current-stamp predicates, real clear count/resident traversal count. |
| Interest, selected/applied core regions, pending explosions | Complete bounded metadata including every pending event. |
| `physics_totals_`, stats, support | Every nonzero ledger entry, used/overflow, visits/phase/allocation counts and support predicates. |
| Active chunk/core scratch, `parallel_` | Sizes/capacities, result/physics vector geometry, phase indices and pool presence. Healthy quiescent endpoints have no pending dispatch. Current World rebuilds/clears lists and resets selected result slots before reuse; values beyond live counts are not continuation authority. Failed scratch cannot resume; quarantine/recovery is checked separately. |
| `settled_discovery_` | Required absent by config and assertion; discovery/connectivity are outside this contract. |
| `transient_obstacles_` | Required present with empty region/body/occupied arrays and all65 contact/impulse slots zero. Null is not its Current default. |

Each full endpoint has one `cells.bin`, `chunks.txt` and `metadata.txt`, with no
duplicate normalized S1 cell stream. Common projections are derived from the
complete independently decoded records and do not replace R/U/owner checks.
Every refusal has metadata-only before/after receipts plus target bytes; all
relevant clocks, activity, ledgers, capacities, sidecar identity and temperatures
must be unchanged. Full before/after endpoints check every unrelated cell too.
The failed-tick fixture induces a real capacity exception, checks quarantine and
then clear/recovery; no synthetic failure flag is set.

Each natural E16 process contains **two sequential65,540-tick roles** under its
single600s process budget. Ordinary reaches natural clear65536; prepared reaches
the same prestate65535, rebases through128 back to65535, then clears and advances4
ticks. Exact B/Q/R joins to natural and B/P predicate/owner checks constrain the
method. Resident processes have sequential event/reference roles:255 setup
 ticks, prepared P, real Q, then4 full-interest reentry ticks R. Exactly eight
large full endpoints B/P/Q/R per process are retained.

## Bounds and staged authority

The matrix is152 processes/platform:16 storage,48 small World,8 natural E16,
64 resident and16 refusal/lifecycle, plus32 builds. Linux+Windows is304 processes,
with each full platform independently checked; no partial matrix is complete.
Resident sides512/2048 and serial1/phased1/4 apply only as specified in `matrix.py`.
There is no4096² case. Compilation has180s/command; storage/small/refusal300s;
natural/resident600s; concurrency1. Build+candidate+independent-reader active wall
is capped at6h/platform; external admission waiting time is excluded. Candidate
normal/sanitized RSS limits are2/3GiB, reader RSS2GiB. Native OS peak receipts
supplement sampled process-family RSS. Windows additionally uses a suspended
child Job Object with kill-on-close and a commit-memory ceiling at the same
numeric limit. This stricter/different guard is not an RSS measurement. Its exact
sanitizer/toolchain compatibility requires preflight; Linux uses a process group.
No platform support is claimed from source paths alone.

Output is capped at32GiB/platform,64GiB combined; conservative full cell-stream
planning is47.75GiB combined. Canonical bytes use at most18bytes/cell including
temperature; metadata is separately bounded and tick receipts allow1024bytes/tick.
Fixed transition buffers fail on overflow. Timeouts, diagnostics, missing roles,
resource breaches and reader failures are retained and prevent completion.
No retries or outlier removal exist. Watchdog durations are resource accounting,
not World tick measurements.

`collect.py` requires separate explicit stages:

1. External build authority binds source commit/tree/all input hashes, platform,
   compiler/linker/flags, pinned psutil7.0.0, sanitizer environment and independently
   qualified linker resolution/toolchain input proof. `build` snapshots/seals
   inputs and freezes generated sources before32 compilations; checkpoint status
   is `built-execution-held`. It launches no candidate cases.
2. External independent binary admission binds `built.json`, every generated and
   binary seal and its review reference. A separate exact execution authority
   binds admission/build authority. `execute` checks the immutable build inventory
   before creating an exclusive attempt marker and starting the fixed152 cases.
3. Independent readback requires the external execution-authority SHA-256. Wall
   guards precede inventory hashing/provenance; monitor identity precedes RSS
   use. Hashing checks guards per1MiB chunk and generated comparisons per file.
   Retained negative fixtures precede semantic readback. A new verification output
   directory outside evidence retains fixture/disposition hashes. Full file,
   command, source, binary, role and logical checks must pass before `verified`.

Future CLI interfaces are `collect.py --stage build|execute --authority ...
--authorized-authority-sha256 ... --output ...` (`execute` also requires
`--binary-admission ...`) and `readback.py --evidence ... --authority-sha256 ...
--verification-output ...`. These are interface descriptions, not dispatch
instructions or permission. No authority or admitted binaries are supplied.
Stop before build/qualification execution or timing until separately authorized.
