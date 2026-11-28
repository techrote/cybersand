# Mainline convergence spawn witness

`run_spawn.py` mounts the existing ordinary Workbench owner fixture and invokes
the production Place, Reset and Restore handlers. It uses the selected Full
two-slot, Stock Safe, coherent Water composition and all-worker configuration.
The registered material fixture remains unchanged. Each process has its own
profile and output directory; recording-on and recording-off are separate arms.

```sh
python tools/pubpres_mainline/run_spawn.py \
  --source-root /exact/source/checkout --runtime /original/native/build \
  --engine /path/to/pinned/godot --output /new/output/directory \
  --source EXACT_APPLICATION_SHA \
  --scene wave512 --scene mixed2048 --recording both --timeout 480
```

Windows uses the pinned engine's OpenGL ANGLE compatibility path. Linux requires
a graphical display unless `--headless` is supplied. A headless arm measures CPU
request, admission, input and real physical completion only; its graphical
fields are absent. It cannot satisfy rendered or physical owner acceptance.
The runner stages the committed source into its output directory and uses the
mission's shared native admission to verify the original build/dependency
receipts and complete current input equivalence. It overlays only that admitted
binary and an explicitly labelled diagnostic manifest. Rapier must match its
committed LFS pointer, the engine must match its platform pin, and all fixture
paths/hashes are recorded. Source project files remain untouched. Staged import
must preserve all authored source; the original runtime manifest remains in Git.

The six cases cover the first additional actor after startup, warmed reset with
Fire off, warmed reset with Fire on, placement near authored material, restoration
of the authored start, and a further placement after restoration. A real 100 ms
W keyboard pulse establishes input acceptance and application; neutral flight
then measures three seconds of operating cadence. C remains held during that
interval, so the real Thruster control determines whether Fire is emitted.
No physical pose, velocity, simulation counter or native credit is injected.

The recorder adds bounded `spawn` rows to its existing queue and rotating files.
Their phase durations are wall-clock CPU observations, including possible
scheduling delays. Nested phases overlap and must not be added together.
`physical_adopted` is elapsed since provisional preparation began. A terrain
packet's `since_preparation_usec` measures the observed handoff interval, not
native execution time. The records do not claim GPU execution or scanout.

`REDUCED.json` joins real completion rows across owner replacement, preserving
the interruption that a new session's zero-based counters would otherwise hide.
The process-frame first-step observation is an upper bound. The recorder's
completion clock supplies an exact actual-step timestamp where available.
Coherent draw observations require the accepted owner, material world and
selected body pose; renderer callbacks still do not prove monitor presentation.
Loss intervals, failed cases, process timeouts and missing fields remain visible.
Any recorder loss makes recording-on timing qualification fail. Recording-off
requires no gameplay segment, while retaining the independent startup receipt.
Adverse completed reports are reduced even when the test exits unsuccessfully.

The shared owned-process and CPU sampler records actual application CPU and
memory, verifies the receipt PID and retains its original lifetime/timeout
checks. The application source/tree, executing driver and mounted Main are bound
independently. There is no local-delta qualification override. The earlier
diagnostic runner remains reproducible at its original commits with its explicit
patch receipts. Use the complete packaging manifest for shipped-source
qualification.

The draw observer records the earliest coherent callback after the actual owner
changes, including callbacks before the input pulse. Its optional upward-pose
response clock is separate from accepted-command and applied-command clocks.
Return-to-cadence is descriptive: twelve consecutive real completed-step
intervals no larger than twice the last-second median, with a minimum50ms band.
It neither replaces nor waives the registered100ms p95/250ms maximum objectives.

Local Python clock-join tests run with:

```sh
python -m unittest tools/pubpres_mainline/test_spawn_reduction.py
```

The existing `verify_pubpres_owner_gameplay_rotation.gd` test also verifies the
new phase schema while retaining its actual bounded-file and loss-accounting
tests.

## Initial investigation, 28 November 2026

An initial headless prototype held W for three seconds. It reached the finite
canvas boundary, causing legitimate native refusal; subsequent retained actor
placements were refused because an existing actor was outside the admissible
construction extent. Its unsuccessful output is retained in the mission
evidence. The registered spawn witness uses the short pulse described above and
explicitly fails if the observation becomes paused or refused.

The first corrected Wave512 recording-on and recording-off runs each admitted
all six cases and observed actual Rapier completion and keyboard application.
Those local observations use the #767 native binary and an explicitly recorded
script delta. They are diagnostic, not qualification of the integrated candidate
or the owner's NVIDIA hardware. They locate a repeatable request/admission delay
without establishing that newly emitted material causes it. Full source and
hardware comparison results belong in the mission evidence ledger.

## Bounded transport compilation reuse

The request path repeatedly validates the same transport profile on Main and
the exclusive simulation owner. Its unchanged compiler expands 81 x 81 directed
pairs into 39,529 integers, including diagnostic origin strings used while
resolving each field. Direct production calls measured repeated baseline
compilation at 65–67 ms and tuned profiles at 107–115 ms on the local host.

`CyberTransportProfiles` retains one compiled table for an exact input profile.
Every request still performs the original schema, range and pair-policy checks.
Only equality with a previously valid input reuses its compiled integers/hash;
all changed profiles go through the original compiler. The retained source
Dictionary is a deep, recursively frozen copy. Returned profile and packed
values are independent copies. A short mutex protects comparison and complete
entry replacement; compilation remains outside the lock. It stores no World,
physical owner, native handle, material history or presentation identity.
Unusual script-created Object keys retain their original compiler acceptance but
bypass reuse, so the cache cannot extend a live object's lifetime.

The direct warmed call observations fell to 12–73 microseconds; first cold
compilation remains necessary. The independent golden-output, mutation and
two-thread test in `test_transport_profile_reuse.gd` binds all three preset packet
hashes to the pre-repair compiler. The original `test_transport_profiles.gd`
continues to exercise native construction and rejection with those packets.

In the first matched local Wave512 six-case recording-on/off comparison,
retained spawn/reset request time changed from 80–87 ms to 5.6–15.9 ms. Observed
owner admission changed from 630–678 ms to 211–249 ms. Restore request time changed
from 96–101 ms to 27–31 ms and admission from 683–686 ms to 224–254 ms. Both source
arms completed all real input and physical checks. The remaining handoff delay
and the initial cold compile are explicit; this is not physical Windows owner
acceptance, and broader integrated/graphical comparisons remain required.
