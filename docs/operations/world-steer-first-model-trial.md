---
title: Optional first local-model architecture trial
status: Current
document-kind: guide
scope: Executable offline preflight and an inert future model trial; genuine dispatch remains gated on the owned Art proposal route
canonical-for: [architecture-first-local-model-trial]
last-reviewed: 2026-11-24
related-documents: [world-steer-collaborative-architecture.md, ../systems/architecture-proposal-owner-seam.md]
---

# Optional first local-model architecture trial

**Offline preflight remains runnable.** The coherent mergedown candidate adds the [Art-owned disclosure and Send route](../systems/architecture-proposal-owner-seam.md) in ordinary Architecture. **Intent and tasks → Inspect region + propose options** still uses the deterministic offline planner. The new route uses the existing Art settings, with no automatic call. Its complete resulting-source qualification and a concrete approved local endpoint/model remain prerequisites for a genuine trial; the separate frozen evaluators do not establish this combined application.

The inert [versioned trial protocol](../audits/2026-11-24-world-steer-m6-m7/owner-local-model-trial.v1.json) fixes three briefs and one authorized local request per brief. It cannot dispatch a request, approve construction or change production defaults. Its tighter trial limits are requirements for the future operator/owner adapter; they are not new automatically enforced global application limits. It authorizes no paid or cloud provider; those need separate owner authority and a specified budget.

## Run the offline preflight

Use the exact qualified Architecture source with its materialized native/Rapier runtime, or run from the extracted Windows evaluator directory containing `godot/` and the bundled console executable. These five fixtures exercise typed planning, bridge correlation, finite campaigns, Workflow approval/staleness and compositional retrieval. Their provider responses are controlled fixtures; they make no HTTP/model requests and do not create native construction Worlds. The import step prepares ordinary Godot resource caches.

**Windows PowerShell, from the extracted evaluator root:**

```powershell
$architectureGodot = (Resolve-Path '.\Godot_v4.7-stable_win64_console.exe').Path
if ((& $architectureGodot --version).Trim() -ne '4.7.stable.official.5b4e0cb0f') {
    throw 'Use the qualified pinned Godot 4.7 executable.'
}
$architectureProfile = Join-Path $env:TEMP ('cybersand-architecture-preflight-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $architectureProfile | Out-Null
$architecturePriorAppData = $env:APPDATA
$architecturePriorXdg = $env:XDG_DATA_HOME
try {
    $env:APPDATA = $architectureProfile
    $env:XDG_DATA_HOME = $architectureProfile
    & $architectureGodot --headless --path godot --editor --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
    foreach ($architectureTest in @(
        'test_architecture_planning_adapter', 'test_architecture_proposal_bridge',
        'test_architecture_campaign', 'test_architecture_workflow',
        'test_architecture_compositional_retrieval'
    )) {
        & $architectureGodot --headless --path godot --script "res://tests/$architectureTest.gd"
        if ($LASTEXITCODE -ne 0) { throw "Offline preflight failed: $architectureTest" }
    }
} finally {
    $env:APPDATA = $architecturePriorAppData
    $env:XDG_DATA_HOME = $architecturePriorXdg
}
```

**Linux Bash, from the qualified source root:** set the first line to the pinned executable's actual installed path.

```bash
architecture_godot=/absolute/path/Godot_v4.7-stable_linux.x86_64
test "$("$architecture_godot" --version)" = '4.7.stable.official.5b4e0cb0f' || exit 1
architecture_profile="$(mktemp -d -t cybersand-architecture-preflight.XXXXXX)"
XDG_DATA_HOME="$architecture_profile" "$architecture_godot" --headless --path godot --editor --quit || exit 1
for architecture_test in test_architecture_planning_adapter test_architecture_proposal_bridge \
  test_architecture_campaign test_architecture_workflow test_architecture_compositional_retrieval; do
  XDG_DATA_HOME="$architecture_profile" "$architecture_godot" --headless --path godot \
    --script "res://tests/${architecture_test}.gd" || exit 1
done
```

Require exit zero and each suite's completion marker with zero failures; retain the output with the exact source and runtime hashes. Fixtures use copied synthetic observations and never certify a genuine native inspection or model capability. The actual application/native/graphical qualification remains the separate hosted campaign. `run_art_provider_local.gd` is a different ordinary-Art harness that sends multiple requests and applies drawing responses; it is not this one-request-per-brief preflight.

## Prepare the three-request trial after the handoff

The protocol fixes a paused Empty 512×512 World and a 256×192 inspected region at `[32,32,256,192]` for each brief. Start from a fresh Empty World for each case and capture its actual native source, generation and revision. The briefs ask for an unequal-bay industrial workshop, a service gallery around a central shaft, and a viaduct with two unequal openings. Each has explicit Empty clearance rectangles; no contradictory source geometry is prescribed.

The mission already authorizes this bounded trial on an approved existing local model when it is actually available. Identify that approved model and concrete literal-loopback server, verify local execution, and complete the exclusive proposal-only route before dispatch; no renewed permission is required for the already-authorized scope. Paid or cloud requests remain unauthorized. The retained observation identifies no available approved local endpoint/model. The later mergedown candidate supplies the owned route, but no genuine-model trial or creative acceptance is inferred from its deterministic native regression.

The ceilings are **three requests total, one response alternative, 4,096 output tokens and 120 seconds per request, no automatic retry or follow-up**. Each response may propose at most three native stages, 8,192 checked cells per stage and 24,576 per brief, with Hardwall58 and Metal28. The first trial uses finite typed native operations; module selection and delegated-worker generation are outside its measured scope. The complete profile, byte/raster limits, briefs, clearances and failure categories are in the JSON protocol.

Before adoption, check the protocol's tighter envelope and all required clearances in every stage. A missing declaration or exceeded limit refuses the response. The host then independently compiles exact footprints, source permissions, protection and actual costs. A model's own cell count is never authority. Select an admitted alternative, use **Review selected native task**, then **Inspect + zero-write preview** and **Approve stage** for each ready stage. Cancel or skip when the result is unsuitable. A queued operation remains queued until its actual native terminal and readback arrive.

Keep the first response unchanged for evaluation. A later manual repair is an owner-revised plan with its own identity; it does not convert the original response into a model success. A timeout, ordinary text, invalid schema, stale source, host refusal, skipped decision or partial native result stays in the three-brief denominator. Stop on an unexpected endpoint/model, native refusal/partial result or protection discrepancy; retain the acknowledged result and mark remaining briefs unattempted after Stop. Do not replace failures with extra calls or fixtures.

## Exact engineering handoff

The mergedown host supplies exclusive `dispatch(request, completion, guard)` and scoped `cancel(provider_id, request_id, reason)` callbacks to `ArchitectureProposalBridge.bind_owner_seam`, plus the trusted live-context guard, only after the owner reviews and explicitly sends the disclosed request. The qualified Provider's optional eleventh `pre_dispatch_guard` argument must receive that guard, covering asynchronous preparation. Its completion must enter only the owned Architecture callback; it must not also reach ordinary Art auto-paint. Existing provider credentials, transport and conversation ownership stay with Art.

The owner entrypoint must visibly identify genuine proposal transport rather than retain the current offline-only caption. With the reviewed hook bound, the existing executable facade can request the registered case through:

```gdscript
# Owner integration code only: `workflow` is the existing bound live facade.
# This is not a current GUI command or a standalone model launcher.
await workflow.propose_intent(
    {"text": brief.intent, "family": brief.family, "seed": brief.host_seed},
    Rect2i(32, 32, 256, 192),
    {"mode": "proposal_transport", "max_alternatives": 1, "materials": [58, 28]}
)
```

The owner adapter supplies the protocol and typed response contract, enforces this trial's smaller envelope, and retains genuine transport/model evidence. The response must use `cybersand-architecture-proposal-v1`, echo the exact request ID, inspection digest and generation, and contain a finite typed campaign. The bridge and Workflow correlate it and fence stale observations; neither approves it. Record the actual future integrated source and hook qualification before using this protocol. The current frozen application is not silently reclassified as that future integration.

Root's read-only check at `2026-11-24T23:13:26Z` found no `ollama` executable and a refused connection to `GET http://127.0.0.1:11434/api/tags` in the current executor. It sent no prompt or inference request. This does not describe the owner's machine or every possible provider. The primary product gate remains the missing owned proposal route and its truthful UI mode, not a fabricated claim that all local model access is impossible.

## Retain and assess the evidence

Retain the protocol SHA, exact source/tree and Godot/native/Rapier identities, actual before/after material planes, native inspection and request IDs, exact context/card identities, and original response and typed-plan hashes. Keep complete sanitized request/response evidence through the existing owner audit; the bridge's bounded text prefix alone is not a complete response archive. Retain actual requested/returned model IDs, server/model build or weights identity when available, finish reason, elapsed time and token usage—or explicitly unknown usage. Exclude credentials and private provider configuration. The current Provider does not set sampling temperature or a model sampling seed; the registered host seeds are not a determinism claim.

Keep proposal admission, host preview, owner decision and native completion as separate outcomes. Native receipts and full readback establish applied geometry; original Godot frames support visual review. Static contact, visual appearance, actual actor traversal and physical owner acceptance remain separate. Three exploratory requests support a descriptive first-use report, not prompt optimization, causal retrieval advantage, broad architectural-quality claims or a blind preference result.
