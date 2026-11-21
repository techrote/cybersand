# CI-OPT-002 Stage B — independent final judgment

## Decision

**Safety and coverage review: GO. Overall delivery recommendation: Draft/HOLD for performance evidence.**

Retain PR [#718](https://github.com/techrote/cybersand/pull/718) at candidate
`65aa1382a49bb01571177b4639f27b64f5dcb66d`, based on
`846fe0533b3170e7b01f690518da49fc40cc24d1`. Do not merge this increment on the
present turnaround claim. No confirmed P1/P2 source-integrity, coverage or
failure-semantics finding remains, and all applicable hosted gates passed.
The observed performance improvement is too small relative to the demonstrated
worker variation to establish a worthwhile turnaround gain.

This judgment is independent of the implementation engineer, source reviewer and
measurement auditor. The final reviewer made no tracked source changes or remote
mutations. The already merged Stage A improvement remains justified by its
separate actual earlier-refusal demonstration.

## What the actual pair shows

| Metric | Six-family control | Seven-family candidate |
|---|---:|---:|
| Event to required Native result | **37m28s** | **37m03s** |
| Unweighted Native runner-minutes | **97.566667** | **102.533333** |
| Initial queue | 3s | 3s |
| First reliable policy result | 34s | 30s |
| First completed functional Native family | **181s** | **390s** |

The complete predeclared Native comparison saves **25 seconds, or 1.11%**.
Runner time increases by **4m58s, or 5.09%**, and the first functional-family
result arrives **209 seconds later**. The six-runner cap remains intact.

The old serial physics/ordinary-worldgen predecessors consumed **451.438068s**.
The candidate's identical sanitizer command consumed **433.053582s more** than
the control. Its critical worker was an AMD EPYC 7763; the control used an AMD
EPYC 9V74. Both had four logical CPUs and the same reported Ubuntu image version.
Other unchanged commands also vary materially across heterogeneous workers.
The 451-second dependency removal must not be substituted for the actual
25-second complete-workflow result or presented as a demonstrated 20–30% speedup.

The full five-workflow candidate cohort completed in **37m03s**, with **299.6
unweighted runner-minutes**, 73 executed jobs and three expected conditional
skips. The control reran Native only, so the five-workflow total is descriptive;
it is not a matched whole-repository cost comparison. Neither a sustained
percentage improvement nor a warm-cache benefit has been established.

## Source and qualification

The candidate changes exactly five CI tooling/test files and five current
documentation/retrieval files. Canonical `native.yml` is byte-identical to the
accepted base: required `native` context, triggers, permissions, concurrency,
failure continuation and six-runner cap are unchanged. All 20 command argument
lists, sanitizer environments, policy keys and child timeouts match. Only the
ownership of `worldgen-sanitize` changes. Physics evidence remains owned by
`worldgen`, and all seven complete source/run/attempt-bound receipts are required.

The complete production diff is empty. Native/Godot source, Makefile, native
test inputs, runtime binaries and their manifests are unchanged. The actual PR
merge checkout `9ae8b2a483d756af18ad21f1d99f529645640f12` has the candidate's exact
tree `b01d95a8cb90ae0be9fb36e368694167dd80efb6`.

| Hosted gate | Evidence | Result |
|---|---|---|
| Native control | [44948256292](https://github.com/techrote/cybersand/actions/runs/44948256292) | Six families, 20 original commands and complete aggregate passed. |
| Native candidate | [44948729271](https://github.com/techrote/cybersand/actions/runs/44948729271) | Seven required families, the same 20 commands and complete aggregate passed. |
| Documentation/provenance | [44948729294](https://github.com/techrote/cybersand/actions/runs/44948729294) | All 22 original steps; 18 materialized runtimes; zero provenance errors. |
| GDExtension/Godot | [44948729275](https://github.com/techrote/cybersand/actions/runs/44948729275) | 338 Linux cases in 24 shards and 315 Windows cases in 23 shards; both builds, both coverage reducers and Art smoke passed. |
| Palette | [44948729280](https://github.com/techrote/cybersand/actions/runs/44948729280) | Eight jobs, six cohorts, 19 process cases and the current v3 acceptance contract passed. |

Palette's retained v2 finished-image identity diagnostic remains explicitly
failed and non-gating under its unchanged contract. This review does not claim
universal cross-backend pixel identity or physical-device acceptance.

The final reviewer independently verified all **15 Native family/aggregate ZIP
digests** against fresh GitHub metadata and replayed each immutable source's
canonical verifier in separate interpreters. Both replays exactly equal their
hosted aggregates and retain the same 192-case core registry. The reviewer also
rechecked nine platform artifact digests and the exact coverage JSON bytes.
These are checksum/custody checks; no additional cryptographic signature is claimed.

## Adverse controls and limits

All 92 focused CI tests passed in engineering/source review. Seven additional
final-review controls used actual isolated Git/process operations: two rapid
pushes while an earlier worker remained active, stale-source result rejection,
an actual stale remote lease refusal, a changed checkout/event mismatch, tracked
source mutation during a worker, exit-19 failure and SIGTERM cancellation with
original 19/143 exits and partial log hashes retained. Original source bytes
were restored, and the shared checkout remained clean.

Those controls used a local bare remote and local processes. They do not claim a
new hosted publication or GitHub service cancellation qualification. Publication
workflows and existing lease/custody boundaries were not modified by this PR.

## Recommended disposition

Keep this qualified candidate as Draft/HOLD and retain the complete measured
pair, including cost and first-feedback regressions. An inexpensive inspection
of the already-selected historical cohort may identify source-compatible
hardware matches, but any such retrospective diagnostic must remain separate
from this predeclared comparison. No additional expensive campaign is justified
solely to seek a preferred percentage.

Future qualification should use genuinely source/test-compatible, hardware-aware
comparisons and preserve every attempted result. Current main still has six
Native families; the seven-family proposal is unmerged. Stage A, merged through
#714 at `846fe0533b3170e7b01f690518da49fc40cc24d1`, already provides the separately
measured 9m51s improvement in stale-source rejection feedback.

Retained-copy navigation: [source review](stage-b-final-source-review.json),
[local adverse controls](stage-b-local-adverse-summary.json),
[Native artifact/replay cross-check](native-final-spotcheck.json),
[platform artifact cross-check](stage-b-platform-final-spotcheck.json), and
[platform gate review](stage-b-platform-review.json). The [paired timing report](stage-b-native-paired-report.md)
and [evidence index](README.md) link the complete retained measurements. Original raw
local records remain under `build/ci-opt-002/final-review/` and `build/ci-opt-002/audit/`;
original hosted artifacts remain with their cited Actions runs. Only this navigation
footer was adapted when the reviewer document was copied into the retained report.
