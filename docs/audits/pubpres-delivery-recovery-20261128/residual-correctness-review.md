# PUBPRES delivery recovery: residual correctness review

**Review date:** 2026-11-28  
**Review scope:** Read-only triage of the retained Water/manual-Step omission, Mixed2048 repeated-moving observations, and the final legacy shared-budget event.  
**Application source reviewed:** `65f71aaf4be3a67896bafac7f5220a0cb25a8fb7`  
**Application tree reviewed:** `f6b7b8d3d613b70cdcdf3643fb906934b3887173`  
**Accepted-main identity recorded by the preceding custody report:** `50e3bcb839211eac2abe1e065750cbcba4d36f8c`  
**Previous physically owner-evaluated PUBPRES source:** `9f2127256a555d177536cbb5fad2be7dcb322c8e`  
**Immutable final evidence source:** `21957d0df95800b0f418c078ebef7ee070c541af`

This review examined the source and evidence identified above. It made no application or native-source edits and ran no application, test, or qualification campaign. It makes no new execution, acceptance, or owner-evaluation claim. The source-level observations below do not replace the original hosted observations.

## Evidence references

- [Final presentation qualification at immutable evidence commit](https://github.com/techrote/cybersand/blob/21957d0df95800b0f418c078ebef7ee070c541af/docs/audits/pubpres-mainline-convergence-20261128/presentation-final-qualification.md)
- [Final native, spawn, and performance report at immutable evidence commit](https://github.com/techrote/cybersand/blob/21957d0df95800b0f418c078ebef7ee070c541af/docs/audits/pubpres-mainline-convergence-20261128/native-spawn-performance-final.md)
- [Presentation campaign record and retained adverse observations](https://github.com/techrote/cybersand/blob/21957d0df95800b0f418c078ebef7ee070c541af/docs/audits/2026-11-28-pubpres-mainline-presentation.md)
- [Original broad Windows presentation campaign](https://github.com/techrote/cybersand/actions/runs/46136935975)
- [Independent read-only inspection of that campaign's artifacts](https://github.com/techrote/cybersand/actions/runs/46139433127)

## Manual-Step omission after history exhaustion

### Observed scope

The final broad Water arms retained a deliberate adversary: 280 actual paused draws, followed by 2,056 real unchanged-body publications against Main's 2,048-slot sample-to-step correspondence ring, followed by one ordinary manual Step. The fixture checks that ordinary Pause does not itself publish samples, that the stress publications do not advance physical completion, and that the original matching sample is actually evicted. The reproduced omissions were:

- Selected owner configuration: three bodies in one manual-Step draw.
- Legacy configuration: six body draws across two manual-Step draws.
- Every recorded omission had an unaccepted native response with a per-body `age` refusal and presentation reason `material_in_swept_mask`.
- No held-body frame was revalidated in either final broad arm.

The exact draw, step, slots, counters, and original receipt remain in the immutable final presentation report. These observations followed the stress sequence; the record does not show that 280 ordinary paused draws alone reproduce the omission. This is distinct from the nonrenewable 100 ms endpoint-hold deadline.

### Source reading

Two histories participate in this path and must not be conflated. Main's `PRESENTATION_SAMPLE_HISTORY` is 2,048 entries and records the physical step and completion time corresponding to each admitted body sample (`godot/scripts/main.gd`, sample binding and `_record_workbench_presentation_sample`). The Workbench physics bridge separately retains only `MAX_AGE + 1` body records; `MAX_AGE` is one physical step (`godot/scripts/workbench_physics_bridge.gd`). `apply_packet()` accepts a native body response only when its serial still names a retained body sample and its sample/physical-step age remains within that limit. The publication adversary can therefore evict the long-lived presentation correspondence while also aging out the short force-application sample record.

For Water composition, Main needs exact native/physical provenance before it can use the Water-compatible presentation path. It obtains that provenance from the current matching sample or a retained exact completion proof (`godot/scripts/main.gd`, `_workbench_water_dependency`). A refused packet does not create a new accepted native dependency. The conservative presentation guard then checks the proposed actor sweep against the visible material planes. In the recorded submerged/contact-clipped case, those planes contain material within the conservative sweep, so the guard refuses `material_in_swept_mask` and the resolver withholds the body. The separate positive retained-endpoint witness covers fully proved Water endpoints; the final qualification explicitly does not extend that result to these prior contact-clipped states.

### Disposition

**No safe narrow production repair is established by this evidence.** Re-admitting an aged packet, expanding or bypassing the native sample fence, manufacturing contact clearance, or drawing an unchecked submerged pose would weaken a provenance or geometry authority. The intended adverse condition is a deliberately overrun sample-history contract; the evidence does not justify treating the omission as an ordinary-pause defect.

Retain the broad fixture as a negative regression: it should continue to detect actual sample eviction and physical-step identity, preserve the native `age` refusal and record the resulting withheld draw without crediting a synthetic completion. Retain the separate full-Water retained-endpoint witness as the positive control. If a later repair proposes a different path, it needs a new source-bound witness showing exact owner, World, sample, physical step, contact proof, visible material, and accepted-frame picking, plus negative controls for stale packets and invalid contact coverage. No such repair or witness was implemented here.

## Mixed2048 repeated-moving poses

The original Mixed2048 contact trace recorded nine repeated-moving draws. The worst repeated-pose interval was 192.384 ms, during which measured live movement was 0.877033 cells. The registered stale predicate requires at least two physical steps and more than two cells of movement while the presented pose repeats; the trace therefore records zero stale-moving draws. Both facts must be preserved: the repeated poses are an observed presentation cadence limitation, and zero under the stricter stale predicate does not erase them.

The same final report records 160.863 ms physical completion-gap p95 and 256.727 ms maximum for the Mixed2048 full patrol; its narrower contact trace has 201.656 ms p95 and 351.619 ms maximum. Those observations are consistent with sparse physical completions and delayed pose updates. The reviewed evidence does not establish a narrower production-code fault in the pose selector. It also does not justify interpolating an unobserved pose, claiming an old pose is current, or changing accepted-frame picking. The existing recorder and reducer should retain repeated poses, physical completion identities, draw times, and movement magnitude separately from the stale predicate. **No production repair is identified.**

## Legacy shared-budget withholds

The final legacy arm had one distinct `dry_to_wet_entry` event: draw 2,393 at physical/bridge step 87, slots 1 and 2 withheld, four budget vetoes, and 968 examined cells. The recorded selection and guard intervals were 2,763 µs and 2,841 µs. This event is reported separately from age refusal and did not occur in the final selected-owner arm.

The legacy resolver in `godot/scripts/main.gd` walks bodies in slot order and shares its 24,000-cell allowance and 2,000 µs frame deadline across the frame. Once that deadline expires, later candidates receive `shared_budget` and are withheld. The observed elapsed time exceeds the time cap while the examined-cell count remains well below the cell cap, making the shared time deadline the specific recorded refusal boundary. The selected coherent resolver uses rotating admission order; this event is not evidence of a selected-configuration regression.

**Disposition:** Preserve the event and the bounded fail-closed behavior. One legacy observation absent from prior and final comparison arms is insufficient grounds to raise the shared frame budget or alter authority. Existing focused timeout/negative coverage includes `godot/tests/test_workbench_presentation_coherence.gd` and temporal presentation refusal cases. No additional execution was performed for this review.

## Delivery and acceptance status

- **Implemented:** No residual correctness patch was made.
- **Independently reviewed:** No new independent source review was commissioned; this is a read-only specialist assessment.
- **Locally tested:** No tests or application execution were run.
- **Hosted qualified:** No new campaign was run. The original observations remain as recorded and linked above.
- **Completely extracted-package qualified:** Not assessed by this residual review.
- **Physically owner-evaluated:** The reviewed integrated source has not been physically owner-evaluated; prior positive evaluation applies only to source `9f2127256a555d177536cbb5fad2be7dcb322c8e`.
- **Authorized for merge / actually merged:** No authorization or merge claim is made.

No package refresh is required by this read-only review because application and package sources were not changed. Any subsequent application-source repair would require its applicable resulting-source qualification and a new source-exact evaluator before delivery claims could be updated.
