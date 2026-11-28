# Submitted actor geometry witness

**Draft / HOLD.** This is an additional observational check, not a runtime
rendering change or a physical-display acceptance result.

The initial submitted-presentation supplement independently joined Main's
selected pose to completed Rapier, but accepted any finite first overlay part.
That could miss a stale or miscomposed submitted transform. The updated helper
records the actual selected and first-part `Transform2D` matrices together with
the actual collider node, parent body node/RID, child-local matrix, shape size
and overlay part identity. The reader binds the body to the original actor
roster and independently reconstructs the production composition. Compound
rectangles use selected pose times collider-local transform; ordinary rectangle
and circle parts use the selected matrix directly. It does not call the
production composition method to obtain an expected transform.

The independently completed Rapier pose remains the only physical-step clock.
The additional `verified_first_part_completion_age_ms` requires both its real
completion join and successful submitted-geometry proof. Unknown geometry has
explicit counts and receives no verified age. The ordinary registered runner
requires every visible first part to be verified. Other compound parts are
outside this bounded probe; none is silently certified. Separate notifications
still have no render-submission identity and no signal proves GPU completion or
scanout.

The helper reads Main-owned nodes only, with the existing eight-body and
512-part bounds. Its extra reads are charged to the same callback-cost clock
and must participate in the registered off/on/on/off calibration. No older
calibration is inherited. Actual production session, rig and overlay source
hashes enter the executed source identity. Frozen physical observers and
reducers are unchanged; the separate mixed derivation only adds the overlay
source hash.

Independent Python checks cover direct and compound transforms, a nonidentity
collider offset/rotation, stale part coordinates, self-consistent changed local
geometry, replacement collider nodes, wrong body ownership, shape dimensions,
zero resource IDs, invented scale, unavailable geometry and production-source
drift. Negative signed RefCounted shape IDs remain valid. Eleven observer-kit test
methods and all 28 final-apparatus methods pass. B independently parsed the exact final, mixed and helper scripts with official
Godot 4.7: both mounted observers passed `--check-only` with the actual retained
Rapier runtime loaded. Hosted capture qualification remains pending; parsing
and synthetic tests do not claim graphical completion.

B identified the cancellation limit of a result-only ULP check. The repair
bounds float32 compound composition by four result ULPs, four float32 epsilons
times the sum of absolute operand products including translation, or `1e-7`
near zero. A retained cancellation adversary passes while a `0.01`-cell
displacement fails. Direct transforms must agree at float32 bit precision.
These are explicit numerical tolerances; no pose interpolation, physical
progression, callback credit or unobserved completion is fabricated.
