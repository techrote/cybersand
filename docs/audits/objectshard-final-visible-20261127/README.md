# Final Windows eight-body display observation

On 2026-11-27 the Windows 11 TITAN RTX ran the [extracted ObjectShard evaluator](https://github.com/techrote/cybersand/actions/runs/45944204842/artifacts/15176676582) for a 60.013-second active observation. The fixture passed 389 checks, including eight distinct material bodies, real Rapier motion, native pose acknowledgements and coherent presentation. Godot 4.7 used ANGLE D3D11 and Rapier 0.35.2. The evaluator came from source `efe3bc19c68a9b9e292821ef28b735caec538915`. Its native DLL has SHA-256 `78a5481193d6379ce8f36689aedc521f3b0d79fd17a2a88815f5c49e737bdce9`.

The measurement used the fixed eight-body stress scene. The external sampler compared a 700 × 253 world-only crop on the desktop. All 178 paused comparisons were identical. No sampled output was occluded or contained accumulated frames. During the active period, the native World completed 1,192 ticks and Rapier completed 4,769 substeps.

| One-second motion criterion | Full windows | Visible changes per second | Windows below 10 |
| --- | ---: | --- | ---: |
| Any matching occupied cell moving inside the crop | 12 | 4–40, median 37.5 | 1 |
| A matching cell on at least one body moves one screen pixel or more | 10 | 18–40, median 39 | 0 |
| A matching cell on each of eight bodies moves one screen pixel or more | 4 | 18–37, median 23.5 | 0 |

The first change arrived 68.35 ms after the start of the active observation. Sixteen cross-clock brackets bound the clock-offset uncertainty to 8.55 ms. The longest later interval between changed crops was 67.62 ms. It contained three identical comparisons and two interior engine-sample pairs and one Rapier advance with occupied cells belonging to all eight bodies visible inside the crop. The material displacement reached 0.707 screen pixels in an adjacent pair. The final 48.886 seconds stayed visually unchanged. Across 2,929 corresponding adjacent samples, no in-crop body movement was measured during that interval while the native World advanced 973 ticks.

A threshold requiring more than 0.5% of the crop to change produced fewer than ten such events in nine of the twelve motion windows. These measurements count changes in the selected visible content. The owner’s judgement of displayed playability remains open. The earlier 1.734-second change gap and the separate 9.47-second correlated capture remain preserved. [Prior synchronized observation](https://github.com/techrote/cybersand/tree/45de554882dc4b4ad193bfda49b2626a0e4451f3/docs/audits/objectshard-synchronized-visible-20261127)

Run `python verify.py` with NumPy to repeat the calculation from the original desktop counters, the sixteen clock brackets and all 3,598 engine observations. The pose file shares identical body records across callback rows and retains every shape, sample and numeric transform. The verifier reconstructs the original decoded transform data and checks its canonical SHA-256. The full raw file SHA-256 values are in `results.json`. For a repeat on hardware, start from the previous observer and apply `sixty-second-observer.patch` with `git apply --unidiff-zero` to its external GDScript. Use the same 1600 × 900 client, overview camera, light sampling, recording off and [DXGI collector](https://github.com/techrote/cybersand/blob/0df4a76410e5ac1f6d1368486dcfeae75280e773/tools/objectshard/windows_visible_region.cpp).
