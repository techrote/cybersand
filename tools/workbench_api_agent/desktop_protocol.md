# Desktop bridge protocol 1

Launch `python -u tools/workbench_api_agent/desktop.py` from the clean repository.
The script bootstraps its tools import path. Stdout is UTF-8 JSONL only; no keys
or profiles appear in argv. One input reader and the existing Runner worker are
independent. Stop never waits for an ordinary native receipt lock.

Godot creates a fresh absolute `bridge_root`. Start is one frame:
`{type:start,protocol:1,profile_path,profile_sha256,bridge_root,fixture_mode,
compute_consent,allow_live,overrides,task,session}`. Task contains prompt, scope,
allowed_materials, protected_regions, cell_limit and optional acceptance.
Session contains task_id, authorized:true, and authorization_receipt from the
actual native owner (status authorized, generation, cell_limit).
Overrides are model/max_model_calls/max_tools/max_output_tokens/
request_timeout_seconds/tokens_per_minute. Existing provider funding gates apply.
Fixture/Ollama require compute_consent:true; cloud additionally requires allow_live.

Python emits `{type:native_request,id,tool,args}`; Godot returns
`{type:native_result,id,receipt_file,receipt_sha256,png_file?,png_sha256?}`.
File paths are relative under bridge_root, never model-selected. Receipt JSON
retains raw native fields, with PackedByteArray PNG removed to a separate original
PNG. Maximum receipt16MiB/PNG8MiB; hashes and PNG dimensions are verified. Tiny
unit fixtures may use inline receipt and framebuffer_png_base64.
Stop uses the same native_request type with tool stop; only a stopped owner
receipt with no_further_agent_mutations:true establishes acknowledgment.

Python emits `{type:event,event,payload}`; payloads over16KiB use
`payload_file,payload_sha256,bytes` instead. Godot reads/verifies that JSON under
bridge_root before forwarding to its existing diagnostics. Provider events are
http.request/http.response with headers excluded and effective key redacted;
request image data is original-image hash/size metadata, not base64 log spam.
Finish is `{type:finished,receipt}` or receipt_file/receipt_sha256/bytes for large
selected reports under reports/. The full original Runner receipt remains under
runner-evidence/receipt.json. Start optionally accepts fixture_script_path
(absolute trusted host path, optional fixture_script_sha256) OR fixture_turns;
both together refuse. An explicitly selected script never silently falls back.
Rate reservation/settlement events carry rate_history before provider dispatch;
the host retains this per provider/endpoint and supplies it on the next Start.
Input `{type:stop,reason}` cancels Runner/provider pacing and requests native Stop.
Control frames are bounded32KiB. EOF/broken pipe fails closed; Godot independently
retires its native task on child exit. Unknown/stale IDs never dispatch a tool.
