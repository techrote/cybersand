---
title: PLAY LIFE010 live publication and extracted-equipment delivery
status: Current
document-kind: audit
scope: Candidate actual-host adversarial consumer delivery and lease-valid equipment cancellation; Linux headless local evidence
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/github-development-and-release.md, 2026-10-31-play-life009-automatic-pause.md]
---

# LIFE010: live publication and extracted-equipment delivery

## Gap and source ownership

The [remaining #269 distinction](https://github.com/techrote/cybersand/issues/269#issuecomment-6532328335)
requires live evidence beyond stopped-worker snapshot reinjection. Production
uses a mutex-protected **latest slot**, not a network reply queue. Its serial
filter normally prevents delayed/duplicate/older values reaching Main. This
package tests the separate consumer refusal with **authentic immutable packets
and an explicitly adversarial delivery seam**. It does not invent a production
transport queue.

The fixture loads actual `main.tscn` and uses the ordinary integrated Play
panel, native course construction, equipment selection, input dispatch, pause,
reset and teardown. Main and physics callbacks remain automatic. The test
worker subclasses `CyberSimulationWorker`, replaces its unstarted default
allocation before inherited startup, and inherits the existing loop. Exactly
one worker is live per host. The two real lifetimes run sequentially with
complete join between them. No native World, rig or Rapier ownership moves
between threads; no World tick or physics callback is manually invoked.

The actual-host fixture uses new files: `play_life010_live_delivery_worker.gd`,
`play_life010_live_delivery_case.gd`, five discoverable
`test_play_life010_<rig>.gd` wrappers, `tools/ci/verify_play_life010.py` and this
audit. A focused ordinary-runner hook additionally requires independent raw
evidence readback; its parent failure controls and canonical guides are updated.
Production/native source, dependency pins, defaults, authored rig
characteristics and scientific fixtures are untouched. Held #308/LIFE006–008,
held/frozen shader candidates and #309 remain outside this package.

## Controls and evidence semantics

Each rig first runs a short negative lifetime. It retains a genuine older
publication, lets the same native publisher and Rapier advance, and bypasses
only the consumer serial refusal. Ordinary Main must actually regress its
latest/consumed serial; the oracle must reject specifically as
`consumer_serial_regressed`. A timeout or another failure is not a valid
negative. The host is then freed and its worker joined.

The guarded lifetime delivers an exact current duplicate, delayed A, older B
after a newer real publication, an authentic receipt-bearing duplicate and an
old actor/World packet after normal reconstruction. Before/after automatic
handoff records must show exactly one rejection without mutation of accepted
snapshot, body-result/sample serials, terrain revision/queue/shapes, render
identity, lap state, ownership or equipment receipt/use/recoil. Actual native
and completed Rapier clocks advance around delivery windows; nonneutral
keyboard movement starts the existing source-bound lap clock.

Equipment selects the existing Impact Slug at test power 0.25 through ordinary
equip-only admission. Each quick M press/release must produce the two ordered
admitted equipment edges. The scheduling gate intercepts an **actual request
extracted by the inherited owner loop**, outside the production mutex and
before its existing consumer. Only copied request/frame values cross back to
Main. Main must continue and Rapier must complete a real step while that gate
remains held. The matched uncancelled request must produce a native consumed
receipt, one physical use and nonzero recoil.

Automatic `refresh_actor_usables` acceptance is then traced to a **subsequent
completed actual Rapier step on the same worker, session, run, epoch and control
generation**. A receipt/use counter alone is insufficient. An additional direct
deep-consumer control supplies the authentic duplicate feedback and requires
zero acceptance without repeat recoil; that explicit supplementary call does
not replace ordinary input admission in the positives.

The matched cancellation sends ordinary P while **both current and originally
extracted leases remain valid in completed physical ticks**. Pause must
immediately retire the pending token/edges, advance control generation and
preserve both owners. Gate release must produce no native commit, physical use
or extra recoil for that request. Resume and a fresh press must successfully
commit a newer request. Actual request sequences distinguish accepted, cancelled
and recovered outcomes. Replaying the original request through inherited
worker admission against a valid current frame requires `generation` refusal;
after reconstruction, replay requires `epoch` refusal.

This is synthetic scheduling at an actual preconsume boundary. It does **not**
establish slow native-phase overlap, a network transport or shutdown with native
jobs outstanding. Accepted #302 retains the mandatory native-busy qualification;
this package neither replaces nor duplicates it.

## Bounds and retained artifacts

All existing limits remain: 15-second operations/teardown, 150-second complete
fixture, 180-second process and 240-second import. The original timestamp before
Main scene load/instantiation/add-child is retained through the first inherited
Main process return and checked against 30 seconds. Synchronous startup cannot
reset that clock. This first-callback guard is explicitly separate from PACE's
Build-selected-to-actor acknowledgement origin.

A preconsume gate has its own 15-second limit and shutdown fallback; either
timeout or fallback invalidates its normal control. The final fixture records
42 bounded operation waits, two first-Main acknowledgements and seven normal
native/physical progress windows. At most eight immutable packets may be
retained over the entire fixture; the present sequence retains five.

Every script-value property is serialized to Godot value bytes and SHA-256
hashed at capture/delivery, then saved and checked after complete join.
Separately hashed readable JSON exposes identities and native equipment
receipts. JSON does not preserve Godot packed-array/vector type encoding; the
`.bin` artifacts preserve the exact typed serialization. No packet field is
modified. The ordinary runner supplies source identity and a retained per-case
artifact directory.

The independent Python reducer requires exact source and fixture/worker hashes,
the original successful process receipt, matching complete log/result, every
delivery and gate, unchanged deadlines, raw packet digests and identities, real
native consumed receipts, physical progress after acceptance, valid cancellation
leases, reconstruction fences and joined lifetimes. It rejects nonzero,
timed-out, skipped or incomplete processes even when assertion counters are
green. Complete source/runtime provenance remains the ordinary repository
runner's responsibility, rather than a self-reported engine-version claim.

Twenty-one corrupt-evidence controls check wrong source, expired current/extracted
lease, late/duplicated/swapped Main acknowledgement, failed wait, missing delivery, stale
body/terrain/lap, missing completed physics, neutral equipment input, blocked
physics while pending, native counters without receipts, cancelled effects,
unjoined worker, wrong negative reason, altered packet bytes, missing post-receipt
step and stale generation on that step.

## Preserved local execution

Base source is published #319 candidate
`aa74448bad7ec77e5f152d9179a417ce76430009` plus the explicit new fixture delta;
this is **not** a claim that #319 is qualified or merged. Pinned Linux engine is
`4.7.stable.official.5b4e0cb0f`. Committed LFS native SHA-256 is
`496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6`;
Rapier 0.35.2 SHA-256 is
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.

The pre-review five-rig source delta passed:

| Rig | Assertions / failures | Fixture seconds | Process seconds |
|---|---:|---:|---:|
| Stunt Buggy | 142 / 0 | 6.433390 | 7.839 |
| Trials Bike | 142 / 0 | 6.935780 | 8.888 |
| Acrobat | 142 / 0 | 6.083313 | 7.542 |
| Arcade Lander | 142 / 0 | 6.266573 | 7.796 |
| Jet Barrel | 142 / 0 | 6.219654 | 7.741 |

Those 710 assertions/zero failures include ten real lifetimes, 25 guarded
deliveries, ten native/physical equipment commits, five lease-valid cancellations
and five actual serial-bypass negatives. Teardown spans 35,426–57,729 microseconds.
Each held request includes at least one real completed physical step. All five
then-current reducers passed sixteen adverse evidence controls.

The `qualification-life010/strengthened-evidence-manifest.json` SHA-256 is
`f2f090943ce5d23946007af13725788f3caab44f9da090db0b1a25deeb7b7837`.
It binds the precise pre-review fixture
`d64987b2507df5c1c4d4d7da9c8b6e6f74cc58a6e31f4679f2141a1e5f31878f`,
worker `9b275f6daaf9c4f092c964546ddb2580f7aa5f4b5125199e7f7b73674678672d`,
original source copies, process logs, raw packets and reductions in
`qualification-life010/attempt03-<rig>/`. These results do not retroactively
qualify the subsequent independent-review additions: the fixed-origin first
Main guard and specifically traced physical step after receipt acceptance.
Those additions require their own committed-source execution.

### Committed-source proof and reviewed reducer

Exact source `23ab41e020c4cfaeb33bc68150d2806f68a30d88`, tree
`324c2f34df99599894bf4e05a68e58956825bfc4`, then completed a fresh clean
240-second-bounded import in 3.173 seconds and all five unchanged 180-second
processes:

| Rig | Assertions / failures | Fixture seconds | Process seconds |
|---|---:|---:|---:|
| Stunt Buggy | 148 / 0 | 6.398239 | 7.839 |
| Trials Bike | 148 / 0 | 6.062618 | 7.537 |
| Acrobat | 148 / 0 | 6.120253 | 7.542 |
| Arcade Lander | 148 / 0 | 6.016424 | 7.338 |
| Jet Barrel | 148 / 0 | 6.045628 | 7.541 |

This is **740 assertions / zero failures**, with all original logs and raw
packets in `qualification-life010/final-<rig>/`. First-Main acknowledgements
range 233,078–297,887 microseconds from their own original load origins.
Each of the ten accepted receipts is followed by one recorded actual completed
Rapier step on the same ownership/control identities. Teardown spans
41,187–55,757 microseconds. The exact Godot executable SHA-256 is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.

Independent review then tightened **only the reducer**: each first-Main
acknowledgement must precede its own lifetime's first retained packet, and the
second origin must follow the first lifetime's last delivery. Duplicate/swapped
acknowledgements are explicit negative controls. Ordinary process records must
contain `status: passed`. The original five-field local receipt schema
(`command`, `timeout_seconds`, `returncode`, `timed_out`, `elapsed_seconds`)
is supported only with explicit `--local-process-receipt`; its original files
remain byte-identical. A missing ordinary status never defaults to passing.

All five original committed-source runs pass the reviewed reducer and all
21 corrupt-evidence controls each. Seven additional synthetic process-evidence
controls reject a post-summary access-violation exit, timeout, process deadline,
missing ordinary status, skipped status, incomplete local schema and a
post-summary engine-error log. These are deliberately altered receipt/log
controls, not new engine runs or claims of actual crashes.

Reviewed reducer SHA-256 is
`1ae479e56d03c8256e7d9316e4ac4020a78b435c75685b5d697b75867e3f74d2`;
`qualification-life010/final-evidence-manifest.json` SHA-256 is
`a52102d8b1faf51715e65bf8068d50a2b060c7f621866c2472270d070b169271`.
The manifest binds source/runtime identities, original process/log/result
hashes, original and reviewed reductions and the preserved predecessors.
This audit/reducer follow-up does not change the tested Godot fixture bytes.

The first editor import exited zero but logged sandbox socket denial and an
unwritable editor-settings file under `/root/.config`. Original `import-01.log`
remains an environment/preflight failure. The task-local writable config/data/log
execution `import-02` completed in 3.275 seconds without engine errors, under
the same 240-second limit. No shader/cache work or graphical warmup occurred.

Earlier `attempt01-acrobat` passed 124/0 and `attempt02-<rig>` passed 133/0 each;
their exact source copies and logs remain intact. The first Python reduction
failed an inventory typo: 33 rather than 34 unique names among the earlier
37 waits. `reducer-attempt01.py` and its failure receipt preserve that verifier
defect. Correcting the inventory did not relax any engine limit.

## Integration and acceptance boundary

The integrated Linux run used source
`86914ee147b2280da1f376448df10e0bdbd4af1f`, tree
`32a4cf7af7c817ea9b5d69aa22682dc2d34cdfba`, including the independently reviewed
UI007 immutable-empty correction. A clean import took 5.075 seconds. All five
actual Main/native/Rapier cases passed **148 assertions each, 740 total**, and
all five independent reductions passed their 21 reason-specific adverse
controls. Original process times were 8.117, 7.816, 7.719, 7.722 and 7.446
seconds for Stunt Buggy, Trials Bike, Acrobat, Arcade Lander and Jet Barrel.
Every tested input hash was unchanged after execution. A separate local native
compiler could be active: these are bounded semantic regressions, not pacing
comparisons or clean-host performance claims. The original source identity is
retained; subsequent runner/docs changes do not relabel those engine runs.

The ordinary runner now retains the successful engine's original receipt and
invokes `verify_play_life010.py --self-test` before promoting each LIFE010 case.
The independent readback has its own 15-second bound. It must exit zero, bind
the same source and rig, and account for two real lifetimes, five rejected
deliveries, two native equipment commits, one lease-valid cancellation and all
21 unique, reason-specific corrupt-evidence controls. Its command, exit,
duration, receipt/result hashes and output remain beside the original log.
The required verifier is included in the Windows source-input/drift inventory.
Each platform additionally checks its invoked bytes against the declared source
commit, retaining separate actual-byte and canonical-Git hashes for permitted
LF/CRLF checkout conversion. The hook compares emitted process/log/raw-result
digests to the original inputs, checks those inputs and verifier remain unchanged
after readback, and shares one 15-second budget across identity and execution.
An incomplete/invalid reduction fails the parent case without rewriting the
original engine exit or log. An existing readback directory is refused rather
than overwritten. This hook applies only to LIFE010; ordinary cases and the
accepted LIFE001 50-lifetime baseline retain their existing execution.

All five copies of the retained integrated raw evidence passed the actual new
parent hook in 1.519–1.621 seconds each; every original file stayed byte-identical.
This was offline readback, not five new engine executions. Fourteen new parent
controls cover intact receipts, nonzero verifier exit, timeout, missing result,
missing control, existing receipt, malformed result/control and parent failure
after a successful child, all three input-digest substitutions, changed original
input and changed verifier. Three separate verifier-identity controls cover
exact bytes, explicitly identified CRLF conversion and modified-source refusal.
The complete runner suite has 42 passes and one
explicit Windows-only observation skip on Linux in both normal and `-O` Python;
that skip is unexecuted local Windows coverage, not a pass.

Independent review re-executed all five original reductions and obtained
byte-identical outputs, then identified the missing verifier source binding
before publication. After that correction, five further offline parent-hook
readbacks passed in 1.375–1.624 seconds, including the actual Git-byte check and
all three input-digest comparisons. Original engine files again remained
unchanged. These additional reductions do not increase the real-lifetime count
or replace required Windows hosted execution.

Windows exact-head evidence and the complete applicable hosted matrix are
required before integration. LIFE001's accepted **50 real lifetimes per OS**
remain unchanged and required. This package alone does not close #269, qualify
pending-native reconstruction/failure recovery held elsewhere, establish
graphical Main startup/FPS, or satisfy physical-device, real OS focus, display
or subjective #270 acceptance.

For retained ordinary-runner evidence:

```sh
python3 tools/ci/verify_play_life010.py \
  --result "$CASE_ARTIFACTS/acrobat-life010.json" \
  --log "$OUTPUT/test_play_life010_acrobat.log" \
  --process-json "$OUTPUT/timings.json" \
  --source "$EXACT_SOURCE_SHA" --self-test
```

The source checkout must supply exact fixture/worker bytes, or use the preserved
files with `--fixture` and `--worker`. The original process receipt remains
separate from in-process assertion results.
