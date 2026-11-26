# Specialist C — correction to the shader identity interpretation

**Current finding: the first cost annex remains rejected, but the inference that its native windows necessarily ran the original shader was too strong.** The frozen renderer's `statistics.shader_sha256` field does not track an in-process shader-code mutation in the reproduced Godot 4.7 diagnostic. A directly read live Shader and its attached material can contain candidate code while that statistics expression still reports the original source hash.

This correction supersedes the original-versus-original and detached-resource explanations in the intermediate [v1 rejection review](c-shader-cost-v1-rejected-review.md), committed as `a4d557365aa31b1fd3e798958e807d192c15cd9a`. That review is retained unchanged to preserve the actual reasoning history. Its ZIP/file hashes, strict rejection, eighteen exact synthetic image pairs and missing application-after receipt remain valid observations. Its causal interpretation of the disagreeing shader fields is withdrawn.

## Independently reproduced behaviour

I ran the lead's small external resource diagnostic independently against immutable application `fd0830abcfadd9ae19162e5677943bb131223e59`, using pinned Godot `4.7.stable.official.5b4e0cb0f`, binary SHA256 `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`. The diagnostic's exact executed source, source hash, command, result and raw-log hash are retained in the [compact diagnostic receipt](c-shader-identity-diagnostic.json). No production file was edited.

Before mutation, both paths report original shader SHA256 `b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb`. The renderer's shader and the separately preloaded shader are the **same object**, with equal instance ID `-9223372009440803370` in this process. After assigning the candidate source through the local Shader variable:

| Observation | Actual hash |
|---|---|
| Local live Shader `.code` |`50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f`|
| Separately preloaded Shader read through a local variable |`50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f`|
| Attached ShaderMaterial's runtime `.shader.code` |`50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f`|
| `Renderer.OPTICAL_SHADER.code.sha256_text()` expression |`b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb`|
| Frozen `renderer.statistics().shader_sha256` |`b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb`|

Restoring the original source restores the directly read live hash. The diagnostic exits successfully without a script error. This establishes the observed difference between runtime resource reads and the frozen constant/property expression. Compiler constant folding or equivalent compile-time evaluation is an explanation consistent with these observations; this experiment does not inspect or prove Godot's compiler internals.

This is a **headless resource-identity diagnostic**, not a graphical test, native timing comparison or physical GPU observation. It falsifies the detached-resource explanation for this controlled example. It does not retrospectively supply the missing per-plane attachment receipts for the earlier native campaign.

## Correct treatment of the first and second observers

The v1 strict reader rejected contradictory identity fields under its registered contract. That original rejection remains recorded. V1 lacks a direct receipt for every live drawable/material attachment, so its native windows are not admitted as an A1 comparison. Neither candidate performance nor original-only execution should be inferred from those labels. Synthetic fixture image equality is preserved within its separately executed scope.

The revised observer must retain **both** meanings explicitly: the frozen statistics field as original compiled-source provenance, and directly read live Shader/material code as the selected runtime implementation. Its schema must require the actual live resource identity, all three rear material attachments, expected runtime hash, stable before/after attachments and restoration. The frozen statistics field must remain the expected original hash; it must not simply be ignored. An arbitrary wrong hash or missing material receipt must still reject the evidence.

This resolves an observation-contract error rather than changing the application's renderer or relaxing the performance requirements. Exact image comparisons, all native progression populations, source custody, 45-second admission target and original relative-rate/p95 gates remain necessary. Actual hosted evidence under the revised contract is still required. The frozen evaluator's enabled-optics performance HOLD remains unchanged.
