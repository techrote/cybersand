# Signed RefCounted ObjectID correction and unchanged-receipt replay

[First successor run 45430704276](https://github.com/techrote/cybersand/actions/runs/45430704276)
at `b21dca8fd6bd30bed9c19ce84601f85050405bed` remains **failed**. Linux and
Windows completed the GPU fixture's 180 current and 180 previous first-read
checks, but the independent Python oracle rejected its texture ObjectIDs as
nonpositive. This was a measurement representation error, not a GPU-history
failure or a justified reason to discard the original run.

The pinned [Godot 4.7 ObjectID definition](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/core/object/object_id.h)
stores a `uint64_t`, reserves bit 63 for RefCounted, defines validity as nonzero,
and exposes an `int64_t` conversion. The pinned
[godot-cpp ObjectID definition](https://github.com/godotengine/godot-cpp/blob/101ae38034304346a46ea9ea84ae156d3e860496/include/godot_cpp/core/object_id.hpp)
has the same representation. ImageTexture inherits RefCounted, so serializing
its ObjectID through the publisher's `PackedInt64Array` legitimately yields
negative signed values. Windows' first observed IDs were
`[-9223371955351058792, -9223371955317504358, -9223371955283949924]`.

`identity_domains.py` now accepts precisely nonzero signed 64-bit ObjectID
representations and keeps a separate positive signed 64-bit texture RID check.
Both `qualification_oracles.py` and `metrics.py` use those explicit domains.
Zero, integer overflow, booleans, floats, aliases and owner replacement remain
rejected. Negative RIDs are not treated as RefCounted IDs. All fixed-resource,
slot-role, allocation, source, engine, exact-byte and history-order gates remain.

The original Linux and Windows transition receipts were replayed without
modification against their exact committed fixture/Main/publisher/policy/shader
bytes and the original engine pins. Both now pass all **35 independently
reconstructed hashes and 180 exact slot admissions**. Original receipt hashes
were checked before and after replay:

| Platform | Original receipt SHA-256 | Corrected independent replay |
| --- | --- | --- |
| Linux | `9638168dbf92a6ee55c72f36646d78f73fcba60ec0e5a3c0914ed851fd842240` | Pass |
| Windows | `9d37f7cef8d40d87302e812349e01d4d4479375db30d555aecc9ffcf6fa68c85` | Pass |

[`object-id-replay.json`](object-id-replay.json) binds the original artifact
download verification, original driver/source/tree, exact engine and receipt
hashes, unchanged source-input hashes, and corrected reducer bytes. The narrow
Python suite passes 17 tests, including acceptance of the actual negative IDs
and semantic rejection controls in both consumers. No native runtime, GPU
fixture, original artifact, historical workflow result, or physical completion
event was changed. This replay establishes those material-history checks;
performance and physical Windows/NVIDIA acceptance remain separate and HOLD.
