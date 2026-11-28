# Final fd0830ab Windows — independent renderer and progression addendum

## Source and review boundary

This 26 November review supplements the [final Linux renderer review](renderer-campaign-06-review-a.md).
It inspects actual application `fd0830abcfadd9ae19162e5677943bb131223e59`,
not the A1 runtime override. Original run
[45721790366, Windows artifact 15078368890](https://github.com/techrote/cybersand/actions/runs/45721790366/artifacts/15078368890)
is 142,359,818 bytes, ZIP SHA256
`84671ae068d7a759112cd6ca84a5485ec555db3aa3a04342f3c7a9bd2927ee13`.
The campaign receipt SHA256 is
`af7fded1a69d50a12fcbbcbca61b6365af0e1cc02ccdf444366b828eafa3b1bc`.
B independently admitted the original optical campaign through the unchanged
strict fd reader; this addendum independently reads the technical pixels and
recomputes the raw progression populations.

The actual graphical engine was Godot 4.7, exact console binary SHA256
`d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`.
It used ANGLE OpenGL ES 3.0 over Microsoft Basic Render Driver/D3D11. This is
hosted software rendering. Native and Rapier binary/provenance identities are
retained in the [renderer review JSON](renderer-campaign-06-windows-review-a.json).
The application revision is distinct from its source-matched native build
revision; neither is substituted for the other.

## Alpha and dense-filter result

The final renderer completed **109 checks with zero failures**. The right-hand
64×64 Classic region under haze 0.3 and parent opacity 0.5 matched the original
Classic baseline exactly: all 16,384 RGBA bytes, zero changed channels and zero
maximum delta. The dense checker witness starts at approximately 0.8 contrast
and reaches zero at radii 1, 2, 3 and 6; thin white hue is preserved at every
registered radius. The retained tiny technical images were also inspected.

The same literal Classic operation can produce different encoded values on the
two backends. These actual example values preserve the distinction:

| Sample | Linux Classic and Linux wipe | Windows Classic and Windows wipe |
| --- | --- | --- |
| Bright, (142,14) | (83,84,86,128) | (82,84,86,128) |
| Dark, (143,14) | (11,13,15,128) | (11,13,14,128) |
| White, (168,16) | (92,94,95,128) | (91,93,95,128) |
| Partial blue, (172,44) | (1,2,25,64) | (1,2,25,64) |

Classic exactness is established **within each actual backend**. The Windows
values must not be judged against Linux's fixed byte oracle. The earlier failed
Linux blend case and the final corrected Linux/Windows cases remain separate.

Of the 18 final technical image pairs compared between Linux and Windows,
11 are exactly equal. Seven differ, and every differing channel differs by
exactly one encoded u8 level. There are 5,524 differing channels out of 884,736
compared channels:

| Technical image | Changed channels | Maximum u8 difference |
| --- | ---: | ---: |
| actor-reveal | 138 | 1 |
| frequency-aperture-2 | 252 | 1 |
| frequency-aperture-6 | 1,386 | 1 |
| frequency-detail | 882 | 1 |
| frequency-diffusion | 288 | 1 |
| frequency-haze-opacity-classic | 780 | 1 |
| frequency-haze-opacity-wipe | 1,798 | 1 |

This does not weaken the same-backend Classic oracle. It is also not a
whole-native-scene cross-backend equivalence claim. The original and A1 shader
pairs in the separate cost experiment remain exactly equal within each host;
those comparisons do not depend on cross-backend identity.

## Independent raw Windows progression calculation

The original challenge progression report SHA256 is
`38caabe80197e78d3ad2e2d370e24b6135ff21a87d9fded22a4d9d6e314db4ce`.
For all 15 windows, this review recomputed native and Rapier rates from actual
counter differences and elapsed microseconds. It reconstructed every physical
interval from successive completion timestamps and independently calculated
the nearest-rank p95. These values matched the retained report. All three
repeats per profile are preserved in the [raw arithmetic review](progression-campaign-06-windows-review-a.json).

The original criterion is unchanged: at least 90% of the Classic median rate
for both physical counters, with physical p95 no greater than the larger of
1.20 times Classic p95 or Classic p95 plus 10 ms. Here the allowance is
402.738 ms, from Classic's 335.615 ms median p95.

| Profile / quality | Native ticks/s median | Native / Rapier rate relative to Classic | Physical p95 median | Registered observation |
| --- | ---: | --- | ---: | --- |
| Classic / Balanced | 2.973471 | 100% / 100% | 335.615 ms | Reference |
| Architectural / Balanced | 2.501342 | 84.121950% / 84.121950% | 397.219 ms | Rate fails; tail passes |
| Cinematic Deep Focus / Balanced | 2.469197 | 83.040898% / 83.040898% | 405.805 ms | Rate and tail fail |
| Gameplay Clarity / Balanced | 2.257506 | 75.921571% / 76.010746% | 439.741 ms | Rate and tail fail |
| Diorama / High | 2.249769 | 75.661363% / 75.686380% | 438.785 ms | Rate and tail fail |

All four enabled profiles fail the rate criterion. Architectural's Windows tail
passes; it would be incorrect to claim that every enabled Windows tail failed.
This does not rescue the failed rate or contradict the separate Linux tail
results. Initial challenge admission was **51.798 seconds**, also failing the
unchanged 45-second target. It is distinct from the later A1 experiment's
63.802-second initial admission and the original five large Windows misses.

## Disposition

Final Windows graphical correctness adds real evidence for the repaired alpha
boundary and dense aperture. It does not establish enabled-optics performance
acceptance. The independent actual native measurements confirm the frozen
application's PERFORMANCE HOLD. The external A1 improvements are useful
separate research and are not silently credited to this application or its
portable package. Physical Windows 11/NVIDIA acceptance, owner artistic
preference and unprimed gameplay interpretation remain open.
