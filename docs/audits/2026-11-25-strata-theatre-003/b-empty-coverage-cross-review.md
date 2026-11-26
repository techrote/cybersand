# Independent review of the optional empty-coverage candidate

**Specialist B · 26 November 2026 · read-only review · experimental HOLD.** This reviews the A1 candidate's coverage algebra. It does not amend the frozen application or admit a performance result.

| Input | Identity |
| --- | --- |
| Frozen application | `fd0830abcfadd9ae19162e5677943bb131223e59` |
| Frozen shader | `godot/shaders/strata_optical_plane.gdshader`, SHA-256 `b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb` |
| A1 candidate | Candidate implementation commit `c14fc244`; external observer file `tools/ci/experiments/strata3_optical_empty_coverage_a1.gdshader` |
| Exact candidate bytes inspected | SHA-256 `50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f` |

B independently read the candidate and compared it with the frozen shader. After ignoring indentation, the only semantic change is an exact `centre.a == 0.0 && low.a == 0.0` guard, returning zero colour before the downstream optical arithmetic. The existing optical body is wrapped in its `else`; no profile, native ownership or geometry change is part of this candidate.

## Coverage reasoning

For the current implementation, the guard is sound. Tone, saturation, tint, scattering and shadows change colour without creating alpha. Clarity and plane opacity scale existing coverage. Highlight diffusion's extra alpha is multiplied by `low.a`. Classic's contribution has `classic.a == centre.a`. Therefore, when both tested alphas are exactly zero, the original effect interpolation also has zero alpha and the final `straight_colour` returns zero RGB. Its output is the same zero RGBA as the proposed early return, including intermediate effect strength and parent opacity.

The guard occurs **after** the bounded dense sample. A transparent centre beside a covered neighbour can receive nonzero `low.a` and continues through the original blur/diffusion path. Exact equality avoids treating faint nonzero halo pixels as empty. The literal Classic and wipe-bypass paths remain unchanged. The candidate still performs the kernel's source sampling; its opportunity is avoiding later colour and optional Play-mask work in zero-coverage areas.

This reasoning depends on the existing effects. A future light volume, emission or coverage operation independent of `centre.a` and `low.a` must revisit the guard. Source inspection also cannot establish GPU branch cost, every backend's compiled behaviour or acceptable native progression. Rendered equality and an admitted cost observer remain separate requirements.

## Observer limitation and correction

The first native timing receipt was strictly rejected because shader identity witnesses disagreed. An earlier interpretation that this necessarily meant a detached or original-only shader was **not established** and has been corrected. The lead's subsequent diagnostic observed matching preload/live object identity and candidate code on the actual three drawable/material attachments, while a constant-expression/statistics hash remained at the frozen source. Compiler folding or stale statistics was being investigated; that discrepancy must not be silently relabelled as a performance pass.

The repaired observer must distinguish the frozen compiled-source identity from the directly read mutable live resource and every attached material, retain those actual attachments before and after the timed window, and preserve the first receipt's rejection. B admits **no native A1 rate or improvement from the rejected receipt**. The frozen application's registered profile-cost regression remains HOLD until a separate valid result supports a narrower conclusion. This cross-review supports further isolated investigation, not automatic integration or default activation.
