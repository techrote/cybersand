# GIP-013 — Gremlin Integration Protocol (experimental, Draft/HOLD)

**Authority boundary:** development-only, opt-in; never runs at normal Workbench startup. The Sprocket language model is a *proposer*, never an executor, oracle, code editor, or judge. No GitHub, shell, filesystem, or unrestricted simulation capability is exposed to it.

## Implemented scope and known limitation

`tools/gip013/gremlin.py` is an offline **reference contract-model proof of concept**. It runs a seeded, bounded, closed-vocabulary transition engine, enforces independent invariants, stops on the first observed violation, emits per-action JSONL receipts, checks deterministic replay fingerprints, and delta-debug shrinks offending action sequences. It **does not inject actions into the actual Godot Workbench** and **does not advance actual native World or Rapier physics**. Its `native_tick`, `rapier_tick`, `epoch` and `generation` fields are **synthetic model identifiers**. They demonstrate the evidence wire format, not source-matched runtime qualification. Never report model passes as engine passes.

Actor Compose 002R is in Draft PR #742; accepted `main` does not yet include the six-tab configuration and live grabbing. This utility starts from accepted `main` and does not change #742 or any Actor recovery branch. `tools/gip013/qualification.py` separately runs fixed existing Godot regression scripts in a disposable user directory when a complete local Godot/native runtime is supplied; it is **not** an action-transcript-to-Godot adapter. Real arbitrary-sequence Workbench replay requires a future narrow, source-matched, test-only adapter after Actor recovery stabilizes. This is the explicit fallback permitted by GIP-013, not a claim of completing full engine integration.

## Quick start

From the repository root, with only Python 3.10+ (no new pip dependencies):

```sh
python3 -m unittest discover -s tools/gip013 -p 'test_*.py' -v
python3 tools/gip013/gremlin.py --mode all --seed 13 --steps 96 --activate-immediately --out /tmp/gip013-run-13
python3 tools/gip013/gremlin.py --replay /tmp/gip013-run-13/chaos/transcript.json --out /tmp/gip013-replay-13
```

Use *new, nonexistent* output directories. The runner refuses to overwrite any existing evidence. Without `--out`, it creates a new OS temporary directory and reports the exact path. The canonical seed is **13**; arbitrary signed int32 seeds are admitted. Maximum 500 actions per campaign and a 120-second default wall watchdog (configurable 1–600 seconds via `--max-campaign-seconds`), with a fixed action vocabulary and fixed parameter choices. A timeout is classified as `runner_watchdog_timeout` and stops dispatch after the current action. Replayed tapes are capped at 500 actions and 5 MB. `--mode all` runs CONTROL and CHAOS; SPROCKET is **skipped**, not simulated, unless a loopback inference endpoint is explicitly provided. The deterministic CONTROL sequence includes a deliberately rejected capacity Apply, simulated physical-grab cancellation, authored save/restore and running paint.

### Thirteenth-minute ceremony

Dormant qualification is CONTROL. GREMLIN is CHAOS or SPROCKET. CONTAINMENT stops before executing the next action after an invariant failure. CI and ordinary runs activate immediately. If a *real* 13-minute delay is desired for a manual session, use `--ceremonial-delay-seconds 780` (optionally after CONTROL); it is never used by CI. `--activate-immediately` explicitly records the instant-on intent and is incompatible with delay.

### Optional local Chief Gremlin

Run a **local** llama.cpp-compatible server serving the Sprocket instruct GGUF (suggested `sprocket-500m-q4_k_m.gguf`), then:

```sh
python3 tools/gip013/gremlin.py --mode sprocket --seed 13 --steps 96 \
  --sprocket-url http://127.0.0.1:8080/v1/chat/completions \
  --sprocket-model sprocket-500m-q4_k_m.gguf \
  --sprocket-model-file /path/to/sprocket-500m-q4_k_m.gguf \
  --out /tmp/gip013-sprocket-13
```

The prompt consists of a short gremlin persona plus the current compact state and numbered **legal** action objects. Sprocket can only return `{"choice": 4}`. The trusted controller resolves that index and validates the action against the current legal set again before dispatch. Redirects, proxies, non-loopback endpoints, oversized responses, malformed JSON, out-of-range indices and repetitive proposals are rejected. If the server fails, the seeded selector takes over without granting additional privileges. Only **actually Sprocket-selected** actions count toward model-guided coverage; a wholly offline run is a seeded fallback, not an Sprocket experiment. No paid API or model download is needed for CONTROL/CHAOS.

## Evidence and safety

Each campaign produces `receipts.jsonl` (action, before/after states, accepted/rejected result, invariant violations, tick/generation/epoch, wall overhead), `transcript.json` (deterministic action tape and fingerprints) and `summary.json` (action coverage, invalid model proposal count, elapsed time, provenance and failure classification). On a violation, also `minimized.json` (best-effort ddmin tape and attempt budget). Root `campaign-summary.json` and `report.md` label the evidence as *reference model*. Fingerprints deliberately exclude timing and proposal origin, so replay using the same adapter/version/seed can compare state transitions exactly. Replays must check every fingerprint, not merely the final failure.

No pre-existing user file is touched. The contract model is entirely in memory. The optional Godot gate isolates `HOME`, XDG and Windows AppData in a new evidence folder, checks clean tracked Git source, hashes the exact Godot executable, records the source SHA, and optionally hashes the supplied native binary. A missing native hash remains *unqualified*. The gate stops at the first failing or timed-out real test and never merges or applies repairs.

## Invariant catalogue and campaign comparison

| Contract | Reference oracle | Real engine follow-on | Status |
| --- | --- | --- | --- |
| Rapier part IDs not duplicated or retired | Unique integer identity set | Assert live RID/part identity against real native occupancy generation | Model only |
| Unrelated joint graph and controller survive inspection/grab | Immutable joint list and controller map during unrelated operations | Sample actual `physical_joint_count`, source/generation and leases | Model only |
| Pilot authority unaffected by inspection | Before/after pilot equality | Read actual host pilot independently of selected inspector | Model only |
| Cancellation revokes grab and pause revokes pending commands | After-state invariants | Query real manipulator and worker command receipts | Model only |
| Rejected Apply preserves staged and accepted settings | Before/after equality | Exercise six-tab panel, rejected native capacity adoption | Model only |
| Running paint remains bounded | Counted material writes | Query actual native material/PAINT owner receipts | Model only |
| Authored save/restore boundary | Compare authored setup only | Save/reopen actual Setup-v2 and verify evolved physics deliberately excluded | Model only |
| No indefinite worker wait | Per-real-test process watchdog | Add per-operation native/rapier deadline receipts | Gate supports real timeouts |
| Art session logging remains session-only | Not represented | Run accepted Art logging regressions | Not tested here |
| Materials Lab/Flatten contract remains intact | Not represented | Run established regression suites | Not tested here |

**CONTROL** is a fixed tape with invariant oracles and no model, **CHAOS** uses seeded legal-action choice, and **SPROCKET** uses the exact same executor and oracles with optional local model proposals. Compare failures, invalid proposal rate, actual accepted Sprocket proposals, adjacent-action coverage and overhead. The reference model establishes no evidence that Sprocket outperforms deterministic chaos.

### Deliberate negative test (oracle qualification only)

```sh
python3 tools/gip013/gremlin.py --mode control --seed 13 \
  --inject-fault rejected_apply_clears_stage --expect-violation \
  --out /tmp/gip013-injected-13
```

The `--inject-fault` switch exists **only in the in-memory reference model** to prove that rejected Apply dropping staged capacity is detected, contained and shrunk to `stage_capacity(1) → apply_capacity`. It does not mutate CyberSand. The ordinary runner returns nonzero on invariant violations; `--expect-violation` is only for negative self-tests. `--replay` returns zero only if the complete recorded fingerprint sequence and failure signature match exactly.

### Optional established Godot regression gate

In a separate clean, source-matched development checkout containing compiled native runtime, with the relevant test scripts present:

```sh
python3 tools/gip013/qualification.py --suite accepted \
  --godot /path/to/godot-4.7 --project ./godot --native /path/to/libcybersand_native.so \
  --out /tmp/gip013-accepted-godot
# Once an isolated Actor-002R checkout is available:
python3 tools/gip013/qualification.py --suite actor-002r \
  --godot /path/to/godot-4.7 --project ./godot --native /path/to/libcybersand_native.so \
  --out /tmp/gip013-actor-godot
```

The actor-002r suite refuses to run on accepted `main` where those test files are absent. The `--native` path is optional but omission is explicitly recorded. `--headless` may not support every graphical integration suite; this gate does not override existing graphical qualification or the required Windows NVIDIA acceptance.

## Follow-on real adapter acceptance gate

A future adapter must take *the same* typed action transcript, operate the **ordinary** `Shared Workbench` on an isolated authored world, and read real host/native/Rapier state without modifying production physics or replay scheduling. It must reject stale epochs, preserve source/runtime hashes, wait for actual native and Rapier receipts, cap per-step time, capture UI/state evidence on failure, and preserve all legacy PAINT, ART, Materials Lab and Flatten tests. Do not enable it until Actor-RECOVERY-A/B are reconciled, reviewed and separately qualified. No automatic merging, production activation or default configuration change is authorized by GIP-013.
