---
title: ObjectShard M4 reviewed material shader source transition
status: Historical record
document-kind: audit
scope: Protected shader source identity, ordinary branch equivalence and opt-in structural material finish
canonical-for: []
last-reviewed: 2026-11-28
related-documents: [../research/objectshard-m4-workbench.md, objectshard-m4-reliability-20261128/presentation-delivery.md]
---

# Reviewed ObjectShard material shader transition

The owner-authorised reliability mission for ObjectShard issue #281 / PR #754
includes a bounded correction to detached-material appearance. This record
admits one protected non-identity consumer through the existing append-only
`REVIEWED_TRANSITIONS` mechanism. It does not change or refresh the immutable
catalogue compatibility lock, material IDs, projection rules, LUT/program bytes,
chemistry, quantities or the ordinary appearance programme.

| Identity | Value |
| --- | --- |
| Protected path | `godot/shaders/material_palette.gdshader` |
| Previous retained source | `1ec3f214662f7d5a0a38ff727b684c15b41c067b` |
| Previous LF SHA-256 | `f686ca416b5b011751ddd5d38a24824742d01cb8d489b46710ee1f1fbb2a09c1` |
| Public source introducing reviewed bytes | `60a71358de549877d65d0bcac08ef6e8bb1573c0` |
| Reviewed LF SHA-256 | `e278e05c1434ead33600081e542bff36fcfd58e011ef5aa6e9c90f1b04341e3c` |

The new source is retained in the principal integration history. The existing
guard authenticates its ancestry, the exact source bytes and this committed
record. A later byte change must receive a separate reviewed transition.

## Ordinary renderer equivalence

The only added executable paths are enclosed by `CYBER_OBJECT_SHARD` conditions.
The ordinary application does not define that symbol. Both prior and reviewed
sources were preprocessed independently with `cpp -P -undef -nostdinc -x c -`,
once without additional definitions and once with the existing
`-DCYBER_BOUNDED_CROSSFADE` ANGLE variant. **The resulting complete ordinary
programmes are byte-identical in both cases**, which is stronger than token
equivalence. The [machine-readable proof](objectshard-m4-reliability-20261128/ordinary-shader-equivalence.json)
records commands, source pins, byte counts and the local preprocessor identity.

| Ordinary variant | Preprocessed bytes | Identical output SHA-256 |
| --- | ---: | --- |
| Default | 108,785 | `b9e1cddade070486305946e961e1c9b116af505904633f682d43928492ff4d45` |
| Existing bounded crossfade | 108,826 | `6c761f1be356c3aceeede2db219d8c46e8ece05a0c6e62d4a129a7ed2309146d` |

For independent reproduction, read the protected file at both source commits,
normalize CRLF to LF, run each command with those bytes on standard input and
compare complete standard output. No shader source edits or baseline refresh
are part of this check. The source uses only the two named conditional symbols;
the existing Godot compiler guards and actual renderer tests independently
exercise the engine's shader compiler.

## ObjectShard-only behaviour and execution evidence

The structural overlay explicitly prefixes `CYBER_OBJECT_SHARD`. This variant
uses local RG8 carrier storage, captured material coordinates, the same ordinary
material lookup/program and finish functions, transparent Empty carriers and
bounded neighbor reads. Ordinary ambient, actor decorations and temporal
old-pose blending remain with their existing presentation owner. Fragment
recropping and rotation preserve the captured finish phase.

[Run 46091912379](https://github.com/techrote/cybersand/actions/runs/46091912379)
at source `60a71358de549877d65d0bcac08ef6e8bb1573c0` passed actual Linux OpenGL
and Windows ANGLE framebuffer comparison: 19 material/view checks, 11 texture
incarnation checks and the existing 27 shader guards per platform.

The expanded renderer jobs in
[run 46094371247](https://github.com/techrote/cybersand/actions/runs/46094371247)
at `0acc8a8b82b0fbaf14631277c309943988410062` also passed both platforms:
28 material/view/fragment-recrop checks, 11 texture checks and 27 shader guards.
The protected shader bytes are unchanged between these two sources. These
renderer fixtures supply synthetic immutable carrier inputs and retain actual
framebuffers; they do not qualify changed native code or physical owner speed.

The first combined campaign's sanitizer job correctly stopped before native
execution because this source transition had not yet been registered. That
failure remains part of the evidence. Adding this reviewed entry permits the
unchanged guard to authenticate the exact shader source; the subsequent
source-bound native campaign must still run and pass its original gates.

The expanded Windows software ANGLE fixture measured 44.710 seconds for the
ordinary first capture and 38.808 seconds for the detached first capture. These
separate elapsed intervals include first-use compilation, frame wait, readback
and PNG I/O. They expose a cold first-use risk, not a steady-state cost or a
physical TITAN RTX result. Admission-time preparation and final evaluator
qualification are tracked in the presentation delivery record.
