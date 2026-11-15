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


## BODY-V2 opt-in expressive host controls (second checkpoint, 15 Nov 2026)

New independent `body_v2.py` is **model-free synthetic**, not an alteration to the real #611 pilot. It retains per-lease isolated World, rejects arbitrary model coordinates and accepts only a digest-fenced **host-offered action ID**. One versioned proposed vocabulary, **not yet wire-compatible with the current native M1 move adapter**, is `INK_{N,E,S,W}_{1..4}`, `LIFT_{N,E,S,W}_{1..4}`, `SAVE_ANCHOR`, `RETRACE_1` and `STOP`. Every ink stroke validates *all* intermediate cells as native-empty and unprotected; pen-up may cross only Empty or the worm's OWN previously drawn material, never foreign material or protected cells. `RETRACE_1` is precisely one adjacent previously visited cursor cell, **not teleportation or material Undo**. Anchor markers are bounded to four, and cannot grant relocation. `STOP` fences all late choices.

The model-facing **local observation** adds a bounded 7×7 occupancy matrix (empty/own ink/foreign/protection/edge), recent physical cursor positions, source-local material hash, menu digest, persistent visited counts and separate **new material cells** versus **cursor logical moves**. Source-matched replay compares every offered menu, original choice, action receipt, World hash and final stored synthetic material. This is **same-code replay**, not independent/native requalification.

The current synthetic-only horizon is explicitly capped at **128 decisions, 128 new cells and 512 logical cursor steps** and is NEVER propagated into #611's 36/36/64/8 native envelope. Four World instances are isolated and never counted as four active model processes. No actual per-runner 1-vs-2 SLM benchmark occurs here.

### First original hosted four-arm pilot

At exact source `352616e8e40faffcd233e2dc3061d7b866a808f6`, [opt-in Actions #43769849173](https://github.com/techrote/cybersand/actions/runs/43769849173) **SUCCESS**, **20/20** model-free tests. The [unaltered original 22-entry ZIP #14183912019](https://github.com/techrote/cybersand/actions/runs/43769849173/artifacts/14183912019), outer SHA-256 `2ed8336e6dc297ba06dd4b97b7b4439c7d52686c5ebfcd9263fa35a8bfa2cc5c`, ZIP CRC PASS and individually manifested original PNG/trace SHA-256 checks, contains four **96×96 synthetic** alternative controls sharing the initial seeded World and host-owned deterministic choice algorithm:

| Variant | Actual synthetic decisions | Unique new synthetic ink cells | Controls enabled |
| --- | ---: | ---: | --- |
| One-cell ink only | 85 | 84 | cardinal 1-cell ink, STOP |
| 1–4-cell ink | 59 | 117 | swept ink, STOP |
| Swept ink + pen-up | 128 | 128 | swept ink, pen-up crawl, STOP |
| Swept ink + pen-up + anchors | 128 | 128 | above + SAVE_ANCHOR + single-step RETRACE |

The synthetic 128-turn arms hit the **synthetic 128-cell ink ceiling**; they do **not** demonstrate native performance or model intelligence. The run's drawn images were inspected: each has a locally coherent zigzag/trunk-like geometry; pen-up variants extend over wider separated regions. These are illustrations of how a body/action set changes a **seeded procedural walker**, not results attributable to a learned wormbrain or human quality rankings. The four alternatives share seed but have different action catalogues and therefore are not a causal model-policy comparison.

At subsequent source `81a1d8c3ff9b201640fcac5fb03847aba5fd763c`, [exact-HEAD CI #43770004754](https://github.com/techrote/cybersand/actions/runs/43770004754) **SUCCESS** (22/22 pure-stdlib methods, including adversarial original-action replay and forged-receipt refusal); [separate rerun #43770009410](https://github.com/techrote/cybersand/actions/runs/43770009410) also SUCCESS. These are source-only tests, no model process or Godot native paint.

**Commander handshake:** Commander owns resident model/runner PID attestations and quota; Body Lab offers the versioned `SyntheticBody.observation() / menu() / choose(choice, menu_digest, original_response)` candidate contract. A real runner may reuse the *vocabulary and tests* only after integrating its own source-authenticated native host observation and per-swept-cell receipt, plus separate 128-turn M3 cursor/history/paint/Stop proof. Do not substitute this Python World for current native source or count synthetic material SHA as a native receipt. The exact next engineering gate is a **native-inert integration adapter** mapping the proposed IDs to Commander choices and refusing old-host limits before any new native session.
