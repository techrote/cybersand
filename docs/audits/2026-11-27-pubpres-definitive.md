# PUBPRES on consolidated Workbench

[Draft PR 767](https://github.com/techrote/cybersand/pull/767) joins accepted main
`7a15691a7c537d07ff10a1bc4da9d46491c0b9d6` and recovered PUBPRES
`ce4f40c8be234617fa3c33957bc423bd5ca7b54f` at
`13c0b731b0659d4a8bd00cbd5d85e5e5b66fc72b`. The accepted main commit is the
fixed comparison source for this campaign. Physical owner acceptance is on hold.

## Protected World source transition

The LF SHA-256 of [world.cpp](../../native/src/world.cpp) changed from
`98254d531ca7ca8f8e76f6d963f15b26b772777dc5633718a92cc637217eb77c`
to `fd7079d6cf4798275280eeb99ed996258482327c4bfeae64a2efb02655daac3e`.
Review `git diff 7a15691a 13c0b731 -- native/src/world.cpp`. The file imports
the recovered persistent worker pool, passes its constructor the immutable
World selector, and exposes its completion counters. The material laws and
Material Audition owner calls in this file match accepted main. Wave's
occupied-mask optimization is separately implemented in `world_wave.inc`.

The evaluation selects all-worker completion. The [eight-arm native result](2026-11-26-pubpres-closure/qualification/native-abba-independent-55dea.md)
records why the alternative was rejected. The closure checks the bytes of
every native input and separately checks the generated godot-cpp dependency.
At the join, N and C share 104 native files byte for byte. Five differ, and C
adds `persistent_worker_pool.hpp`.

## Presentation and input

Grab and Place now resolve the pointer through the submitted camera and pick
the displayed physical member in draw order. A live grab revalidates the
session, epoch, actor, part and body identity before applying force at that
member's local anchor. The tests exercise a new Sand upload before a draw and
retired or withheld members. The multipart tests use the authored logical
capacity and the actual maximum physical roster for their respective bounds.
