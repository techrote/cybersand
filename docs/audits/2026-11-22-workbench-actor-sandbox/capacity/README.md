---
title: WB-ACTOR-COMPOSE-002R local capacity qualification
status: Current
document-kind: evidence
scope: Dated Linux headless capacity and native registration evidence at the recorded local source snapshots
canonical-for: []
last-reviewed: 2026-11-22
related-documents: [../../../systems/workbench-actor-composition.md, ../../../operations/workbench-actor-composition.md]
---

# Workbench actor capacity: executed local qualification

**All 13 real Workbench cases passed: 4,742 checks, zero failures.** This includes
16/32/64 actors in each of three workload families, 128/256 barrels, and
128 mixed and articulated actors. These are actual Rapier bodies and native
registrations. Mixed/articulated runs also issued a high-slot Runner equipment
command through an actual external-policy observation/lease and received the
native equipment owner's successful execution receipt. Other independently
scheduled actors continued operating.

This is local Linux headless evidence at source
`8e9a35fe5ee434307a3b9c1f131389cde3693090`, descended from accepted main
`662df51cd8409a52332fa7ef15d06d8ab8945aed`. It is not packaged Windows performance
or owner NVIDIA acceptance, and it does not independently qualify later UI edits.
The source-matched hosted Windows candidate must retain its own final-source
execution and package provenance.

## Workloads and observed performance

All fixtures used an ordinary 1,024 × 1,024 Shared Workbench, its real prepared
native owner, worker, Rapier session and Play/Pause path. A broad floor and a
small granular strip left room between assemblies. Each case replaced the
previous world, checked all retired body objects, refused an insufficient budget
without changing the accepted world, and completed 30 native and 30 Rapier ticks.

The barrel workload uses one-body passive barrels. Mixed repeats Midge, Runner,
Crawler, Skimmer, Stuntbuggy, barrel, 4LY Trainer and Monowheel. Articulated repeats
Stuntbuggy, Ripper, Crawler, Winchbug, Runner, Tiltrotor, Monowheel and Inchworm.
Mixed populations include a human source, independently scheduled scripted and
policy actors, and one explicit external equipment producer. The articulated
population uses independently scheduled sources plus the equipment producer.
All equipped actors are registered with the actual equipment worker; non-equipped
flyers/barrels are correctly absent from that equipment-specific roster.

| Family | Actors | Bodies / proxies | Physical joints | Native / Rapier ticks | 30-tick wall time (s) | Mean wall frame (ms) | Max gap (ms) | Prepare (s) | RSS (MiB) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| barrels | 16 | 16 / 16 | 0 | 30 / 30 | 1.195 | 6.87 | 18.2 | 1.940 | 592.1 |
| barrels | 32 | 32 / 32 | 0 | 30 / 30 | 1.614 | 7.57 | 83.7 | 1.485 | 592.4 |
| barrels | 64 | 64 / 64 | 0 | 30 / 30 | 1.642 | 7.48 | 69.3 | 1.708 | 600.6 |
| mixed | 16 | 56 / 56 | 48 | 30 / 30 | 1.660 | 7.81 | 68.1 | 1.516 | 601.0 |
| mixed | 32 | 112 / 112 | 96 | 30 / 30 | 2.079 | 9.67 | 62.8 | 1.646 | 601.3 |
| mixed | 64 | 224 / 224 | 192 | 30 / 30 | 3.485 | 18.62 | 142.6 | 1.914 | 601.8 |
| articulated | 16 | 80 / 80 | 80 | 30 / 30 | 2.225 | 11.42 | 176.1 | 2.194 | 601.9 |
| articulated | 32 | 160 / 160 | 160 | 30 / 30 | 2.752 | 12.85 | 90.0 | 1.804 | 602.3 |
| articulated | 64 | 320 / 320 | 320 | 30 / 30 | 4.577 | 21.98 | 249.9 | 2.418 | 602.6 |
| barrels | 128 | 128 / 128 | 0 | 30 / 30 | 2.242 | 10.12 | 93.4 | 1.676 | 602.8 |
| barrels | 256 | 256 / 256 | 0 | 30 / 30 | 3.778 | 19.55 | 247.8 | 2.160 | 602.8 |
| mixed | 128 | 448 / 448 | 384 | 30 / 30 | 6.592 | 100.15 | 478.1 | 2.720 | 603.5 |
| articulated | 128 | 640 / 640 | 640 | 30 / 30 | 9.166 | 112.89 | 773.6 | 3.628 | 610.2 |

The mean wall-frame column comes from measured process-frame intervals. The JSON
also retains the application's `frame_time_ms`, which clamps long deltas and
therefore must not be used to hide severe stalls. Native/Rapier tick progression
and elapsed wall time are reported separately: 60 Hz simulation steps do not
imply 60 steps per wall-clock second on this host. High actor counts were allowed
to run slowly; no actors, NPC decisions, equipment or joints were dropped to
recover performance.

Preparation includes the real asynchronous owner transaction and its scheduling,
not a pure body-allocation microbenchmark. The same process ran cases in sequence;
RSS therefore includes retained allocators and caches and is not per-case isolated
memory. Process peak RSS from `getrusage` was 639,418,368 bytes. The native adapter
reported a 4,744,376-byte bounded Workbench response workspace and 1,081,608 bytes
of body-state/observation storage. Full finite-canvas occupancy storage and live
Godot/Rapier objects are additional; these metrics are not total native memory.

The JSON contains actual controller decision costs, accepted commands, preparation
latency, Godot allocator use, RSS, upload timing and equipment roster/progression.
At 64 actors, mixed decision work totaled 19,080 microseconds and articulated
25,539 microseconds over the sample. These are controller-local counters, not
complete physics cost. Headless upload measurements do not predict desktop GPU
publication stalls. These whole-Workbench measurements do not isolate the
separately owned PUBPRES renderer path from actor overhead.

## Resource contracts and safety evidence

The ordinary authored defaults remain 8 logical actors, 64 response bodies and
64 native proxies. Setup-v2's optional version-1 `sandbox_capacity` supplies
independent numeric limits, each 1–4,096. Admission charges actual prepared
parts/proxies, including permanent equipment, while preserving the existing
per-actor eight-part topology bound. A barrel costs one body and one proxy.
A compound hull can require multiple proxies for one response owner. Physical
joint counts are actual constraints: a rotary link creates one, a slide two,
and a spring three. Authored link count is separately available in the catalogue.

4,096 is the present bounded native identity/workspace ceiling, safely represented
by retained uint16 IDs and copied numeric records. No FPS-derived actor ceiling
is added. The aggregate response workspace is owned on the heap, including its
pending sample; large transient sample objects are not copied onto the Windows
thread stack. Controller/equipment arrays size from the admitted roster or its
bounded identity span. Physical equipment aggregate work/storage quotas scale
with that span while preserving existing per-actor resource rules. Existing
sampled equipment and classic physical-lab defaults stay at eight.

The standalone real-native fixture ran 16/32/64/128/256/512/4,096 registered
identities at one and four native workers. All 14 cases completed native ticks,
kept contact responses distinct, preserved authoritative material hashes, refused
invalid IDs, retired masks and reused the highest slot. The identical fixture
also passed AddressSanitizer + UndefinedBehaviorSanitizer without reports.
Local LeakSanitizer cannot operate under this host's ptrace environment: the
default Makefile invocation reached its exit-time LSAN infrastructure error,
which is retained. An explicit `ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1`
rerun passed all 14 cases. No local leak-sanitizer success is claimed.
**4,096 native registrations are not 4,096 actual Rapier actors.** The largest
real logical-actor fixture here is 256 barrels; the largest physical topology is
128 articulated actors with 640 bodies/proxies/joints. Values beyond those remain
unqualified experiments. The 4,096 engineering bound does not promise that every
model mixture or serialized document fits other retained finite constraints.

The native equipment suite passed 272 checks across all 32 catalogue items and
expanded owner identities 0/63/64/127/255/4,095. It used real native masks, body IDs
through 4,096, independent projectile launches, effect writes, replay fences and
resource continuity. An active same-epoch roster expansion refuses without
resetting existing payloads. The ACT-004 native and fallback protocol fixtures
also passed their 64-body receipt/occupancy/retirement and malformed-record tests
against the enlarged protocol ceiling.

Additional focused regressions completed after the matrix: physical equipment
admission **35 checks / zero failures**, effect queue admission **32 / zero**,
classic physical arena **915 / zero**, physical effect cancellation **passed**,
and Workbench equipment extent **passed**. The admission tests now exercise the
actual expanded boundary (4,096 plus an invalid 4,097th request), while retained
eight-actor fixtures continue to cover ordinary behavior. The original tests
that expected an unconditional nine-request refusal are retained as corrected
test-contract failures, not presented as successful runs. See the corresponding
`*-final.log` and `updated-*-test-failure.log` files in the separately retained development evidence bundle.

## Repaired failures and evidence limits

The first real Workbench run found two worker generation arrays still initialized
to eight entries while their iteration bound had expanded. The out-of-bounds
write could retain the worker mutex and prevent startup. Both arrays now allocate
the complete bounded identity range before use (64 KiB together); all subsequent
matrix worlds started and retired successfully. The original failing log is kept.

A follow-up equipment audit found that an empty worker could reset at the new
epoch before receiving the first high-count equipment frame. That first frame
was incorrectly refused as live roster growth. The repair allows an empty owner
to allocate once from its first valid frame; later same-epoch growth remains
refused. The real-native failing regression and passing 272-check result are
both retained. A test-development assertion also initially counted unequipped
actors as equipment owners; the final assertion uses the real prepared equipment
roster and independently verifies native receipt execution. Its failure log is
explicitly a corrected test-accounting issue.

These are finite progression tests, not long-running soak results. They check
finite body transforms/velocities, live RIDs, matching native owner/proxy counts,
unique IDs, actual joints, worker health, replacement teardown and refusal
atomicity. They do not prove arbitrary-hour stability, every collision pattern,
large-population owner playfeel or Windows driver behavior. Authored JSON roundtrip
and strict budget validation are exercised; fresh-process package persistence
belongs to the final integrated qualification.

## Reproduction and provenance

From a source-matched checkout with the supported Godot 4.7 and patched native and
Rapier extensions materialized:

```sh
make test-workbench-actor-capacity
make test-workbench-actor-capacity-sanitize
# Only on this ptrace-restricted host: repeat with ASAN_OPTIONS=detect_leaks=0.
CYBERSAND_ACTOR_CAPACITY_REPORT=/tmp/workbench-capacity.json \
  "$GODOT" --headless --path godot \
  --script res://tests/test_workbench_actor_capacity.gd
"$GODOT" --headless --path godot \
  --script res://tests/test_physical_usables_runtime.gd
"$GODOT" --headless --path godot \
  --script res://tests/test_act004_body_capacity.gd
```

Append `-- --family mixed --count 64` to run a focused real-Workbench row. The
helper substitutes only the OS-focus predicate unavailable in headless mode;
it does not mock bodies, native masks, controller decisions or equipment owners.

The local native extension was rebuilt from this candidate's native source using
pinned godot-cpp revision `101ae38034304346a46ea9ea84ae156d3e860496`, with explicit
local GCC 14.2/binutils 2.44 toolchain drift enabled. It is not described as the
release compiler build. Its SHA-256 is
`7a8bf38fcfdfa92a770a67879477a708cfceb6c606b03c3c0a5fd55b5a028a4a`.
The runtime was official Godot 4.7 (`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`) and
the repository's patched Rapier 0.35.2 build. Complete hashes, native source ledger,
source commits, compiler identity and evidence hashes are in
[provenance.json](provenance.json). Raw results are
[workbench-matrix.json](workbench-matrix.json),
[native-sanitized-matrix.jsonl](native-sanitized-matrix.jsonl),
and the original logs named in `provenance.json`, retained in the development evidence bundle. Logs are not committed as source artifacts.
