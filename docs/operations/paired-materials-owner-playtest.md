---
title: Paired materials owner playtest packet
status: Current
document-kind: guide
scope: Source-bound exploratory and final owner checks for draft PR358; all human results start untested and checkpoint policy requires a separate owner decision
canonical-for: [paired-material-owner-playtest]
last-reviewed: 2026-11-04
related-documents: [../systems/paired-materials-and-curing.md, ../reference/level-saves-and-replay.md, ../audits/2026-11-04-paired-materials-remediation.md]
---

# Paired materials owner playtest

**Human acceptance: UNTESTED. PR358 remains draft and unmerged.** Use the repaired
source named in its latest remediation checkpoint. Earlier owner packages or
unchanged native DLLs do not identify the repaired Godot scripts. Technical test
passes and this checklist are not an owner acceptance result.

## Authenticate and launch

Use an isolated checkout of `codex/paired-materials-20261103` with its LFS objects
materialized. Preserve any dirty development checkout. From that source root on
Windows, using the pinned Godot4.7 installation:

```powershell
python tools/experiments/run_paired_material_review.py --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe --identity-only
python tools/experiments/run_paired_material_review.py --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe
```

On Linux, pass the authenticated Godot executable to the same helper. Save its
identity JSON with your observations. Require the published repaired source/tree,
native build source `f069b439510742e7bbb6ddcd0afc6e7372de03e8`, engine
`4.7.stable.official.5b4e0cb0f`, and the exact runtime below. The helper refuses
dirty or mismatched project/native inputs; it records the selected engine bytes.

| Runtime | SHA-256 |
|---|---|
| Windows native | `2b80fcacd9f79c7e0753aeae51d617931a7f0a3464152527cdac6144aaac59f3` |
| Linux native | `fcdf97b8d3623074b018f489e202f6b9d307f2ef8ac160a25434d0e4e5a74211` |

Enter **F2 → Paired walls / finite curing** if starting from the launcher. LMB
paints, RMB erases, the wheel changes radius, P pauses, R reconstructs, keys1/2
choose actors, and F2 retires the lab and returns to the launcher. Select Stone,
Salt or Coal to reconstruct its matching A/B/C bays.

## Record these observations

Record PASS, FAIL or UNTESTED, source identity, OS/renderer, actor/family and brief
steps for each row. A failure should name the visible behavior and reproducible
location, not merely the final image.

| Check | Procedure and expected observation | Human result |
|---|---|---|
| Shell support and breach | Land each actor on intact bay B, compare loose A and breached C, then use **Breach intact roof**. Observe actual release and any penetration/snags. Explicit editing is not load fracture; detached islands may remain static. | UNTESTED |
| Shared chemistry | Put Water beside Salt Wall, Acid beside Stone Wall and Fire/heat beside Coal Wall; compare exposed loose controls. Record actual products/support loss and retained quiet-contact stalls. Painting over a target is an external edit. | UNTESTED |
| No-agent control | Fresh dry tray, no dose: no cure. Pause, add16 Water cells, remove free Water before stepping, then run: no activation remains. | UNTESTED |
| Finite dose and retained bound Water | Fresh16-cell dose is4,080 units at8bits. Observe the activated rim becoming Crust over180 eligible updates. Remove remaining free Water mid-cure: already bound cells can finish; no agent-free propagation should start. | UNTESTED |
| Erasure and diagnostics | Hold paint/erase inside and outside the tray, including no-op strokes and paused play. Watch sample age/staleness. Counts refresh at a bounded rate; erasing bound Binder is a separate destruction sink and must not be called closed-cure conservation. | UNTESTED |
| Existing controls | Reset between Cement and ordinary Sand/Water controls. Record changed behavior if observed; Cement retains its distinct old Air/Water/Brine/Concrete behavior. | UNTESTED |
| Lifecycle and usability | Pause/resume, reset, change actor/family, lose/regain focus and rearm input, return through F2 and reopen. Record stalls, stale inputs and held-brush responsiveness. | UNTESTED |

## Decisions kept separate from gameplay

The [checkpoint decision](../audits/2026-11-04-paired-materials-remediation.md#quantity-compatibility-owner-decision)
requires an explicit owner choice: accept refusal of old schema1 physical
checkpoints, or commission a bounded tested migration. It does not follow from
a successful playtest. CYSD Binder exchange remains same-precision only.

The inherited native-OpenGL growth-pan failure and six-pixel diagnostic retain
their original classifications. Full required CI, observer compatibility for a
future union with #370 and the renderer owner's failure disposition remain
technical gates. Report exploratory feedback now if useful; final acceptance
must name the repaired and qualified source. No automatic merge is authorized.
