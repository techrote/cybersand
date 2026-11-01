---
title: Y1 post-arrest accounting and finite clearance observation
status: Current
document-kind: audit
scope: Copied bridge accounting followed by separately registered 1800-sample B0/Y1 observation; no response changes or production selection
last-reviewed: 2026-11-01
related-documents: [../operations/granular-bearing-post-arrest-handoff-proposal.md, 2026-11-01-granular-bearing-candidate-discrimination.md]
---

# Y1 post-arrest accounting and finite clearance observation

## Frozen intake

The isolated branch `codex/y1-post-arrest-clearance-20261101` starts at exact
reviewed PR #341 head `064a3306dc3a87c3a88172003e42c8e426cb73e1`, tree
`0e695747de2a73f319584b25ee1aa0c4031d4672`. Its executed candidate source remains
`39d91671c1d0bb7978a29460f14419cd1b37a252`. Observed remote main
`25ce0731d89b9540c2d95cfa8bae321c37e6e118` is metadata only. No main or concurrent
source is consumed. The root `C:/khybersand` material branch and its dirty work
are preserved. Work occurs in
`C:/Users/_/.codex/worktrees/y1-post-arrest-clearance/khybersand`.

The historical handover's `C:/kybersand/source` path is superseded for this task
by the inspected source root/worktree; it is not a checkout instruction.
Godot4.7, Rapier0.35.2 with retained x86_64 backport, godot-cpp101ae380 and
LLVM-MinGW20260826 pins remain unchanged. LFS payloads are materialized.
The published native payload is not the diagnostic runtime.

## Stage A: copied-value oracle

The [machine receipt](y1-post-arrest-2026-11-01/stage-a.json) retains42 samples:
300..321 and580..599, including21 consecutive pairs. Source trajectory and
acquisition receipt SHA-256 bind them to PR #341. The
[oracle](../../tools/experiments/post_arrest_accounting.py) imports no simulation
API, reads copied values only and changes no live response.

All application, correction, age scaling, impulse and next-pre-Rapier boundaries
close **exactly** with literal float32 storage/addition: maximum residual0.
Ignoring float32 position rounding gives maximum7.323920726776123e-6px,
below the existing2e-5 API accounting tolerance. No tolerance is enlarged.
The frame599 successor is unavailable in the retained record and explicitly
null; frame598-to599 closes. Rapier transitions are observed, without inferring
unavailable forces or implementing a second integrator.

Incoming vy alternates0.006344288121908903 and1.52896249294281px/s.
The first phase has no correction and the impulse cancels incoming vy to0.
The second applies requested upward correction-0.015831299126148224px;
the opposing incoming component is zeroed before impulse-1.52896249294281
produces outgoing vy-1.52896249294281. Age0 gives scale1 throughout.
Both retained windows reproduce this pair without hard-coded expected velocities.
This explains the bridge handoff; it neither proves a defect nor eventual clearance.

Command: `python tools/experiments/post_arrest_accounting.py --output
docs/audits/y1-post-arrest-2026-11-01/stage-a.json` on Windows/Python3.13,
followed by `python -m unittest discover -s tools/experiments -p
test_post_arrest_accounting.py`. Six regressions include altered impulse,
missing zeroing, wrong sample boundary, explicit missing observation and input
immutability. Stage B is not executed at this checkpoint.

## Documentation change map

This is copied diagnostic accounting only. Native ownership/lifetimes,
interfaces, capacities, response laws, ADR007/009, user controls and dependency
pins are unchanged. The canonical post-arrest proposal routes to this receipt;
the final observation checkpoint will synchronize the roadmap, retrieval and
validation routes. Historical PR #341 evidence remains intact.

Stage-A checks: six Python regressions pass; M11 integrity and retrieval execution
pass. Documentation retains the six frozen companion-reference findings;
repository qualification additionally retains12 published-runtime source-rebuild
findings, matching the parent. No published runtime hash is rewritten.

## Stage B: frozen method and execution
Stage A was committed as `5ca390a8` before the duration extension. Harness and
reduction were frozen before registration. Machine [preregistration](y1-post-arrest-2026-11-01/protocol.json)
was committed as `121f04914a62ff9bb33682cac8ed7d53ad0fc0f4`, tree
`d122a08b18c048a4d9cd6e9f2eb4e1d54fbec5cc`, before the first extended launch.
All four arms use that exact common source/tree/runtime. The runner seals a
pre-execution receipt before launch. Only these four arms were acquired, in order:
B0-speed90, Y1-speed90, B0-speed30, Y1-speed30. No A2 or combined candidate arm.

The original32×48 bank at(96,160),8×14 mass-one body, rotation0.08, spin0,
lower extent2px above Sand, one worker,1/60 timestep and once-assigned candidate/
initial speed are unchanged. Every compiled input and all response/admission,
bridge, ejection and material sources match PR #341. The diagnostic native DLL
is SHA-256 `3537a86852c6278f66706615e891ad116406e2a06a16f8c6b8148ba9bab4d30c`;
engine `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`,
console launcher `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`,
Rapier `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
Runtime reuse follows the successful parent build receipt and exact input hashes,
not the stale published-native payload. All execution is local Windows headless
Godot4.7. Source-matched Linux native tests are separate qualification.

The first600 samples match all available frame keys recursively, all complete
parsed capsule values and the first10 segment receipts **exactly**. Only named
volatile owner IDs/timestamps and additive derived capsule hashes are excluded;
no physical, numeric, geometry, quantity, result, support, correction, event-order
or outcome tolerance is introduced. All four prefix gates pass. Every one of
7,200 application boundaries also closes with zero float32 accounting residual.

The inherited capture uses30 existing60-tick diagnostic segments without resetting
World/body state,1800 retained frames, one application row/frame,256 pending and
8192 total events/segment,245760 global event ceiling and500 capsules/replay part.
Internal/outer capture guards remain120/150s; collection180s and each outer replay
150s. No guard increase was needed. Probe high-water10/256, application1,
contact0/16; no contact-at-capacity frame. Zero event loss, silent truncation,
relocation refusal, conservation failure or replay mutation.

The [machine result](y1-post-arrest-2026-11-01/result.json) contains every
registered block, sample landmark, incoming/outgoing distribution, raw-support/
limiter distribution and response total. [Selected causal traces](y1-post-arrest-2026-11-01/selected-traces.json)
retain pre/post-Rapier, correction/zeroing/impulse and next-step values around
prefix, clearance, recurrence and tail boundaries. Selection is explicit; the
raw archive retains the entire population.

## Clearance and recurrence

Clearance requires60 consecutive zero post-ejection endpoint **and** post-tick
packed-pose overlap samples, starting at/after first contact. Initial airborne
zeros do not supply clearance. Never-overlapped arms are contact prevented.
None of these arms is right-censored; the unchanged rule would censor an
unconfirmed final59-sample zero run at1800. All indices are0-based.

| Arm | First contact | First zero after contact | Sustained start / confirmed | Recurrence starts before sustained | After sustained | Longest overlap episode |
|---|---:|---:|---|---|---|---:|
| B0-speed90 | 1 | 47 | 47 / 106 | none | none | 46 |
| Y1-speed90 | 1 | 640 | 706 / 765 | [641, 643, 693, 705] | none | 639 |
| B0-speed30 | 4 | 30 | 70 / 129 | [61] | none | 26 |
| Y1-speed30 | — | — | — / — | none | none | 0 |

Y1-speed90 first reaches zero at640, but its zero runs640,642,644..692 and
694..704 are interrupted. Recurrence periods are2/50/12 samples. Sustained
clearance starts706, confirmed765, and both channels remain zero through1799
(1094 samples). Contact begins1: contact-to-sustained latency705samples or11.75s;
start706 is11.766667s from sample0. The initial uninterrupted overlap episode is
1..639,639frames; later interruptions explain why the episode immediately before
706 is only one frame. These are separate durations, not interchangeable.

Through sample705,350 corrections request/apply a total-5.540954694151878px,
with actual float32 body translation-5.54351806640625px. Correction translation
is reported as an amount of intervention, not mechanical energy/work. No missing
force is inferred. Correction continues after sustained clearance: the total
1800-sample requested amount is-14.980744450353086px and actual translation
-14.985794067382812px. Clearance therefore does not mean response retirement or
rest. Quantized requested-versus-actual translation differences are accounted
at each application boundary, not unexplained drift.

## Overlap blocks and landmarks

Each entry below is post-tick overlap **cell-ticks / positive frames / min..max**
for the named inclusive300-sample block. Machine results separately retain the
pre-ejection and post-ejection channels with the same statistics.

| Arm |0..299|300..599|600..899|900..1199|1200..1499|1500..1799|
|---|---|---|---|---|---|---|
| B0-speed90 | 842 / 46 / 0..32 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 |
| Y1-speed90 | 3145 / 299 / 0..16 | 1008 / 300 / 1..7 | 44 / 44 / 0..1 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 |
| B0-speed30 | 248 / 35 / 0..13 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 |
| Y1-speed30 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 | 0 / 0 / 0..0 |

At600/900/1200/1500/1799, Y1-speed90 has respectively1/0/0/0/0 overlaps in
each of pre-ejection, post-ejection and post-tick channels. All other arms have
zero in every channel at those landmarks. A zero landmark alone supplies no
clearance claim.

## Final300 body motion and response

Net drift includes the complete before-step1500 to after-application1799
boundary. Endpoint-only after-application span/drift are separately retained.
Positive Y is downward. Actual correction is measured server translation.

| Arm | Y span px | Net drift px | Rapier increment px | Actual correction px | p50 / p95 / max absolute outgoing vy px/s |
|---|---:|---:|---:|---:|---|
| B0-speed90 | 0.216934204 | 0.135574341 | 2.478607178 | -2.343032837 | 1.528962493 / 2.098457813 / 3.057872534 |
| Y1-speed90 | 0.117172241 | -0.063018799 | 2.707580566 | -2.770599365 | 1.068143845 / 2.110878944 / 2.592674255 |
| B0-speed30 | 0.113861084 | 0.003860474 | 3.559478760 | -3.555618286 | 1.300532222 / 1.765672326 / 2.824098587 |
| Y1-speed30 | 0.110107422 | -0.031600952 | 2.876785278 | -2.908386230 | 1.068143845 / 3.631082773 / 3.631082773 |

Rapier increment plus actual correction equals resulting translation and net
boundary drift exactly for every block and arm. For Y1-speed90 final300:
`+2.70758056640625 - 2.770599365234375 = -0.063018798828125px`.
Incoming vy spans-0.462738723..4.110878944; outgoing spans-2..2.592674255px/s.
All signed distribution quantiles and zero/positive/negative populations are
retained. Small centre span does not imply a motionless handoff.

| Arm | Correction-active frames | Velocity-zeroing frames | Accepted net Y impulse | Nominal bearing Y |
|---|---:|---:|---:|---:|
| B0-speed90 | 133 | 133 | -238.005769407 | -235.573769485 |
| Y1-speed90 | 119 | 119 | -223.747769725 | -221.011769813 |
| B0-speed30 | 104 | 104 | -185.008464570 | -184.400464590 |
| Y1-speed30 | 81 | 81 | -236.766572505 | -230.990572691 |

All requested/applied correction vectors, total and final300 limiter/raw-support
histograms, and post-clearance summaries remain in the machine result. No arm
has bearing/correction when raw support is zero. Supported rest/contact can
retain response; sustained clearance is not a requirement that support vanish.

The preregistered near-static overlap envelope requires final300 span<=1px,
absolute drift<=0.5px, p95/max|outgoing vy|<=4/8px/s **and** incoming/outgoing
velocity ranges<=0.1px/s, with nonzero overlap throughout. Dynamic withdrawal
would require net upward motion>0.05px and an adjacent-block mean overlap change
>0.01cells/frame outside that envelope. Neither censored classification applies:
Y1-speed90 already achieved sustained clearance. No equilibrium is inferred.

## Speed30 context and unchanged controls

Y1-speed30 has zero overlap at all three observed boundaries across all1800
samples, with no delayed appearance. Its longest unsupported near-zero-speed
above-bank episode is2frames, below the registered30-frame hover condition;
no artificial-lift sequence and no full>1px positional cycle occurs in any300
block. Final300 centre span0.110107422px, drift-0.031600952px; no long-period
instability under the registered cycle criterion. Support is zero181frames,
one100frames and two19frames; no response persists on a zero-support sample.
Existing low-amplitude velocity variation remains and does not establish a
production rest criterion. Speed30 does not relax the speed90 clearance rule.

[Reused controls](y1-post-arrest-2026-11-01/reused-controls.json) bind both
B0/Y1 speed0 settling/rebound, excavation release, hard and Water controls plus
their on/off pairs to PR #341 source39d91671 and exact compiled/response identity.
All143 native/adapter/test files match the parent for test-binary reuse; runtime
build-input hashes also match. Material/Water laws and those paths are untouched.
Candidate-off neutrality is retained from the qualified parent pairs, corroborated
by exact B0 prefixes/default-selector controls; no extra1800 off/candidate arm.

## Ejection populations and evidence custody

| Arm | Attempts | Positive incoming-vy no-target | Nonpositive incoming-vy no-target | Pending high-water | Segment events high-water |
|---|---:|---:|---:|---:|---:|
| B0-speed90 | 895 | 411 | 432 | 33 | 892 |
| Y1-speed90 | 4320 | 4198 | 0 | 23 | 842 |
| B0-speed30 | 257 | 136 | 112 | 14 | 237 |
| Y1-speed30 | 0 | 0 | 0 | 0 | 0 |

These are deterministic attempts, not independent efficacy populations. All5472
events pass complete Python production-hash/order/reason comparison and native/
fallback replay, including44 additional late Y1 positive-incoming-vy no-target
events after the600-prefix. There is no first-N event retention.

The [raw-retention manifest](y1-post-arrest-2026-11-01/raw-retention.json) seals
all68 original acquisition/replay/log members in the local archive
`build/y1-post-arrest-1800-raw.zip` (5544024bytes), SHA-256
`1f081961e97bf257688dc2cdbde6c9945b4a61f94347435ef0b5a78bbc74ccca`. ZIP CRC and SHA-256 of every decompressed member pass.
Source/tree/runtime identities, member hashes, commands and UTC pre-execution
file timestamps are retained. Full original JSONL, complete1800-frame trajectories,
capsules and process logs stay local; committed summaries/selected traces and
replay-capable inputs at exact source121f0491 preserve reproducibility. The
[build guide](../operations/local-build-and-validation.md#frozen-y1-finite-observation-reproduction)
gives the command. No generated imports, binary, cache or archive is committed.

## Final integration and qualification boundary

After acquisition, inspection found ordinary test discovery would invoke the new
wrapper without candidate arguments. A final **non-acquisition** control branch
now runs the inherited copied bridge controls and asserts horizon1800 in that
entry point. The registered acquisition/replay branches and inherited fixture
remain unchanged. Original registration bytes and every measured source identity
remain untouched; reacquisition deliberately requires exact121f0491. This is
diagnostic integration, not a post-result definition or response change.

The [qualification input ledger](y1-post-arrest-2026-11-01/qualification-inputs.json)
binds reused native test binaries to all unchanged source/test files. Exact final
head qualification is recorded in the PR's machine receipt and locally under
`build/qualification-final/`: native core/candidate binaries are re-executed,
relevant Godot regressions and wrapper controls run, all prefix/custody/replay
checks are repeated, and both reducers reproduce their committed receipts.
The final receipt identifies actual source/tree, commands, limits and log hashes.
It does not reattest the published runtime or release/platform matrix. Parent
Linux O0 timeout and six companion-reference/12 published-runtime findings remain
preserved; no historical artifact or hash is rewritten.

## Documentation checklist and causal disposition

Canonical bearing and post-arrest guides, coupling contract, roadmap, validation
ledger, handover, build instructions, documentation/retrieval indexes, corpus
exclusion and BEARING questions are synchronized. The frozen32 query texts remain
unchanged; BEARING-002's planned fact is explicitly superseded and BEARING-003
adds this finite question. Ownership/lifetime, packed11/9 interfaces, material
laws, invariants, configuration constants, ADR007/009 and user controls require
no semantic revision. Observation capacities live in the registered protocol;
native capacity and ownership are unchanged. CI provider/routing is untouched.

**Disposition: Y1 clears after finite withdrawal latency in this fixture.**
The observed two-sample application cycle is explained by existing bridge
semantics. There is no unexplained material residual or established handoff
defect requiring a response intervention. Continued correction/velocity activity
after clearance is retained adverse/context evidence; no acceptable-rest,
production model, broad REM-004 completion or owner gameplay acceptance follows.
No further intervention is proposed or executed. Final PR remains draft/unmerged.
