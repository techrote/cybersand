# Independent font engine source and comparison review

**Draft / HOLD.** The repaired engine is a new candidate with pending actual
execution. Earlier failures and Safe controls remain retained evidence.

## Source and patch custody

Specialist C independently retrieved the two upstream text-server files at
Godot commit `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` through the primary
GitHub repository API, then computed SHA-256 over the returned UTF-8 bytes.
The independent hash implementation was checked with the standard `abc`
SHA-256 vector before hashing either file.

| Pinned source | Bytes | Upstream SHA-256 | Patched SHA-256 |
| --- | ---: | --- | --- |
| [TextServerAdvanced](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/modules/text_server_adv/text_server_adv.cpp) | 310597 | `f156a5b0100ab39d588a3abc09a013c468b49dbff0ed085b7cb9c2a3e577cfcf` | `12e8c7e36b6845a82cc2db5a514b7b97e051c23f6783c560bf2a3fe15caa9a5b` |
| [TextServerFallback](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/modules/text_server_fb/text_server_fb.cpp) | 183877 | `b1a6a009a89007bcbf48f3c70a8a02da037e9aef6d9cf9fa22b9f003c756a6d7` | `637d19f1e4cd55a0f3b10fa307646dc2d72d0a637de827d8be86e6d4132c35a1` |

Applying the exact font patch with `git apply --check` and `git apply`
reproduced both declared after hashes. The patch SHA-256 is
`49f06da6478582499adf5f466daec1d20981c5facbd2ef5a0acfa61cc6f788a6`.
Each server contains five guards covering five texture creation sites and
four update calls. The guard copies the mutable font cache `Image` object only
when the selected publication image is that cache object. Existing private
mipmap images remain private without an extra duplicate. Guards follow the
existing alpha-edge and mipmap processing. The patch does not alter those
pixel rules, material publication or Main/render synchronization.

The four engine derivation/tamper methods passed independently. The builder is
an exact derived form of the retained builder with separate input admission,
lock selection and proof recording. Original source-delta, dependency,
compiler, public API and payload gates remain intact. This source review does
not establish runtime correctness or a performance gain.

## Prospective same-engine comparison

`font_renderer_registration.json` declares a new Safe/Separate/Separate/Safe
cohort. One actual repaired GUI executable, exact current application and
independently built native/Rapier runtime are required in every arm. External
engine build source/run/attempt/proof identity is mandatory. The timed driver
independently replays all four font arms and both ordinary paused startup arms
before accepting that engine, then requires both owners to pass the complete
two-slot 180-admission GPU history oracle. Missing or failed prerequisites
produce no timing credit.

The two primary workload cases retain their original real-step windows and
all frozen physical gates, with only the explicitly registered actual render
owner predicate derived. Full two-slot publication, Early physics, coherent
presentation and same-frame continuation off stay fixed. A small inherited
observer additionally proves the actual material-deadline policy is off, so
the separate deadline treatment cannot contaminate this comparison. Optional
submitted geometry and external CPU observations use the same explicit state
throughout all four arms. Separate notification clocks stay unassociated with
material serials and cannot become display or GPU completion evidence.

Old #609 Separate startup crashes and its eight completed Safe captures remain
unchanged. Stock-versus-custom comparisons are whole-engine bundle comparisons;
different build/toolchain details prevent attribution to this one patch.
The new same-executable pair can isolate render ownership after qualification.
It cannot establish physical NVIDIA acceptance.
