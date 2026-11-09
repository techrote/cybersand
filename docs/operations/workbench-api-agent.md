---
title: Provider-neutral remote workbench API-agent runner
status: Planned
document-kind: runbook
scope: New Draft #547 consumer, provider/tool protocol, keyless qualification and bounded host execution
canonical-for: [workbench-api-agent-runner]
last-reviewed: 2026-11-09
related-documents: [atlas-agent-runner.md, github-development-and-release.md, documentation-maintenance.md, ../systems/shared-workbench-agent-authoring.md, ../../tools/remote_workbench/CODESPACES.md]
---

# Provider-neutral API workbench runner (Draft consumer)

## Desktop provider-runner integration candidate

The owner-requested isolated composition joins #531 head29988b7f with #552
headbe7b5d47 without MCP. The desktop backend operates the existing native World
through Godot's dispatcher; the same Python Runner owns provider calls, budget
reservations and model history. Logging, pacing and independent human Stop remain
in the UI. This is a Draft candidate, not merged production or accepted genuine
provider inference. The [independent reviewer supplement](../reviews/2026-11-08-workbench-agent-design-and-semantics.md)
explains design, tool effects, measured overhead and unresolved alternatives.

### Use from the development workbench

The owner-authorized desktop OpenAI profile may explicitly select
`spend.funding_mode: operator_authorized_desktop`, a positive per-call/run budget,
ceiling and authorization reference. This retains credential, model-availability,
verified-price, source and Budget checks without requiring an account-credit
attestation. Its receipt states that account credits are not verified. The default
attested-credit mode and remote CLI remain unchanged. `CYBERSAND_WB_PROFILE`
preselects a trusted local profile at panel startup; it never enables Live or
starts inference automatically.

Launch the project from a complete clean Git checkout, with Python 3 available
(`CYBERSAND_PYTHON` can select its executable). Open **Agent authoring**. Choose
OpenAI, NVIDIA or local Ollama, then **Profile…** to select your trusted JSON
profile. **Key…** accepts the profile's environment credential through a masked
local dialog; it is inherited only by this process's child and is never saved.
Private file credentials are supported on POSIX with ownership/mode verification;
Windows must use the environment/key dialog route. Selecting **Live** and pressing
**Start** authorizes an inference attempt within the chosen profile's gates.
Example cloud profiles intentionally lack funding approval; a key alone does
not make them runnable. Source/prices/credit checks can refuse before inference.
The clean-source gate compares both staged and unstaged content, refuses Git
errors or a moving HEAD, and ignores untracked caches as before. This avoids
Windows Godot-import stat-cache false positives without exempting import files
or accepting real source changes; no caller-supplied clean-source assertion is
trusted. Preserve the full Git checkout when distributing the development app.

Windows startup (2026-11-09 repair): source commands capture output into bounded
temporary-file reads, with detached console creation and an eight-second command
timeout. Captured pipes could keep waiting for inherited-handle EOF during
timeout cleanup even after Git exited. Startup now displays/logs profile, key,
source, spending and model-access phases, with a75-second startup watchdog that
revokes dispatch and requests native Stop. Python uses raw OS stdin/stdout for
its JSONL process, avoiding the buffered-stdin daemon lock at interpreter exit.
Stop can request native retirement while preflight is still blocked, before a
Runner exists; no timeout/process exit is substituted for a native ACK. The
keyless `test_workbench_agent_runner_startup.gd` exercises missing-key refusal,
restart and live-path Git checks with deliberately unauthorised dummy credentials,
so it reaches a funding refusal without contacting a provider. This is startup
qualification with a synthetic owner ACK, separate from the real-native gate.

For a keyless engineering check, select **Fixture** explicitly. It runs the same
Runner with scripted decisions, not a language model. The mounted automated test
installs the nine-then-eight scene, verifies original frames and native readback,
then starts a second child and injects human Stop during Step. A blank prompt or
arbitrary work area does not turn the fixed fixture into a general drawing agent.

The UI's API/Tools/Toks/Time/Cells/TPM controls are enforced by the desktop
configuration. Defaults remain 128 requests, 256 tools, 32,768 output tokens per
response and 180 seconds per request. Desktop hard caps are 4,096 requests,
8,192 tools, 131,072 output tokens and 65,536 cells per observation/edit; the
profile's other history, cumulative token, run-time, image and cash budgets also
apply. **Match area** sets Cells from W×H within that hard cap; it does not raise
the cap or grant access outside XYWH. Cells is a per-operation footprint, not a
lifetime edit allowance. Desktop tools permit up to eight disc/line/rectangle
operations per prepared edit. The separate HTTP runner contract below retains
its original 96-rectangle/4,096-cell bounds.

**Traffic…** retains the common Content/Event viewer, filters, copy and JSONL
export. Provider bodies are inspectable with credentials redacted and images
represented in traffic by hash/size metadata; original PNGs remain in the owned
session evidence. Pacing/response/native-ACK waits are explicit. Human **Stop**
revokes dispatch immediately and retires the native task independently of Python
or the provider. Wait for its acknowledgment and child cleanup before restarting.
Per-endpoint local rate reservations survive successive UI tasks; this estimate
cannot see other applications consuming the same provider quota.

## Current implementation and boundaries

Model-facing traffic trimming (2026-11-09): routine edit successes return status,
proposal handle when needed, and write/change counts. Distinct-cell counts are
included when different from changes; nonzero exclusions/reasons remain explicit.
Observations keep their handle, region/counts and native-to-image viewport mapping.
Material0=Empty and58=Hard Wall are explained once; palette names are returned only
for other materials actually present. Step includes completed/cumulative ticks and
its compact observation. Full identities, receipt hashes, per-cell evidence and
original PNGs remain locally validated/retained, not repeated in model results.
One initial instruction explains the summaries; old-image notices are short and
their original hashes remain in local evidence. Whole prior tool exchanges are
not silently deleted. Oversized necessary results refuse explicitly instead of
substituting a hash and dropping their view/count/error detail.

This new **one-controller** executable consumes the **already-running** #547 private remote workbench; it does not create a simulation, edit host authorization, provide a shell, register MCP or publish code. The host selects provider/model/endpoint/credential reference, capacity, material scope and acceptance criteria. Model-visible operations: **observe, prepare_edit, apply_edit, step** only. The operator retains **session and Stop**. The native owner remains authoritative for revision/generation, scope, protected cells and material provenance. A model's final text is never a verified edit.

The isolated implementation branch is stacked on the Draft #547 exact source; main's merged `tools/atlas_agent` is imported read-only for its **reserve-before-call Budget, rates and OpenAI credit gate**. Atlas's separate art editing/publishing permissions and validators are not imported. NVIDIA paid use requires host-supplied fresh model-specific rates, a verified funding attestation and an authorisation reference. Local model API spend is zero by design; GPU/electricity compute costs are **unknown**, not zero. Provider keys are environment variables or private 0600 files; key presence **never** authorizes a charge.

## Fast keyless validation (no model and no native service)

```bash
cd /workspaces/cybersand
python3 tools/workbench_api_agent_runner.py dry-run \
 --profile tools/workbench_api_agent/profiles/fixture.json \
 --task tools/workbench_api_agent/fixtures/nine-then-eight.task.json \
 --authorization tools/remote_workbench/fixtures/roundtrip-authorization.json
PYTHONPATH=tools python3 -m unittest -v workbench_api_agent.test_runner
```

Run tests from the `tools/` Python module search path (`PYTHONPATH=tools` when using the module form) or from an installed checkout. The tests exercise deterministic three-provider HTTP wire fixtures, actual non-streaming image payload construction and tool normalization, client request uncertainty, scope/material checks, provider refusal, bounded Stop and native-receipt projection. **No real provider inference occurs.**

## Profiles and capabilities

Profiles are trusted operator-authored JSON, never model-generated. The four example profiles are:

- `profiles/openai-responses.example.json`: exact OpenAI endpoint and example `gpt-6-luna` via **Responses**, host-selected model must exist in Atlas's verified rate table. Live calls require `--allow-live`, a nonzero explicit max, authorisation reference, fresh credit attestation, credential, model-availability probe and Atlas budget gate. `store:false` and complete explicit stateless history; no assumed `previous_response_id`.
- `profiles/nvidia-catalog.example.json`: NVIDIA-hosted **Chat Completions** via `integrate.api.nvidia.com`; `REPLACE_WITH_VERIFIED_VISION_AND_TOOL_MODEL` is intentionally **not executable live**. Select a real hosted model with tested image and function-call support, verify rates/credit manually, fill fresh host-only rates and funding attestation. Do not invent price zero or model availability.
- `profiles/ollama-qwen3-vl-8b.example.json`: named local Ollama 0.12.7+ `qwen3-vl:8b`, `/v1/chat/completions` on `127.0.0.1:11434`, no cloud credential. Ollama lists the model as vision + tools; a real deployment still needs independent tool+image inference qualification. No automatic model download, fallback or switch; model itself is several GB.
- `profiles/fixture.json`: scripted provider, not a trained model. This is **B-gate** input for true native source-built #547 verification and **A-gate** fixture testing, never accepted as C.

`capabilities.tools` and `.images` must both be true, and their actual requested wire formats must succeed during model qualification. `strict_tools` and `parallel_tools` control only the documented option fields on that endpoint; if unsupported they are omitted. Multiple returned calls, incomplete/truncated call arguments, unexpected models, JSON extracted from free-form prose, unsupported vision and missing usage fail closed. The `image_detail` profile choice is explicit (`low`, `high` or `auto`). Original PNG bytes are always retained; the model receives unmodified PNG data via base64 URI, not a simulated image. Previous images can be omitted **only with explicit on-history projection markers**; original hashes remain in local evidence rather than each marker. Context requests stop when byte limits would be exceeded.

## Actual Codespaces native workbench host

Create an authorized Codespace from the appropriate qualified stacked Draft branch (4-core / 8 GB minimum) or use an owner-authorized existing one; do not rebuild the owner's active Codespace without preserving work. After the existing `.devcontainer/post-create.sh` and SSH preflight complete, create a private bearer file using the owner-controlled `gh codespace ssh` stdin procedure in [CODESPACES.md](../../tools/remote_workbench/CODESPACES.md), then **in the Codespace**:

```bash
source ~/.cache/cybersand-wb/runtime.env
cd /workspaces/cybersand
python3 tools/remote_workbench/serve.py \
 --godot "$GODOT_BIN" \
 --authorization "$PWD/tools/remote_workbench/fixtures/roundtrip-authorization.json" \
 --token-file "$HOME/.config/cybersand/wb.token" \
 --state-root "$HOME/.local/state/cybersand-wb" \
 --xvfb --seconds 1740 --bind 127.0.0.1 --port 8765
```

On the **agent execution host**, run `gh codespace ports visibility 8765:private -c "$CODESPACE"`, then keep `gh codespace ports forward 8765:8765 -c "$CODESPACE"` running. The runner must execute *on that same host* (Linux/macOS/Windows WSL), with a separate 0600 bearer file. This is authenticated loopback transport; a web-browser GitHub login or GitHub repository access is not the tool connection. The agent host never needs Godot or a Windows editor.

## Real native B-gate with scripted model decisions (keyless)

```bash
python3 tools/workbench_api_agent_runner.py run \
 --profile tools/workbench_api_agent/profiles/fixture.json \
 --task tools/workbench_api_agent/fixtures/nine-then-eight.task.json \
 --authorization tools/remote_workbench/fixtures/roundtrip-authorization.json \
 --fixture-script tools/workbench_api_agent/fixtures/nine-then-eight.fixture.json \
 --base http://127.0.0.1:8765 --token-file "$HOME/.cybersand-wb.token" \
 --output "$PWD/build/wb-api-agent-native-fixture"
```

The scripted provider receives actual native observation IDs and proposal IDs, checks **nine real Hard Wall cells** before choosing a one-cell removal, inspects eight native cells after revision and runs four ticks on the same World. The controller retrieves and checks original PNG SHA256 before conveying it to provider. Native Stop is host-owned and mandatory. `receipt.json` records true result status, session/generation identity, original per-command native receipts, source/runtime evidence when provided, model-facing projection, usage and explicit remaining verification boundaries. The deterministic fixture is not proof of any commercial or local model performing inference.

Host-only `status` and `stop` operate without a model:

```bash
python3 tools/workbench_api_agent_runner.py status --base http://127.0.0.1:8765 --token-file "$HOME/.cybersand-wb.token"
python3 tools/workbench_api_agent_runner.py stop --base http://127.0.0.1:8765 --token-file "$HOME/.cybersand-wb.token" --request-id owner-stop-001
```

An interrupted model call or native receipt wait must not block Stop; the controller's signal handler sends Stop from an independent thread without acquiring the ordinary operation wait. A timed-out native mutation is **unknown**, never resubmitted with a fresh ID. Query the same request ID and inspect the existing receipt; if unknown, hold for operator review. After a session restart, all old proposals are invalid. A Codespace restart creates a new World; no evolved-state recovery is claimed.

## Genuine providers: C-gate (separate authorization)

To start a live configured profile, clone an example to a private operator-owned path, select exact qualified model and capability parameters, supply the credential via `OPENAI_API_KEY`/`NVIDIA_API_KEY` or 0600 file, enter fresh published model prices (NVIDIA), a signed-off budget/authorisation reference and the required current owner funding/credit attestation. Then use the **same** `run` command **without** `--fixture-script` and **with** `--allow-live`. No key presence implies consent to spend. Missing image support, tool calling, cost verification, model probe, credits or credentials block live operation.

The local Ollama profile requires a *real* server with `qwen3-vl:8b` loaded and an explicit `--allow-live` execution request; GPU power cost remains unknown. The named local model is **protocol selected**, not yet hardware-qualified. For NVIDIA catalog examples, do not set the illustrative 0 rates as a real price: these are deliberately rejected for live use.

**Acceptance levels are independent:**

- **A:** `test_runner.py` deterministic keyless provider/controller tests; fake provider and fake native are explicitly labelled.
- **B:** the separate source-built native Docker/Codespaces script fixture with original PNGs and receipts; no genuine provider call.
- **C:** three *individually* authorized real-provider smoke tests (OpenAI, NVIDIA hosted and named Ollama) with exact model/server, image+tool capability evidence, original native evidence, receipts/usage and attempts retained. Missing access stays NOT_RUN, never swapped with another provider.

Neither B nor C automatically discharges #531/#525's separate registered three live trials or Windows owner acceptance. No automatic source publishing, CI-provider migration, physics changes or scheduling work is permitted.

## Limits and failure / threat semantics

Host-selected defaults: 18 model calls, 30 tools, 900 seconds, 1024 output tokens/call, 32k input tokens/call, 160k cumulative input, 20k output, 8 original frames, 3 MiB each, 40 MiB evidence, 140k canonical-history bytes, 12k model-facing native result, 2 model rate retries and 6 total, 120 native ticks. Hard configuration caps: 64 model calls, 95 tools (Stop reserved), 3500 seconds, 4096 output tokens/call, 120k input/call, 1M cumulative input, 250k output, 24 frames, 8 MiB each, 100 MiB evidence, 240k history, 24k tool result, 12 total rate retries, 480 native ticks. Profiles freeze these at start. Atlas reserves worst-case tokens and USD before provider calls; 429 retries honor bounded Retry-After. Unknown 5xx/timeouts may still be charged and stay reserved, while native mutations are *never* reissued with new identity. Unknown rate is not zero. Stop is the host's independent call.

Secret safety is limited to a remote client whose authority consists of the private forwarded port and token. A process with unrestricted same-user Codespace shell access can bypass host-only files; **this is not a sandbox**. No host source files or publication endpoints are writable by this runner. Never include API tokens, bearer tokens, private key data or provider response bodies in PR/CI artifacts. The exact original image hash and native receipts are retained; any model-facing truncation is disclosed. Native/edit completion is based on declared counts, ticks, returned original images and acknowledged Stop, not the model's final prose.

## Design choices / integration ownership

A single controller with provider adapters was selected instead of MCP-first integration (optional future interface). The runner imports Atlas budget/pricing/credit enforcement rather than cloning or weakening it, but deliberately excludes Atlas art edits/patch/publishing operations. #547 remains the sole native transport and session owner; separate scripts never spawn a second World or expose credentials to models. Future visual-assessor roles can select another host profile without rewriting core tool/evidence history, but there is no multi-agent dispatcher in this milestone. Reversing this design means replacing adapter transport only, leaving native authorization unchanged.

Historical #545/#547 owner evidence remains valid on its exact heads, not on new provider-source changes. Record each new source SHA/tree, adapter fixtures, Python interpreter, actual image hashes, native/renderer identity, stopped/failed receipts and whether the provider was genuine. Run the documentation checklist and relevant focused validators before any Ready/merge transition; this branch remains Draft/HOLD.
