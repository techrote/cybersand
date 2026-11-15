# D-1B four-stream offline handoff — 15 November 2026

**Research-only.** For #570 / Draft PR #596. This is an optional input/sample
generator for the Wormfleet Commander, **not a fleet scheduler, actual model
prompt adapter, native observation, native receipt, or M1-conformant event
journal**. No workflow, runner, model, PNG renderer, material editor, or Undo is
started. Source writes remain strictly in D-1B.

## Accepted source and boundaries

- Accepted M1 source: 8fa90de6be209ed0b7bd125039e6ec8b332fb1a6;
  schema SHA-256 ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d.
  This module names the approved vocabulary; **it does not validate a complete
  M1 event journal**. Full five-record conformance is still a central-owner gate.
- Q8 native #611 evidence is **text-only** (--no-mmproj), one paired seed;
  the independent D-1B archive auditor and its original material receipts are
  neither altered nor assumed for these synthetic fixtures. No vision d1 claim.
- Goal: study modest, sometimes wayward line steering, not A* supremacy or an
  autonomous art supervisor. A native host alone owns the legal candidate
  catalog, materials, protection, STOP, revision fencing and rollback.

## Paired design, not a four-worm claim

For each declared synthetic seed/source, build_stream freezes the identical
snapshot, World/material SHA-256, legal action IDs/footprints and host geometry.
It produces four **independently mutable** sample arms:

| Arm | Pre-choice scalar | After-choice shadow critique |
|---|---|---|
| sham | u16 neutral zero | none |
| guidance | source-derived u16 positive scalar | none |
| critic | u16 neutral zero | hypothetical KEEP/UNDO/STOP |
| combined | source-derived u16 positive scalar | hypothetical KEEP/UNDO/STOP |

The pre-choice **sham == critic** model views and
**guidance == combined** model views have identical SHA-256 at every optional
information level. The critic is strictly post-choice; **it cannot leak a
suggested action or future metric into a controller's pre-choice prompt**.
A proposed shadow UNDO is never actual native rollback.

For each arm, the same source state supports core, preference, geometry,
and all numeric-channel ablations. Channel vocabularies/encodings follow
the accepted M1's positive u16, signed i16 and XY i16 registrations; each
numeric tile is capped at 4,096 cells and hashed from its explicit little-endian
bytes. Omitted semantic identities/hashes appear in audit-only data,
never in the model view. The exported record is a **D-1B research preview**, not
a replacement for M1's typed source schema or native safety checks.

build_four_streams refuses fewer/more than four sources, duplicate stream
IDs, seeds or snapshot IDs, and duplicate (world_sha256, material_sha256)
pairs. Each stream must be independently reverified by the integrating host.
Four prepared synthetic streams imply **zero** actual model PIDs or resident
worms; only Commander's real leases/PIDs/job IDs can establish concurrency.

## Reproduction (offline stdlib; no GitHub Actions dispatch)

From repo root:

~~~bash
python3 -m unittest experiments.driv3r.stage_d.guidance.test_fleet_samples -v
python3 - <<'PY'
import json
from experiments.driv3r.stage_d.guidance.fleet_samples import build_four_streams
from experiments.driv3r.stage_d.guidance.test_fleet_samples import fixture
bundle = build_four_streams([fixture(i) for i in range(4)])
print(json.dumps({"accepted_m1_source": bundle["accepted_m1_source"],
                  "stream_count": bundle["sample_stream_count"],
                  "resident_worm_count": bundle["resident_worm_count"],
                  "content_sha256": bundle["content_sha256_without_self_digest"]},
                 sort_keys=True))
PY
python3 -m experiments.driv3r.stage_d.guidance.qualification --timeout-seconds 180
~~~

Golden fixture: seeds **101, 203, 307, 409**; four source-isolated
synthetic World/material pairs; **4 arms × 4 optional-field views × 4
source seeds = 64 pre-choice input previews**; eight post-choice shadow sets
with three illustrative KEEP/UNDO/STOP cases each. Canonical bundle
digest **excluding its self-digest**:
e81d076d67b94cbf25d70813cfb6eee2f40c5e218c67ad8b20a0ac4973b78b9b.
This digest is for the synthetic fixture, not a native artifact.

**Local qualification on authored source bytes:** 16/16 focused stdlib tests
passed; both new Git blobs were SHA-matched against the tested files.
The fail-closed full-suite gate has been raised to **215 methods in
20 modules**. The entire exact clean-checkout suite **has not been executed
in this run**; do not cite Stage A or source-scope CI as full-suite proof.

## Commander integration / M2 handoff

Before actual model/native inference, Commander must bind each sample stream to
a real source-checked native World and distinct wrangler ID, lease ID,
model/checkpoint hash, run/job ID, loaded PID, original observation/receipt
hashes and bounded decision budget. Only host-produced catalogs are legal.
The Commander, not this producer, must verify raw original Q8 receipts, isolate
run-level seeds and native episodes, and measure actual one-vs-two model
co-residency. Real KEEP/UNDO/STOP needs native rollback/revision acceptance by
the central owner. No 128-turn, training, paid compute or graphics support is
implied by these offline samples.
