# Native derived-Empty alternative — 24 November 2026

Status: **unselected candidate; local native correctness passed; native timing
screen refused a registered-worker mismatch and retained adverse controls;
ordinary hosted performance/final qualification pending; Draft/HOLD**.
This is a separate architectural arm against the already measured sparse
occupied-mask bounds source. It preserves the earlier unfavorable zero/eight-body
and Wave512 tail observations. No publication, terrain admission or Rapier
completion credit changes.

## Causal hypothesis

The previous occupied-bounds repair removes most cell-level obstacle lookups,
but the current gameplay Wave2048 one-body screen still spends roughly 61 ms of
roughly 82 ms in the column stage. A full-canvas allocated mask region deliberately
prevents the existing clean/dry optimization even in distant empty halves.
Changing that original classification would change retained solver metadata
and potentially paused-face behavior. The new arm instead retains a separate,
redundant storage certificate, leaving all original classifications untouched.

This can remove repeated strided reads and zero writes for air. It still runs
the entire vertical settle/refill, support/head and depth calculations, because
Water can enter a column segment from above and the refill law has nonlocal
dependencies. It is neither a broad active-region omission nor permission to
step Rapier against old terrain.

## Predicate, lifetime and proof

`WaveChunk::empty_derived[half]` means every actual stored material in the half
is `Empty`, every retained `weight` is zero and every retained `meta` byte is
zero. Empty cell auxiliary/epoch bytes are unrestricted and unchanged. Retained
flux, including a paused boundary face, is unrestricted. The cache initializes
false, is neither serialized nor hashed, and only replaces loads/stores of
values fully determined by already hashed storage.

| Boundary | Required behavior |
|---|---|
| Reuse | The entire half is selected and the actual occupied-mask bounding rectangle does not intersect it. The original allocated region still controls dry/clean behavior. |
| Gather | Fill the segment's scratch mass and flags with zero. Do not skip settling, head or depth reconstruction. |
| Scatter | Preserve the original post-column `any`/`wet`, dry marking and flux retirement. Omit only redundant cell/head/meta scatter when a valid certificate existed and every resulting mass code is zero. |
| Inflow or solid/body code | Any positive or negative mass code clears local reuse and the retained certificate before normal scatter. |
| Certification | Assign true only after the complete selected half's original `empty[c]` predicate remains true. The zero-mass head branch explicitly overwrites both scratch weight and flags with zero. |
| Old dry-column shortcut | An old `dry==2` column retains zero storage from its earlier complete scatter. A partial selected half is revoked before this shortcut can continue. |
| External/material writes | `wake_wave_chunk` revokes both halves. Owner cell edits, relocations and transferred writes use dirty/wake helpers; worker effects merge before the next Wave pass. |
| Wave writes | Positive `wave_write_mass` revokes the destination half. Removing the final Water cannot create a certificate until a later complete column pass clears its derived head/meta. |
| Region and large-group fallback | Any partial half or task index at/above the existing 64-entry cache bound is explicitly revoked; the original generic path remains available. |
| Reset/reopen | New chunks start uncertified. Ordinary authored reconstruction creates a new World; unsupported exact Wave physical save/restore remains unsupported. |
| Flux and history | Original dry/clean state, boundary retirement, `prior_flux` copying, flux and apply passes are unchanged. No cache predicate assumes zero flux. |

The performance specialist independently followed owner mutation, phased worker
effects, ballistic deposition and floating-Oil paths. Wave runs at tick entry;
phased worker effects merge after each pool dispatch and before finish, so a
prior tick's writes invalidate before the next Wave. Ballistic deposits occur
immediately before Wave through dirty helpers. Floating Oil runs after Wave
through the same move/transfer paths. No mutation bypass was found. Independent
review of the actual diff found no source blocker, including partial selection,
negative body codes, first-inflow revocation and the long-group fallback.

## Adversarial validation apparatus

`CYBERSAND_WAVE_VERIFY_EMPTY_DERIVED` scans actual stored cells, weight and meta
before every reuse and immediately after certification, terminating on any
contradiction even under `NDEBUG`. It deliberately does not constrain flux or
Empty-cell auxiliary bytes. The flag is enabled in the dedicated lifecycle and
sanitizer targets and absent from ordinary performance builds.

`native/tests/test_wave_empty_derived.cpp` emits every-tick complete physical,
state and content hashes plus Water, parcels, body contacts and impulses. The
same fixture is compiled independently against the frozen occupied-bounds
source and this candidate, with one and four workers. It challenges generic
Sand/Oil/solid/reactive writes into previously empty halves, negative-coordinate
chunk seams, newly introduced and cleared bodies, partial X and Y selection,
cross-chunk/lateral Water arrival, formerly wet erasure, explicit relocation,
authored new-World reconstruction, retained paused boundary flux and a 70-chunk
vertical group crossing the 64-entry optimization boundary. Existing complete
Wave, spill and body-boundary tests remain additional gates.

`native/bench/pubpres_empty_derived.cpp` preserves the earlier native benchmark's
scene, trajectories, actual tick boundary, conservation checks and semantic
checkpoints. It additionally retains every per-tick duration and each tick's
prepare/column/flux/apply durations, before sorting any aggregate. Raw clocks
allow independent reconstruction of every reported percentile and preserve
adverse ticks. Both source arms use the exact same benchmark overlay and
compiler configuration. Native phase timing remains a diagnostic screen;
ordinary Workbench/Rapier, graphical, input and physical Windows/NVIDIA gates
must be qualified separately before any playability conclusion.

## Source-exact local correctness result

The [complete receipt](native-empty-derived-correctness.json) retains the exact
native source-input hashes, issued compile commands, compiler/binary hashes,
actual lifecycle stdout/stderr, complete suite output and unsuccessful build
attempts. The occupied-bounds control is native source at
`27a08efb` with the identical new lifecycle fixture overlaid. Both independent
builds execute 153 ticks at one and four workers. Every physical/state/content
hash, Water/parcel value and contact/impulse observation matches at each tick;
the same-worker entire stdout is byte-identical. The
[independent performance-lane review](native-empty-derived-independent-lifecycle.json)
recomputed this agreement from the actual binaries and original logs, including
eight contact-bearing checkpoints and 52 ballistic-bearing checkpoints.

With `CYBERSAND_WAVE_VERIFY_EMPTY_DERIVED` active, complete Wave 34/34 and spill 47/47
tests pass. The complete body-boundary matrix passes 50 runs/6,000 ticks at one,
two, four and six workers, both seeds, all three modes and one/three substeps;
its original semantic checkpoints remain exact. These tests use local GCC 14.2
and a serial `-O1` diagnostic build after two parallel compilers were killed and
a later build encountered ENOSPC. Those failures remain recorded. The
successful result does not turn the failed attempts into successful builds,
claim a pinned hosted toolchain or supply a leak-sanitizer result.

The new clock-reader tests independently reconstruct each reported aggregate
from 72 original tick/phase samples and reject 11 malformed/forged clock or
checkpoint variants. The compiler flag's expensive invariant scans are absent
from both timed native arms, while the exact same benchmark source and compiler
flags remain fixed across them.

## Retained native timing screen and refusal

The [original raw receipts](native-empty-derived-abba-receipts.json) contain all
24 fresh processes, the exact issued runner source, source-input/benchmark and
compiler hashes, independent binary identities, original stdout/stderr, UTC
boundaries and every per-tick/phase clock. The quiet interval was
17:28:55–17:31:40 UTC. Root and both other specialists were asked to suspend
local heavy execution; external host activity was not observed. The measured
control is `27a08efb4a78186c0e2b19176576752e2503b998`, tree
`24a69fea61a7f5ef02f533280a07a3c8f3e67741`; the candidate is
`fa34fc2129125d77a5255c95bfa82af91eff05a5`, tree
`bf7603054b69023a87d5c14902358c3d4d8c0478`. Both use the same local GCC 14.2
`-O3 -DNDEBUG -pthread` flags and benchmark SHA-256
`0ee16b0592fd2be58543020c258dab23801e4b89318469bf0e94b1b393a6a2f8`.

The strict reducer **refuses the campaign**: `current512-one-4-A` reports only
three observed workers, while the registration requires four. No gate was
relaxed. The [descriptive screen](native-empty-derived-screen.json) separately
reconstructs every raw aggregate and checks complete semantic, Water and parcel
parity for all six cohorts. Its descriptive values are not a replacement
qualification. Storage bytes are equal across all four runs in every cohort.

Each cell below is **mean / p95 / maximum native tick milliseconds**, in actual
A/B/B/A execution order. A is the occupied-bounds control; B adds the Empty
derived-state cache. Every run has 72 ticks, making nearest-rank p99 equal to
its maximum. The original clocks permit independent reconstruction.

| Workload | First A | First B | Second B | Final A | Descriptive mean change |
|---|---|---|---|---|---|
| Current512, one body | 13.360 / 20.860 / 22.326 | 15.761 / 26.399 / 41.244 | 13.288 / 24.849 / 39.147 | 12.684 / 21.881 / 27.866 **(three workers)** | +11.53% |
| Current1024, one body | 45.476 / 56.876 / 92.532 | 38.289 / 56.904 / 74.487 | 40.394 / 86.318 / 104.002 | 45.568 / 62.429 / 95.990 | −13.58% |
| Current2048, one body | 208.767 / 283.881 / 477.296 | 123.397 / 195.088 / 268.848 | 123.655 / 200.792 / 330.707 | 143.255 / 210.707 / 334.713 | −29.82% |
| Historical512, one body | 3.364 / 5.702 / 8.928 | 3.435 / 5.646 / 12.405 | 2.903 / 4.244 / 5.332 | 3.415 / 5.325 / 14.183 | −6.52% |
| Current2048, no body | 98.872 / 143.063 / 209.409 | 131.666 / 182.667 / 233.180 | 142.732 / 264.250 / 357.036 | 125.321 / 277.539 / 531.516 | +22.39% |
| Current2048, eight bodies | 164.987 / 264.913 / 411.401 | 114.547 / 155.627 / 176.342 | 83.396 / 142.750 / 210.872 | 129.315 / 219.837 / 481.936 | −32.74% |

The large one/eight-body means improve in these observations, while Wave512
and the no-body control are adverse. Control spread and non-column phase
variation are substantial. For example, the large one-body controls change
from 208.767 to 143.255 ms and their unchanged flux phases from 47.163 to 29.140 ms.
It would be unjustified to attribute that host/cohort variation to source or
to choose the candidate from the favorable large runs. The current design
also introduces cache bookkeeping in no-mask paths where original clean/dry
logic can already avoid zero storage; its applicability and new half-flag
stores deserve investigation. That hypothesis is not a measured diagnosis.

The candidate remains explicitly **unselected**. Root may include its exact
source in the next ordinary hosted comparison while retaining this refusal
and every negative control. A mathematically reviewed zero-carry settle shortcut,
if implemented, must be a separate arm with its own full parity and measurements.
No full screen is repeated merely to erase unfavorable or invalid evidence.
