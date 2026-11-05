---
title: REC-001 offline observed-event bookmark experiment (non-runtime)
document-kind: audit
status: Experimental
scope: Bounded offline REC-001 v2 material/actor event indexing with synthetic negative controls
last-reviewed: 2026-11-05
related-documents: [../operations/gameplay-recording.md]
---

# REC-001 offline observed-event bookmarks — 5 November 2026

## Source custody and intended role

Independent work for [REC #130](https://github.com/techrote/cybersand/issues/130),
[REC-001 #135](https://github.com/techrote/cybersand/issues/135),
and [PLAY-VAL #134](https://github.com/techrote/cybersand/issues/134).
Based on accepted `main` `ba9cbc89029be88b812af59b19e5c59829bbcd90`, tree
`3af18f50e6094776263119623b64a1b2f4ca0ab2` (read 2026-11-05 UTC),
and the *Current* recorder `godot/scripts/gameplay_recorder.gd` blob
`e2d8d72361d38f48b15a8eba213a72ff7ca68c0d`, schema v2 contract
`docs/operations/gameplay-recording.md` blob
`19d941e3680bc1e91fe2e2233697d748ede6d99f`.

This is an **additive offline analysis tool**, not a second recorder. The
independent viewer proposed in draft [#419](https://github.com/techrote/cybersand/pull/419)
remains owner/reviewer held. This tool does not import, edit or depend on that PR,
its validators or its changed paths. The new script lives in its own file,
`tools/recording/index_rec001_events.py`, and uses only the Python standard library.
No gameplay or simulation source, defaults, GDExtension, renderer, recording runtime,
or physics semantics change. No production adoption or merge is requested.

## What is measured (and what is not)

Input: one finalized REC-001 v2 session directory with `recording.json`,
`frame-NNNNNN.json` and **raw** `frame-NNNNNN.ids`. Review BMP overlays are
intentionally NOT used for material comparisons. Output: an `events.json`
observation ledger and compact `timeline.svg` displaying the observed material,
player and body activity on the same capture-time axis.

- **Material-change observed:** only between *distinct* actual
  `material_generation.render_snapshot_serial` values. Record changed raw-ID
  cell count, inclusive world-space bounding rectangle and top 12 ID
  transitions, alongside the bracketing generation ticks. Repeated generation
  with identical IDs is correctly counted as reused, without fabricated
  material activity. Reused serial with different ID bytes or tick is refused.
- **Player/rigid movement observed:** only between distinct
  `actor_sample.snapshot_serial` values, using separate actor tick bounds and
  copied actor/body positions. The recorder's actor sampling can advance while
  material bytes remain unchanged; the index preserves that distinction.
- **Capture losses:** retained drop events and bounded omitted-drop counts are
  reported separately. When the manifest provides a session monotonic start,
  retained drops appear as dotted marks on the SVG time axis.
- **Scenario changes:** mark changes of the recorded scenario ID rather than
  silently pooling different scenario content.

None of these events establishes **when** within the interval a change occurred,
its physical cause, collision/penetration/impulse, exact deterministic replay,
or subjective gameplay feel. The `ids` channel has no Water quantity,
temperature or reaction-eligibility state. An unchanged capture does not prove
an idle simulation between samples. Runtime/source identity is a **recorded
claim**, not independently authenticated by this offline script.

Input controls are deliberately bounded: up to 4,096 written frames, up to
4,194,304 raw cells per frame, at most 256 MiB aggregate raw-ID+metadata
payload, at most 2 MiB per JSON input and 256 retained drop events. Refuse
missing/symlinked/truncated raw IDs, unexpected ROI, wrong evidence/schema,
inconsistent counters, drop-ledger contradictions, changed bytes under a reused
generation, nonmonotonic clocks and existing output directory. The bounds
are for this offline indexer, not production recorder configuration.

## Local qualification, negative evidence and limits

Command (Linux x86-64, Python 3.13.5, no Godot/native runtime):

```bash
python3 -m unittest discover -s tests -p test_index_rec001_events.py -v
python3 -m py_compile tools/recording/index_rec001_events.py
python3 tools/recording/index_rec001_events.py SESSION_DIRECTORY OUTPUT_DIRECTORY
```

**18/18 synthetic tests PASS**, including generation/actor separation,
player and rigid displacement, signed-coordinate bbox, drop time alignment,
SVG XML validity, no writes to the inputs, bounds, refusal of raw path escape,
symlinks, wrong ROI, truncated ID payload, inconsistent loss counters, changed
payload under unchanged serial and nonmonotonic samples. The synthetic
four-frame example gives four bookmarks: one player movement, one one-cell
material change, one rigid-body movement and one recorded queue drop.

An independently retained 12-frame demo from the previous #419 exercise
contains a **synthetic contradictory complete manifest** (`capture_attempts=12`,
`enqueued_frames=12`, `dropped_frames=1`). This indexer correctly refuses that
unmodified input. That result agrees with independent review issue A02 and
is not a claim about a real REC-001 capture. Do not change historical negative
evidence to make a demonstration pass; the fresh generated four-frame fixture
has a consistent five-attempt/four-enqueued/one-dropped ledger.

**Unexecuted:** real desktop / Windows capture, ACT/Water/granular physical
observations, matched recording OFF/ON simulation-overhead measurements,
actual 1/4 native worker participation, Godot/GDExtension CI, and human feel.
The synthetic `worker_count=4` field is only a *fixture claim*, not actual
worker execution. No runtime source attestations are inferred from it.

## Next bounded gate

Obtain one complete actual REC-001 v2 `rem003/player-granular-review`
recording containing active falling material and a matching scenario control.
Run this indexer read-only, verify frame/material/actor clock provenance and
reported drop observations against original source-identifiable files, then
make a human review of event highlights. Separately run the required matched
recording ON/OFF desktop overhead study before claiming #135's performance gate.
Do not merge this experimental tool without independent validation and all
applicable source-check/CI/owner gates.
