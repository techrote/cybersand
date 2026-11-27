# ART-LOCAL-CLOSE-744 — bounded local-model responsiveness investigation

**Issue:** [#744](https://github.com/techrote/cybersand/issues/744).
**Source:** accepted main `00cdb02f103265b6dc5224c68283e9a0c8cb449f` (PR #727 included).
**Status:** Investigation fixture + bounded source diagnostics; physical Windows/NVIDIA cause **not yet established**. No claim that Godot responsiveness is repaired.

## Observed ownership boundary

The accepted Art window binds `close_requested` to `hide()`; the HTTP request
remains in flight. This is an existing semantic policy, **unchanged here**.
`HTTPRequest.use_threads` covers network work, not necessarily main-thread
`request_completed` processing and JSONL writes.

The provider's completion callback performs synchronous JSONL appends, JSON
parsing, redaction, and a synchronous `finished` signal. These operations are
plausible latency sources, but source inspection alone is not a measured cause
of the owner's physical Windows freeze.

## Constant-size instrumented values

`art_provider.gd::last_request_timing` tracks only the latest request:
dispatch and request log times, completion wait, response/other log times,
JSON parse time, total callback time, cancel time, response bytes, transport
status, HTTP status and provider category. It stores **no credentials, URL,
model prompt, full response, or past request list**. Values remain in memory,
and add no new session JSONL events or historical archive restore.

`art_batch_panel.gd::last_close_timing` records the synchronous close/hide
duration and in-flight request status. `last_stop_timing` records Stop cost.
No change to Stop, hidden-window continuation, native PAINT or save/load
semantics is intended.

## Deterministic offline fixture

`tools/ci/run_art_local_close.py` starts a loopback-only Python HTTP server
bound to 127.0.0.1, then executes the actual Godot 4.7 Shared Workbench and
mounted Art panel via `godot/tests/test_art_local_close.gd` with isolated
`user://` data. It exercises:

- Idle window close (baseline);
- Three invalid-model immediate-404 requests hidden immediately;
- Invalid-model 404 while the window remains open;
- Delayed 404 while hidden, and delayed 404 followed by reopening;
- Explicit Stop before closing a delayed request;
- Unreachable loopback endpoint;
- Known-valid local `[]` response while hidden.

Each case records request timing, synchronous close and Stop time, maximum
adjacent `process_frame` gap and elapsed time, without recording private
provider traffic. Each request is time-bounded. Unexpected >2.5-second frame
gaps and missing terminal/cancel receipts fail the fixture. One root Art JSONL
must persist across all cases, without drawing or sending cloud requests.

CI invokes this fixture on source-matched Linux and Windows Godot 4.7.
The original session-only Art regressions still run.

## Reproducing on physical Windows

To test the owner's reported NVIDIA/LM Studio freeze, run an exact-source
Godot 4.7 Workbench evaluator on the owner's Windows machine:

1. Open Workbench, select Art → Model prompt → LM Studio, turn **Image** off,
   and set a definitely unavailable model ID. Set an ordinary local endpoint.
2. Press **Send** and immediately close Art using X. Record the first
   responsive frame after closing and any screen freeze. Repeat with Art left
   open, Stop before X, and reopen before completion.
3. Record source commit, runtime DLL SHA, Godot version, actual local server,
   GPU load, response status and redacted JSONL. Do not record API keys.
4. Compare with the bounded loopback fixture's `art-close-report.json` and
   original Godot stdout logs. Note whether stalls occur in close/hide,
   `request_completed`, JSONL writes or outside the Godot process.

**Acceptance boundary:** Passing CI proves local deterministic transport,
window lifecycle and short hosted frame gaps. It **does not** prove the owner
Windows GPU freeze is fixed or identify LM Studio load contention. If the
physical issue persists, use these measurements to choose a narrow fix before
changing close-cancels-request semantics.
