# Independent AMBIENT-002 physical readback

Source `83a3db6ffb207761df999abedac77eb1401604a8`: 194 actual actor episodes in 122 fresh World clusters; 16 actors are auxiliary companions.

Independently checked 2910 reduced metric values and 67200 copied peer samples against the original raw trajectories.

## Matched seed differences

Values are median paired stateful-minus-comparator differences across the three declared seeds. They are descriptive differences, not significance tests.

| Rig | Comparator | Stable bins | X range | Net movement | Selection-label changes | Active stall fraction |
|---|---|---:|---:|---:|---:|---:|
| 4ly_trainer | coarse_only | +0.000 | -2.297 | -0.799 | +0.000 | +0.004 |
| 4ly_trainer | legacy | +5.000 | +38.819 | +6.920 | -1.000 | -0.025 |
| 4ly_trainer | no_memory | -1.000 | -4.420 | -6.489 | +0.000 | +0.000 |
| 4ly_trainer | no_traits | -1.000 | -16.728 | -16.900 | -1.000 | +0.007 |
| 4ly_trainer | random | +11.000 | +28.640 | +10.204 | +9.000 | -0.061 |
| 4ly_trainer | random_hold | -3.000 | -16.169 | +11.822 | +9.000 | -0.011 |
| 4ly_trainer | scripted | +11.000 | +13.898 | +12.360 | +9.000 | -0.019 |
| monowheel | coarse_only | +0.000 | -5.199 | -23.240 | -8.000 | -0.072 |
| monowheel | legacy | +0.000 | +3.550 | -29.506 | +0.000 | +0.150 |
| monowheel | no_memory | +0.000 | -4.271 | -16.101 | +0.000 | -0.055 |
| monowheel | no_traits | +0.000 | -3.108 | -18.284 | -1.000 | +0.164 |
| monowheel | random | +1.000 | +16.988 | -1.021 | +10.000 | +0.147 |
| monowheel | random_hold | -2.000 | -24.889 | -8.180 | +10.000 | +0.266 |
| monowheel | scripted | -2.000 | -34.277 | -7.475 | +10.000 | +0.371 |
| runner | coarse_only | +0.000 | -15.795 | -5.310 | +6.000 | +0.014 |
| runner | legacy | +0.000 | -3.672 | +11.370 | +14.000 | +0.224 |
| runner | no_memory | +0.000 | -12.145 | -9.197 | +14.000 | +0.013 |
| runner | no_traits | +0.000 | -0.241 | +0.477 | +2.000 | +0.118 |
| runner | random | -1.000 | -11.268 | -6.246 | +25.000 | +0.178 |
| runner | random_hold | -2.000 | -32.742 | -2.332 | +25.000 | +0.289 |
| runner | scripted | -2.000 | -30.428 | -7.944 | +25.000 | +0.331 |

## Descriptive catalogue episodes

One 30-second treatment per editable profile, each with a real passive compatible companion. These are examples under one condition, not a replicated ranking.

| Profile | Rig | Stable bins | X range | Net movement | Selection-label changes | Intentional idle seconds |
|---|---|---:|---:|---:|---:|---:|
| boundary_grazer | 4ly_trainer | 14 | 100.18 | 54.36 | 12 | 2.9 |
| cautious_flyer | 4ly_trainer | 18 | 147.72 | 123.42 | 16 | 3.1 |
| curious_surveyor | runner | 4 | 54.58 | 23.73 | 24 | 5.7 |
| drifting_flyer | 4ly_trainer | 9 | 52.22 | 6.30 | 7 | 1.6 |
| homebody_keeper | runner | 3 | 36.72 | 24.73 | 30 | 8.8 |
| idle_mechanic | runner | 4 | 49.43 | 4.74 | 10 | 12.7 |
| independent_wanderer | runner | 4 | 44.77 | 4.77 | 25 | 0.1 |
| oil_moth | runner | 3 | 36.17 | 8.19 | 11 | 0.0 |
| persistent_scavenger | runner | 3 | 32.26 | 12.47 | 25 | 5.1 |
| restless_explorer | runner | 5 | 65.30 | 12.16 | 14 | 2.9 |
| routine_patrol | runner | 3 | 25.85 | 9.53 | 24 | 0.8 |
| shy_crawler | runner | 3 | 34.46 | 0.79 | 17 | 2.6 |
| social_drifter | runner | 3 | 33.01 | 22.93 | 126 | 6.3 |
| social_roamer | runner | 3 | 26.48 | 15.27 | 127 | 0.1 |
| territorial_watcher | runner | 3 | 36.15 | 1.29 | 32 | 12.7 |
| timid_follower | runner | 2 | 18.10 | 5.43 | 39 | 17.9 |

## Limits and retained negative observations

- Metrics are observations, not automatic scores of intelligence or entertainment.
- Stable bins include the starting bin. Small horizontal oscillation at a grid boundary can populate two bins; pair occupancy with range and net displacement.
- Bin count times bin width/area is nominal occupied-grid measure, not exact traversed extent.
- Paired differences are stateful minus comparator for matching seeds. Three World pairs do not establish general superiority.
- The legacy field intention_transitions counts changes of recorded selection labels. Blend-label changes can reflect contributor changes; separate phase counts are reported. No goal_key was recorded, so new goal-instance counts are unavailable.
- A zero geometric home-return count is not a failed homeward attempt when no home rule was authored or selected, or when no qualifying departure occurred.
- Social/population actors share Worlds. Auxiliary companions are physical actors but not independent personality subjects.
- No-traits jointly disables personality modifiers and accumulated drives; separate contributions are not identified.
- Intentional inactivity and neutral commands permit real momentum and drift.
- Headless trajectories do not qualify graphical presentation or owner NVIDIA playfeel.

Outside-canvas centre observations occurred in 0 actor episodes; exact episode IDs and every-step sample counts are retained in the JSON readback.
