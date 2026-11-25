# Windows startup phase observation — Draft/HOLD

This separate diagnostic measures the remaining hosted Windows startup delay. It
does not change the Art application, native scheduling, worker policy or the
principal evaluator source. It is not physical Windows/NVIDIA owner acceptance.

## Source boundary

Application source: `bcc92927ce3894a16d5544923cfbf7b1d0339fda`.
Application tree: `517164084860a19f18b36cb94f77597eb3220578`.

The diagnostic branch must differ from that application by exactly four files:
the external read-only GDScript fixture, its Windows Python runner, this record
and the narrow GitHub-hosted Windows workflow. The runner enforces this set and
clean source before and after every arm. Native and Rapier DLL bytes must match
the application's committed LFS identities. Both executable components of the
pinned official Godot 4.7 Windows distribution are authenticated independently.
No application file or runtime payload is replaced by the apparatus.

The fixture is adapted from the earlier Linux phase apparatus at
`a895e622072b88ab59dbef1db5a473dfc950bd85`. It loads ordinary `main.tscn`, waits for
the actual native Workbench, opens ordinary Art and obtains three real bounded
native captures. It asserts no provider dispatch and no native source revision
change during those captures. Complete bounded context construction uses the
application's actual context implementation. It performs no model inference.

## Why this observation is needed

The independently verified pristine extracted Windows evaluator at application
source `e536d128f85e948223b25e13931a7a801faf956d`, campaign `45541065622`, recorded
56.265125 seconds to readiness and a 51.259956-second maximum startup frame gap.
Its hosted Microsoft software-rendering environment is not the owner's NVIDIA
machine. Earlier Linux observations were about five seconds and do not explain
the Windows gap. No cold-start fix is claimed here.

## Four consecutive arms

| Arm | Project cache at entry | User profile | Rendering |
| --- | --- | --- | --- |
| graphical-first | Fresh checkout; no explicit editor import | Fresh | OpenGL compatibility with ANGLE |
| graphical-repeat | Retains the preceding arm's project cache | Fresh | OpenGL compatibility with ANGLE |
| graphical-after-import | Explicit headless editor import first | Fresh | OpenGL compatibility with ANGLE |
| headless-after-graphical | Retains the preceding project cache | Fresh | Headless control |

The OS page cache is neither cleared nor controlled. These are fresh-process
observations in a fixed order, not a randomized cold-cache causal benchmark.
Every arm records cache inventories and SHA-256 values before and after use,
the actual runner image, CPU, available memory, video adapter and driver, exact
source and runtime identities, original stdout and complete fixture result.
Failed arms remain evidence and do not prevent collection of subsequent arms.

## Phase interpretation

The fixture separately times scene resource loading, scene instantiation,
synchronous `_ready`, the remaining native World installation wait, total
Workbench readiness, the next completed graphical draw, opening Art, the next
frame, loading the context script and each native capture/context build. The
first completed draw measurement starts after World readiness; it must not be
described as the entire renderer initialization cost. The fixture also records
its maximum observed main-loop gap, viewport dimensions and configured worker
setting without modifying them.

Each process has a finite 240-second allowance. A timeout terminates only that
owned console process and its child tree, and records the cleanup output.
Source admission errors and original failed processes are not replaced with
successful synthetic timings. The diagnostic does not package a Windows
evaluator, authorize a new production default or supersede the principal
Art campaign. Results must name their source and cache arm when cited.

## Follow-up after the first four observations

The first diagnostic source `8ce9bbd780df7ac1a82caf1ae1598fed27371138` completed
all four original arms with 27 checks each in
[campaign 45549435385](https://github.com/techrote/cybersand/actions/runs/45549435385).
Artifact `14993266843` is 4,981,131 bytes with SHA-256
`c79ffd7960cb02c66d66e1e09d3c6fc167aa288d101b748771b5af2def7ffe1f`.
The actual host reports Windows Server 2022 image `20261116.370.1`, AMD EPYC 9V74,
two exposed physical cores/four logical processors, 16,771,836 KiB visible memory,
and a Microsoft software-rendering adapter. Source loading was about 1.5 seconds
in all four arms. Graphical readiness was 42.631, 38.979 and 40.161 seconds, versus
3.511 seconds headless. Graphical maximum gaps were 39.130, 35.501 and 36.697
seconds. Opening Art itself took 115–122 ms graphically. These original timings
remain retained and do not establish a native worker cause.

Every original graphical arm had a fresh user profile. The artifact shows that
Godot's shader cache lives in that profile, outside the project's `.godot`
directory. Consequently the original project-cache repeat and editor-import
arms did not test a warmed runtime shader cache.

The follow-up adds bounded `frame_pre_draw`/`frame_post_draw` timestamps and
read-only startup-frame observations. Its three arms are a fresh graphical
profile, a second process explicitly reusing only the preceding passed arm's
owned profile, and a fresh headless control. Profile reuse refuses a failed,
different-source or non-sibling arm. Shader-cache file hashes are recorded before
and after each arm. No user profile, private provider configuration, production
shader or World scheduling policy is modified by this apparatus.

The draw interval includes the work between the engine's two render signals;
it is not a GPU-only measurement and cannot by itself name a shader compiler
or driver function. The fixed-order profile comparison can test whether this
observed cost persists with that owned cache, while OS cache and host contention
remain uncontrolled. These diagnostic arms neither change nor qualify the
principal evaluator.
