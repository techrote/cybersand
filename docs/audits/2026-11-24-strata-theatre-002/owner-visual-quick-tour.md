# Owner visual quick tour — Strata Theatre 002

**Draft/HOLD.** Use the verified Windows evaluator identified in the [decision packet](decision-packet.md). The [full evaluation guide](../../operations/strata-workbench-evaluation.md) is the canonical workflow reference. This short tour focuses on appearance, plane ownership and a useful first editing session.

## Open a place and inspect its depth

1. Extract the whole evaluator into a writable directory and run **Open Workbench.cmd**. Ordinary Workbench starts with Strata off. Open **Strata Theatre… → Scenes**, choose **Orbital Fabrication Terminal**, and load it. Scene loading replaces the authored composition; save existing work first and wait for actual admission feedback.
2. Begin in **Overview**, then zoom closer and pan with the ordinary Workbench camera. Overview is for the architecture: the actor is small and is mainly located by its **PILOT** label at that scale. Use a closer view to judge actual movement and route readability. Use ordinary **Play/Pause [P]**; with the default **Midge**, **W/Space** gives body-axis thrust, **A/D** rotates, **C** assists upright and **Ctrl** brakes. For another physical actor, follow its live control hint in **Details** or the actor catalogue tooltip ([flyer hints](../../../godot/scripts/gcr_review_fleet.gd), [physical actor control source](../../../godot/scripts/workbench_actor_catalog.gd)).
3. In **Layers**, compare **Stack · all visible planes**, **Flat · selected plane** and **Solo**. Inspect **Play** first, then **Rear architecture**, **Atmosphere / effects** and **Background**. The ordinary toolbar's **EDIT:** indication names the paint target. The native pixels behind a route do not create Play collision.

Try these scene-specific comparisons:

| Environment | Look for | Ownership reminder |
| --- | --- | --- |
| Orbital Fabrication Terminal | Connected far dock arms behind the megatrusses; a broad lower flight space | Rear machinery is separate from the bright Play decks. |
| Rain over the Arcology | Uneven inhabited blocks and a taller distant skyline visible through openings | The native facade texture remains when atmosphere is off. Sparse visual rain does not accumulate Water. |
| Underworks / Reactor Service | Rear turbine mass, pressure columns and pale service platforms | The large turbine and orange lower truss are decorative. They are not a spinning physical machine or a traversable Play beam. |
| Abyss Foundry | Connected far rock framing a large central void | The central orange gantry/framework is decoration. Use Solo Play to establish which floors and walls collide. |
| Vertical Transfer Spine | Repeated carriage cages, hoist cables and distinct transfer decks | The portrait Overview compresses individual pixels; inspect a detail before judging collision edges. |

The shipped **Gallery.html** provides actual full-stack, isolated-plane, native-grid and atmosphere OFF/ON captures. Its source/receipt details identify the executed build. Native-grid details use a nominal near-1:1 framebuffer scale, qualified within 1%; browser and desktop scaling are separate. It is a viewing aid; it does not replace piloting the ordinary actor on your own display.

## Import and reuse a small native construction

4. In **Import**, load the **synthetic alpha-cutout** sample and choose a decorative plane explicitly. Use an empty destination region for this first exercise. Keep **Overlay · no write into cutouts**: transparent pixels preserve the destination, including any material already there. Scroll down to inspect the source, mask and native material proposal, changed/no-write counts and **Approve reviewed placement**. A preview changes no native cells. Change a mapping or placement option and prepare a fresh preview before approval. **Replace · explicitly write Empty** is a separate erasure choice.
5. For reusable architecture, reload untouched Orbital or inspect your prior edits, then choose **Compose → Factory service bay** with shared origin **X 800, Y 512**. This is a checked source-layout starting suggestion, not a reserved empty area or approval token. **Preview layered composition** must still validate the actual current materials, clearances and revisions. Scroll through the per-plane before/after views and composite native-ID proposal. Approve only the result you intend to place. The proposal image uses current opacity and fixed plane order; it does not predict haze, depth, glow or animation.

After every stage has actually completed, **Apply reviewed depth and atmosphere** is a separate optional approval. It replaces the existing atmosphere configuration with the preset's proposal and does not add material history. For native Undo/Redo, select the relevant plane; a multi-chunk operation can require several history steps. **Stop · keep applied prefix** stops before the next chunk; an already submitted native request must finish its acknowledgement and readback, and the committed prefix remains.

## Compare motion, then reopen your work

6. In **Atmosphere**, compare **Enable atmosphere** off/on with the same scene, camera and actor state. Try **Pause animation**, then **Reset motion**. They change visual motion, not authored native materials. Hidden, Solo-excluded and zero-opacity planes stop their motifs; locking protects edits but does not itself pause an already visible animation. Judge whether rain, mist, steam or signals help the place remain legible. These are presentation effects, not native Steam mass, physical light transport or cross-plane hazards.
7. Save using **Save start / Ctrl+S**, exit the application completely, relaunch **Open Workbench.cmd**, and **Load start**. Inspect all four layouts, the imported opening and the effect settings in the fresh process. The scene save preserves authored layouts/settings and provenance; it is not exact evolved multi-World physical continuation, and animation phase restarts.

Record the package/source identity, Windows version, GPU/driver and display scaling in **OWNER-EVALUATION.md**. Note real movement, input response, opacity/visibility leakage, readable collision silhouettes and pacing with atmosphere off/on. Physical Windows/NVIDIA appearance, interaction and subjective acceptance remain the owner's gate.

## Historical visual reference

Before final successor qualification, source-2 original Linux captures at `1a124c0a47cd9f94e07b541e5c451602b8e8e0fd` informed the design review. That campaign **failed one Orbital exact source-colour assertion** and is not represented as final qualification.

The [unaltered original artifact](https://github.com/techrote/cybersand/actions/runs/45493745153/artifacts/14967949955) contains these real Godot images:

- `orbital-terminal/reference-composite.png`
- `neon-rain-arcology/reference-composite.png` and `reference-plane-play.png` / `reference-plane-background.png`
- `industrial-underworks/reference-composite.png`
- `abyss-foundry/reference-composite.png`
- `vertical-transfer-spine/reference-composite.png`
- Each scene's `atmosphere-off.png` / `atmosphere-on.png`

The [dated visual review](reviews/refined-linux-visual-review-b.md) records exact PNG hashes, interpretation and limits. Source-3 [run 45502846309](https://github.com/techrote/cybersand/actions/runs/45502846309) later produced readable lower approval controls but failed three strict status-text assertions; it produced no successor evaluator. The [source-3 UI review](reviews/source3-ready-ui-review-b.md) preserves those captures and the then-visible Import location-summary gap. Prefer the final evaluator's source-matched Gallery for owner acceptance.
