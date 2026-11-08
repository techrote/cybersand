# CyberSand remote workbench in GitHub Codespaces

**Status:** development-only transport consumer. Final acceptance is blocked until
PR #545 publishes a corrected, source-specific live-session head and this branch
is recomposed onto it. Do not treat the current branch ancestry as final live
qualification.

## Threat model

The HTTP service is a narrow interface for a client that can reach only the
forwarded TCP port and possesses the bearer token. It exposes session status,
five existing workbench commands, request receipts and original retained PNGs.
It does not expose the host authorization path or an endpoint that mutates
authorization.

This is **not** a security boundary against an agent or process with unrestricted
same-user shell/filesystem access inside the Codespace. Such a process can read
same-user files, including the token and host authorization, and can bypass this
transport. The supported boundary is remote-command-client versus trusted host
process/filesystem.

The service binds loopback only. Codespaces port visibility is private. Do not
publish the port. A private `*.app.github.dev` URL that returns GitHub login is
not an API qualification path; the intended external path is a
`gh codespace ports forward` tunnel followed by bearer authentication at the
CyberSand service itself.

## Container preparation

`.devcontainer/Dockerfile` pins the Microsoft Noble devcontainer image by OCI
digest. The post-create step materializes only the required Linux Rapier LFS
runtime and verifies its repository-qualified SHA-256, installs SCons from the
hash-locked requirement, checks out the pinned godot-cpp commit, builds the native
extension from the checked-out CyberSand source, verifies the existing Linux ABI
floor, restores the checksum-locked official Godot 4.7 editor, imports the
project, and runs the pure protocol/transport tests.

After creation:

```bash
cd /workspaces/cybersand
source ~/.cache/cybersand-wb/runtime.env
"$GODOT_BIN" --version
```

Final acceptance must record `git rev-parse HEAD`, `git rev-parse HEAD^{tree}`,
the corrected #545 source SHA consumed, Rapier SHA-256, native SHA-256 and Godot
SHA-256.

## Token setup without command-line disclosure

On the **external client host**:

```bash
CODESPACE='<codespace-name>'
umask 077
python3 -c 'import secrets; print(secrets.token_urlsafe(48))' > "$HOME/.cybersand-wb.token"
gh codespace ssh -c "$CODESPACE" \
  'install -d -m 700 ~/.config/cybersand && umask 077 && cat > ~/.config/cybersand/wb.token' \
  < "$HOME/.cybersand-wb.token"
```

The token is passed on standard input, not a process argument. The service and
client both require the token file to be owned by the current user with no
group/other permissions.

## Start one persistent World

In a Codespace terminal:

```bash
cd /workspaces/cybersand
source ~/.cache/cybersand-wb/runtime.env
exec python3 tools/remote_workbench/serve.py \
  --godot "$GODOT_BIN" \
  --authorization "$PWD/tools/remote_workbench/fixtures/roundtrip-authorization.json" \
  --token-file "$HOME/.config/cybersand/wb.token" \
  --state-root "$HOME/.local/state/cybersand-wb" \
  --xvfb --seconds 1740 --bind 127.0.0.1 --port 8765
```

That process launches one upstream `run.py --live` owner, hence one Godot/native
World. HTTP requests append to that one owner's command stream; no request
launches a simulation.

## External access and client

On the external client host, keep this foreground tunnel running:

```bash
gh codespace ports visibility 8765:private -c "$CODESPACE"
gh codespace ports forward 8765:8765 -c "$CODESPACE"
```

In another external shell, from a checkout containing the matching `client.py`:

```bash
python3 tools/remote_workbench/client.py \
  --base http://127.0.0.1:8765 \
  --token-file "$HOME/.cybersand-wb.token" session
```

A missing/wrong bearer token must return
`401 bearer_authentication_required`. A successful `/v1/session` response
through this **actual external tunnel** proves the client reached CyberSand,
not a GitHub login page. The client accepts only a loopback HTTP endpoint,
never follows redirects, bypasses HTTP proxies, and refuses an HTML login
page or malformed JSON. The GitHub CLI tunnel authentication and CyberSand's
own bearer token are separate layers. A remote `*.app.github.dev` URL is not
an allowed direct `--base` target.

Commands are submitted with an explicit idempotency key. Example:

```bash
SID="$(python3 tools/remote_workbench/client.py \
  --base http://127.0.0.1:8765 \
  --token-file "$HOME/.cybersand-wb.token" session \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["session_id"])')"

python3 tools/remote_workbench/client.py \
  --base http://127.0.0.1:8765 \
  --token-file "$HOME/.cybersand-wb.token" \
  call observe --session "$SID" --request-id req-observe-0001 \
  --args '{"region":{"x":28,"y":28,"width":8,"height":8},"detail":"cells"}'
```

Do not blindly retry a POST after a connection failure. `client.py` reports
`submission_outcome_unknown` with the stable request ID. Reconnect, query that
request ID, and only if it is unknown resubmit the **identical** command with the
same request ID. Reusing an ID for different command content is refused.

Use the `frame.path` returned in an acknowledged receipt to retrieve original
PNG bytes:

```bash
python3 tools/remote_workbench/client.py \
  --base http://127.0.0.1:8765 \
  --token-file "$HOME/.cybersand-wb.token" \
  frame 001-observe.png --output ./001-observe.png --sha256 '<sha256-from-receipt>'
```

## Stop

Submit native Stop through the same client:

```bash
python3 tools/remote_workbench/client.py \
  --base http://127.0.0.1:8765 \
  --token-file "$HOME/.cybersand-wb.token" \
  call stop --session "$SID" --request-id req-stop-000001 --args '{}'
```

A `202 pending` Stop is queued intent, **not** native retirement. Poll that
request through its native receipt. The service process exits successfully only
after the upstream owner records acknowledged retirement and a passing Stop
manifest. If bounded
graceful retirement fails, the transport marks the session `unconfirmed` and
terminates its process group; forced cleanup is never represented as acknowledged
native Stop.

## Session, restart and Codespace limits

Each service start has a new `session_id`; the native authorization receipt
supplies the underlying World generation. Old HTTP requests are rejected against
a new service session, and the native owner remains responsible for proposal
revision/generation fencing.

A client disconnect does not stop the World. Reconnect to the same tunnel and
session and query the existing request ID. A Codespace stop/restart, service
restart, container rebuild or host crash terminates process state. Files under
the Codespace may persist after an ordinary stop, but they are evidence only:
CyberSand does **not** restore the evolved World from them. Restart creates a
fresh session/World and must not be described as evolved-state recovery.

## Final same-container qualification commands

These commands are **final-source only**: run them after #547 has been recomposed
onto the released, green #545 head and the pinned post-create runtime has been
prepared. They do not exercise the GitHub Codespaces tunnel itself.

```bash
cd /workspaces/cybersand
source ~/.cache/cybersand-wb/runtime.env
rm -rf build/wb-remote-codespaces-live
python3 tools/remote_workbench/qualify_live.py \
  --godot "$GODOT_BIN" \
  --authorization "$PWD/tools/remote_workbench/fixtures/roundtrip-authorization.json" \
  --output "$PWD/build/wb-remote-codespaces-live" \
  --display-mode xvfb
```

The required ordinary host/human stale-proposal control is the existing owner
test, not a new privileged remote endpoint:

```bash
mkdir -p build/wb-remote-codespaces-live/human-owner
WB_AGENT_EVIDENCE_DIR="$PWD/build/wb-remote-codespaces-live/human-owner" \
  timeout 360 xvfb-run --auto-servernum \
  --server-args='-screen 0 1920x1080x24 -nolisten tcp' \
  "$GODOT_BIN" --path godot --rendering-method gl_compatibility \
  --script res://tests/test_workbench_agent_owner.gd \
  2>&1 | tee build/wb-remote-codespaces-live/human-owner.log
grep -E 'WB_AGENT_OWNER: [0-9]+ assertions, 0 failures' \
  build/wb-remote-codespaces-live/human-owner.log
```

That owner test prepares a real native proposal, admits an ordinary human Hard
Wall brush through the existing workbench, verifies `stale_proposal`, preserves
the human cell through native readback, and retains matched original framebuffer
PNG evidence when `WB_AGENT_EVIDENCE_DIR` is set.

## Final acceptance still required

After corrected #545 is released, refresh #531 and #545, compose this branch
onto that exact #545 head, then demonstrate from a separate client process
against one World:

`observe -> prepare/apply edit -> inspect PNG/native receipt -> revise -> step -> inspect -> Stop`

Also retain measured evidence for duplicate request/no duplicate mutation, stale
proposal after host/human intervention, disconnect/reconnect, service restart
refusing old session/proposal, Stop queued during an outstanding operation, and
the actual Codespaces tunnel authentication path. Until that source-specific run
exists, Codespaces native connectivity remains unverified rather than inferred
from local/container transport tests.

## Source coordination and custody hold

#545's remediation owner owns the existing launcher, JSONL engine, verifier
and their original regressions. This branch owns only the new transport,
client, container, documentation and dedicated CI paths. Final composition
must use the **exact released** upstream source, never transplant historical
copies of its owned files. #545 now has a **candidate** host-only process-custody seam:
`launcher-process.json` binds the launcher PID and separate Xvfb/Godot process
group to the opaque owner session and the Linux group leader's `/proc` start
ticks. This transport contains a guarded consumer: after an abnormal launcher
exit it may signal only that exact still-live group after session/PID/start-time
revalidation; a missing or mismatched identity is quarantined as unconfirmed
and is never killed by process name.

That consumer is deliberately not counted as qualified on the current stale
stack: its positive orphan-reap and PID-reuse-refusal tests are skipped until
the final released #545 head is composed. A catastrophic parent death in the
upstream spawn-to-custody-publication window also remains outside the file
seam; a hard guarantee for that interval requires independent cgroup/container
custody. Therefore catastrophic process-tree cleanup remains **NOT_RUN** until
the final source-specific run records the supported cases and limitations.

