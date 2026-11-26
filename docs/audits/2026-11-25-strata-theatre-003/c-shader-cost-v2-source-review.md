# Specialist C — revised shader-cost observer source review

**Disposition: revised observer ready for hosted graphical and timing qualification; no blocking source-contract issue found.** This review does not admit a native A1 performance result, change the frozen application, or erase either platform's first rejected annex.

The reviewed observer is `55951750466dc76e0482954f3d9e8bd9a9d1ada4`, tree `edc750a1e2205b079dca5fd284af9091038aca6d`. The application remains `fd0830abcfadd9ae19162e5677943bb131223e59`. The [source receipt](c-shader-cost-v2-source-review.json) records exact reviewed hashes, the sixteen adverse controls rerun at this published commit, and the limited headless diagnostic observations.

## Repaired observation contract

The [independent identity diagnostic and correction](c-shader-identity-correction.md) establish that the frozen constant/property expression can retain the original hash while the actual same Shader object's code and attached material read the candidate. The earlier detached-resource explanation was not established and is withdrawn. V1 remains rejected because its registered fields disagreed and it lacks the stronger direct attachment receipts.

V2 requires a separately executed, source-pinned resource diagnostic on **each host before graphics**. Its retained command, log, resources, engine version, script hash, equal resource IDs, original/candidate runtime values and final restoration are verified. It remains explicitly headless. The original source-expression hash and the chosen live-code hash are now distinct required witnesses; arbitrary changes to either still reject the observation.

After every fresh native scene admission, the driver resolves the actual presenter's renderer, changes its live Shader code, settles, and records each active rear drawable's material and attached Shader. All three material objects must be distinct, attached to the same expected live Shader, and contain the chosen code. These witnesses are taken before the inherited warmup and timer and repeated after the window. The reader requires the entire before/after attachment receipts to match. Classic must retain zero optical materials and its original material objects; processed statistics and attachment counts must both be exactly three.

The exact set of existing Shader resources touched by the observer must be restored once each. At most fifteen references can be retained; no additional Shader is constructed by the progression driver. Whole-process resource observations include that bounded observer retention. The original exact image, native-state, source-custody, capture-isolation, fifteen-window population, 45-second admission and relative rate/p95 criteria remain unchanged. V1 records and missing-attachment records cannot be relabelled as v2.

I independently inspected the corrected full headless native diagnostic, report SHA256 `e7d46e7356645b840f9d5aa36dc3dea5efa8f845f1cbbe2926ae10997d7f40d7`. It has 3,087 checks, zero failures and fifteen windows. Its executed driver SHA256 `9b87a8130c70160e359af4b6264c567a80ede18d58a785cc60ffeb39c63162dd` exactly matches the published driver. Applying the new attachment/statistics validators to its actual records passes: all six candidate windows have direct runtime candidate code with original frozen-source metadata; all before/after material witnesses agree; Classic has zero attachments; the one actual shared Shader is restored. This is diagnostic readiness, not a full strict graphical-reader admission.

The sixteen adverse controls pass at the published revision. They include missing/wrong attachment identities, partial rear-plane coverage, changed materials during timing, incomplete restoration, altered frozen-source metadata, missing per-host diagnostic, engine/source substitutions, old schema, ordinary physical-population failures and valid slow-candidate negative research. The workflow and original source separation remain unchanged apart from the new bounded diagnostic process.

## Both first-campaign rejections retained

Both artifacts come from [run 45730815481](https://github.com/techrote/cybersand/actions/runs/45730815481), external source `c1b13096da9dbbe1c3c45f9ee4c48fa009e6f14e`.

| Platform | Artifact | Original ZIP SHA256 | Native driver checks | Annex disposition |
|---|---:|---|---:|---|
| Linux |15075884273|`60f8265419830d411022978f70311575a6877b1fa3faa1f6a7fb56db57bf0564`|4,007 /0 failures|Rejected|
| Windows |15077761504|`e8e19df1885f08545c912e53eeb269550d663adcfd1ea5dc7b6ecd71afe1f0cd`|4,010 /0 failures|Rejected|

I independently verified each original ZIP size/SHA, all seventy retained file hashes per artifact, and all eighteen 192×64 original/candidate synthetic PNG pairs per platform. Each platform compares 884,736 exact RGBA bytes, including alpha, and retains the exact partial-opacity Classic wipe result. Both fixture processes on each platform report 109 assertions and zero failures. These are preserved synthetic graphical observations, distinct from the unadmitted native comparison.

Neither rejected annex contains a successful final application-after custody receipt. Neither provides the new per-plane runtime attachment proof. Their native timing labels establish neither original-only execution nor a candidate speed result. The [Windows compact review](c-shader-cost-v1-windows-rejected-review.json), [Linux raw witnesses](c-shader-cost-v1-rejected-review.json) and the explicit interpretation correction preserve these boundaries.

The final owner guide now correctly reports the frozen application's enabled-optics performance HOLD, Linux progression losses, sustained Windows admission and physical/draw tails, and actor-overview limitations. Physical Windows 11/NVIDIA acceptance remains open. An improved result from this revised observer would still be external research; adoption requires an explicit new application identity and appropriate qualification.
