# Sparse aperture failure and dense optical replacement

## Why the first kernel was replaced

The first optical shader sampled a centre and four points on an expanding cross,
optionally adding four diagonal points. Its transparent-edge tests passed on
both hosted backends. That did not establish its response to fine architectural
texture. The subsequent frequency review found a concrete failure: a one-cell
checkerboard disappears at odd integer radii and returns at even radii.

For the original balanced kernel at integer radius `r`, the response to spatial
frequencies `kx, ky` is

`H = 0.5 + 0.25 × [cos(r × kx) + cos(r × ky)]`.

At checker frequency `kx = ky = π`, this becomes `0.5 + 0.5 × cos(r × π)`.
Crossfading adjacent sparse rings removes positional jumps but does not remove
that repeated contrast return. It can make texture appear to refocus during a
smooth change of the lens control. No focus-state hunting is involved; the
problem belongs to the sampling kernel.

| Radius in material cells | Original sparse checker gain | Dense replacement checker gain |
| --- | --- | --- |
| 0 | 1 | 1 |
| 1 | 0 | 0 |
| 2 | 1 | 0 |
| 3 | 0 | 0 |
| 6 | 1 | 0 |

These values are an analytical kernel property, not a human perception score.
The original shader is preserved by source `909a139d` and integrated sources
`12b6beed`/`a57aaeea`, shader SHA-256
`e919e9cc17d82320fe54b34f5a48d649fc01fe11dd8ac702fc5fff21b6442312`.
The first original shader captures and Underworks profile reviews remain tied
to those identities; they are not relabelled as evidence for the replacement.

## Selected dense kernel

Source `0338b80146444bdeac30589b61cea3296c1c2eac` replaces sparse rings with the
average of a horizontal and a vertical normalized binomial convolution. Each
integer radius uses every intervening integer texel. The positive weights are
the corresponding row of Pascal's triangle, divided by its row sum. The shared
centre is read once; four neighbours are read for each positive distance.

For integer radius `r`, the response is

`H_r = [cos(kx / 2)^(2r) + cos(ky / 2)^(2r)] / 2`.

Both squared cosine factors lie in `[0,1]`, so increasing `r` cannot increase
the response at any spatial frequency. Fractional radii interpolate adjacent
weight vectors, preserving that monotonicity and positive normalization. Seven
scalar weights are computed when settings or animated focus change. Pixels are
still sampled on the GPU at exact nearest-neighbour material-cell centres.

This is a stylised bounded cross filter, not physical lens simulation or a full
two-dimensional Gaussian. Axis-aligned texture can retain more contrast than
diagonal texture because each branch blurs along one axis. The maximum support
is six cells, not a promise of six-cell photographic standard deviation. For
the cross at integer radius `r`, per-axis variance is `r/4`; that restrained
spread helps preserve construction. The one-cell kernel exactly matches the
old balanced one-cell kernel, retaining the crisp/detail profile path.

## Cost and quality tiers

| Tier | Maximum support radius | Maximum existing surface reads per fragment |
| --- | --- | --- |
| Low | 1 cell | 5 |
| Balanced | 3 cells | 13 |
| High | 6 cells | 25 |

No intermediate texture, viewport, native capture, image copy, new World or
additional render pass is introduced. High no longer uses diagonal sparse
samples. Its larger support is the explicit quality/cost distinction. The
radius cap belongs to the application quality preference; authored focus and
depth settings remain unchanged.

Dense filtering has a greater worst-case sample cost than sparse sampling at
large support. The old balanced kernel used five reads at integer radii and
nine when interpolating positive radii; the old high tier used nine or seventeen.
The new algorithm is selected for its stable optical response, not claimed to
be cheaper. Optional High/Diorama needs actual comparative physical progression
and renderer timing. Crisp optical profiles still avoid the aperture when no
detail or illumination kernel is required; their one-cell treatment remains
five surface reads.

## Qualification boundary

The pinned headless renderer run passes 21 checks, including normalization and
nonnegative weights across 25 fractional radii and monotone response across 81
frequency pairs. This is scalar/kernel evidence only. The real-renderer test
now captures a checkerboard and isolated thin white structure at radii
`0,1,2,3,6`, checks that checker contrast never returns, and checks RGB/coverage
agreement throughout the sweep. It also retains diffusion, texture-edge,
parent-opacity and nonzero-haze Classic-wipe witnesses.

Those new pixel assertions require a subsequent exact-source hosted campaign.
The replacement is not graphically qualified by the earlier 59-check run.

## Disabled-path review and retained optimization opportunity

With optical processing disabled, bypass active, zero strength or a zero wipe,
the renderer restores original material objects. `advance()` and `sync_view()`
return before any new optical uniform work; the presenter does not collect actor
bounds. When shadow and clarity effects are both absent, no Play texture or
player rectangle is fetched by the optical helper. Settings updates retain only
bounded optical dictionaries and per-plane parallax depth, never native layout
arrays. These are source contracts and structural tests, with integrated native
capture/upload evidence owned by the campaign.

There remains a possible GPU optimization for empty source pixels in crisp
profiles: skip colour and Play-mask arithmetic when no enabled treatment can
spread coverage into that pixel. It is deliberately deferred until it can be
compared on a fixed source/camera/runtime identity. No performance benefit is
claimed for an optimization that has not been implemented and measured.
