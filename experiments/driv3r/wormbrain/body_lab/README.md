# DRIV3R Worm Brain & Body Lab — isolated four-slot preflight

**Draft/HOLD: MODEL-FREE SYNTHETIC ONLY. No live model, native PAINT, 128-turn support or actual runner-pair qualification is claimed.** This opt-in work is stacked on [#611](https://github.com/techrote/cybersand/pull/611) at source b4079e74207d7a70992c48ebd70e9c7b2016f463, with code exclusively in this Body Lab directory.

## Implemented

- A four-episode wrangler identity and world lease registry that refuses duplicate leases and shared Worlds; the offline registry always reports **zero verified resident model processes and zero native receipts**.
- Corrected model-prompt ink counting derived from supplied initial/current material-58 World readbacks, replacing the incorrect original `len(history)-1` cursor-history proxy. A new prompt object is returned; frozen #611 source is untouched. A future adapter must authenticate both original native snapshots.
- Host-offered cardinal 1–4-cell swept candidate lists, checking **each intermediate cell** for focus, empty material and protected-region exclusion. This is a model-free menu preflight; actual Godot/native host must revalidate every step against current World/epoch and obtain real PAINT receipts before use.
- Four independent deterministic 96×96 **model-free synthetic** material PNGs, action traces, SHA-256 manifest and self-tests. Model names are only planned comparison labels; NO model is loaded, none of these are native World screenshots, and no live worm count is implied.

## Verified native limitations from unchanged parent #611

`wormbrain/pilot.py` has 36 model decisions, 36 one-cell native ink additions, at most eight recoveries, and the faulty cursor-history counter. `godot/tests/run_driv3r_m3_history.gd` has hard `M3_MAX_LOGICAL_MOVES := 64`, only cardinal one-cell cursor moves, at most four branch anchors and brush-up relocation drawing from the logical move budget. M4 has its distinct 56-native-edit cap. The source-fenced original two d1 worms [recorded in #611](https://github.com/techrote/cybersand/pull/611) made 36 selections each and painted respectively 33 and 36 genuine cells.

**128+ turns remain inadmissible.** Extending the native harness/isolated segmented session, safe cursor steps, real material budgets, STOP/cleanup, original receipts/replay and source/corpus fences requires separate code ownership, review and execution. The provided envelope checker refuses 128 regardless of the unsupported `extended=True` flag, rather than silently relaxing the Godot hard limit.

## Reproduce (only standard-library Python)

From repository root: `python3 -m unittest -v experiments.driv3r.wormbrain.body_lab.test_preflight`; then `python3 -m experiments.driv3r.wormbrain.body_lab.preflight --out /tmp/driv3r-body-lab-original`. The opt-in dedicated workflow produces the same reproducible synthetic artifacts and source checks; it never downloads models or builds native/Godot.

## Handoff

Commander: own genuine runtime dispatch, runner lease/health/PID attestations and benchmark one vs two resident models per 4-vCPU runner before claiming four live worms. This lab owns only the native-inert body preflight, not expensive inference execution. Ethologist: the four gallery PNGs are **synthetic prototypes**, not creative results attributable to d1-2B/LFM/SmolLM/Sprocket. Next Body Lab work: request a narrow integration-owner handoff for new opt-in native adapter and qualify the 36-turn original safety envelope with live readback/count repair before expanding to 128. No training, merging, Ready or production default changes.
