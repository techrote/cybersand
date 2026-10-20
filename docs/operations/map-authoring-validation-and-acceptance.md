---
title: Map authoring validation and acceptance
status: Current
document-kind: guide
scope: Agent workflow for proving authored map structure, native exhibit outcomes, visible composition, capture provenance and review readiness
canonical-for: [map-authoring-validation, map-exhibit-acceptance, map-capture-provenance]
last-reviewed: 2026-10-20
related-documents: [map-authoring-walkthrough.md, map-authoring-design-and-materials.md, map-authoring-native-layers-and-programmes.md, deepworks-exhibition.md, local-build-and-validation.md, testing-validation-and-replay.md, documentation-maintenance.md, ../reference/validation-evidence.md]
---

# Map authoring validation and acceptance

**Current workflow:** use this chapter to turn an authored scene into a
reviewable map with evidence for its actual behavior. Start with the
[authoring walkthrough](map-authoring-walkthrough.md), develop the
[composition and material choices](map-authoring-design-and-materials.md),
and implement the [native layers and programmes](map-authoring-native-layers-and-programmes.md).
Return here throughout implementation.

Deepworks supplies executable examples for this process. Its commands below
exercise Deepworks and the shared depth infrastructure. A new map needs its own
fixtures, expected exhibit identities and visual witnesses. This guide describes
reproduction and acceptance procedures; dated execution results belong in the
[validation ledger](../reference/validation-evidence.md) and linked evidence.

## Establish the inputs before judging a result

Work from the inspected source root and record HEAD, branch, dirty paths and
the recoverable checkpoint. Materialize the required Git LFS runtime objects.
Use the pinned Godot executable and native/Rapier libraries identified by the
[build guide](local-build-and-validation.md#which-build-inputs-are-required).
Godot scripts load the installed extension; running a scene does not rebuild it.

For each evidence set, retain the command, timeout, OS/architecture, engine
version, renderer when applicable, native and vendor library hashes,
configuration, worker counts, source revision and changed executable-file
hashes. A commit identifies committed inputs; a dirty working tree needs its
additional identities. A recipe hash identifies the authored definition but
does not identify every controller, oracle or native library.

Keep current runtime provenance separate from
[historical M11 integrity](current-and-historical-validation.md).
If native inputs change, rebuild and validate the matching runtime according
to that contract. Map authoring should not silently alter dependency pins,
material kernels or historical hashes to accommodate a troublesome fixture.

## Validate a useful slice, then the complete composition

Choose the smallest fixture that can expose the next concrete risk. An initial
slice should contain a real enclosure, its source, intended substrate, collection
or reaction region, layer placement and an observable outcome. Establish that
the mechanism works before duplicating its architecture across the map.

Expand validation along distinct boundaries:

| Boundary | Evidence to obtain |
|---|---|
| Authored definition | Valid dimensions/materials, bounded sources, complete district and plane coverage, intended passage openings and rejection of invalid replacement without losing the installed scene. |
| Native mechanism | Production scheduling, copied native observations, completion of the intended transport, reaction, growth or curing behavior. |
| Host and controls | Production scene installation, camera and brush transforms, pause/step/reset, tour behavior and UI input ownership. |
| Final composition | Actual pixels, visible rear/far/atmosphere contributions, readable controls and useful map area at supported window sizes. |

Deepworks separates these concerns in
[`test_deepworks.gd`](../../godot/tests/test_deepworks.gd),
[`test_deepworks_reactions.gd`](../../godot/tests/test_deepworks_reactions.gd),
[`test_deepworks_controller.gd`](../../godot/tests/test_deepworks_controller.gd)
and [`test_deepworks_render.gd`](../../godot/tests/test_deepworks_render.gd).

Keep accepted regression meanings intact. Shared depth changes require the
retained dimension, compositor, runtime and default-lab checks. Material-rule
changes additionally require the native compatibility and frozen pair-oracle
coverage described in [test selection](testing-validation-and-replay.md).
A focused authoring iteration can remain small; checkpoint acceptance must
cover the shared boundaries actually changed.

## Require a completed mechanism oracle for every exhibit

Derive expected exhibit identities from the intended design, independently of
whatever records the test happened to produce. Give each district/plane
apparatus a stable identity and an explicit mechanism oracle. Final accounting
must reject missing, duplicated, unexpected or unverified identities.

Use observations from the actual map and production scheduler. Deepworks reads
copied native RG8 packets, samples early enough to observe transient products,
and continues long enough to observe slower transport, growth and curing.
Its reaction fixture completes 360 manual native ticks per dynamic plane.
Those tick counts establish this bounded fixture's execution, not elapsed
normal-play timing.

Choose an observation that demonstrates the claimed mechanism:

- For a new reaction product, require its absence initially, prohibit sources
  from painting it directly, and observe its later appearance.
- For transport, observe material beyond the feed region and past the relevant
  obstruction or collection boundary.
- For growth with injected seeds, account for all directly written cells and
  require growth beyond that allowance.
- For consumption or purification, check the original substrate's reduction
  as well as the resulting material.

[`_verify_exhibit()`, `_check_products()` and `_check_flow()`](../../godot/tests/test_deepworks_reactions.gd)
show these different oracles. Source admission alone cannot establish them.

Each mechanism helper must return an explicit completion receipt. Record
`oracle_completed`, the number of mechanism assertions and `verified`.
Verification requires completion, at least one mechanism assertion and no
failures in that exhibit's checks. An unknown mechanism must fail.

Exercise a focused negative control whenever the acceptance path itself changes:
block a required transport route, return without completing a helper, or return
success without executing checks. Run the control in an isolated scratch copy
against the real map. Retain its expected rejection separately from positive
evidence. Stop extending controls once the concrete failure mode is covered.

### The Deepworks false-pass and Stone lessons

The [PR #185 correction](../audits/2026-10-20-deepworks-pr185-completion.md)
documents why both completion accounting and physical observations matter.
An untyped conditional array assigned to `Array[int]` aborted a helper before
eight transport assertions. Godot exited zero and the old local summary
reported 626 simulation assertions, or 627 with report writing. The caller
incorrectly marked both affected exhibits verified. Hosted CI correctly
rejected the script errors in the complete logs.

Restoring those assertions exposed a real rear Stone failure: its feed sat
above a continuous shelf, and Stone did not move sideways off it. Moving the
three-cell nozzle from x157–159 to the open chute at x170–172 restored transport
while preserving the material and original below-y143 oracle.

The repaired fixture also rejects a helper that returns true without checks.
Preserve the original failed evidence and add a correction record. The lesson
is to repair the apparatus and the missing acceptance path, retaining the
physical meaning of the test.

## Run the current commands and register new map cases

The following examples run from the repository root on configured **Linux**.
They use Bash, GNU `timeout`, Python and the pinned Godot executable available
as `godot`. Use an isolated evidence directory for each run:

```sh
set -euo pipefail
map_godot="$(command -v godot)"
map_evidence="$(mktemp -d /tmp/cybersand-map.XXXXXX)"
test "$("$map_godot" --version)" = "4.7.stable.official.5b4e0cb0f"

export XDG_CONFIG_HOME="$map_evidence/config"
export XDG_DATA_HOME="$map_evidence/data"
export XDG_CACHE_HOME="$map_evidence/cache"

timeout 240 "$map_godot" --headless --audio-driver Dummy \
  --path godot --editor --quit
```

After a successful import, these are the focused **headless** Deepworks and
shared-depth commands:

```sh
timeout 180 "$map_godot" --headless --audio-driver Dummy --path godot \
  --script res://tests/test_deepworks.gd
timeout 180 "$map_godot" --headless --audio-driver Dummy --path godot \
  --script res://tests/test_deepworks_controller.gd
CYBERSAND_DEEPWORKS_REACTION_REPORT="$map_evidence/reactions.json" \
  timeout 180 "$map_godot" --headless --audio-driver Dummy --path godot \
  --script res://tests/test_deepworks_reactions.gd
timeout 180 "$map_godot" --headless --audio-driver Dummy --path godot \
  --script res://tests/test_depth_dimensions.gd
timeout 180 "$map_godot" --headless --audio-driver Dummy --path godot \
  --script res://tests/test_depth_compositor.gd
```

Retain complete combined stdout/stderr, exit status and duration for each
command. Reject timeouts, engine/script errors and skipped required cases.
Inspect the full log for `SCRIPT ERROR:` and `ERROR:` even when the exit status
is zero. The [shared runner](../../tools/ci/run_godot_regressions.py) implements
these failure rules. Shell exit-on-error alone cannot catch a Godot script
error accompanied by exit zero.

When requesting the Deepworks JSON report, independently read it back and
require zero failures, all 32 expected identities, and completed, nonempty,
verified mechanism checks:

```sh
python - "$map_evidence/reactions.json" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
expected = {
    f"deepworks-{district:02d}-{plane}"
    for district in range(16)
    for plane in ("play", "scripted")
}
records = report.get("exhibits", {})
accepted = (
    report.get("failures") == 0
    and report.get("verified_exhibit_count") == len(expected)
    and set(records) == expected
    and all(
        record.get("oracle_completed") is True
        and record.get("oracle_assertions", 0) > 0
        and record.get("verified") is True
        for record in records.values()
    )
)
if not accepted:
    raise SystemExit("Incomplete or failed Deepworks mechanism evidence")
print("Verified all 32 expected Deepworks exhibits")
PY
```

For a **new map**, create the appropriate `godot/tests/test_<name>.gd` fixtures
using its actual recipe/runtime/host and an independently specified expected
roster. Name graphical fixtures `test_<name>_render.gd`. Current discovery finds
`test_*.gd` automatically; the `_render` suffix declares a display requirement.
Check that the resulting case manifest includes the new files and that final
logs show their actual execution. Existing Deepworks tests continue exercising
their own preloaded scene.

## Prove that the composition is visible and usable

Run graphical fixtures with an actual compatibility renderer:

```sh
timeout 180 "$map_godot" --audio-driver Dummy \
  --rendering-method gl_compatibility --path godot \
  --script res://tests/test_depth_dimensions_render.gd
timeout 180 "$map_godot" --audio-driver Dummy \
  --rendering-method gl_compatibility --path godot \
  --script res://tests/test_deepworks_render.gd -- \
  --deepworks-render-output="$map_evidence/render"
```

These commands require a display. The
[Deepworks render fixture](../../godot/tests/test_deepworks_render.gd)
instantiates the production scene, freezes material animation and compares
matched pixels while changing layer visibility. Returning to the original
visibility must restore the same pixels. This prevents simulation drift from
masquerading as a layer contribution.

It tests the HUD at 1280×720 and 1600×900, including overlap and actual map
pixels beneath the controls. At a 1024-square overview, each district must
show rear and far contributions. Atmosphere checks follow each local source's
first native pulse, mask observations using actual nonempty, non-Wall effects
cells and compare visible/hidden atmosphere at the same published tick.

Choose a new map's witness regions from its own geometry and define acceptance
thresholds before accepting its results. Include far edges and apparently
quiet districts. Allocated worlds, event counters and nonempty textures can
all coexist with an invisible composition.

Separately test input ownership: focused controls must consume their keys and
pointer interactions without moving or painting the world. The
[controller correction](../audits/2026-10-20-deepworks-pr185-completion.md)
retains keyboard slider adjustment, camera stability and fresh-press rearming.
Visually inspect overview and detail captures for composition and readability
after automated assertions complete.

## Capture reproducible review images

The existing helper captures **Deepworks** from its actual graphical scene:

```sh
export CYBERSAND_SOURCE_REVISION="$(git rev-parse HEAD)"
"$map_godot" --path godot --rendering-method gl_compatibility \
  --audio-driver Dummy --script res://tools/capture_deepworks.gd -- \
  --deepworks-output="$map_evidence/captures"
```

Declare and record a capture deadline appropriate to the selected scope.
The [capture helper](../../godot/tools/capture_deepworks.gd) rejects headless
execution and failed image/manifest writes. Its `--quick` mode produces the
controls image, a 2048-square atlas and sixteen exact 512-square atlas crops:
18 images. The full run adds detail views, four isolated planes, a later atlas
and reaction details: 34 images.

The later composition follows **240 manual ticks of each dynamic plane**.
It is a different clock from 240 frames of independently paced normal play.
Keep capture mode, tick state, camera, layer visibility and animation state
with each comparison.

Read `capture-manifest.json`, verify every listed file's dimensions and
SHA-256, and inspect the images. Exact district crops should agree with their
atlas regions. The manifest records the recipe, caller-supplied source
revision, engine, renderer, runtime statistics and capture hashes. Retain
native-library and changed-script hashes separately.

A new map needs a capture helper targeting its own production scene and
coverage. Reuse the procedure while replacing the scene, district roster and
camera choices deliberately.

After a recipe change, regenerate evidence for claims affected by that change.
Keep prior captures under their original source/recipe identity. The
[Deepworks correction record](../audits/2026-10-20-deepworks-pr185-completion.md)
preserves old-feed post-tick images as historical observations while explicitly
superseding their acceptance claim.

## Complete documentation, retrieval and hosted acceptance

Apply the [documentation maintenance contract](documentation-maintenance.md).
Update canonical scene, control, configuration or subsystem claims first.
Route the guide through `docs/README.md` and `docs/reference/retrieval-index.md`.
Register new current answer pages in the `documents` list of
`docs/reference/retrieval-corpus.json`; preserve unique `canonical-for` ownership.
Keep dated audits outside the default answer corpus and link their scoped
results from the validation ledger.

Use all required frontmatter fields, ISO review dates and inline lists. Review
handover and roadmap implications; explain unaffected contracts in the change
record. Keep Current behavior, Approved direction and Planned work distinct
within independently retrievable sections.

Run these repository checks and retain their outputs:

```sh
mkdir -p "$map_evidence/retrieval"
python tools/ci/check_docs.py
python tools/ci/check_repository.py --require-materialized
python tools/ci/check_m11_consistency.py
python tools/docs/retrieval_eval.py \
  --output "$map_evidence/retrieval/frozen.json"
python tools/docs/retrieval_eval.py \
  --queries docs/reference/retrieval-challenges.json \
  --output "$map_evidence/retrieval/challenges.json"
git lfs fsck
git diff --check
```

The [documentation workflow](../../.github/workflows/documentation.yml)
restores pinned companion-workspace documentation needed by existing links and
frozen questions. Reproduce that layout when those prerequisites are absent;
retain the existing questions and references.

Preserve the frozen retrieval fixture byte-for-byte for comparisons. Add
independent authoring questions to the supplementary challenges, retain existing
questions and disclose changed expectations. Review both canonical retrieval
ranks and whether returned contexts contain the required facts and qualifiers.
The [evaluator](../../tools/docs/retrieval_eval.py) reports a lexical BM25
baseline; its successful process exit does not enforce a minimum retrieval
score. The documentation checker also cannot establish runtime truth.

For a complete configured Linux run, the current hosted arrangement can be
reproduced with Xvfb and Mesa:

```sh
LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 GALLIVM_PERF=nopt \
  timeout 30m xvfb-run --auto-servernum \
  --server-args="-screen 0 1920x1080x24 -nolisten tcp" \
  python tools/ci/run_godot_regressions.py \
  --godot "$map_godot" --output "$map_evidence/full-suite" --keep-going
```

The runner records identities, discovery/shard planning, per-case logs and
`timings.json`. Its CLI has no focused-test filter. Normal hosted validation
uses four shards; confirm exact case coverage and the aggregate result.

On **actual Windows**, the separate retained-runtime gate accepts the pinned
official Windows Godot archive:

```powershell
$mapSource = git rev-parse HEAD
python tools/ci/run_windows_godot_regressions.py `
  --godot-archive C:\tools\godot-windows.zip `
  --expected-source-sha $mapSource `
  --output C:\map-evidence\windows
```

That [runner](../../tools/ci/run_windows_godot_regressions.py) verifies the
checkout/runtime inputs and executes applicable headless cases, recording
`windows-execution.json`. Windows cross-compilation, Windows headless execution,
Linux software-rendered pixels, browser execution and target-GPU performance
remain separate evidence scopes.

## Hand off a concrete acceptance record

Publish the exact candidate identity with links to the map entry point,
controls, source-backed mechanism descriptions and review images. Include
the expected exhibit roster and actual completed results, preserved negative
controls or failures, runtime and capture identities, commands, deadlines and
platform scope.

Read final CI case output as well as job conclusions. Confirm the intended
fixtures executed, their completion accounting passed and logs contain no
engine/script errors. For implementation changes, follow
[repository acceptance policy](../../AGENTS.md): make the PR ready for review
and obtain exact-head Documentation/provenance plus all applicable Native,
GDExtension/Godot and apparatus gates.

State separately what was implemented, integrated, verified and accepted,
following the [claims programme](development-claims-remediation-programme.md).
Record remaining blocked or unexecuted scope explicitly. A documentation-only
change supplies instructions and retrieval coverage; it does not create a new
runtime pass claim.
