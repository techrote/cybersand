# Specialist C — first shader-cost campaign rejection

> **Interpretation correction:** the detached-resource and original-versus-original explanations below were an intermediate inference and are superseded by the independently reproduced [shader identity correction](c-shader-identity-correction.md). The observed v1 hash contradiction and strict rejection remain valid; its native A1 timing remains unadmitted. The original text is retained to make the reasoning correction recoverable.

**The first hosted shader-cost annex is rejected as native A1 performance evidence. The strict reader correctly detected that the live presenter still used the original shader.** The earlier [source review](c-shader-cost-source-review.md) remains unchanged; this finding supplements it and corrects its assumption that the driver's preloaded shader reference was the one used by the ordinary native Workbench.

## Actual evidence and failed assumption

Application `fd0830abcfadd9ae19162e5677943bb131223e59` was observed by external commit `c1b13096da9dbbe1c3c45f9ee4c48fa009e6f14e` in [run 45730815481](https://github.com/techrote/cybersand/actions/runs/45730815481). The Linux artifact is `15075884273`, original ZIP SHA256 `60f8265419830d411022978f70311575a6877b1fa3faa1f6a7fb56db57bf0564`, 14,690,912 bytes. The [machine-readable review](c-shader-cost-v1-rejected-review.json) retains original receipt hashes, every native-window shader witness and the synthetic capture hashes.

The actual GDScript report contains 4,007 checks and zero recorded failures, yet the enclosing strict annex says `completed: false` with `Actual shader, bounded resources or native isolation changed`. In all six A1-labelled native windows, the driver's declared shader and paused-capture fields contain candidate SHA256 `50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f`, while `optical_statistics.shader_sha256` contains original SHA256 `b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb`. All fifteen actual presenter observations use that original identity.

The external driver's preload reference therefore did not reach the shader resource used by the newly admitted live presenter. The source-level assumption was insufficient. The strict end-of-run identity check prevented those complete-looking native populations and exact images from being accepted as original-versus-A1 observations. No rates from these incorrectly labelled pairs should be used to claim a candidate gain, regression or gate result.

This also limits the native image result: equality in those windows compares original presentation with original presentation. It is not native-scene evidence for the A1 shader. Raw windows and captures remain preserved for diagnosis; their existence and assertion count do not repair the identity mismatch.

## Separate valid graphical result

The standalone graphical wrapper modifies the actual `Renderer.OPTICAL_SHADER` constant used by its inherited fixture. Original and A1 fixture processes each completed 109 assertions with zero failures. I independently decoded all eighteen unchanged original/candidate PNG pairs with the frozen application's bounded RGBA decoder: all **884,736 RGBA bytes** match, including alpha. Each 192×64 capture has its original SHA256 recorded in the review. The exact partial-opacity Classic wipe also matches its 16,384-byte comparison region under both shaders.

That positive fixture result is retained within its synthetic scope. It does not qualify the rejected native timing stage or substitute for a future correctly bound native-scene comparison. The actual backend was llvmpipe LLVM 20.1.2; no physical GPU conclusion follows.

I independently verified the ZIP size/SHA and all file hashes retained in the rejected annex. The rejection occurred before a successful application-after custody receipt was produced. Accordingly this review does not claim that the run passed the post-execution application-file gate. No original evidence or reader predicate was rewritten to manufacture acceptance.

## Required repair and disposition

The next observer must resolve the current presenter's renderer after fresh native admission, modify that renderer's actual shader resource, then prove the loaded code and all active rear drawable material attachments **before timing**. Each material's attached shader must be the same live shader object and have the expected code hash. Classic must still retain zero optical materials. The strict retained reader must check these independent witnesses as well as the actual end-of-window presenter statistics. These checks are an observer repair, not a reason to weaken the original identity predicate.

Until that revised observer produces accepted hosted evidence, A1 native performance remains unknown. The frozen application's measured enabled-optics performance HOLD, original scene-admission failures and owner acceptance gates remain unchanged. The first source review's confidence is explicitly narrowed by this actual integration discovery rather than silently edited after the fact.
