# CyberSand native in-chunk neighbour cursor — experimental draft

Base: techrote/cybersand PR #406 at 4a80af2a891332176a3912a235582d77d076a185.
Source implementation commit: b51f01536db6408458442c532d75256d33422fba.
Status: UNQUALIFIED. No merge, no production publication, no performance claim.

## Scope and invariants

World::update_cell passes a read-only source chunk cursor to update_rule_kernel
and the pending pair-reaction wake scan. 27 visible reads in the rule kernel
and the wake reads avoid address/find_chunk when the neighbour is in the same
chunk. World::get's transient body mask is consulted on every visible read.
Cross-chunk lookups fall back to stored_material, retaining missing Empty chunks.
Material values are never cached; writes, epoch, sidecar, JobEffects, activity
and scheduling paths are unchanged. Phased jobs prepare write domains first.

## Reproducible benchmark

    make CXX=g++-13 build/tests
    ./build/tests
    python3 native/bench/run_neighbour_cursor.py --repo . --out /tmp/nr --cycles 3 --extended

Run the same harness on a detached worktree of base 4a80af2a and compare
per-checkpoint state_hash and physical_state_hash, work counts and timings.
Alternate 1/6 workers in ABBA cycles. Profile with -O2 -g
-fno-omit-frame-pointer and report perf function and source line data.
Use the 129-rectangle source fixture, which excludes eight Rapier barrels.

Additional read oracle: compile native with -DCYBERSAND_VERIFY_LOCAL_NEIGHBOUR.
This compares every guarded in-chunk material load with World::get.
Do not confuse that with full thread safety or production validation.

## Mandatory qualification

- Native full suite; baseline vs candidate 1/6-worker state/physical hashes
  at ticks 150,300,450,600 and final 1800, plus work counters.
- ASan/UBSan full; TSan phased/worker parity/determinism; signed/missing
  chunks, body masks, waking/sleep, Water, Inertial, epoch wraps.
- Confirm reproducible gain across repetitions, or revert this experiment.
- After correctness, prepare immutable protected-source admission in
  tools/material_catalogue/compatibility.py REVIEWED_TRANSITIONS for
  native/src/world.cpp, recording exact old/new LF SHA256 and source commit.
- Documentation/provenance, full exact-head native and Godot CI, independent
  review, and explicit owner approval prior to integration.

## Actual results

Not run in this environment: no accessible GitHub source checkout, g++-13,
or perf. Historic stress-canvas numbers are not evidence for this candidate.
