# SWARM-004/005 Windows r1 startup diagnosis

Run **44947666723**, attempt **1**, investigated 2026-11-21. This report reads the retained Windows source and extracted-package evidence; it is not a new Windows execution or an acceptance result.

## Finding

The package fails the unchanged 60-second ordinary Shared Workbench startup check before reciprocal-panel creation or generator execution. The retained evidence strongly supports a cold software-ANGLE palette-compilation stall in the first graphical frame. No package source/runtime divergence or Workbench transaction deadlock was demonstrated. No repository source, production defaults, or timeout was changed during this investigation.

The timeout image shows the ordinary Workbench in “Preparing”. All five failed package modes record process frame 1 / physics frame 16, pending Workbench serial 1, no owner/worker/frame error, and an idle worker whose generation/revision have advanced. The Main owner consumes the installation publication in its next `_process`; the stalled first render prevents that next frame from arriving inside the bound. This explains the observed pending state without establishing a native deadlock.

## Exact identity comparison

| Field | Source and package value | Match |
|---|---|---|
| source_commit | `9b688aed1f06f031f983c27f50d1f17821446e43` | True |
| source_tree | `5d048be7dc3248dd2e0ecd8e13ac1eca7c8b7a77` | True |
| godot_sha256 | `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c` | True |
| godot_version | `4.7.stable.official.5b4e0cb0f` | True |
| native_adapter_sha256 | `84f08979546f1d250fa7f2e4a94617bee060eb4ce1bb6e2997134ea2a366d2d7` | True |
| runtime_manifest_sha256 | `7a0b0ff8050d23429ffb06d49bef81f1e49fa9a4095601a53e3a8f39035e2868` | True |
| platform | `windows` | True |
| graphical_required | `True` | True |

Both commands use `--rendering-method gl_compatibility --max-fps 60 --rendering-driver opengl3_angle`. Both logs identify ANGLE 2.1.1 / Microsoft Basic Render Driver / D3D11-10.0.20348.5756. The package additionally places the attested VS2022 release `vcruntime140.dll` beside its engine. No separate ANGLE or D3D compiler DLL is bundled. The two jobs ran on different hosted runners; live compiler-module and CPU provenance were not retained.

| r1 source file | SHA-256 | Still identical in current worktree |
|---|---|---|
| `godot/shaders/material_palette.gdshader` | `f686ca416b5b011751ddd5d38a24824742d01cb8d489b46710ee1f1fbb2a09c1` | True |
| `godot/scripts/palette_shader_selector.gd` | `31785f54212aa743e4cae521907355a3780c4c2e9cc40f6e36aa8bc9f5974eb4` | True |
| `godot/scripts/main.gd` | `347a8d11e5ea4db717945b6077cfba35c068191d0138cc006e6a1dba0a1d2ec5` | True |
| `godot/tests/swarm45_reciprocal_ui.gd` | `6b56a28b7105ef32b4d6b4b8531cb7244adec051e267cba8141b8f64ba2834f7` | True |

## Observed startup times

Seconds from scene construction through startup outcome; the fixture retains its exact 60-second polling deadline after construction. A blocking first frame can overrun that wall clock before the fixture resumes to record failure.

| Case | Source cold | Package cold | Source same-profile reopen |
|---|---:|---:|---:|
| transaction | 42.577 | 86.946 | 5.675 |
| reciprocal | 42.977 | 77.189 | 6.115 |
| swarm005_irregular | 43.650 | 73.246 | 6.106 |
| swarm005_viaduct | 44.249 | 66.589 | — |
| lifecycle | 43.979 | 69.949 | — |

All 14 Windows source child processes passed; that job subsequently failed its source-custody check because editor import generated untracked UID files. The package passed its six headless processes, then failed all five initial graphical modes; no fresh reopen was admitted after those failures. The independent source-staging repair is owned separately.

## Responsible shader and cache evidence

All **34 initial shader-cache files** are identical by full relative path, byte count, and SHA-256 between source and package. Source has one additional later cache, `EGL/4MbNHWfzdlioeepVxeyQ5LuKzUE=.cache`; the package has no unmatched cache.

The delayed 748,248-byte canvas cache is `CanvasShaderGLES3/45a350cecb283a355d1d98b87c8c00898257a32d8feff3fc4939e86531e3f851/7fc0f7e5f39495b3057991721a729796679c3b84.cache`. Its cached ANGLE HLSL identifies the production material palette. The 178,895-byte extracted HLSL has SHA-256 `8b3d23272dd6ad2e5e88ce12b3ae54805e73db3e3e63c90231138a460bf916e3`; it contains one `material_colour` definition and one call, with the previous snapshot using `material_base_colour`. The existing bounded-crossfade selector is functioning; this is not an accidental full-crossfade selection.

ZIP timestamps bracket a **36-second source gap** (20:49:08 → 20:49:44 UTC) and a **78-second package gap** (20:50:02 → 20:51:20 UTC) before the identical palette cache appears. These are cache-write intervals, **not compiler-only measurements**. The cold/warm difference, first-frame state, and identical compiled outputs support cold shader compilation as the dominant cause. They do not prove which host CPU, compiler module, or scheduling factor caused the speed difference.

### Complete matching cache inventory

Paths are relative to `profile/roaming/Godot/app_userdata/Cyber Sand Reference Sandbox/shader_cache/`. Every row was compared in both retained transaction profiles and matches.

| Relative path | Bytes | SHA-256 in both |
|---|---:|---|
| `CanvasShaderGLES3/45a350cecb283a355d1d98b87c8c00898257a32d8feff3fc4939e86531e3f851/104b6b2525291e2d53908134c06b63b1ff731d31.cache` | 32527 | `6a7ceee8740c1b778ac67cea010ad2389f003fbb2c0070f5389c402f82b25ff8` |
| `CanvasShaderGLES3/45a350cecb283a355d1d98b87c8c00898257a32d8feff3fc4939e86531e3f851/7fc0f7e5f39495b3057991721a729796679c3b84.cache` | 748248 | `ed3ecbf751186cd13a34bec2ad19a11571384cb0b4c45dac4978ec46447e4a08` |
| `CanvasShaderGLES3/45a350cecb283a355d1d98b87c8c00898257a32d8feff3fc4939e86531e3f851/981e273b7e9094f670bbf61ef628c92057e9d77a.cache` | 28607 | `d330285ddb42a0b1d1d45fc6bf78cdeb97d7a2f7fd762abc83ec40eb199be24c` |
| `CanvasShaderGLES3/45a350cecb283a355d1d98b87c8c00898257a32d8feff3fc4939e86531e3f851/b7bf26eb787d221ffda92ad4ca9427812ee879e2.cache` | 101338 | `c2df6df3ba544440201bf54c8c9a74181f71b608ffa65b85c06b6c80844bbf9c` |
| `CanvasShaderGLES3/45a350cecb283a355d1d98b87c8c00898257a32d8feff3fc4939e86531e3f851/fa7b62523470356194bdf709eb2639ab149a07cc.cache` | 52504 | `4ebd23815333a80a4fbb3b925e6c263aa2d4d357bbef307a14c9a508c01fa119` |
| `CopyShaderGLES3/4fc88d68897a50a9605acc30479eff94f46250a44a55c8cc0df5a9854fcf0455/fa7b62523470356194bdf709eb2639ab149a07cc.cache` | 118729 | `2cd514a26d494c7c4be19b030729e622737444656aacb5aabc99874ae6890d6d` |
| `EGL/1R0mNmMTpC_pHlumlFaApF+5mr8=.cache` | 43655 | `86f4f670d7be0a908b4bde90426181c22cff7dc499e35cb9fc6f299ed296cdd7` |
| `EGL/1z6eBJGw1w0koU1AhU41AhX3d3U=.cache` | 2462 | `31ea48b2d9ca7c2da94ba1f349a4cda6a5a661adc250e18a5c23ec3a219c49d5` |
| `EGL/7n0NdjMApmAO34d5Y+cKU+NzV6I=.cache` | 6649 | `c78e5d1414f5b69156cd296ea4a1dc9027bc31f464038b0b791a12aecaf08d7c` |
| `EGL/8POlCCNihhOG0pwjpMCYhTjFGRw=.cache` | 43243 | `fc1bf88a79dc2789dada8808bb69678284d20e46b2f1a6bade28cce78eeff5ef` |
| `EGL/9c5LmMURzNsNhL0E4mbg6MQcbJM=.cache` | 6455 | `32a8f42ab5c9bc5de8843a315b906602fb7391bdb3585b3087f40b872fc1acd5` |
| `EGL/AV42Cz3Jv8pmrGkLKHBTEzq1oIE=.cache` | 1535 | `09a132a4ec21ab1dd24975536e34d397a97908c317a4d3b702d0f3f1e106dcf7` |
| `EGL/Db7uIBwGDTjnswkle7esOpDKlTw=.cache` | 7720 | `88051f24e5afbd76cdc7a063a60f1edf595520aa1bba1ca859694a237f495132` |
| `EGL/DjN+1Ql6of6eqrdfKFv1eq5laFE=.cache` | 4273 | `76df2b307e1da3dc6877fe51e188b753a9db2f44ed9749d834956a6a891a1cde` |
| `EGL/E0KSKi78b5Lq4jTAM30tyC3v9nE=.cache` | 2184 | `4b8a08761e6fc802801960d4ab11602671184d6bb537f9250fa748bdc04aa50a` |
| `EGL/FIjN_V8jvYzipsNuan74x+vfrDc=.cache` | 2966 | `38d6fd85759509e9679aedc40268946b104875c90d33985e23297e5cabac2d43` |
| `EGL/MH3eSdY26FHj3u4LU2OJnIhT7Lc=.cache` | 2478 | `c654a75de5130124e5db013a620cd5513c912f0ffb62b2c3acfe6bffcefee32d` |
| `EGL/MoAiqGJIb4D1lUIVFO5DlcuG1ic=.cache` | 5809 | `093c5afc139155cda21013b54f63c7ba82918bb2330f3840bf156fbf3750cfe0` |
| `EGL/U0tW8ZPkTGFauMNexgIPR70NUhY=.cache` | 2512 | `0bed27f04678803eed24af4c7e916470847e310043f41d50c0e48bdc727d943f` |
| `EGL/U3KEKDjjvjt6ETOKMx6qhlgJbQ4=.cache` | 5974 | `0a970bbfe20eaa5bf51a4c2d59218143bfd1066d26c6065be1e3449c7408fc5e` |
| `EGL/XMtc58mFGPwjBYjTZQacr3jUKF0=.cache` | 2385 | `b55c050b2125912e0376438de48d4cadfdd31d151e055a0733470731d58f14d7` |
| `EGL/Yy1sTWPHZbzU6bvFLvbYgdwghgw=.cache` | 2024 | `947101bc3ba96531a2fc4a9280207a0802cc5d2232eb847b0b52a107bfa2ee94` |
| `EGL/aNmrpbTuPF3F5qSapOpPbFti_k0=.cache` | 2855 | `5e6c814b296b3728dea8ef0ed307d6e20d5de91d85f1a2bf6461f3c4a1afbd93` |
| `EGL/buqQ5O7H9iOawbE5dH8c+klXvkU=.cache` | 2237 | `5e44fbe93e99a1361309effc17c7ec456998e3f32a7bf5eb66f4439568df89e7` |
| `EGL/hba7AO6A6C4hIjgru88INIHWSss=.cache` | 2032 | `ac79720c160126bac23a6c0391bb46c593af53af4fe4cd4f8dcd832b1f77f20b` |
| `EGL/lFlBkVf_QpyRTxNLno_WJhB9Z+Q=.cache` | 2147 | `6ced6159728b8a509f727a0fb5ebdbaecf3b1930a72b68a2175d3a72b86f187d` |
| `EGL/t+gTItMgqjooVhk87t7IStaa6U0=.cache` | 116239 | `bd7178611927ce4d7e3aa9e81d4dd722f94ff72e1d9deba8a88bac330dca0611` |
| `EGL/t5YLeacnlqeywXGhIha7eOT9+3s=.cache` | 2381 | `a8e13531e86e923b7b8959eaf6beb5cb806178ad807283f29ea6fe99dc9f5134` |
| `EGL/uDZjmHY6+fJux3gv94RLMj1ysus=.cache` | 5450 | `0a74b3cd86310a3068939e996cfecf7812f6d840ba4719e08de702bebcfac6f6` |
| `EGL/uKH3fe6N6dh4obNDBYCVq_ZPFH0=.cache` | 14538 | `09d42c4461eea2616955a224fbab94257545aeb48d20a5f35929f5bec8473434` |
| `EGL/vSwwrZdiEYS3M0lb4kgqgSDtwB4=.cache` | 1865 | `29db1da32bfdb787cfd1195379e86f1d9d6140cbc01f1e14f435b74ccef08eac` |
| `FeedShaderGLES3/f321a92fe6ec82f8f68d477f1368525d75c46087ded233638400be69485ad209/fa7b62523470356194bdf709eb2639ab149a07cc.cache` | 7872 | `fd63caff637cb139af623dcfb31d4b0dbdb632c4bca18aa1daeb4406a0051d5d` |
| `PostShaderGLES3/4d94a75ab9f2c65a94e886b37bb4d80083b6e77174747cbec9e675287a8d138d/fa7b62523470356194bdf709eb2639ab149a07cc.cache` | 15572 | `77331d215e201ccc865cd79c171224f5ba0391b6ef1191da7f1b3114d6fc72e2` |
| `SceneShaderGLES3/5bdf157992731b4951a3584a99bba7eefedd313e8cebca30d4214abea4d961ae/fa7b62523470356194bdf709eb2639ab149a07cc.cache` | 729768 | `2df79cd270b77cb60a322b2c5b7f795d651ba3014265563e6b2d25186188862f` |

## Evidence custody and next step

| Retained archive | SHA-256 |
|---|---|
| Windows source evidence | `51924dc6499920be937f9872eddb9e9399687df212fedfa5b8d7562e2d4dbc15` |
| Windows package evidence | `06133cd7740c70a3ee96362e4d7ad0752c8b5801e4d6966fa6b37d2be2174cb4` |

Keep r1 as a failed package qualification and keep the 60-second startup bound. Run the already-required exact-source r2 rebuild/gates once for the independently required ABI, isolated staging, and accepted-main reconciliation changes. If the graphical startup failure recurs, stop retries and run a bounded same-host cold/warm diagnostic with actual engine placement and live compiler-module provenance. Do not prewarm isolated qualification profiles, bypass presentation, change defaults, or refactor the shader without separate evidence and review.

The companion `windows-r1-startup-diagnosis.json` retains the full per-case startup diagnostics and comparison records. No remote action was taken by this investigator.
