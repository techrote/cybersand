# CyberSand remote workbench file bridge — REMOTE-WB-001

**Status:** isolated #531 consumer / Draft engineering candidate. The remote
transport is not merged into `main` and does not replace the ordinary editor.
This is an implementation of **existing** native owner tooling, not a separate
simulation, API agent or controller. The external agent decides the operations;
this package supplies a bounded, real-workbench command surface.

## One GitHub-hosted batch job

Open **Actions → WB-REMOTE-001 real shared-workbench file bridge → Run
workflow** on the isolated branch, or use a pull request containing these paths
to trigger the same build. The job builds the native extension from its checked
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
