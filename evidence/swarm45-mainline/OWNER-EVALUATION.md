# SWARM-004/005 — current Windows owner evaluation

**Draft/HOLD: physical owner evaluation is pending.** This guide accompanies the
unchanged source-matched evaluator ZIP. Earlier evaluation of donor packages does
not accept this reconstructed package. Automated admission status and final
candidate HEAD are recorded in [integration PR #715](https://github.com/techrote/cybersand/pull/715).

## Exact candidate

| Item | Identity |
| --- | --- |
| ZIP | `CyberSand-SWARM45-Draft-HOLD-Windows-96b8d3fb9d5a.zip` |
| ZIP SHA-256 | `ce50316be11caafe32879395b681ef7f131541732061ded5db36dc3af6236c6d` |
| Package manifest SHA-256 | `73ae92f19034bf8a9311430200c269df1b18e6c2a2ee18c8609ef62379daaf3b` |
| Original build/execution source | `96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f` |
| Frozen source before request-only commit | `79b8a0a4a1c2ace435d709b35114ee7065c935e6` |
| Native definition | `217bfa716e61198f5b3849f2ae14c30e85bc9f623fc1d05438c59df2296ce7f7` |
| Windows reciprocal CLI SHA-256 | `001672a6961c113f51b4f483e33cbb97702fec09616a60949c26a991a5a18105` |
| Windows native adapter SHA-256 | `c7fc1fbfea2999489ae83a6da100ca795b336dc6efa251af7e5003071a2bb43d` |
| Engine | `4.7.stable.official.5b4e0cb0f`, Windows x86-64 |

Use `candidate-manifest.json` and `swarm45-runtime-provenance.json` for the
delivered identities. The bundled `READ-ME.md` preserves historical donor
reproduction guidance; its `12a481…` hash is explicitly a donor identity. Its
relative current-runbook link is unavailable offline. The
[current integration runbook](https://github.com/techrote/cybersand/blob/96b8d3fb9d5a2e9f580d4b33293b1ab725269d4f/docs/operations/swarm45-mainline-integration.md)
and the steps below describe this candidate.

## Run the physical evaluation

1. Verify the downloaded ZIP in PowerShell, extract it into a fresh folder, and
   double-click **Open Workbench.cmd**. Keep the engine, native libraries, CLI,
   licences and manifests together.

   ```powershell
   Get-FileHash .\CyberSand-SWARM45-Draft-HOLD-Windows-96b8d3fb9d5a.zip -Algorithm SHA256
   ```

2. In ordinary Shared Workbench, open **Reciprocal assembly…**. Confirm the
   **Experimental · FRAMEWEAVER × MOSAIC** label and both SWARM-005 switches OFF.
   Opening the dock must leave the World unchanged. Pause, choose **New blank**
   at **512 × 512**, and use **Paint territory / Activation stroke** to place one
   dab at native cell **64,48**. Confirm crop origin **0,0**.

3. Reproduce the known examples below. For each, use **2 rounds**, clear border
   **4**, interface reach **13**, balanced orientation, optional negotiation ON,
   destruction **0**, and independent Gentek overrides OFF. Set decoration
   explicitly; changing expression does not reset it.

   | Example | Expression; seed; crop | Ownership; sharing; decoration | SWARM-005 switches | Known native result |
   | --- | --- | --- | --- | --- |
   | Reciprocal construction | Viaduct-like; **4099**; **128 × 96** | FRAME centre / MOSAIC surround; **OFF**; **0** | Both OFF | Complete; **8 foreign joints and 8 foreign-closed obligations** |
   | Local termination comparison | Irregular megastructure; **605**; **192 × 112** | FRAME left / MOSAIC right; **ON**; **0.25** | Test OFF/OFF, ON/OFF, OFF/ON, ON/ON | Terminal parts OFF: Blocked, **6,034** material cells, one unresolved obligation. Terminal parts ON: Complete, **6,026** cells, no unresolved obligation and **zero foreign joints** |
   | Genuinely blocked control | Viaduct-like; **605**; **192 × 112** | FRAME left / MOSAIC right; **ON**; **0.15** | Both ON | Blocked; **6,035** material cells and one unresolved obligation |

   Expression selection supplies the five structural values. Viaduct-like uses
   variation/branching/irregularity/environment/cohesion
   **0.65 / 0.55 / 0.05 / 0.25 / 0.35**; Irregular uses
   **0.65 / 1.0 / 0.95 / 0.7 / 0.2**. These are already known authoring examples,
   not new holdouts. A local welded cap remains distinct from a foreign joint.

4. Generate and inspect Materials, Joints and Unresolved. Preview must leave the
   installed World unchanged. A control edit or new territory gesture must
   disable stale Apply. Generate again; apply only a genuinely authorised
   composition. For an authorised example: **Apply → Undo → Generate → Apply →
   Save start → fully quit → launch a new process → Load start**. Inspect saved
   evidence and confirm the reopened construction and recorded identity. Saved
   inspection is read-only; a fresh current-source Generate is required for a
   new transaction.

5. Repeat the relevant authoring/persistence sequence on a **copy of the original
   saved/painted 2048 × 2048 map**, using its actual protected cells and intended
   crop. Record genuine Blocked outcomes. Observe architecture, player collision,
   visual presentation and usability on the physical NVIDIA system. Static
   material-path validity does not establish load-bearing stability.

## Return the acceptance record

Record the ZIP/source identities above, GPU and driver, actual rendering backend,
original-map identity, exact settings, native status, foreign joints versus local
termination, and any visual/collision/usability defect. Retain the named saved map
and its adjacent `.swarm004.json` and `.swarm004-evidence.json` files, with their
SHA-256 hashes. State whether this exact candidate is accepted or remains blocked.

Hosted graphical execution and synthetic blank-world cases do not substitute for
this physical NVIDIA/original-map gate. The PR remains Draft/HOLD until every
mandatory admission condition, including this gate, is satisfied.
