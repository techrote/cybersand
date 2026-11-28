---
status: Current
date: 2026-11-26
scope: Bounded fresh read-only architectural/conversational compatibility review; no integration execution
---

# Concurrent authoring seams — Specialist A

## Refreshed identities and disposition

The 26 November GitHub refresh confirms both counterpart PRs remain open,
unmerged and Draft. Their current heads are:

| Programme | Exact head | Tree |
|---|---|---|
| [Architecture #777](https://github.com/techrote/cybersand/pull/777) | `4cc400cea6be7cb338f15bc6a6a2b28b44143b71` | `119c681377e00b2be86cee15d400e839560461b6` |
| [Collaborative Art #780](https://github.com/techrote/cybersand/pull/780) | `d503d824aac4128968f7dfba5dccd540c3c07b59` | `464c60288d5461d61578b000ae68ac029cffb5bd` |
| Optical application | `fd0830abcfadd9ae19162e5677943bb131223e59` | `fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499` |

The adjacent refresh and input JSON files retain metadata and exact inspected
source hashes. No counterpart code was imported, merged or modified. This is a
source compatibility assessment, not an integrated runtime qualification.

## Persistence: no competing CYSSTRAT version allocation

Neither counterpart head contains the Strata Workbench document codec,
`CYSSTRAT`, optical settings or the named optics catalogue. They therefore do
not allocate a conflicting Strata envelope version 3 or optics schema version 1.
Both retain Setup version 2, generated-start v1 and material-baseline v1;
those three shared codecs are identical between the counterpart heads and were
not changed by Strata 003. The optical envelope keeps Setup separate and adds
one validated `scene.optics` object only on an explicit authored optical edit.

Absence of a collision is not backward interoperability: either standalone
counterpart lacks the Strata Workbench codec and cannot open a v3 layered scene.
A future combined checkout must preserve Strata's load/save dispatch and v1/v2/v3
round trips. It must not discard `optics`, reset it on a native edit, or treat
the envelope version as Setup's version. Unknown optical keys remain refused.

There is also a concrete **module interchange limit**. The unchanged Strata
`strata_native_module.gd` adapter accepts only the frozen #770
`cybersand-native-module-v1` contract. Architecture #777 accepts both v1 and
`cybersand-native-module-v2`, with v2 fixed-region and face-adjacent connection
semantics. A v2 module is currently refused by Strata. Do not relabel v2 as v1,
drop its constraints or claim it is already supported. A future adapter needs
explicit semantic and native-authoring qualification.

## Edit and native authority

Strata's `play_edit_reason()` guards the actual edit target, Play lock/visibility
and active native authoring. Its shared Workbench Art admission explicitly
targets Play; its PAINT controller retains native receipt ownership. The
counterpart Art context explicitly describes a copied native **Play-only**
observation, never rendered-pixel authority. #780 adds read-only context-capture
callbacks to that PAINT owner and does not acquire a World or consume its
receipt mailbox independently.

When reconciling the shared controller, preserve both those callbacks and the
Strata guards in `_ready_to_author`, native Art admission, history routing and
scene retirement. Choosing a rear optical focal subject must never retarget an
Art capture or native write. Selecting decorative authoring must continue to
refuse ordinary Play writes under the established guard. Architecture's native
stage/session remains an owner-reviewed path; optical distance and appearance
cannot establish material, collision, connector or approval authority.

## Named optical context: useful future extension, currently unsupported

The Art `cybersand-art-proposal-v1` compiler admits only its existing bounded
native proposal fields and refuses unknown fields. It has no optical action,
plane-selector action or preset-write operation. Architecture uses its separate
typed proposal/campaign/session formats. Its transport handoff remains Art-owned;
optical integration must not add a competing provider listener or auto-paint
path. Current source provides no conversational application of optical presets.

A future read-only appearance context can identify the scene, four plane IDs,
complete validated optical values, configuration hash and optional human preset
name. A preset name alone is insufficient: names can be reused while a scene
retains its own complete values. Native source/generation guards should remain
separate from appearance identity because optical edits intentionally do not
increment native material authority. If a future proposal depends on appearance,
its freshness guard must also cover the optical configuration it observed.

Any future optical action should use the existing validated presentation owner,
without native history entries, geometry compilation, automatic catalogue
transmission or implicit provider calls. Temporary inspection state and quality
preferences remain separate from authored art. These are integration constraints
and possible future context, not implemented or qualified model features.
