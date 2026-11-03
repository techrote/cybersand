---
title: LCB-FEEL #360 four-family 32-row admission preflight
status: Current
document-kind: evidence
scope: Source-pinned local Windows and WSL2 Linux native-only admission of four Water liquid families at configured workers 1/4 on two registered scenarios for 30 ticks, with negative controls and strict independent reduction; no Rapier, rendering, human or GitHub-hosted execution claim
canonical-for: []
last-reviewed: 2026-11-03
related-documents: [../architecture/liquid-solver-family-policy.md, ../architecture/inertial-cellular-v1.md, ../architecture/pressure-flow-v1.md, ../architecture/liquid-prepared-setup-and-receipts.md, ../architecture/simulation-tick-and-threading.md, 2026-10-23-lcb003-scenario-qualification.md, 2026-10-31-play-life011-composed-solver-matrix.md]
---

# LCB-FEEL #360 admission preflight — 3 November 2026

## Result

**ADMITTED.** All **32 registered primary rows** (2 scenarios × 4 Water families
× configured workers 1/4 × Windows/Linux) completed 30 native ticks and passed
every registered invariant. The 24 supplemental lane-B rows and both
negative-control packets also passed. No stop condition fired; nothing was
retried, relaxed, dropped or reclassified.

This admits the bounded seven-scenario expansion. It is **not** a benchmark,
a Rapier/desktop-host result, a GitHub-hosted CI result, a feel assessment or
a preferred-solver decision.

## Source and runtime authority

| Input | Identity |
|---|---|
| Accepted main (rechecked 2026-11-03) | `070c7a22ad51ea9206931cd9d56fd1e7cfe212aa` (#334 merged); #359 handover consumed from draft #367 head `5bcb4b90` without assuming it landed |
| Executed source | `95e72985c334874a131fa4e5c60195f9ce517c96`, tree `3effd927aeea8835ea9913af8ff801b3c10885f6`, branch `claude/lcb360-feel`; clean apart from Godot-regenerated `.uid`/`.import` files |
| Registration | [`lcb.feel.preflight.v1.json`](../../godot/tests/fixtures/lcb/feel/lcb.feel.preflight.v1.json), SHA-256 `0dfcd81b2b1dd76226668a3c1eecef78d148b65fcd9290053f80bc9acde3344b`, committed in `2f50d059` before any qualifying run |
| Windows native | `cybersand_native.windows.x86_64.dll` SHA-256 `ee09f7ab485f817b5f58e767ddb26f2e430439bb3dd4f185019eda028f47199a` |
| Linux native | `libcybersand_native.linux.x86_64.so` SHA-256 `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45` |
| Runtime binding | Both equal their committed provenance (build `a7ee10f2`, run [41301725876](https://github.com/techrote/cybersand/actions/runs/41301725876)); all 646 recorded native source inputs equal the executed tree. **No native, adapter, policy, default or fixture byte changed.** |
| Rapier | Windows `b54e54bd1a03ae90…`, Linux `566e68ae53bfb2eb…` (committed LFS objects) |
| Godot | `4.7.stable.official.5b4e0cb0f`; Windows `Godot_v4.7-stable_win64.exe` SHA-256 `b2ca888d…`; Linux executable `f85bbc6b…` from the CI-pinned archive `0b1a6c54…` |
| Machine | One AMD Ryzen 5 5600X (6C/12T), 32 GB. Windows 11 Pro 10.0.26300. Linux is WSL2 Ubuntu 24.04, kernel `6.18.54.1-microsoft-standard-WSL2`, on the **same** hardware |

Linux ran in a fresh pointer-only clone of the executed commit with the two
committed LFS objects copied in; the driver accepts a status-dirty runtime only
when its bytes equal the committed pointer's object.

## Registered design

The registration preceded execution. It reuses unchanged LCB-003 fixtures and
gives each comparison arm a new identity; original fixture IDs, bytes and
goldens are untouched.

| Scenario | Fixture (Git blob / definition hash) | Initial Water | Expected edit |
|---|---|---:|---|
| `lcb.feel.dam-release.d96.v1` | `lcb.dam.water.freemass.depth-96.v1` (`e189f876…` / `d1f70132…`) | 4,700,160 | Tick-0 gate erase: Wall −1,536 |
| `lcb.feel.quiet-pool.v1` | `lcb.rest.deep-quiet-pool.v1` (`4d49876b…` / `08d7ad7b…`) | 38,515,200 | None |

- **Lane A (primary, matched):** FreeMass, CellularYield, PressureFlow and
  InertialCellular, all `reference`, explicit radius 3.
- **Lane B (supplemental, preferred):** FM/CY/PF at native radius 2. IN's
  preferred geometry is its lane-A row, not re-executed. Lane timings are not pooled.
- Every arm uses explicit `water-normalize-v1`; the fixtures are whole-cell,
  so the registered and observed deltas are zero (18,432 cells unchanged).
- Each arm is a separate process: `diagnostic_reset({workers})`, then the
  ordinary controlled prepared-liquid route (`CyberMicroScenarioHost.install`
  with policy, normalization and radius), 30 `advance()` calls, census and
  owner release.

## Commands

```bash
python tools/lcb/feel_preflight.py run --godot C:/tools/Godot/Godot_v4.7-stable_win64.exe --output OUT/windows
python3 tools/lcb/feel_preflight.py run --godot ~/…/Godot_v4.7-stable_linux.x86_64 --output OUT/linux
python tools/lcb/feel_preflight.py reduce --logs-external --packet docs/audits/lcb360-preflight-2026-11-03/windows --packet docs/audits/lcb360-preflight-2026-11-03/linux --output docs/audits/lcb360-preflight-2026-11-03/summary.json
```

Each process used the shared `ordinary_case_seconds` watchdog (1,200 s); the
slowest took 4.7 s. Windows ran 22:33:27–22:34:39Z and Linux 22:35:01–22:36:20Z.
The [committed packet](lcb360-preflight-2026-11-03/) holds both `packet.json`
manifests, all 58 raw receipts and the reduced `summary.json`. Committed
LF-blob SHA-256: Windows packet `edf179e9…47f1e9` (produced with CRLF as
`0f2bdb17…12eaa3`; the driver now writes LF on every host), Linux packet
`1176818f…49f429b`, summary `aebbc0b2…4daec1`. Receipt hashes are unaffected
because Godot wrote them with LF. Process logs are kept outside
Git under the repository log policy. Their SHA-256 values are in the manifests.

## Correctness

Every primary and supplemental row satisfied:

- The requested Water family, variant, radius and configured workers equal the
  native applied readback. Every other material keeps its native default, so there
  was no silent fallback or leak.
- Complete stored Water (visible + PF overfill) equals the registered quantity
  at tick 0 and after every one of the 30 ticks. Explicit source/sink totals are 0.
- The complete 1024² inventory contains only Empty/Wall/Water. Wall changes only
  by the registered gate edit, so no hard-boundary crossing occurred.
- No World failure, a tick-failure count of 0, and 30 attempted/completed ticks.
- IN: a complete motion census over all Water cells (the inertial cell count
  equals the Water cell count) with zero negative `vy`. PF: the gas ledger closes.
- Retirement: no World reference remains after host release; every process exited 0.

**Worker parity:** all 14 arm pairs per OS have identical per-tick physical
hashes for configured workers 1 and 4. They also match on terminal Water cells,
inventory, IN tuple digest and PF ledger. **Cross-OS:** all 28 per-arm tick-hash
sequences are identical on Windows and Linux. This was observed, not required
by the registration.

### Negative controls (both OSes)

| Control | Result |
|---|---|
| Water IN at radius 2 | Refused `malformed_policy: inertial_cellular_v1 requires complete execution radius three`; previous World, receipt and policy hash byte-identical |
| Fractional Water (128/255) without normalization, CY and IN | Refused `normalization_required`; previous World retained |
| The same fill with `water-normalize-v1` under CY | Accepted. Reported before/after 2,359,296 → 4,700,160, +2,340,864/−0, equal to the reducer's independent half-maximum rule |
| Pressure for Oil (16) and Brine (24) | Offered only as refused `combination_rejected` |
| Water variant catalogue | `cached`/`cached_dormant` offered only for `pressure_flow_v1` |

The reducer's 28 hermetic tests confirm that it stops on each violation class:
quantity loss, a per-tick change, fallback, foreign-material leak, radius
upgrade, a boolean or float used as an integer, wall corruption, an
unregistered material, a failed World reported healthy, negative IN `vy`, an
unclosed gas ledger, an unretired owner, a single worker reporting multiple
claimants, a short horizon and a nonzero normalization delta.

## Observations

Native `World::tick()` milliseconds are from 30-tick cold windows in a fresh
process. They are **not** a benchmark. Windows and WSL builds differ in compiler
and environment, so cross-OS ratios are not meaningful. Claimants are the maximum
distinct task-claiming participants in one dispatch, **not** utilization or proof
of simultaneous overlap.

| Scenario / lane | Family | Win w1 p50/p95 | Win w4 p50/p95 | Linux w1 p50/p95 | Linux w4 p50/p95 | w4 claimants (ticks >1) | Cells moved (30 ticks) |
|---|---|---|---|---|---|---|---:|
| Dam A r3 | FM | 7.85 / 11.02 | 6.35 / 7.18 | 20.23 / 25.28 | 17.52 / 18.53 | 4 (30/30) | 104,089 |
| Dam A r3 | CY | 6.14 / 9.18 | 4.62 / 6.46 | 19.67 / 25.94 | 15.24 / 16.26 | 4 (30/30) | 144,187 |
| Dam A r3 | PF ref | 21.86 / 28.88 | 22.04 / 31.10 | 26.91 / 40.86 | 27.37 / 35.46 | 4 (30/30) | 134,552 |
| Dam A r3 | IN | 1.57 / 8.70 | 1.62 / 5.26 | 5.17 / 23.97 | 5.02 / 16.65 | 4 (30/30) | 13,173 |
| Dam B r2 | FM | 7.90 / 13.38 | 6.50 / 9.77 | 20.09 / 24.57 | 17.45 / 19.17 | 4 (30/30) | 104,089 |
| Dam B r2 | CY | 6.01 / 7.91 | 4.39 / 4.76 | 19.41 / 20.35 | 15.36 / 18.52 | 4 (30/30) | 144,187 |
| Dam B r2 | PF ref | 21.74 / 30.97 | 22.84 / 28.13 | 33.00 / 78.37 | 29.29 / 35.04 | 4 (30/30) | 134,552 |
| Pool A r3 | FM / CY / IN | ≈0.01 / 48–79 | ≈0.01 / 16–26 | ≈0.02 / 211–281 | ≈0.02 / 59–70 | 4 (3/30) | 0 |
| Pool A r3 | PF ref | 30.01 / 91.63 | 31.16 / 44.46 | 47.11 / 247.48 | 37.01 / 89.07 | 4 (3/30) | 0 |
| Pool B r2 | PF ref | 31.14 / 94.62 | 30.80 / 44.38 | 33.95 / 246.92 | 34.71 / 93.92 | 4 (3/30) | 0 |

- **Distributed work exists.** The dam dispatched 46 phase jobs in a tick, and
  every configured-four arm had 4 claimants on all 30 ticks. The quiet pool had
  4 claimants only during its first three settling ticks before FM/CY/IN slept.
  Configured four therefore observed four. These counts do not establish scaling
  or simultaneous execution.
- **PressureFlow reference does not rest.** It costs about 30 ms per tick on a
  motionless pool where the other families cost about 0.01 ms. Four workers do
  not reduce PF time, consistent with the documented serial owner preparation.
  The cached/cached_dormant comparison belongs to the secondary
  optimisation-variant arm, not to this four-family count.
- **IN starts slowly by design.** It moved 13,173 cells in 30 dam ticks, against
  104k–144k for the other families. Its retained velocity was 762 moving cells,
  Σ|vx| 7,139 and Σvy 10,517 (16 quanta per cell), with maximum vy 30. It does
  not yet show leak or drain appearance.
- **FM splits whole cells.** The dam ended with 18,496 FreeMass cells for the
  same quantity; whole-cell CY/IN kept 18,432. PF showed 18,408 visible cells,
  with its quantity closed through overfill (21 compartments, 113 relief cells).
- Process peak working set/RSS was 173–205 MiB (Windows) and 186–225 MiB (Linux),
  with PF highest and IN next. These figures include Godot and the apparatus, so
  they are not a solver memory census. The tick-time chunk allocation total was 0.

## Limits and parked-work reconciliation

- **Native-only.** There was no Rapier body, player, Main/worker owner,
  publication or rendering. The full desktop host is the next milestone.
  `host_eligible_for_full_matched_evidence` stays `false`.
- **Not hosted CI.** The 30-tick horizon reaches neither leak/drain behavior nor
  steady-state cost. Both legs ran locally on one machine.
- **Reuse instead of rebuild.** The [`liquid_feel_probe.gd`](../../godot/scripts/liquid_feel_probe.gd)
  census uses only existing adapter queries. It takes non-Water counts from
  copied material cells, because they dither fractional Water, and stored Water
  from the quantity observation.
  - The #258 copied nineteen-field IN ledger and the #259 CYPS science consumer
    both need adapter or native changes, and so a runtime republication, which
    this admission does not need.
  - IN state identity is covered here by the full tuple digest plus the v3
    physical hash. The strict-integer and refusal semantics of #259 are
    reimplemented in the reducer, and #260 is not used.
  - Reconcile #258's ledger only if a later scenario needs cumulative IN ledger
    fields beyond the tuple census.
- **Not measured.** Heap-allocation profile, per-worker utilization,
  simultaneous-overlap duration and a solver-only memory census.
