---
status: Current
date: 2026-11-26
scope: Independent review of immutable external A1 cost observer v2; no application adoption
---

# Specialist C — actual two-platform shader-cost review

## Disposition

**A1 is a credible deferred optimization candidate. It does not qualify a changed
application or resolve the frozen evaluator's performance HOLD.** The original
application `fd0830abcfadd9ae19162e5677943bb131223e59` and its principal package
remain unchanged. In the registered small challenge, the empty-coverage shader
reduces the measured physical-progression penalty and preserves the admitted
pixel comparisons. Linux Architectural still misses the unchanged 90% rate
criterion; the other A1 rate passes are narrow. A different source identity and
new application/delivery gates are necessary before adoption.

This review ran the unmodified published strict reader from observer
`55951750466dc76e0482954f3d9e8bd9a9d1ada4` on both original artifacts from
[run 45733231981](https://github.com/techrote/cybersand/actions/runs/45733231981).
Both passed. C also independently reconstructed every completed Rapier tick
sequence, counter-derived native/Rapier rate, physical completion gap and
nearest-rank p95 in all fifteen windows on each host. The compact
[original identity and recomputation record](c-shader-cost-v2-actual-review.json)
retains both archive hashes, report hashes, all thirty per-window calculations
and the exact backend strings. Whole archives and process logs remain in their
original artifacts, not this repository document.

## What the admitted comparison establishes

The v2 reader requires direct live Shader-resource identity and code hashes on
the actual cached and drawable materials before and after each timed window.
It separately retains the frozen statistics expression as original source
provenance. These distinctions matter: the v1 statistics mismatch remains a
rejection, and the earlier detached-resource/original-only inference was
corrected by the same-resource runtime diagnostic. V2 does not retroactively
admit v1 timing results. See the preserved
[identity correction](c-shader-identity-correction.md) and
[v2 source review](c-shader-cost-v2-source-review.md).

Both actual hosts passed eighteen exact synthetic image comparisons and six
exact native-world comparison pairs. Their live attachment and restoration
receipts bind the selected shader, three processed material attachments, native
ownership, original application-file custody and unchanged direct Play material
presentation. These are valuable bounded correctness results. They do not prove
equivalence for every scene, palette, sampling configuration or future renderer.

The three-repeat cost comparison uses actual native tick deltas and completed
Rapier steps over each observed window. It does not substitute nominal FPS,
render submission rate or zero capture/upload counts for physical progression.
Linux uses llvmpipe; Windows uses ANGLE with Microsoft Basic Render Driver. No
physical NVIDIA measurements are present.

## Results and remaining cost

The table reports median native rate relative to the same host's Classic
windows. Rapier ratios give the same A1 gate decisions. The registered p95 limit
is 120% of that host's median Classic p95, independently computed for this annex.

| Host / treatment | Original rate / Classic | A1 rate / Classic | A1 gain versus same profile | A1 physical p95 | Registered p95 limit | Rate / tail decision |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Linux Architectural | 82.1672% | **89.6821%** | +9.1459% | 201.378 ms | 207.762 ms | **Rate FAIL**, tail pass |
| Linux Gameplay Clarity | 77.7078% | 90.4663% | +16.4185% | 183.013 ms | 207.762 ms | Both numerical criteria pass |
| Windows Architectural | 80.1078% | 90.7529% | +13.2884% | 370.074 ms | 401.8224 ms | Both numerical criteria pass |
| Windows Gameplay Clarity | 74.2566% | 90.1953% | +21.4643% | 372.136 ms | 401.8224 ms | Both numerical criteria pass |

These percentages describe this annex's source-bound cohort, not the earlier
full application campaign. They must not replace the frozen full-campaign
performance numbers or be pooled across hosts. Sequential repeats are not a
confidence interval. Windows A1 still contains individual physical completion
gaps above one second: the maxima are 1,040.738 ms for Architectural and
1,054.236 ms for Clarity. Passing the registered p95 bound does not establish a
smooth ordinary-play experience.

The Windows initial scene admission is **63.802 seconds**, exceeding the
unchanged 45-second target. Faster subsequent scene replacements in this same
process are separate observations. They do not erase initial admission, the
prior original five-scene failures or the frozen sustained-session startup miss.

## Recommendation for any later adoption

The measured advantage is consistent with avoiding work on transparent
decorative coverage. Dense architecture may leave less empty coverage and may
benefit less; that is a concrete remaining generalization risk. A1 also does not
address the cost of nonempty crisp-profile detail/glow and Play-mask samples.

Any adoption should be one separately source-bound application revision, with
the registered rate/tail criteria retained. Its delta gate should include exact
alpha/wipe/edge cases, sparse and dense ordinary native scenes, actual shader
attachments and restoration, material/readback isolation, live editing and
Undo/Redo, scene/save/reopen, multiple-actor movement and clarity, and sustained
resource behavior. It must then receive its own portable package and actual
shipped-command qualification. The existing frozen application, original
artifacts, failed targets and earlier reader rejections stay identifiable.

For the current owner evaluation, Classic remains the immediate performance and
visual reference. Gameplay Clarity is the strongest practical presentation
candidate from C's separate opaque-profile comparison, but its frozen full
application progression regression remains real. Users should judge actor
control, false platforms/passages and architecture retention alongside the
image; the research result is not a reason to silently activate a new default.
