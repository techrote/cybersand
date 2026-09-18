---
title: Water H-gate synthesis — bulk flow, precision, surface stability and presentation
status: Current
document-kind: evidence
scope: Human Water Feel evidence through 2026-09-18 across twelve registered scenarios; programme disposition for #14/#18/#26 and post-H measurement charter
canonical-for: [water-h-gate-2026-09-18]
last-reviewed: 2026-09-18
related-documents: [2026-09-12-issue-19-water-feel-lab.md, ../operations/water-feel-lab-experiment.md, ../operations/architecture-programme-water-feel-addendum.md, ../operations/architecture-programme.md, ../systems/water-design.md, ../systems/material-appearance-and-rendering.md, ../reference/validation-evidence.md]
---

# Water H-gate synthesis — 2026-09-18

## Executive disposition

The Water H campaign has produced enough evidence to stop broad baseline manual testing and move back to engineering.

The main conclusion is **not** “choose a mass precision”. The dominant current Water-feel defect is a bulk transport/leveling problem:

- deep or spatially extended Water redistributes laterally too weakly or too slowly;
- broad bodies can retain steep free-surface slopes, cliffs and terrace steps for far too long;
- communicating pools remain visibly non-level;
- constricted releases can behave like a granular slump with an approximately 42–43° free-surface wedge;
- shallow Water, thin dribbles and edge breakup can look substantially more convincing than the same solver in deep volumes.

The leading mechanism hypothesis is therefore a missing or inadequate **depth/head-dependent lateral drive and/or bounded larger-scale leveling mechanism**. Current Water performs gravity and local same-row equalization, but has no explicit term that makes a lower cell push laterally harder merely because a deep Water column sits above it.

This is a **#26 problem first**. It does not yet prove that #18 compact directional history is useful. #18 remains open and held.

A second independent conclusion is that current presentation is also insufficient. Four-level oriented reconstruction exposes real quantization and may amplify some visible surface instability. Rendering is expected to help with surface smoothness, contact shape, temporal continuity and controlled breakup, but it must not conceal wrong authoritative discharge, leveling, quantity or settling.

A third conclusion is now strong enough to constrain later state-budget work: **3-bit Water is strongly disfavored if tiny droplets matter to gameplay**. In `long-tail-settling`, the registered 8/12/16 normalized droplets quantize to zero at 3-bit and disappear from authoritative state. No shader can recover Water that does not exist.

No production Water mass width, Cell layout, flow-memory field, sparse ballistic path or production renderer is selected by this report.

## Programme state after H

| Work | Disposition |
|---|---|
| #19 Water Feel Lab | H-ready apparatus successfully used; manual H evidence now exists. #19's original completion remains unchanged. |
| #26 Water leveling | **Priority next engineering work.** Characterize and compare bounded head/leveling candidates. |
| #18 compact motion/history | **Remain open, held.** Re-test directional references after #26; admit history only if a residual directional-persistence target remains. |
| Water mass precision | mass8 remains numerical/control oracle. No production selection. mass3 strongly disfavored for tiny-quantity representability; 5/6/8 remain serious later candidates; 4 remains an explicit threshold-risk arm. |
| Water presentation | Required later layer. Must be measured separately from authoritative surface behavior. |
| #20 sparse ballistic motion | No new admission from H. Existing dependency remains. |
| #14 G-final | Still open. H materially changes the evidence set but does not complete the architecture decision. |

## Evidence identity and integrity

### Runtime and apparatus

Formal semantic comparisons used coherence 12, seed 0 and four-level oriented presentation unless explicitly noted.

The retained Windows H sessions report the validated #19 runtime lineage:
- source checkpoint: `3ef4923abb011c5451be0f2ba477d8a3bffb0ee3`;
- Windows DLL SHA-256: `ce0b252171a7931317068eda62ec1ec773632d760f85f0ebb594af44d197a138`;
- Godot 4.7 official runtime.

Two H-apparatus fingerprint groups exist:
1. the earlier shallow-pool session uses the first recorder/panel apparatus;
2. corrected `steps` and every later retained session use one common later apparatus fingerprint, including the corrected `steps` recipe and later capture UX.

The machine-readable companion file, `2026-09-18-water-h-gate-evidence.json`, retains raw archive filename, byte size, SHA-256, reveal mapping, canonical observations, sequence notes and explicit evidence limitations.

### Raw archive inventory

Eleven unique H session archives are retained in the evidence index, totalling about 735 MB decimal (~701 MiB). A second uploaded `direction-diagonal` ZIP is byte-identical and is recorded as an alias, not a second experiment.

Raw PNG sequence archives are not committed to Git history. Their exact identities are retained by size and SHA-256 so a later local copy can be verified against this report.

### Excluded, partial and qualified evidence

The following distinctions are mandatory:

- the original stale/pre-#19 H attempt is invalid H evidence;
- the pre-fix `steps` fixture faced uphill and is excluded; only corrected downhill `steps` is used;
- the early `irregular-bed` pilot is incomplete/contaminated; a later qualitative subset is retained but lacks its reveal mapping, so it is not used for mass-bit ranking;
- `fast-dump` has formal B/C captures but no canonical A formal observation; do not invent a complete rank;
- the current `u-vessel` recipe is uniformly filled and is **not** a differential-head U-tube; its run is calm-surface evidence only;
- one constriction C sequence was recovered by a later reblind after reveal. Its policy mapping is identical, but its camera framing differs, so it is supplemental, not part of the original blinded judgement set;
- frame-sequence PNG output does not capture every 60 Hz render publication. Use simulation tick/serial metadata for timing and geometry, not frame index as a literal 60 fps video clock.

## Human evidence matrix

| Scenario | Revealed result / observation | Main inference |
|---|---|---|
| `shallow-pool` | 3-bit Marginal/rank3; 5-bit Marginal/rank2; 8-bit Marginal/rank2. 3-bit has irregular blunt sawblade surface; 5-bit missing/speckled surface; 8-bit coarse regular sawtooth. | Precision affects visible surface quality, but none is a production-quality appearance. |
| `irregular-bed` | Label-blind retained subset: Acceptable/Acceptable/Marginal; all described as close and somewhat slow. | First strong shared-sluggishness signal. Do not use for bit ranking without reveal. |
| corrected `steps` | A=3 Reject/rank3; B=5 Marginal/rank2; C=8 Acceptable/rank1. Owner: shallow Water and rapid edge dribbles can look convincing; deeper Water feels slow/stuck/hesitant. | Strong evidence that local depth changes perceived realism and that useful shallow-flow character already exists. |
| `constriction` | A=3 Marginal/rank1; B=5 Reject/rank2; C=8 Reject/rank3. All retain a broad granular-like wedge; representative later slope ~42–43°. | Bulk defect dominates enough to reverse precision preference. Strong head/pressure-style deficit signal. |
| `connected-pools` | A=3 Reject/rank3; B=5 Marginal/rank2; C=8 Marginal/rank1. Multi-degree free-surface slope remains long after connection; B/C ~3.4° around tick 4200 in retained analysis. | Cleanest communicating-level/equilibrium evidence. Higher precision does not solve leveling. |
| `fast-dump` | B=5 Marginal/rank2; C=8 Reject/rank3; no canonical A formal capture. Owner annotations identify an impossible wall-adjacent gap, unacceptable middle terraces, interesting but glitch-like tumbling randomness, and a smoother desired mockup. | Structural defect vocabulary: contact gap, terrace, slump, breakup. Useful “tumbling” character may be reproduced later under control, not preserved as a bug. |
| `u-vessel` | A=3 Marginal/rank2; B=5 Marginal/rank2; C=8 Acceptable/rank1. 8-bit has only four tiny raised lumps; lower precision shows more lumps/serration. | Calm-surface/quantization evidence only. Current fixture does not test differential head. |
| `long-tail-settling` | A=3 Anomaly/rank3; B=5 Marginal/rank2; C=8 Good/rank1. The three smallest leftmost droplets are missing entirely at 3-bit. | Direct authoritative representability boundary. Rendering cannot repair quantities quantized to zero. |
| `direction-horizontal` | A=3 Reject/rank3; B=5 Good/rank2; C=8 Good/rank1. Observer says 8-bit continues lateral flow after 5-bit has largely stopped. | Precision-dependent lateral equalization/persistence evidence, but not a clean stored-velocity/history oracle. |
| `calm-settling` | A=3 Reject/rank3; B=5 Acceptable/rank2; C=8 Good/rank1. 8-bit reaches an acceptable final state but is judged **2–4× too slow**; “ripple/hill nipple” remains. | Strongest H target for time-to-flat/slope-decay, plus explicit surface-defect metric. |
| `direction-diagonal` | A=3 Reject/rank3; B=5 Acceptable/rank2; C=8 Good/rank2. 3-bit waterslump; 5-bit calmer terraces but edge drips die quickly; 8-bit lively but flickering hillnipple/terrace edges. | Confirms slump/terrace/shimmer family beyond purely horizontal geometry. |
| `ledge-sheet` | A=3 Reject/rank3; B=5 Acceptable/rank2; C=8 Good/rank1. 8-bit has better dribble/front motion and several interesting front phases, but vertical-line/block artifacts remain undesirable. | Positive shallow-flow control. Preserve useful liveliness while fixing deep-water and surface-stability defects. |

## Cross-scenario conclusions

### A. Bulk lateral relaxation / leveling is the dominant simulation defect

The repeated symptoms are mutually consistent:

- deep bodies keep excessive height differential;
- connected bodies level too slowly;
- deep releases form broad persistent slopes;
- constricted Water resembles a granular heap;
- slopes/terraces can become quasi-stable rather than liquid-like;
- shallow Water is much more convincing than deep Water.

The current leading hypothesis is not “Water needs full pressure physics”. It is narrower: local pairwise equalization lacks enough information about **column head and/or a nearby lower surface potential** to generate convincing bulk redistribution.

That justifies two bounded candidate families under #26:

1. **Head-scaled local drive**  
   A bounded local depth/head proxy increases lateral request strength and/or cadence where a deeper Water body should push outward more strongly.

2. **Bounded leveling horizon**  
   A limited horizontal lookahead/relaxation horizon lets Water respond to a nearby lower free-surface potential rather than only immediate same-row mass difference.

Test these separately before combining them. Neither candidate implies a global pressure field, Navier–Stokes solver, unbounded search or persistent velocity state.

### B. Calm-settling supplies an explicit speed target

The 8-bit `calm-settling` arm reaches a human-acceptable final state but is explicitly judged **2–4× too slow** to reach it.

Therefore #26 must measure:
- final equilibrium error;
- **and time-to-flat / slope-decay rate**.

A candidate that reaches the same final surface but only marginally faster has not addressed the owner-observed deficit. Conversely, “make Water globally 4× faster” is not the requirement: shallow/ledge behavior is already comparatively good and must be preserved.

The 2–4× observation is an H target band, not yet a hard benchmark threshold. Freeze the baseline measurement definition first, then preregister candidate thresholds before semantic candidate code.

### C. Surface-state defects are first-class acceptance metrics

The H campaign repeatedly identified two named defects:

- **hillnipple** — a localized surface mound/peak or ripple-like protrusion that persists or flickers unnaturally;
- **terrace / terrace shimmer** — discrete surface shelves/steps whose edges persist, flicker, move in/out, or visibly switch state.

Fast-dump also adds:
- **wall-contact gap** — an empty/visually detached slit where the main Water body should remain in contact with a wall/outlet boundary.

These must not be relegated to “shader polish”. Measure them at two layers.

#### Authoritative surface metrics

Derived from Water mass/state before presentation:
- **hill amplitude**: maximum positive local surface deviation above a frozen low-pass/local-equilibrium baseline;
- **hill width** and **hill lifetime**;
- **terrace severity**: count, horizontal extent and vertical step magnitude of persistent surface shelves in a registered ROI;
- **authoritative shimmer/turnover**: rate at which the authoritative surface contour changes terrace/hill classification over simulated time;
- **contact-gap extent/lifetime** where fixture geometry requires continuous contact.

If these are bad in authority, the simulation candidate must improve them. A shader must not hide a persistent authoritative mound, terrace or contact gap and then claim the physics is fixed.

#### Rendered surface metrics

Computed from rendered pixels for the same tick-indexed authoritative frames:
- rendered hill amplitude/width;
- rendered terrace severity;
- rendered contour turnover / shimmer rate;
- rendered contact gap;
- temporal flicker at unchanged or minimally changed authority.

This creates a diagnostic matrix:

| Authority | Render | Interpretation |
|---|---|---|
| bad | bad | simulation defect visible as expected |
| good | bad | renderer/reconstruction defect |
| bad | superficially good | renderer is concealing an authoritative defect; simulation still fails |
| good | good | pass candidate |

The exact contour extraction, smoothing window, ROI and thresholds must be frozen in #26 registration before comparing semantic candidates.

### D. Preserve useful shallow-flow liveliness

The owner explicitly identified several current shallow/front motifs as potentially desirable:

- rapid over-edge dribble;
- serpentine trail;
- splashy flat front;
- splashy creep;
- small active local breakup;
- some tumbling/asymmetric front motion.

By contrast the following are rejected:

- broad waterslump;
- persistent hillnipples;
- terrace edges that shimmer/flicker in and out;
- vertical-line / vertical-block phases;
- impossible wall-contact gaps.

This means #26 is not allowed to “solve” the problem by making all Water maximally smooth, inert or uniformly fast. The later H regression must preserve the useful statistical/lively character of thin flows.

If the later renderer recreates good breakup motifs, it should do so from stable authoritative state using bounded presentation logic, not by depending on accidental solver instability.

### E. Precision matters, but the bulk defect currently confounds preference

Precision preference is not monotonic while flow is wrong:

- 8-bit is preferred in corrected steps, connected-pools, u-vessel, long-tail, horizontal, calm and ledge cases;
- 3-bit is visibly poor in many surface and flow cases;
- 3-bit nevertheless ranked best in constriction, where every arm retained the dominant granular-like bulk defect.

Therefore do not choose a production width from aggregate H ranks today.

Keep mass8 as numerical/control oracle. After #26 and presentation work, retest a practical set such as **4/5/6/8**:
- 3-bit is now strongly disfavored if tiny droplets are gameplay-relevant;
- 4-bit remains an explicit threshold-risk arm because very small quantities are near its representability boundary;
- 5/6 are the most interesting potential reclaimed-bit candidates;
- 8 remains the exact/reference control.

### F. Tiny-quantity representability is not a rendering problem

`long-tail-settling` uses twelve 6×6 droplets with normalized masses `8, 12, 16, ... 52`.

Under the registered half-up quantizer:
- 3-bit (`max=7`) maps normalized 8/12/16 to zero;
- 5-bit retains all registered droplets but introduces approximately -4.0% initial physical quantization error across the set;
- 8-bit is exact.

The observer independently reported the exact 3-bit symptom: “3 leftmost drops are missing completely”.

This is a hard distinction between:
- **visual quantization**, which a renderer can often reconstruct acceptably;
- **authoritative representability**, which a renderer must not fabricate.

### G. Directional references do not yet admit #18

`direction-horizontal` and `direction-diagonal` show real precision-dependent differences in lateral motion and settling. They are useful pre-#26 baselines.

They do **not** cleanly isolate remembered momentum:
- horizontal is a horizontally extended strip plus same-row fill event;
- diagonal is a diagonal arrangement of Water blocks;
- neither injects a controlled persistent velocity/history variable.

Thus the observed differences can still arise from #26 leveling semantics and quantization.

After a #26 candidate passes its bulk/surface screens:
1. repeat horizontal and diagonal references;
2. add a true controlled directional-injection fixture if needed;
3. only if useful motion still decays too quickly should #18 register a concrete history target.

#18 remains open and unimplemented.

## #26 measurement charter

Before semantic candidate code, freeze the baseline implementation, source/artifact identity, ROIs, measurement definitions, run lengths, seeds/translations and rejection thresholds.

### Required automated fixtures

1. **Head-response family:** shallow / medium / deep reservoirs with identical outlets.
2. **Communicating pools:** fixed initial level difference.
3. **True unequal-head U-tube:** replace the current uniformly filled `u-vessel` as the hydrostatic/communicating-column probe.
4. **Constriction/nozzle:** strong transient pressure/head release.
5. **Fast dump:** large transient collapse and wall/outlet contact.
6. **Calm settling:** time-to-flat and surface stability.
7. **Ledge sheet / shallow dribble:** positive control whose lively behavior should not be destroyed.

### Bulk metrics

- early discharge as a function of initial head/depth;
- lateral COM displacement and range;
- free-surface slope versus tick;
- slope half-life;
- communicating-pool level difference and half-life;
- time-to-flat / time-to-registered equilibrium;
- cliff lifetime;
- total Water quantity / explicit source-sink ledger;
- active blocks, visits/transfers and wake work;
- p50/p95/p99/max tick cost and total run cost.

### Surface metrics — authoritative and rendered separately

- hill amplitude, width and lifetime;
- terrace count, extent and vertical severity;
- terrace/hill contour turnover (“shimmer”) per simulated second;
- wall-contact gap area/extent and lifetime;
- rendered-only temporal flicker where authoritative contour is unchanged;
- correlation between authoritative defect and rendered defect.

### Candidate acceptance requirements

A candidate is not accepted merely because one metric improves.

It must:
- materially improve head/depth response and time-to-flat in the registered deep/extended fixtures;
- reduce authoritative persistent hill/terrace/contact defects;
- not replace sluggishness with crawling, oscillation, perpetual micro-motion or excessive over-fluidity;
- preserve exact closed Water integer mass;
- preserve deterministic expected worker behavior;
- preserve bounded writes/work and scheduler/activity contracts;
- preserve protected granular/material policies and failure/region contracts;
- keep shallow/ledge positive-control behavior acceptably lively;
- report work and performance cost honestly.

### Candidate sequence

1. Baseline characterization only.
2. Head-scaled local-drive candidate.
3. Bounded leveling-horizon candidate with the same baseline.
4. Only if both isolated candidates justify it, one registered combined arm.
5. Small H regression on `calm-settling`, `connected-pools`, `constriction`, and `ledge-sheet`.
6. Then repeat directional references for the #18 admission/no-go decision.

## Presentation / renderer disposition

No current mass arm has a universally acceptable raw Water surface.

A later rendering pass may legitimately add:
- smoother derived free-surface reconstruction;
- sub-cell coverage;
- local normals/curvature;
- contact-aware boundary reconstruction;
- temporal interpolation/hysteresis;
- thin-film continuity and droplet shaping;
- bounded cosmetic ripple/breakup cues.

But presentation must be evaluated against the two-layer surface metrics above.

Rendering may fix:
- pixel-level sawtooth/serration;
- presentation-only threshold flicker;
- visually harsh terrace boundaries when authoritative mass is already smooth enough;
- benign small hill/ripple appearance;
- aesthetically useful front breakup.

Rendering may **not** be used as evidence that these authoritative defects are solved:
- incorrect discharge;
- slow level equalization;
- persistent authoritative hill/terrace states;
- contact gaps caused by real occupancy/mass state;
- quantities lost to initial quantization.

## H apparatus and recording limitations

The frame-sequence recorder is useful as tick-indexed supplemental evidence, not as literal 60 fps video.

Early `steps` recording reduced simulation progress to roughly 56 Hz and saved only about 21–22 PNG/s. Later sessions generally kept simulation close to 60 ticks/s while still saving fewer visual frames because synchronous readback/PNG work skipped intermediate render publications.

Therefore:
- human feel judgement comes from normal-speed audition, not recorded playback;
- use tick/serial metadata for motion timing;
- sequence frame count is not elapsed simulation frames;
- do not infer a complete 60 Hz visual trace;
- duplicated or stale pre-reset frames at reset boundaries are provenance artifacts and are explicitly identified in the evidence index.

The recording apparatus should be optimized separately if full-rate visual evidence becomes necessary; this does not block #26 automated native/authoritative metrics.

## Recommended minimal future H regression

Broad baseline H testing is complete enough for engineering.

After an automated candidate passes #26 screens, use only:

1. `calm-settling` — time-to-flat plus hillnipple/shimmer;
2. `connected-pools` — communicating-level equalization;
3. `constriction` — deep/head-driven discharge and slump;
4. `ledge-sheet` — preservation of good shallow dribble/front breakup.

Repeat `direction-horizontal` and `direction-diagonal` only after #26 to decide #18 admission/no-go.

## #18 disposition — explicitly remain open

**Do not close #18.**

The H campaign found a real Water-motion deficit, but the strongest evidence points to head/leveling and surface-stability behavior rather than stored directional memory.

#18 should remain open while #26 characterizes and, if possible, repairs that deficit.

After #26:
- if a clean directional-injection test still shows useful motion dying too quickly, register that residual as #18's concrete benefit target and run the compact-history experiment;
- if the apparent directional deficit disappears or becomes irrelevant after leveling is repaired, complete #18 by an H-backed no-go.

No #18 implementation is admitted by this report.

## G-final / architecture conclusion

The H gate has served its purpose: it prevented a premature state-budget choice and exposed the higher-priority behavior problem.

Current programme decision:

1. retain mass8 as numerical/control reference;
2. select no production Water mass width yet;
3. strongly disfavor mass3 where tiny Water quantities matter;
4. move engineering priority to #26 automated head/leveling/surface characterization;
5. treat hillnipple, terrace severity, terrace shimmer and wall-contact gaps as first-class two-layer metrics;
6. preserve lively shallow/edge behavior as a positive-control requirement;
7. keep #18 open/held until the residual directional-memory question is isolated after #26;
8. keep rendering reconstruction as a required later layer, but never as a substitute for correct authoritative bulk flow;
9. keep G-final open until the admitted #26/#18 consequences and other programme dependencies are reconciled.

This report is an evidence and programme checkpoint, not a production migration or issue closure.
