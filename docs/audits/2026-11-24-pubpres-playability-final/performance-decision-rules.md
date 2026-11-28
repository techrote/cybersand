# Performance decision rules and remaining acceptance boundaries

**Status: Draft/HOLD.** This note explains the existing prospective registration
and how the final packet should interpret it. It introduces no retroactive
acceptance threshold and changes no frozen test or comparator. The owner has
not supplied an absolute millisecond or CPU budget. Physical NVIDIA execution
has not been observed in the hosted software-renderer campaigns.

## Separate decisions

| Decision | Required evidence | Result and practical meaning |
|---|---|---|
| Evidence validity | Exact source/tree/runtime/driver/engine custody, correct actual renderer owner, complete callback/native/terrain/body/input/Water/GPU oracles and unchanged raw hashes | Valid evidence is eligible for interpretation. Any failed prerequisite remains a failure or an unexecuted arm, with its original evidence retained. |
| Registered relative direction | Complete matched counterbalanced cohort and the unchanged strict rule below | A treatment can satisfy a measured relative direction for that workload and host. This result says nothing by itself about an acceptable absolute stall burden. |
| Absolute physical burden | Actual completion-gap p50/p95/p99/max, sample count, all existing 100/250/500/1000 ms bins, normalized counts and sustained captures | Report concrete time and frequency. These bins are descriptive registration thresholds, not an invented owner pass budget. |
| Ordinary mixed viability | Both explicit eight-actor 512/1024 cases run at least 60 s and 144 genuine steps, with all eight owners, live paint/erase, current Wave, Follow, actual contact and source/GPU/terrain gates valid | Establishes the tested ordinary control/painting workload remains correct and progresses. Its single captures do not establish a comparative speed gain. |
| Submitted presentation and resource costs | Source-bound actual frame-submission pose/material/camera observations, valid known-identity coverage, external actual-process CPU and memory counters | Report freshness/holds and costs alongside physical rates. Submitted state is distinct from physical scanout, and absent identity remains unknown. |
| Physical owner acceptance | Exact verified evaluator on the actual Windows/NVIDIA installation, responsive ordinary manipulation/painting/Follow and persistence exercised by the owner | Remains pending until observed. Hosted ANGLE/basic/software output does not identify physical NVIDIA driver behavior. |

## Relative direction remains the original rule

For each registered primary ABBA question, every candidate replicate must have
a higher first 144-step completion rate than every control replicate, and lower
p95 and p99 completion gaps than every control. Candidate maximum gaps and
counts above every registered severity threshold must not exceed the worse
control. The corresponding exact hardware, renderer, fixture, policy and native
toolchain matching gates remain mandatory. Actual equal-step body trajectories
and consumed actions must satisfy the registered parity contract. A missing or
invalid arm cannot be omitted to obtain a direction.

Source D/C/C/D, slot 2/3/3/2, recovered-engine Safe controls, actual render-owner
controls and material-deadline controls answer distinct questions. Preserve
their separate identities. A native-only result, shader submission result,
renderer startup repair or one favorable run does not choose a whole-Workbench
winner. Native 512 tails, zero-body controls and the adverse eight-body native
replicate remain in the packet even if a large-canvas rate improves.

Report each primary workload separately. The existing registration does not
provide a weighting that permits a Wave2048 improvement to erase a Wave512
regression. A treatment that only helps a subset is a conditional result with
that workload scope, not a generally qualified replacement. Keep application
and evaluator defaults unchanged and the programme Draft/HOLD.

## Absolute tail burden has concrete units

The existing thresholds are 100, 250, 500 and 1000 ms between genuine completed
physical steps. For each first 144-step and whole sustained window, report:

- Number of completed steps, capture duration and completion rate.
- Number of inter-step gaps and linear p50/p95/p99/max in milliseconds.
- Count above each threshold and count per capture minute.
- Sum of the inter-step time lying in gaps above each threshold, and that sum
  divided by all observed inter-step time.
- Sum of each gap's excess above the threshold, clearly labelled descriptive.
- First admitted command to the next genuine physical completion; retain
  latest-consumed-command latency separately because repeated input can hide
  earlier waiting if only its latest admission is reported.

Inter-step spans exclude the capture edges before the first completion and
after the last. Counts per minute use the full selected capture duration. The
metrics describe absence of new completed physics during those intervals;
they do not assert that rendering, device input or every other thread stopped.
No millisecond bin is automatically reclassified as a playability pass.

For example, a rate gain with repeated gaps near 800 ms remains a substantial
absolute burden despite satisfying a relative average-rate comparison. The
retained historical sustained window had 18 gaps above 500 ms in about 60 s; a
candidate packet must show how that actual burden changes, not only a faster
texture update call or aggregate frame count.

## Sampling and confounds

First 144 steps produce 143 inter-step gaps. Under the retained linear quantile
definition, p99 interpolates sorted zero-based positions 140 and 141: the third
and second largest gaps. It is not a stable estimate of the population 99th
percentile from many independent sessions. The maximum and all severity counts
therefore remain visible. A 60-second large-canvas run may still have only a
few hundred gaps; state its actual count.

The two candidate replicates in a four-arm sequence establish the specific
registered direction if both satisfy it. They do not supply broad statistical
confidence, a p-value, or a guarantee across machines. ABBA controls monotonic
drift better than a single ordered A/B pair, but residual host scheduling,
thermal/caching behavior and periodic engine/driver stalls can remain. Preserve
all arms and their order. Do not pool runs into quantiles or hide an adverse run
behind an aggregate. A promising relative result still merits an independently
executed matched confirmation before any stronger general claim.

Whole-window captures can end at different native/physical steps. Use the
equal-step window for matched outcome and timing comparisons, and the full
duration to expose sustained stalls. The mixed live-paint workload is separately
registered: equal requested physical paint ticks do not guarantee equal native
worker admission ticks. Retain actual material tick/revision witnesses and do
not assume matched material evolution across its separate captures.

## Presentation and CPU interpretation

Actual submitted overlay transforms, selected physical step/material identity
and Follow camera state should be bound at the source's frame-submission
boundary. Report known submitted-step lag/age, repeated held submissions,
current/previous material revisions and unknown/censored observations. A legal
coherent hold can preserve correct history while still creating noticeable
latency; its duration belongs beside throughput. Identity mismatch is a
correctness failure. Unknown identity does not become zero age.

Safe inline draw delivery can support its explicitly proven serial joins.
Separate post-draw notifications are deferred to Main and cannot be joined to
Main's then-current upload as if that were the rendered submission. Neither
boundary proves GPU completion or display scanout. Before/after framebuffers
and independent current/previous GPU histories address visual correctness,
with physical owner evaluation still required for trails and felt response.

External process user+kernel CPU seconds should be divided by observed wall
duration as CPU-core equivalents; this value can exceed one. If normalized by
logical processor count, label that additional denominator explicitly. Keep
actual observed PID/creation identity, sample coverage and censored endpoints.
Godot allocator peak, whole-process resident/working-set peak and logical GPU
texture allocation are separate costs. A three-slot 2048² RG8 publisher adds
one 8 MiB logical texture; that is not a measured 8 MiB increase in physical VRAM
residency. Unsupported or absent resource counters remain unavailable.

The full and mixed observers, paint searches, submitted-presentation sidecar
and external samplers have measurement cost. Keep their exact hashes and enabled
state equal within each comparison and report measured observer/sampler costs
where available. The new observer does not inherit an old reduced-observer
calibration as an automatic overhead bound. Ordinary evaluator instrumentation
remains optional, and ordinary owner play remains a separate observation.
