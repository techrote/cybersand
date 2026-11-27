# Native thin-patch observation probe — 25 November 2026

Status: **one successful external diagnostic, 228 checks, zero added behavioral
episodes**. This closes a specific evidence gap between the synthetic copied-ID
sampling tests and an actual native World with an admitted physical actor. It
does not change the frozen application or replace the registered 194-actor
programme.

## Source and custody

The executed application was exactly
`a7250e15495667b2fcf564cbed1eaa8dea217c45`, tree
`a038e6df65d58529f4c496c01f26c65975654fa6`. The ordinary evaluator's complete
custody checks passed before and after execution: 1,143 committed source inputs,
855 loaded project inputs, official pinned Godot 4.7, and retained native/Rapier
provenance. The two custody JSON files are byte-identical. The diagnostic lived
outside the application checkout's `godot/` directory; its two source files were
independently hashed before and after. This evidence commit adds documentation
and original diagnostic bytes, not a new application candidate.

| Item | SHA-256 |
| --- | --- |
| Official Linux Godot executable | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| External GDScript diagnostic | `d3162736f8a8b3b29c0445b20cfd79f49fe25ee48626c97d5ef6cde57c856238` |
| External custody wrapper | `d0ea566e54b4c2e93c4f1b9e5b954b575e72027ea65261351c9c28cdd6db5e6c` |
| Original report | `14d1311b1658e4843a9c8ab8f389092670b4994ec6e30d91741e676c2068f9e7` |
| Original copied native ID payload | `8b4d44aa9c68f931b30c10c44a6837312753cd795efd747ea75a3b0f9f253165` |
| Original execution receipt | `e1f7f76946a302da3308dc1115815dea4448da81dad82110d4a0e61551818eda` |
| Original custody, before and after | `9654a41373e3a00c8ae56a349c9dd6554b7abe91875297f0b9a3aed1702bbea7` |
| Complete evidence ZIP | `c565b2e50ad1749decb94b7873167b6608d4bb2789c8d3e541d33391a567d949` |

The process started at `2026-11-25T03:56:20Z`, returned zero after 2.572 seconds,
and emitted one successful terminal. There was no failed or discarded prior
attempt. `archive-manifest.json` binds every original file and its byte count;
the archive was reopened and every member's SHA-256 verified. The uncompressed
copies of the two diagnostic scripts beside this document exactly match the
executed scripts in the archive.

## What was compared

One synchronous `PhysicalActorSession` owned one ordinary 4LY Trainer and its
Rapier bridge in a native 256 by 256 World. Native hard surfaces and the actual
moving-body coupling passed through the existing owner interfaces. The session
completed one native tick and one physical step. Its public copied observation
then reported position `(128.5, 100.521293640137)`, a rectangular 10 by 6 chassis,
zero rotation, and finite motion. The approximately 0.021-cell downward movement
occurred during that real step; the pose was not fabricated or teleported.

The public native `emit_disc` operation with radius zero authored exactly one
Oil cell, ID 16, at `(129,94)`, and one Water cell, ID 3, at `(169,94)`. The near
cell's center was 6.104 cells from the actual actor center; the far cell's center
was 41.440 cells away. Both were off the global four-cell sampling lattice and
inside the same 50-cell query radius.

A separating-axis calculation used the **actual copied part position, rotation,
size, shape and native mask**. The complete near cell square was outside the
actual chassis by a 2.521-cell separating margin; the far square also lay outside
the chassis. The supported near radius of eight was therefore sufficient without
painting material inside a body or increasing the default near field.

The owner published a full numeric material-ID payload after painting. A separate
verification pass decoded only these copied bytes, confirming exactly one Oil
and one Water cell at the authored coordinates. It did not read private native
World storage or infer identity from rendered colors. This full-canvas
verification scan is explicitly excluded from the policy sampling counts and
query timing.

Both arms then called the production session's `_ambient_environment` method
with the identical admitted observation, copied publication, two material IDs and
50-cell scope. The ordinary Cautious Flyer profile was copied with only its two
material modules enabled, so terrain rays and unrelated modules did not confound
the material-query comparison. The profiles differed only in these perception
settings:

| Arm | Coarse spacing | Exact near radius | Boundary refinement |
| --- | ---: | ---: | --- |
| Coarse-only | 4 | 0 | Off |
| Adaptive | 4 | 8 | On |

The experiment warmed each arm once, then made 100 further calls per arm,
alternating which arm ran first. All 101 results within each arm had exactly the
same observed material values. No policy, native or physical step occurred
between the arms. Public actor state, native payload hash, native revision 4,
tick 1, publication serial 2, owner epoch 11 and World generation 1 remained
unchanged throughout.

## Result and bounded cost

| Observation | Coarse-only | Adaptive |
| --- | ---: | ---: |
| Unique copied-ID reads per query | 489 | 677 |
| Reads in the exact near field | 0 | 194 |
| Additional unique refinement reads | 0 | 4 |
| Near one-cell Oil observed | No | Yes, exact center `(129.5,94.5)` |
| Far one-cell Water observed | No | No |
| Full coverage claimed | No | No |
| 4,096-read cap exhausted | No | No |
| Median warm owner-call elapsed time | 884 microseconds | 1,216 microseconds |
| Minimum–maximum elapsed time, 100 calls | 802–1,413 microseconds | 1,146–1,709 microseconds |

The adaptive query required 188 additional unique reads, a 38.4% increase for this
pose and scope. The near stage runs before the coarse stage and deduplicates
reads, so adding the near count to the coarse count would overstate the total.
Observed near Oil also supplied a locally estimated boundary normal and tangent
from exact adjacent ID transitions; this does not establish a useful traversal
route around the patch.

The far Water miss is a retained limit, not a false negative relabelled as absence.
Both arms returned `unobserved_in_incomplete_coverage`, with
`absence_scope = admitted_samples_only`. Coarse-only returned the same explicit
incomplete status for its near Oil miss. Adaptive refinement expands an already
observed neighborhood; it cannot discover every remote thin feature between
lattice sites.

These are **warm repeated-query elapsed times**, measured around the production
owner environment call. They exclude publication copying, the diagnostic full
payload scan, native progression, Rapier progression and actual policy cadence.
The two specialist lanes coordinated so A's six-case physical diagnostic started
only after this process ended; this is not an isolated-machine CPU benchmark.
Use the retained full hosted campaign for production advance and population
costs. The one snapshot supports this local detection claim, not universal thin
coverage, behavioral attraction, pathfinding, entertainment or Windows timing.

## Reproduction and accounting

`originals.zip` contains both executed external scripts, the untouched report,
console, native payload, execution receipt, before/after complete custody and
verification result. Extract it outside a clean checkout of the exact application
commit, restore the pinned native libraries and Godot, then run:

```sh
python3 run_native_thin.py --root /absolute/a725-checkout \
  --godot /absolute/Godot_v4.7-stable_linux.x86_64 \
  --output /absolute/new-native-thin-attempt
```

The wrapper refuses a different HEAD or changed committed application inputs and
preserves process outputs before reporting a failure. Paths in the original
receipt are execution identities, not portable installation requirements.

Accounting is **one World, one physical actor, one native tick, one physical
step, zero additional behavioral episodes**. The registered 122-World,
194-actor programme remains unchanged.
