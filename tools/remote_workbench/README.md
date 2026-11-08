# CyberSand remote workbench file bridge — REMOTE-WB-001

**Status:** isolated #531 consumer / Draft engineering candidate. The remote
transport is not merged into `main` and does not replace the ordinary editor.
This is an implementation of **existing** native owner tooling, not a separate
simulation, API agent or controller. The external agent decides the operations;
this package supplies a bounded, real-workbench command surface.

## One GitHub-hosted batch job

A **Draft pull request touching these paths** triggers the dedicated build
on its exact immutable PR head. The workflow also declares trusted-host
`workflow_dispatch` inputs (`authorization_json`, `commands_jsonl`) for
custom batches and a `workflow_call` ingress. GitHub only exposes manual
`workflow_dispatch` once the workflow file exists on the default branch:
**while this is a Draft stacked PR, use its pull-request runs** or the local
CLI rather than assuming the new workflow appears in the main Actions list. The job builds the native extension from its checked
out exact source, downloads the hash-locked Godot 4.7 binary, runs Godot under
Xvfb/actual OpenGL, and retains original matched render PNGs and native receipts.

Local equivalent (Linux, with *source-matched* native and Rapier shared objects
already installed and the locked Godot 4.7 editor available):

```bash
python3 tools/remote_workbench/test_protocol.py
godot_bin=/path/to/Godot_v4.7-stable_linux.x86_64
timeout 180 "$godot_bin" --headless --path godot --editor --import --quit
python3 tools/remote_workbench/run.py --xvfb --godot "$godot_bin" \
  --authorization "$PWD/tools/remote_workbench/fixtures/roundtrip-authorization.json" \
  --commands "$PWD/tools/remote_workbench/fixtures/roundtrip-commands.jsonl" \
  --evidence "$PWD/build/wb-remote-local" --timeout 480
python3 tools/remote_workbench/verify.py --roundtrip \
  --evidence "$PWD/build/wb-remote-local"
```

Do **not** supply `--headless` to the runtime execution. Only initial
**import** uses headless Godot. Verify first that the native binary is actual
Linux ELF and not a Git LFS pointer. The default workflow's separate native
hopper control uses the *unchanged* v2 source fixture SHA256
`549a1db2520bcfb35f068f46b62320d7325d6297037ca2faf23c3b488d80347c`.
Its +512 translated control has 26 intermediate NORMAL occupancy differences
but retains 32 native Sand, 17 protected walls and the 480-total-tick limit;
it does **not** assert original signed-trajectory equivalence or change physics.

## Host authorization and model-visible commands

The trusted operator selects the starting construction, region, protection
and output allowlist in a **separate** versioned JSON file before launching.
This file is never included in the model's tool schema. Example:

```json
{
  "version":1,
  "task_id":"small-test",
  "extent":[512,512],
  "scope":{"x":24,"y":24,"width":48,"height":48},
  "protected":[{"x":66,"y":66,"width":3,"height":3}],
  "allowed_materials":[0,58],
  "start_edits":[],
  "camera_origin":[0,0]
}
```

The trusted host may pre-author Sand via `start_edits` following the
existing named-start rectangle representation
`[x, y, width, height, material_id]`; the **agent** may only write
Empty(0)/Hard Wall(58), may not edit Sand, and must pass all native
scope/protection/source/revision/generation checks. The native owner, not the
transport, grants authority. Start edits are a *construction recipe*, never
a persisted evolved native simulation state.

The **agent** writes one JSON object per complete LF-terminated line to a
strictly append-only JSONL file; all commands have `version:1`,
strictly increasing `seq`, `tool`, `args`; optional `expect_status` is
a batch assertion. Supported tools are only:

| Tool | Args | Owner guarantees |
| --- | --- | --- |
| `observe` | `{"region":{"x":28,"y":28,"width":8,"height":8},"detail":"cells"}` | ≤4096 native cells and exact matched post-draw PNG |
| `prepare_edit` | `{"observation_id":"@last","operations":[{"shape":"rectangle","x0":30,"y0":30,"x1":32,"y1":32,"material":58}]}` | bounded footprint, no mutation, native source/protection check |
| `apply_edit` | `{"proposal_id":"@last"}` | native readback, idempotent receipts, authored-start recording |
| `step` | `{"ticks":4}` | 1–120 per call, ≤480 completed ticks this session, matching after-tick native+frame |
| `stop` | `{}` | waits for real native task retirement; subsequent mutations refused |

The convenience identifiers `@last` are substituted **only** for the most
recent acknowledged observation/proposal ID; the owner still validates
identity. Ordinary explicit IDs are accepted. An unconfirmed edit is never
automatically retried. Unrecognized commands and shell/filesystem/network
operations are not available to the agent.

## Live process versus Actions batch

The exact same launcher supports `--live` with one persistent Godot/World
process and a JSONL file that an external agent can append to. The agent
reads the flush-on-receipt `results.jsonl` between actions and can inspect
individual original PNGs in `frames/`. It **must not** rewrite/truncate or
replace previously issued JSONL, and must explicitly `stop` when done.
The bounded hosted batch feeds a *complete predeclared* command sequence
instead, executes in one Godot/World and terminates, uploading its artifact;
every subsequent workflow dispatch is a **new** World/job, not continuation
of the previous physics state.

The trusted process launcher accepts file paths and an optional `--xvfb`,
but the **model-visible interface never accepts paths, arbitrary file
operations, shell commands, HTTP addresses or credentials**. This is a
file bridge, **not** an always-on remote public HTTP endpoint: remote users
without a host connection operate it by submitting an authorized job to
Actions. GitHub-hosted minutes/storage are not free model tokens; no OpenAI
key or paid model call is required for these operations.

## Evidence, failures and acceptance

`launcher-identity.json` retains exact commit/tree, native/Rapier/Godot
SHA256, host authorization digest, command input digest, platform, CLI mode
and budget. `results.jsonl` retains full owner/native receipts and failure
statuses; `frames/*.png` retains **unmodified original post-draw bytes**;
`manifest.json` contains their SHA256 and full native render identities;
`verification.json` is independent decoded-pixel/native-result analysis.
A true source-built run also retains compiler logs and the locked dependency
manifest. The CLI returns nonzero on failure/unconfirmed results and does
not equate successful JSON serialization with graphical or native acceptance.

The committed roundtrip:
authorize → observe → prepare nine Hard Wall cells → apply/readback → observe
post-edit PNG → Step four native ticks + matched frame → observe → Stop →
refuse late apply. It must pass with **actual rendered pixel changes**, not
only synthetic status checks. The moved hopper is a separate pre-registered
native-control lane, not a different acceptance target.

**Not provided:** a hosted persistent service across workflow jobs, HTTP
public port, external generic shell, task-scope approval by the agent,
evolved state save/replay, genuine model API trials or owner's Windows human
graphical verdict. The panel's ongoing owner work in Draft #531 and separate
PAINT-001 source ownership are not modified.

## Integration request

The bridge consumes new paths `godot/tools/remote_workbench_batch.gd`,
`tools/remote_workbench/` and new CI workflow only. It loads the existing
`main.tscn` and `workbench_agent_four_tool_bridge.gd` directly, without
changes to `main.gd`, `shared_workbench.gd`, worker, native sources or
PAINT-001. The narrow integration seam requested of the #531 owner is **only**
a stability check that a standalone SceneTree may bind and run the existing
four-tool bridge on the current head; no new Godot patch or concurrent edit
ownership is requested.


## 8 November 2026 remediation: source-specific local contract (Draft)

This layer is **trusted/cooperative local file ingress**, not authenticated
network access, a sandbox or a security boundary against unrestricted same-user
host filesystem/shell access. Keeping the versioned authorization in a separate
file ensures the five workbench tools cannot modify it *through this protocol*.
A process able to modify or read arbitrary files as the host user may instead
alter that file, substitute the launcher, impersonate the command writer, read
receipts or change the runtime. Do not claim otherwise.

**Prompt 2 Codespaces transport responsibility:** keep its network service
private by default; authenticate and authorize the *real external client path*
before translating commands; enforce that an unauthenticated agent cannot
reach host-only authorization/session limit inputs or arbitrarily access the
host filesystem. An HTTP listener, GitHub sign-in response, or a browser login
alone is not authentication proof. Transport/client/container sources are
separately owned; no direct edits to this existing launcher or Godot engine
without an explicit coordination handoff on Draft #545.

**Host-owned inputs, never agent command fields:**

- Version-1 authorization JSON: `task_id`, `extent`, `scope`,
  `protected`, `allowed_materials`, optional `start_edits` and camera,
  loaded exclusively at session startup. Canvas sides follow actual editor
  `Setup.validate`: **512–2048 cells, multiples of 64**. Python preflight
  reads that rule from the current source and fails closed if it changes;
  Godot also calls `Setup.validate` before constructing the World.
- Launcher `--timeout` is the total hard wall budget (60–1840 seconds).
  It supplies Godot an internal deadline exactly **30 seconds earlier**,
  counting initialization, commands and retirement. The remaining wall
  budget is for Stop, flush and child-tree cleanup. On expiry or external
  SIGINT/SIGTERM, the Linux launcher signals **its own** process session/group,
  waits up to five seconds, escalates SIGKILL if needed and checks that no
  executable group member survives. Nothing kills by process name.
  SIGKILL or host crash against the *launcher* cannot guarantee cleanup.
- `--evidence-limit-bytes` (13 MiB–512 MiB, default 128 MiB)
  is a finite host-only ceiling on cumulative evidence. Godot reserves one
  maximum 8 MiB original PNG, one 4 MiB native receipt, 1 MiB side-output
  headroom and 64 KiB terminal headroom **before** each operation.
  On insufficiency it returns an explicit refusal *before any native mutation*,
  records the failure and attempts native Stop. The launcher additionally
  polls **all** retained files, including `godot.log`, and terminates its
  group if the total approaches the ceiling. A successful mutation's native
  result is flushed before advancing completed progress. An unconfirmed result
  is never treated as accepted or blindly retried.

**Agent-writable ingress:** only the already-created append-only UTF-8 command
file. Each complete LF-terminated line is one version-1 `seq/tool/args`
envelope with one of the five tools. No host task, evidence path, deadline,
evidence limit, shell command or credential can be set in that envelope.
One ordered writer is required. Sequence numbers must **strictly increase**;
gaps are allowed, repeated or regressing numbers are a fatal stream error,
not replay or a second native mutation. Changing, truncating, replacing or
rewriting the consumed prefix also fails the session closed. A partial final
line is ignored until its LF arrives. An invalid complete JSON line is fatal
and ends the session after the retirement attempt. The original bytes supplied
at launch and every persisted receipt remain retained.

**Result access:** `results.jsonl` gives flushed native/host receipts,
including the `seq`, owner status and original `frame` path;
`frames/*.png` are unmodified matched post-draw bytes. A client must pair
result sequence and render/native identity rather than poll only the PNG
filename. `manifest.json` is terminal acceptance/failure output;
`cleanup-result.json` identifies process group, termination reason,
SIGTERM/SIGKILL escalation and confirmed owned exit status;
`process-result.json` records wrapper exit and evidence totals.

**Health:** atomically replaced `session-health.json` reports opaque
`session_id`, `godot_pid`, mode, state, monotonic last-heartbeat time,
`last_completed_seq`, cumulative native completed ticks, last known native
generation/tick and used output bytes. This is **not a native receipt**.
A fresh heartbeat only means the Godot event loop is running, not that
an edit or Step completed. The last-completed sequence advances after its
receipt flush; inspect that result for application certainty. When the
supervisor returns, it records `launcher_alive:false`,
`process_group_exited` and the precise shutdown reason even if the Godot
manifest could not be produced.

**Disconnect/reconnect:** files have no socket connection concept. Client
death or disconnect does **not** end the host-owned, time-bounded World.
A replacement client with access to the same ingress/results may inspect
session health, read the last completed receipt, and append the **next new**
sequence, within remaining host deadline/evidence limits. It must never
rewrite prior commands or assume a receipt was applied solely because a
request was sent. Disconnect authentication, isolation, concurrent writer
arbitration and network retry are explicitly **Prompt 2's transport gates**.

**Evidence and qualification:** The previously accepted historical native
nine-cell result changed 198 decoded framebuffer pixels under its recorded
renderer; this is **not** a fixed cross-renderer pixel threshold. The current
verifier requires native readback of the exact cells and a nonzero changed
pixel witness inside their actual owner-reported projected canvas rectangle,
with a separate unchanged on-canvas control. Its synthetic negative control
tests that changes elsewhere cannot make that edit pass. A standalone
`test_live.py` launches one *actual* Godot/native World, uses a separately
spawned client process to examine the first native/PNG result before editing,
abruptly kills that client, reconnects with a different client process,
applies a second revision, Steps, observes and Stops. It also runs actual
Godot/Xvfb negative sessions for duplicate, malformed, rewritten, exhausted
and interrupted input, plus a test-injected hard supervisor timeout.
Neither the old batch pass nor a synthetic transport demonstration satisfies
that incremental gate; consult exact-head CI artifacts for its actual outcome.

**No merge/Ready authority:** the upstream #531 Source and owner Windows/live
model acceptance, Codespaces external authentication, combined-source
independent QA and exact-head execution remain separate gates.
