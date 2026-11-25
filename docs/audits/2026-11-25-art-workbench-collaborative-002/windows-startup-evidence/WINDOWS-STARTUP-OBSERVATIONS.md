# Windows startup: render interval and profile-cache evidence

**Decision: preserve the qualified Art application and hand the localized
rendering finding to the rendering programme. No production startup fix is
claimed.** The final Art package is still application
`bcc92927ce3894a16d5544923cfbf7b1d0339fda`, tree
`517164084860a19f18b36cb94f77597eb3220578`.

The older qualified baseline e536 recorded a 51.259956-second maximum startup
frame gap in its pristine Windows launcher. The final bcc pristine launcher
recorded 34.966643 seconds. Those different hosted runs are not a controlled
source comparison. Both retain a substantial first-launch limit.

## Independent diagnostic boundary

[Draft PR #782](https://github.com/techrote/cybersand/pull/782) contains exactly
four apparatus files over bcc. All application scripts and native/runtime inputs
remain byte-identical to bcc. The runner enforces that complete difference set,
clean source before and after each arm, both official Godot 4.7 executable hashes
and the native/Rapier DLL hashes from bcc's LFS pointers.

The apparatus loads ordinary `main.tscn`, observes actual native Workbench
installation, opens ordinary Art and captures three bounded native regions.
Every arm passed 27 checks with no provider request, no model inference and
unchanged native source identity across read-only capture. It changes no worker
policy, production shader or renderer scheduling. The diagnostic clock begins
at its SceneTree initialization, after engine bootstrap; it is not an OS process
creation clock.

## Four original fresh-profile observations

Source `8ce9bbd780df7ac1a82caf1ae1598fed27371138`, tree
`e7a3557e2983bb596fabe3f226e3939baf353a47`,
[run 45549435385](https://github.com/techrote/cybersand/actions/runs/45549435385).

The host was Windows Server 2022 image `20261116.370.1`, AMD EPYC 9V74 with two
exposed physical cores/four logical processors, 16,771,836 KiB visible memory,
and Microsoft software rendering through ANGLE. Each arm used a fresh profile.

| Arm | Main resource load | Synchronous ready | Remaining installation wall time | Workbench ready | Maximum observed gap | Open Art |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Graphical first | 1.489 s | 1.161 s | 39.948 s | 42.631 s | 39.130 s | 115.148 ms |
| Graphical repeat | 1.497 s | 1.137 s | 36.314 s | 38.979 s | 35.501 s | 122.329 ms |
| Graphical after explicit import | 1.509 s | 1.136 s | 37.485 s | 40.161 s | 36.697 s | 115.013 ms |
| Headless control | 1.498 s | 1.059 s | 0.929 s | 3.511 s | 2.690 s | 69.720 ms |

The remaining-installation column includes main-loop and rendering work while
the fixture waits for native installation to be consumed. It is not a native
worker CPU measurement. Project-cache reuse and explicit import did not remove
the large displayed gap in these observations. Original profiles showed that
the runtime shader cache lives under the user profile, outside the project's
`.godot` directory; fresh profiles therefore did not reuse that cache.

Complete original measurements, logs and audits are in
[original-measurements.zip](original-measurements.zip), with the
[manifest](original-measurements-manifest.json) and
[four-arm derived index](four-arm-summary.json). Only reproducible shader and
editor-documentation cache binaries were omitted from that small durable archive;
their original hashes are preserved separately. The complete original
[artifact 14993266843](https://github.com/techrote/cybersand/actions/runs/45549435385/artifacts/14993266843)
is 4,981,131 bytes, SHA-256
`c79ffd7960cb02c66d66e1e09d3c6fc167aa288d101b748771b5af2def7ffe1f`.

## Follow-up: actual render interval and owned profile reuse

Source `60a0db0206a6e7ef24b97d44e7cc1db60918dbca`, tree
`f52fd14241738ec20bba1ea5590e9a888c5ee785`,
[run 45550363681](https://github.com/techrote/cybersand/actions/runs/45550363681).

This host had an Intel Xeon Platinum 8573C, two exposed physical cores/four
logical processors, the same Windows image and visible memory, and Microsoft
software rendering. It was a different allocation from the AMD experiment.

The fixture records bounded `frame_pre_draw`/`frame_post_draw` intervals. A second
process explicitly reuses only its passed same-source sibling arm's generated
profile. The runner refuses arbitrary, failed or different-source profile reuse.
The original 34 shader-cache file identities after the first arm exactly match
the second arm's recorded input cache. All three bounded context digests match
across all arms, and every native capture preserves its actual source identity.

| Arm | Workbench ready | First render interval | Largest render interval | Maximum observed main-loop gap |
| --- | ---: | ---: | ---: | ---: |
| Fresh graphical profile | 52.114 s | **47.889 s** | 47.889 s | 47.892 s |
| Reused generated profile | **4.728 s** | 0.207 s | 0.882 s | 3.197 s |
| Fresh headless control | 4.028 s | Not applicable | Not applicable | 3.134 s |

The first fresh-profile draw begins 3.240 seconds after the fixture's clock and
ends at 51.129 seconds. The observed first-frame gap therefore lies almost
entirely between the engine's render signals. That is a direct localization of
this observed stall; it does not measure only GPU execution or identify a
particular shader-compiler function.

The fixed-order repeated-process result is consistent with a large runtime
rendering/profile-cache setup cost. It reuses the whole generated profile, not
only shader bytes, and does not control OS caches or host contention. Thus it
does not isolate the causal contribution of one cache file. The reused-profile
arm still has an 882 ms render interval and seconds of initial resource/setup
work. It does not establish smooth physical-hardware startup or playability.

## Resulting engineering choice

Do not import unfinished PUBPRES scheduling work or ship a driver-specific cache
as a universal performance repair. Keep Art's independently qualified transport,
context-scan and Conversation Apply improvements. Their controlled measurements
address different boundaries and remain valid within their stated scope.

Give the rendering owner the original render intervals, hardware/cache records
and exact apparatus source. A later rendering change should compare actual
first-launch and repeated-launch behavior on the same hardware and preserve
native publication, physical simulation and source custody. The original
Windows/NVIDIA absent-listener Send→ordinary Art X/Hide case remains a separate
owner acceptance item; this startup experiment neither reproduces nor closes it.

The follow-up's complete measurement archive is
[render-profile-measurements.zip](render-profile-measurements.zip), with its
[manifest](render-profile-manifest.json) and
[derived comparison](render-profile-summary.json). All original measurement
records, logs and audits are retained; only reproducible shader-cache binaries
are omitted from that compact archive. The complete original
[artifact 14993970171](https://github.com/techrote/cybersand/actions/runs/45550363681/artifacts/14993970171)
is 619,916 bytes, SHA-256
`8515813ed298f3d1aa5eba9c4eea7456e36af6b96eeb86307495d63b9ebfaf4d`.
No principal application, evaluator payload or other programme's branch was
changed by either diagnostic campaign.
