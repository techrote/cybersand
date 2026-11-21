# SWARM-006 native comparisons

**Experimental / Draft / HOLD.** Programme [#704](https://github.com/techrote/cybersand/issues/704)
owns this successor. These tools compare native proposals; they do not run the
owner's saved World, Windows GUI or NVIDIA GPU. They leave the frozen SWARM-004
and SWARM-005 runners, registrations and evidence unchanged.

## Sources and harness identity

`run_swarm006.py build` accepts an explicit source checkout and creates a fresh
external build directory. Frozen `swarm004` requires clean commit
`2c4b8061ef5315de6a31df933e9f84c31865284e`; frozen `swarm005` requires clean
`c178feeb39899fd155b7deb9d5bde3f50ee28548`. The `swarm006` candidate requires
clean committed source unless `--allow-dirty` explicitly labels development.

The strict C++20 core comes from that checkout's original Makefile. A snapshot
of `swarm006_experiment_main.cpp` is compiled outside its own checkout, so quoted
header includes resolve to the selected donor. Explicit compilation macros
declare available treatments. An unsupported 005/006 treatment is rejected,
never silently mapped to an earlier policy. The build receipt binds source and
tree, every inventoried header/core file, native definition, harness snapshot,
commands, actual executable, source custody and platform. No binary or evidence
artifact belongs in Git.

```sh
python3 native/experiments/gentek_swarm/run_swarm006.py build \
  --source-root /absolute/frozen-sw005-checkout \
  --build /absolute/fresh-sw005-build --variant swarm005
python3 native/experiments/gentek_swarm/run_swarm006.py run \
  --build /absolute/fresh-sw005-build --out /absolute/fresh-sw005-evidence \
  --suite development --controls
python3 native/experiments/gentek_swarm/run_swarm006.py compare \
  --before /absolute/sw004-evidence --after /absolute/sw005-evidence \
  --before-policy off@2 --after-policy off@2 \
  --out /absolute/fresh-off-compatibility.json
```

The driver interface is:

```text
swarm006_experiment describe
swarm006_experiment run OUT SOURCE FIXTURE PROFILE SEED POLICY ROUNDS [controls]
```

`OUT` must not already exist. The driver writes a non-authorizing request envelope
before assembly, a full native response afterward and optional independent
control results. The Python runner checks input equality, serializes exact
request JSON, computes LE16 material-plane SHA-256, and losslessly compresses raw
JSON only after a byte-for-byte round-trip check. Each execution retains its
command, process exit, timeout/cancellation, child-reaping receipt and log hash.
An incomplete/failed invocation remains in its expected denominator.

An input refusal before native admission can return `input_header_only: 1` with
the bounded identity header instead of copying unadmitted vectors. The runner
accepts this representation only for nonauthorizing `exhausted`/`invalid` results,
with zero work, no material/ledger/joints/history and the exact native empty plan.
Only the declared input arrays may be empty; every scalar identity, profile,
limit, option and other input field must still match exactly, including JSON
types. The full original request is always separately retained and hashed.
`input_representation` distinguishes this refusal from `full_exact`; a full
native response still requires exact input equality. Rejected or malformed
responses retain all original request/response bytes and hashes while the
campaign fails integrity checks. A runner correction is recorded in a new
campaign with its own runner hash; old failed campaigns are not overwritten.

The compatibility comparison verifies stored compressed and raw response hashes.
It normalizes only explicitly enumerated source identities, source-bound native
request/result digests and the exact compiled-definition suffix. It supplies the
absent SWARM-005 OFF option fields, zero receptor work and empty receptor receipts
when reading SWARM-004. Every material, ownership, authored part, obligation,
history, work, failure and prose field remains exact. A change to those fields
fails the comparison; aggregate success rates alone cannot establish compatibility.
Add `--exact` for deterministic replay or reverse-evaluation comparison at one
source: it requires identical canonical native JSON without identity normalization
and supports the new recovery schema. New campaign manifests also retain native
receiver rejection/attempt distributions, unresolved reasons, per-phase work
count/minimum/median/maximum/sum, conservative memory bounds and matched causal
success counts. Missing work is reported as unobserved, not averaged as zero.

## Development cases and controls

The `owner` suite contains **synthetic blank native crops** using origin (0, 0),
activation (64, 48), border 4, interface reach 13 and FRAME-left/MOSAIC-right:

| Case | Size | Seed | Decoration/clutter |
|---|---|---:|---:|
| Industrial native expression defaults | 192×112 | 605 | 0.35 |
| Industrial current GUI default (`industrial_gui`) | 192×112 | 605 | 0 |
| Viaduct-like source GUI exercise | 192×112 | 605 | 0.15 |
| Irregular Megastructure source GUI exercise | 192×112 | 605 | 0.25 |
| Irregular Megastructure smaller crop | 128×128 | 605 | 0.25 |
| Known fixed4099 reciprocal control | 128×96 | 4099 | 0 |

Other normalized values come from the native expression profile. Fixed4099 uses
the actual centered rectangle from `ownership_masks`: x = 32–95 and y = 24–71, fixed
territory, retained interface band and Viaduct-like profile. The runner records
the effective fixed policy explicitly. None of these cases establishes that the
owner's actual crop material, protection masks, sliders or surrounding 2048²
World were reproduced. The two Industrial variants are separate controls because
the native expression and current UI use different decoration defaults.

`development` also retains all twelve SWARM-005 pilot cases:
protected-corridor/narrow-neck × sparse-regular/dense-cohesive/branching-irregular
× seeds 605/19457. `stress` uses the maximum admitted 256×128 native crop, cancellation
and individually reduced FRAME/MOSAIC/solver/memory allowances.

Treatments are `off`, `terminal_only`, `receptor_only`, `both`, `recovery` and
`recovery_without_005`. `recovery` enables both preceding switches plus the new
experiment. Diagnostics append `+fixed`, `+hard_only`, `+frame_frozen`,
`+mosaic_frozen`, `+no_offers`, `+reverse`, `+cancel`, `+frame_budget`,
`+mosaic_budget`, `+solver_budget` or `+memory_budget`. Round caps remain 0–4.
Explicit runner selections use repeatable `--policy NAME@ROUNDS` arguments.

The ordinary envelope stays 2M FRAME + 2M MOSAIC + 4M solver + 2M shared, 16 MiB
conservative admitted storage, eight reservations and four reciprocal rounds.
Reduced-budget controls never increase this envelope. The memory figure is not
a measured process-RSS ceiling.

## Causal controls

For original SWARM-004/005 proposals, the no-offer replay preserves the initial
peer, exact masks, protected union and context. It clamps the native donor's
generator/solver grants to the candidate round-one request, then verifies the
resulting grants actually match. Avoided wrapper work therefore cannot silently
give the no-offer categorical donor a larger allowance. A separate coordinator
execution freezes initial MOSAIC; it must retain the exact initial pair and
unchanged masonry through every round. Failed controls yield unknown causality.

For SWARM-006, the complete no-offer coordinator run changes only
`recovery_offers=false`. The separate peer control changes only
`mosaic_adaptation=false`. Both must start with identical native material,
protection/eligibility/context/peer masks and initial donor grants. The retained
raw outputs expose all work and later history. No control work is hidden inside
or credited to the candidate's aggregate allowance. A causal success requires
positive occupied-footprint effects from both controls, at least one qualified
joint and complete native Apply authorization. Material substitution alone is
insufficient.

The Python reducer independently checks the C++ control summary against the full
native JSON: the only request option changed must be the declared control; initial
FRAME and MOSAIC plans, provenance, categories and donor request must be identical;
every frozen MOSAIC plan must remain identical; and the reported footprint effects
must equal the native planes. A misleading summary therefore fails evidence
integrity even if its individual material previews appear plausible.

## Revealed evidence and future holdouts

`--suite revealed005` reruns the already published [#698](https://github.com/techrote/cybersand/issues/698)
360-execution cohort: four seeds 707861/414855/959922/681376 × island/concave-intrusion/
foreign-solid × three expressions × ten exact policies. It is **developmental
reproduction of revealed evidence**, never a new holdout. The original primary
both-versus-off result has zero newly Apply-valid cases and zero new qualified
joints. Its earlier aggregation failure and original receipts remain preserved.

No new holdout seeds or candidate selection are defined here. Freeze the
candidate source, ranking, search policy, resources and corpus registration
before evaluating a new unseen cohort. No post-reveal tuning may be presented as
validation of that frozen candidate.

The future registration path is:

```sh
python3 native/experiments/gentek_swarm/run_swarm006.py run \
  --build /absolute/frozen-clean-candidate-build \
  --registration /absolute/published-registration.json \
  --out /absolute/fresh-registered-evidence
```

[SWARM-006-REGISTRATION.schema.json](SWARM-006-REGISTRATION.schema.json) defines
the file format. It contains no selected new cases or seeds. Registration fields
are:

| Field | Required value or meaning |
|---|---|
| `schema`, `programme`, `classification` | `1`, `GENTEK-SWARM-006`, `preregistered_unseen` |
| `registration_id` | Publicly recorded identity, 1–96 characters |
| `candidate` | Exact `git_sha`, `definition_sha256`, `harness_sha256` and `runner_sha256` from the frozen clean build |
| `limits` | Exact original FRAME/MOSAIC/solver/shared, memory, reservation and round envelope |
| `cases` | Complete explicit list of `{fixture, profile, seed}` objects; no generation, selection or filtering by this runner |
| `policies` | Complete explicit list of `{name, rounds, role}` objects; role is `primary` or `secondary` |
| `case_count`, `execution_count` | Exact case count and complete case×policy denominator |
| `controls`, `timeout_seconds` | Fixed matched-control policy and child timeout |

The primary comparison is exactly `both` at two rounds versus `recovery` at two
rounds on the frozen candidate whose disabled behavior is independently compared
with frozen SWARM-005. Other declared policies are secondary. The runner rejects
unknown/repeated policies, undeclared modifiers, duplicate cases, changed limits,
wrong denominators, and the known owner/pilot/revealed-005 seeds. That exclusion
check is a guard; the public preregistration must also establish that its selected
corpus was not examined in other development work.

Build with clean committed source and without `--allow-dirty`. Publish the exact
registration SHA-256 after source/policy freeze and before evaluation. The runner
retains the original registration bytes and SHA-256, refuses command-line suite,
policy, controls or timeout overrides, checks source cleanliness before and after
execution, and verifies the registration has not changed. Any failure, timeout,
invalid result or exhausted case remains in the declared denominator. Publication
and the no-post-reveal-tuning decision remain auditable programme actions; the
runner does not manufacture their evidence.

## Evidence interpretation

Only an authoritative final ledger supplies remaining-required counts.
Exhausted/invalid/UNSAT/cancelled early results retain `closure_evaluated=false`
and `null` counts. Original FRAME and new assembly obligations are counted
separately. A zero-joint complete result is valid authoring but not evidence of
reciprocal architecture. A failure does not disappear because its raw preview
contains many material cells.

Runner regression tests specifically challenge unknown closure, forged Apply,
inconsistent obligations, source-time zero-joint completions, LE16 digests,
lossless negative-evidence preservation and the full 360-case denominator:

```sh
python3 -m unittest discover -s native/experiments/gentek_swarm -p test_swarm006_runner.py -v
```

This lab's PASS means execution/evidence integrity for its declared suite.
It does not mean all proposals succeeded, the algorithm generalizes, Windows
graphical qualification passed or owner acceptance was granted.
