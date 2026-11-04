---
title: Workbench 394 protected material-source transition
status: Current
document-kind: evidence
scope: Proposed three-consumer MAT admission for the retained workbench native source; frozen identities and historical compatibility evidence remain unchanged
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md, 2026-11-04-mat-auth-reviewed-transitions.md, 2026-11-04-workbench-consolidation.md, 2026-11-04-workbench-boundary-and-pacing.md]
---

# Workbench 394 material-source transition — 4 November 2026

## Decision and limits

**Proposed, awaiting independent exact-entry admission review.** The owner asked
to clean up Draft [PR #394](https://github.com/techrote/cybersand/pull/394), work
through MAT admission and preserve the current flight/contact feel, with the PR
unmerged. This record prepares that review; it does not assert owner adoption,
merge authorization, a catalogue cutover or completed gameplay qualification.

The [original MAT handoff](https://github.com/techrote/cybersand/issues/391#issuecomment-6640737890)
requested a separately reviewed source/interface transition, with protected
Current material/capability/quantity controls. The later
[owner-approved mechanism](https://github.com/techrote/cybersand/issues/353#issuecomment-6642966578)
is implemented by [PR #396](https://github.com/techrote/cybersand/pull/396) at
`4aeac7071d1446e33bce7ccda0eafaeae7077847`. Cleanup merge
`972616ef3d5fc1d476a3fcc5c0ea13fb7057dcf9` preserves that implementation and its
independent review in ancestry. Its checker rules are unchanged here; this
candidate adds only the three code-pinned entries and this review record.

The [canonical transition rules](../operations/material-catalogue-shadow.md#reviewed-per-file-transitions)
apply. Each target must match its retained source commit exactly, all other
protected files must retain their baseline bytes, and all twelve identity inputs
are refused as per-file transitions. The guard authenticates identities and
records; it cannot prove behavioural equivalence. Independent review of the
actual source changes and the controls below remains required.

**Keep PR #394 unmerged.** Any eventual entry-adding integration must preserve
`source_commit` in history through a merge commit. A squash or rebase that drops
it is refused by the guard. Reverting these source changes requires reverting
their entries together; old source bytes do not pass an admitted target entry.

## Exact source checkpoint and protected inventory

The accepted-main starting point is
`751edc0b495dc85484ad5509a7c95f863651c76b`. The frozen compatibility oracle remains
`0fd4af5987e77db4da3e37c757cf2c0917ae9e15`. All three targets are the LF-normalized
bytes at retained native build source
`1ca90de5181953f9ebd95ef19c920d8dee7e17e2`, and independently match original
PR #394 head `1f968fa2ab403aa564aa6c816e60bf6c572b27a5`.

| Protected consumer | Frozen/from LF SHA-256 | Candidate/to LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1` | `a47955f79ed5fbc8bc0ca8e2892ed4eb0ddbd728b841bc08ccee14a4c239e4a7` |
| `native/src/world_pressure.inc` | `c8cb11512e935d05e099d8f155c1659473a7f61aa301e2e4900e55bdcfe4024b` | `a1dd5c486dad16f114cce3b38d292407edb91e5bbaf03d0193dcc4ecd7338e62` |
| `native/src/world_inertial.inc` | `f9e891dafa9c61e76460b5b3a720e3e522e7b63c381e81539e5e508b2719a0dd` | `8a5d3680e96ca47a3f496be5a8b953084d2c6d2e0bd723c3214b87bdbc3580b5` |

An LF-byte inventory at cleanup merge `972616ef` found exactly **3 changed and
24 unchanged** protected consumers. All **12 identity inputs are unchanged**.
The compatibility lock itself is unchanged, file SHA-256
`8b4d3351cbe4380e976655d10dc34c4bf9e81d95442719a53770b62d219183dc`.
Catalogue digest remains
`82b5ab9a6e87ae817072390105052f8a5ac6d0ee22b3301cd973efdfc7fdbad3`;
capability digest remains
`33c608f875e3d8b5730f1d3b81a54dbeff9579b433e061535610a8bfa276e237`.
The unchanged files include the material and reaction headers, quantity codec and
ledger schema, policy identity generators and retained wire/normalization/receipt
vectors, and fallback identity, granular-policy and appearance definitions.

The raw local inventory is `build/cleanup394-mat/protected-inventory.json`,
SHA-256 `dd0620082727efbcd0f7975a283312e8150ba688679ebb356b2222d30379f9bc`.
It is reproducible from the unchanged lock, `SOURCE_ROLES`, `IDENTITY_INPUTS`
and the three retained commits using the checker's LF normalization. Generated
raw receipts remain local; the exact source checkpoints above retain every
material claim's inputs.

Before adding entries, the inherited #396 guard correctly refused World.cpp's
drift with exit 1. The local original stream is
`build/cleanup394-mat/pre-transition-refusal.log`, SHA-256
`23aa6147ae030425b4fe79ce1ceb8991e4d45f37d441ecaf762a543ac96de7fd`.
That refusal and the earlier documented refusals remain valid evidence; no
baseline hash was refreshed to erase them.

## Source review boundary

Against accepted main, the protected diff is World.cpp 275 additions/32
deletions, world_pressure.inc 214/18 and world_inertial.inc 1/1. Review the full
diff, including inactive paths, rather than treating the pressure include as
only a contact-signature edit.

- **World.cpp:** extracts the existing stable-grain support predicate, adds the
  bounded side-contact admission query, supplies native contacting coordinates
  to contact observations, and adds opt-in granular wrench/arrival accounting.
  Arrival storage is disabled on ordinary construction and allocated only by
  explicit pre-tick enablement; non-transport writes retire provenance. Existing
  raw blocked-contact counters and impulses remain available. Explicit workbench
  mask reservation and external-coupling quarantine are separate bounded owner
  operations. Material cells remain native-owned; this introduces no cell erase
  or body-to-material conversion.
- **world_inertial.inc:** supplies the already known source coordinates to the
  same contact observation; the IN movement and state-update law is retained.
- **world_pressure.inc:** supplies those coordinates on Water contact, adds an
  explicit prepared-destination workbench liquid/state transfer with quantity,
  overfill, gas, exterior inventory, IN and loss receipts, and adds opt-in
  reference pressure-column dispatch. Ordinary hosts keep their existing
  execution policy. Column tasks join before row repair/wake processing. The
  pressure hash, policy identity and physical save codec stay under their
  retained contracts; exact parity controls are needed for execution changes.

The intended active workbench granular response is the previously reviewed
LA-SA route. The source transition does not authorize changing its coefficients,
material laws, flight control forces or sleep behaviour. It also does not
admit an unbounded body/material carrying guarantee: the earlier measured
Scooper drips and carry limits remain qualified as recorded.

## Qualification and review ledger

Preparation used Windows 11, PowerShell, Python 3.13.16 and retained Git objects.
The merge/identity inventory and original guard refusal above completed. The
following checks are required at a committed candidate; their fresh results and
independent review disposition will be appended without rewriting the historical
workbench runs:

| Gate | Current result |
|---|---|
| Three retained blobs, other 24 owners, 12 identity inputs, lock and digests | PASS at cleanup merge `972616ef`; hashes above |
| `python tools/material_catalogue/compatibility.py --check` | Pending committed record and exact-entry review |
| `python tools/material_catalogue/compiler.py --check` | Pending fresh candidate execution |
| `python -m unittest discover -s tools/material_catalogue -p 'test_*.py'` | Pending fresh candidate execution; run Linux for C++/symlink controls |
| `python tools/material_catalogue/check_native_parity.py --output build/cleanup394-mat/native-parity.json` | Pending fresh candidate execution; metadata/pure-query scope only |
| Inactive accepted-main/candidate native differential | Pending fresh source-qualified comparison |
| Native core, arrival, pressure-head, quantity and pressure-capacity controls | Pending fresh candidate execution |
| Applicable sanitizer and Godot host controls | Pending fresh candidate execution |
| Independent exact-entry/source review | Pending; no admission verdict asserted |

Earlier source-matched execution is retained in the
[boundary/pacing audit](2026-11-04-workbench-boundary-and-pacing.md) and
[consolidation audit](2026-11-04-workbench-consolidation.md). In particular, the
four-arm pressure-head fixture compares per-cell heads, physical hash, CYPS2
bytes, quantity ledger, diagnostics, wakes and scheduling over 42 ticks. That
within-candidate parity does not by itself prove accepted-main equivalence.
Native query parity likewise does not execute World ticks or certify gameplay.

PR #384 remains a separate generated-display consumer admission. Its current
`3d537d1a62e9b7eca546c63ffd4ec6e7654d5957` executable-inventory guard does not admit
these World changes and is not imported. Its behavioural interaction with the
new transition mechanism is recorded by
[the MAT owner](https://github.com/techrote/cybersand/issues/353#issuecomment-6643681542).
Future reconciliation must preserve both programmes' explicit boundaries.
