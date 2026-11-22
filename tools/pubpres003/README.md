# PUBPRES-PLAYABILITY-003 causal measurement

The frozen PUBPRES-001 v2/v3 registrations, observers and reducers remain in
`tools/pubpres_playability`. This directory holds additive PUBPRES-003 evidence
tools. No retained receipt is rewritten or relabelled as a new execution.

## Retained-trace audit

`audit_traces.py` accepts extracted original campaign artifacts containing
`campaign.json`, arm/receipt/trace/analysis JSON, process receipts and the two
original framebuffer PNGs. It first reruns the unchanged v3 validator, including
real actor/body ownership, native response/terrain identity, fixed-step callback
credit, actual participating workers, input leases, Water ledger, registered
fixture and strict framebuffer hashes. It then independently recomputes the
selected timing statistics for all three registered windows and checks them
against the retained original analysis and the frozen reducer's fresh output.

```sh
python tools/pubpres003/audit_traces.py /path/to/retained/extracted \
  --output /path/to/new-evidence/retained-trace-audit.json
python -m unittest discover -s tools/pubpres003 -p 'test_*.py' -v
```

The output path must be new. Failures remain explicit records and return a
nonzero exit code. The tool does not re-run archived binaries or claim that
source hash receipts alone prove current runtime identity. Original ZIP hashes
and download custody remain separate records. Pairing checks bind source,
native runtime, engine, CPU/adapter, fixture, Water profile, worker count and all
non-intervention selectors. Equal-step body trajectory and admitted-move hashes
must agree before paired attribution is admitted.

The first healthy handoff is joined by native World, tick, body sample and
required terrain revision. Repeated status publications cannot reset its age.
The v3 worker trace does not expose session/epoch or actual Main mailbox
observation and terrain-install boundaries; unavailable causality remains
unavailable. Prefixes with no completed step retain their full censored freeze
duration. No step is inferred from an attempted continuation or a draw callback.

Rates are computed per run. The report averages paired run-level rates but
retains each run's gap quantiles. It does not pool different workload profiles,
platforms or intervention types, and does not average p95/p99 values.

## Prospective causal seams

PUBPRES-003 adds bounded, explicit diagnostic observation at existing Main and
worker boundaries. These observations must preserve their own source/runtime
identity and remain separate from the frozen v3 apparatus. Required joins are:

- Native request/start/completion and participating worker work.
- The first healthy immutable mailbox packet for the exact World, session,
  epoch, native tick, body sample and required terrain revision.
- Each existing mailbox read, including empty, contended and mismatched packets.
- Existing terrain queue/budget calls and their before/after pending counts;
  the queued revision alone is not evidence of a completed install.
- Final admitted packet immediately before the ordinary Rapier transaction,
  followed by the existing genuine completed-step/body/credit oracle.
- Material publication and Main/camera/draw callbacks, with no assertion of GPU
  completion or physical scanout from `frame_post_draw`.

The diagnostic must perform no additional mailbox reads, install work, physics
callbacks or solver work. No failed or unavailable boundary becomes a zero-time
success. Measurement is enabled explicitly and compared with the same-source
diagnostic OFF path to expose observer overhead.
