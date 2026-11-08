# CyberSand Workbench: private, model-neutral MCP tool adapter

**Status: isolated Draft consumer of #547, not a completed ChatGPT connection.**
This directory is independently owned; it does not modify #545's native/JSONL
engine, #547's HTTP service/client, host task authorization, or the simulation.
The branch is stacked on #547 `2b6b8f4ae7da631a81d7393ed01c7940f54bfe93` (includes
the later SSH container prerequisite); the **measured external-native transport**
checkpoint remains #547 `08e79b7bca7f18c78e3dd8254ac992e014160226` on #545
`b7c6204625dad14fdf15430f7872d9841cf92afd`. Recheck current PR heads
before running or composing. See `../CODESPACES.md`, `../README.md`,
`../../../docs/systems/shared-workbench-agent-authoring.md` and `AGENTS.md`.

## Architecture and limits

`ChatGPT (or another MCP host)` → **authenticated OpenAI Secure MCP Tunnel** →
`tunnel-client (trusted external host)` → `127.0.0.1:8766/mcp`
(**this adapter**) → **actual** `../client.py` → `127.0.0.1:8765`
(authenticated GitHub CLI private port tunnel) → #547 `serve.py` in the
Codespace → #545 `run.py --live` → existing Godot/native World.

- The adapter starts **no World**, cannot change task scope or host protection,
  does not execute model calls, and accepts no model-supplied URL, path,
  credentials, executable, authorization, or budget overrides.
- The trusted host owns three separate trust credentials: GitHub's CLI identity,
  the **workbench** bearer, and the **adapter** bearer. The OpenAI tunnel runtime
  key is a fourth credential used only by `tunnel-client` to reach its control
  plane. Never put them into model tools, repository files, transcripts, PRs,
  or the Codespace URL.
- Upstream `client.py` still requires a loopback URL; both the workbench and
  adapter HTTP listeners bind `127.0.0.1`, never `0.0.0.0`. Do not change a
  Codespaces port to public. No public proxy, ngrok, direct `*.app.github.dev`
  access, or unrestricted shell tool is involved.
- The MCP layer supports JSON-RPC Streamable HTTP `initialize`,
  `notifications/initialized`, `ping`, `tools/list`, and `tools/call`; the
  server is stateless at the MCP HTTP level, but retains an upstream session
  binding for its process lifetime. No OAuth or UI widget is implemented.
  The tunnel client supplies a secret backend-only HTTP header.
- MCP tools are **exactly** `session_status`, `observe`, `prepare_edit`,
  `apply_edit`, `step`, `stop`. `request_id` is optional on all tools; callers
  should explicitly supply and retain a stable ID for mutations. After any
  uncertain submission, call `session_status(request_id=...)`: GET only.
  Never invent a new ID and blindly reissue an unconfirmed mutation.
- Native receipts remain structured, including their native/render identities.
  `observe` and `step` carry the original `image/png` in an MCP ImageContent
  block, verified against the original native frame SHA256 before emission.
  A plain path or base64 text does **not** substitute for the image block.
- Native bounds remain strict: up to 4096 observed/edited cells, 8 edit
  primitives, 1–120 ticks per Step, 480 native ticks per task, and only host-
  allowed Empty (0)/Hard Wall (58) output (never Sand fabrication). The
  native owner enforces source/scope/protection and generation/revision fences.
- Limits for Secure MCP Tunnel's default 10 MiB serialized envelope and 120s
  absolute deadline: the adapter permits up to 6 MiB image data and 9 MiB JSON
  result, and waits at most 80s for a native receipt. Larger/slow results are
  explicitly uncertain/refused, not silently truncated or counted as applied.
- An adapter restart forgets its process-local request map but upstream
  idempotency receipts remain authoritative. A detected change of upstream
  session ID makes the adapter **refuse further work** until the trusted
  operator restarts it intentionally. An upstream service restart does not
  restore evolved native state; it is a new World.

## Start the local adapter (host-side only)

Precondition: the operator has already followed `../CODESPACES.md` to start a
**disposable** native workbench in a Codespace, verified **private** port
visibility, and opened `gh codespace ports forward 8765:8765` from the
**same** trusted host that will run the adapter and `tunnel-client` (for example,
Ubuntu in WSL). The existing authorized host file and workbench bearer are not
under model control. Stop/Step/edit tools are destructive; do not attach the
adapter to an important active World.

On that trusted host, with a checkout containing the matching #547 source:

```bash
umask 077
python3 -c 'import secrets; print(secrets.token_urlsafe(48))' > "$HOME/.cybersand-mcp.token"
python3 - <<'PY'
from pathlib import Path
p = Path.home()
token = (p / '.cybersand-mcp.token').read_text().strip()
auth = p / '.cybersand-mcp-auth-header'
auth.write_text('Bearer ' + token)
auth.chmod(0o600)
PY
python3 tools/remote_workbench/mcp_adapter/adapter.py \
  --base http://127.0.0.1:8765 \
  --workbench-token-file "$HOME/.cybersand-wb.token" \
  --mcp-token-file "$HOME/.cybersand-mcp.token" \
  --port 8766
```

The MCP token must be different from the workbench token. Both files must be
regular, local, owner-only (mode 0600) files. The adapter refuses unsafe
`--base` locations using the **actual** #547 client validator. It holds no
Godot/native process lifetime: the workbench service must already be started
and must remain alive independently.

## Private host-to-ChatGPT registration: operator-only

Follow the official [Secure MCP Tunnel guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
and the latest [tunnel-client configuration reference](https://github.com/openai/tunnel-client/blob/master/docs/configuration.md).
Create a `tunnel_id` in Platform tunnel settings for the intended organization
and ChatGPT workspace with restricted **Tunnels Read+Use** runtime access.
Install the supported `tunnel-client` on the same trusted external host. Enter
its runtime API key **locally** (never in a chat message, log, command argument
or repo file). For example:

```bash
# In the trusted host's shell, use a hidden local prompt. No token appears here.
read -rs -p 'Tunnel runtime API key: ' CONTROL_PLANE_API_KEY; printf '\n'
export CONTROL_PLANE_API_KEY
# Replace only with the tunnel ID shown in the operator's Platform settings.
TUNNEL_ID='<operator-created-tunnel-id>'
tunnel-client init --sample sample_mcp_remote_no_auth \
  --profile cybersand-wb --tunnel-id "$TUNNEL_ID" \
  --mcp-server-url http://127.0.0.1:8766/mcp
# Read backend Authorization only from a trusted local file. It is NOT a model
# argument, connector-forwarded secret, or public endpoint credential.
export MCP_EXTRA_HEADERS="Authorization: file:$HOME/.cybersand-mcp-auth-header"
tunnel-client doctor --profile cybersand-wb --explain
tunnel-client run --profile cybersand-wb
```

`MCP_EXTRA_HEADERS` injects the adapter bearer **only on the local
`tunnel-client` → MCP HTTP hop**. Use *No authentication* for the ChatGPT
plugin **only when** the configured private tunnel and its trusted host
supply this header and the workspace/tunnel permissions are constrained.
Do not turn off the MCP server's bearer check to satisfy registration.
No bearer token need traverse ChatGPT or the OpenAI tunnel queue as a
connector-provided Authorization value.

In ChatGPT: **Plugins → + → Add custom MCP server → Connection: Tunnel**;
select that `tunnel_id`, configure the supported plugin permissions, test
and install the plugin to the intended private workspace. Test read-only
`session_status` first, then `observe`; use edit/Step/Stop only in a disposable
World. The operator must actually see six tools in the selected chat and a
real `image/png` observation before claiming model integration.

**Plan/capability gate:** As documented in November 2026, some ChatGPT plans
can register only read/fetch MCP tools, and full custom-MCP **write** support
is in beta for Business, Enterprise and Edu. In a read-only workspace,
`apply_edit`, `step` and `stop` cannot be exercised from that chat even if
this adapter and tunnel work. Do not evade the platform's policy by
mislabeling mutations as read-only. Other capable MCP hosts can use the
same adapter without an OpenAI inference loop.

## First read-only MCP wire verification (trusted host)

The HTTP request is generated locally; the two token files are not included
in evidence or chat. This checks MCP discovery, not model-tool registration:

```bash
python3 tools/remote_workbench/mcp_adapter/test_adapter.py
python3 - <<'PY'
from pathlib import Path
from urllib.request import Request, build_opener, ProxyHandler
import json
p=Path.home(); token=(p/'.cybersand-mcp.token').read_text().strip()
body=json.dumps({'jsonrpc':'2.0','id':1,'method':'tools/call',
                 'params':{'name':'session_status','arguments':{}}}).encode()
req=Request('http://127.0.0.1:8766/mcp',data=body,method='POST',
            headers={'Content-Type':'application/json', 'Authorization':'Bearer '+token})
with build_opener(ProxyHandler({})).open(req,timeout=10) as response:
    doc=json.load(response)
assert doc['result']['structuredContent']['ok']
print('MCP status: connected to native session')
PY
```

For a **real disposable** native adapter qualification using the tool
surface (this is an external scripted acceptance, **not** a Cloud Sol chat
model call), run before Stop or other owner actions:

```bash
python3 tools/remote_workbench/mcp_adapter/qualify_native.py \
  --mcp-url http://127.0.0.1:8766/mcp \
  --mcp-token-file "$HOME/.cybersand-mcp.token" \
  --output "$PWD/build/wb-mcp-native-$(date +%Y%m%d-%H%M%S)"
```

The script records a sanitized MCP JSON-RPC transcript, **original PNGs** and
SHA256, native receipt identities, explicit source/runtime session evidence
and failure reason. Its sequence uses a stale proposal (advance one tick
before apply), a successful nine-wall edit, duplicate ID, observed count,
readback-driven one-cell removal, four further real ticks, and acknowledged
native Stop. For a source/runtime manifest and independent original PNGs,
retain the upstream #547 server artifact/identity, too. The scripted
qualifier cannot and does not prove that Cloud Sol itself invoked the tools.

## Final gate ledger

| Gate | Required evidence | This directory alone |
|---|---|---|
| Adapter implementation | Source + exact write-set + passing offline MCP-wire tests | Testable locally |
| Real native adapter acceptance | Fresh disposable Codespace, authentic Godot/native receipts, four original PNGs, stale proposal, duplicate, reconnect, Stop | Needs authorized external host and runtime |
| Private deployment | Host-local adapters, authenticated private gh port forwarding, healthy Secure MCP Tunnel, constrained workspace registration | Operator action |
| Chat tool discovery | Six methods discovered by **the actual Cloud Sol chat** | Not proven by CLI/Inspector |
| Chat live invocation | Real `session_status`/observed PNG/edit/edit/Step/Stop tool transcripts in the chat | Not proven by scripted qualifier |

No merge, Ready transition, paid inference, public endpoint, changed physics,
or schedule change is authorized by this adapter.
