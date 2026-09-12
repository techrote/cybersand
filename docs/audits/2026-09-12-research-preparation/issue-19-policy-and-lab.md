# #19: policy arithmetic and Water Feel Lab integration preparation

**Completed standalone work; proposed integration, not a native runtime feature.** See [sources R1–R5](primary-sources.md) for the governing repository contracts. The Python configuration is a reference implementation for sharing semantics across eventual UI/file/CLI entry points. It is not an extra competing game configuration system.

## Exact policy budget

A policy contains schema 1, mass bits 3..8, coherence duration 0..12 and a named rest-threshold policy. The 156 validated records cover both normalized and literal-one tolerances. There are 78 records per threshold policy. Defaults are mass8, duration 12, normalized. Derived thresholds are not independently editable conflicting values.

For `M = 2^bits - 1` and exact rational input `n/d`, the registered #17 rule is `Q = floor((2*n*M+d)/(2*d))`. Python uses arbitrary-size integers; a native port must bound external integers and widen before multiplication. The separate C++ oracle safely widens its uint32 operands for maxima at most 255. It is not evidence about a game parser.

| Bits | M | Film Q(48/255) | Normalized tolerance Q(1/255) | Q(1/255) input |
|---|---:|---:|---:|---:|
| 3 | 7 | 1 | 0 | 0 |
| 4 | 15 | 3 | 0 | 0 |
| 5 | 31 | 6 | 0 | 0 |
| 6 | 63 | 12 | 0 | 0 |
| 7 | 127 | 24 | 0 | 0 |
| 8 | 255 | 48 | 1 | 1 |

The calculations exhaust 1,536 byte-normalized inputs, 498 exact halfway inputs and 174,720 local source/destination pairs across the two threshold policies. The pair operation deliberately omits viscosity, gravity, adhesion, epochs, scheduler activity and reactions. Its integer conservation is an arithmetic oracle, not proof of complete Water behavior. In this reduced operation, a one-unit imbalance requests zero even when tolerance is zero: `floor(3/4)=0`. Zero tolerance alone does not guarantee that residual films move.

The delay study checks 91 initial countdown cases across configured durations 0..12 and 819 legal max-merge pairs. Suppression is tested before decrement. The storage result “four bits represent 0..12” is separate from the behavioral experiment “duration 7 instead of 12.” Neither a shorter duration nor its visual preference is selected here.

## The tiny-emitter trap

An independently rounded 1/255 input vanishes at every tested width below 8. In particular, 127/255 is slightly **less** than one half; mass7 does not round this input upward. A first local test incorrectly expected it to do so. The expectation was corrected, the original failed log retained, and the formula left unchanged. See [validation](validation.md).

For a repeated source, register which question the apparatus asks. A physically normalized requested volume can expose emission-lattice loss, but must record requested and admitted volume separately. An arm-dependent integer emission quantum tests motion of representable droplets, not identical physical inputs. A fractional emitter reservoir is a third, separately versioned emission model; it adds temporal source state and cannot be smuggled into the World as a “precision fix.” The closed #17 basin controls remain useful because full cells have exact initial quantity in every arm.

Always keep two ledgers: requested physical input versus admitted integer quantity, then actual integer sources/sinks versus each successful tick's quantity. A conservation failure is not excused as an expected input-rounding difference.

## Identity and refusal behavior

The reference configuration refuses out-of-range widths/durations, booleans standing in for integers, strings/floats, unknown fields, duplicate JSON keys, nonfinite values and unsupported schemas. Explicit defaults and omitted defaults resolve identically. The tests exercise 156 mapping/JSON/CLI equivalence cases. The dataclass is immutable.

Simulation-policy and presentation identifiers are separate. A render-mode change must not change the simulation-policy hash. Conversely, a source revision remains essential: this hash describes normalized configuration, **not** the kernel, scheduler, fixture, executable or successful correspondence with #17. Normalized and literal-one policies intentionally retain distinct identities even where effective values happen to coincide at mass8.

A useful complete run identity includes source SHA, executable SHA, semantic-policy hash, scenario/recipe hash, initial integer quantity, seed, worker count, transport profile, fixed-step/cadence configuration, world generation, presentation hash and accepted snapshot serial. The generated manifest supplies research source/data hashes, not a substitute for all those eventual runtime fields.

## Apply + Reset: integration transaction to implement

Validate the complete proposed configuration before touching the running owner. Construct the candidate World and its immutable policy through the normal exclusive-owner path. Prepare all needed bounded queues/snapshot resources. On successful preparation, switch the active World generation and its policy as one acknowledged owner transition, then publish an explicit full refresh. Failure before activation leaves the previous World and policy intact.

Retire or reject old-generation commands, snapshots, acknowledgements and temporal presentation history. A stale raw-mass frame interpreted under a new denominator can be visually wrong even when each buffer is immutable. Do not blend the previous World's texture into the new world's first frame. Mass8 versus mass3 is not a hot-rescale of existing live cells. Render-only options may hot-switch independently after their generation checks.

Required failure injections include invalid UI/file/CLI input, candidate allocation failure, reset while paused, slow/delayed snapshot consumption, duplicate reset requests, stale generation acknowledgement, full publication capacity and failed-world quarantine. The reference immutable dataclass test does not execute any of these native ownership paths.

## Prepared apparatus, with honest coverage

Five generator recipes provide bounded geometry, rational Water inputs, barrier coordinates, camera reset metadata, hashes and per-width initial ledgers: basin48, supported film, support removal, ledge and tiny-input chambers. The basin is 384 full cells, hence 97,920 integer units at mass8. The support event occurs before tick 601. The geometric barrier role still needs verified native material mapping; these JSON files are not Godot scenes and have not run the physics.

The broader scenario coverage manifest records pooling, small quantities, geometric restrictions, releases, directional emissions, terrain modification, Water/Sand and protected Mercury controls, supported player/body cases, seams and long-tail rest. Unimplemented scenarios are explicitly unimplemented. #11's administrative closure is not permission to assume bearing/ejection support exists.

The initial isolated-axis comparison set has six mass candidates at duration 12 and four duration candidates 0/3/7/12 at mass8: nine distinct configurations after the common reference is counted once. Order tables balance both display position and each directed adjacent pair within an axis. A separate deterministic key conceals configuration labels from the proposed UI; it is an example, not cryptographic secrecy or a claim that perceptually distinctive candidates cannot be recognized.

Hold scenario, seed, camera, timing and presentation fixed within a block. The blocking rationale is supported by [NIST S4](primary-sources.md); the specific tables are independently generated and exhaustively checked. Record a response before reveal, hide hashes/debug labels that identify an arm, and retain discarded/failed trials with reasons. No sample size, population preference or statistical significance is asserted: there have been **zero human observations**.

## Smallest meaningful next checkpoint

First implement one native immutable policy path and explicit reset, proving mass4/6/8 correspondence on shared #17 fixtures with unchanged numeric rules. Simultaneously verify normalized Water condition bytes and non-Water exact controls through the existing snapshot/renderer boundary. Only then admit new 3/5/7 widths and shorter durations into the real apparatus. Complete actual scenario execution and desktop/Web walkthroughs before saying H-ready. Preferred Water feel and a motion deficit remain later human-led decisions.
