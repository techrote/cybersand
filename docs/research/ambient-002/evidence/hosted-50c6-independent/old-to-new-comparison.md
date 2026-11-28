# AMBIENT-002 — a725 to 50c6 physical-programme comparison

This is a descriptive comparison of fresh hosted executions of the same 122 registered Worlds and 194 actual actor episodes. It adds no independent treatment registrations. All 122 initial native material hashes, full initial pose hashes, geometry, seeds, observation scope and authored profiles match; only the approved three loaded source/test/help files differ. Rapier trajectories and hosted elapsed-call timings are not assumed identical across executions.

Values are **a725 → 50c6**. Ranges and distances are native cells. A profile with no home module or no qualifying departure does not fail merely because its geometric home-return count is zero.

## Main 30-second programme

Each cell is the median of three matched World seeds. Ground horizontal extent excludes vertical gait. Stable bins require 0.5 seconds cumulative occupancy, including the starting bin only if it qualifies.

| Rig | Arm | X range | Y range | Stable bins | Active stall fraction | Selection-label changes |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| runner | legacy | 35.599 → 35.599 | 21.046 → 21.046 | 3.000 → 3.000 | 0.231 → 0.231 | 11.000 → 11.000 |
| runner | random | 44.619 → 44.619 | 20.316 → 20.316 | 3.000 → 3.000 | 0.249 → 0.249 | 0.000 → 0.000 |
| runner | random_hold | 65.184 → 65.184 | 21.500 → 21.500 | 5.000 → 5.000 | 0.162 → 0.162 | 0.000 → 0.000 |
| runner | scripted | 63.728 → 63.728 | 20.298 → 20.298 | 5.000 → 5.000 | 0.104 → 0.104 | 0.000 → 0.000 |
| runner | stateful | 47.602 → 47.602 | 21.455 → 21.455 | 4.000 → 4.000 | 0.084 → 0.084 | 15.000 → 15.000 |
| runner | no_memory | 47.289 → 47.289 | 21.420 → 21.420 | 4.000 → 4.000 | 0.093 → 0.093 | 11.000 → 11.000 |
| runner | no_traits | 47.372 → 47.372 | 21.414 → 21.414 | 4.000 → 4.000 | 0.119 → 0.119 | 11.000 → 11.000 |
| runner | coarse_only | 46.406 → 46.406 | 20.702 → 20.702 | 3.000 → 3.000 | 0.109 → 0.109 | 7.000 → 7.000 |
| monowheel | legacy | 34.364 → 34.364 | 10.052 → 10.052 | 3.000 → 3.000 | 0.254 → 0.254 | 10.000 → 10.000 |
| monowheel | random | 19.068 → 19.068 | 10.033 → 10.033 | 2.000 → 2.000 | 0.254 → 0.254 | 0.000 → 0.000 |
| monowheel | random_hold | 63.047 → 63.047 | 10.060 → 10.060 | 5.000 → 5.000 | 0.140 → 0.140 | 0.000 → 0.000 |
| monowheel | scripted | 96.787 → 96.787 | 22.509 → 22.509 | 7.000 → 7.000 | 0.114 → 0.114 | 0.000 → 0.000 |
| monowheel | stateful | 49.513 → 49.513 | 10.045 → 10.045 | 4.000 → 4.000 | 0.081 → 0.081 | 13.000 → 13.000 |
| monowheel | no_memory | 49.439 → 49.439 | 10.051 → 10.051 | 4.000 → 4.000 | 0.147 → 0.147 | 13.000 → 13.000 |
| monowheel | no_traits | 33.654 → 33.654 | 10.037 → 10.037 | 3.000 → 3.000 | 0.045 → 0.045 | 6.000 → 6.000 |
| monowheel | coarse_only | 45.467 → 45.467 | 10.048 → 10.048 | 3.000 → 3.000 | 0.095 → 0.095 | 8.000 → 8.000 |
| 4ly_trainer | legacy | 52.224 → 52.224 | 47.269 → 47.269 | 10.000 → 10.000 | 0.237 → 0.237 | 7.000 → 7.000 |
| 4ly_trainer | random | 41.634 → 41.634 | 29.812 → 29.812 | 5.000 → 5.000 | 0.072 → 0.072 | 0.000 → 0.000 |
| 4ly_trainer | random_hold | 84.537 → 84.537 | 53.622 → 53.622 | 18.000 → 18.000 | 0.063 → 0.063 | 0.000 → 0.000 |
| 4ly_trainer | scripted | 56.375 → 56.375 | 2.331 → 2.331 | 4.000 → 4.000 | 0.030 → 0.030 | 0.000 → 0.000 |
| 4ly_trainer | stateful | 114.929 → 114.929 | 61.124 → 61.124 | 15.000 → 15.000 | 0.011 → 0.011 | 9.000 → 9.000 |
| 4ly_trainer | no_memory | 85.513 → 85.513 | 49.851 → 49.851 | 16.000 → 16.000 | 0.013 → 0.013 | 8.000 → 8.000 |
| 4ly_trainer | no_traits | 114.314 → 114.314 | 61.347 → 61.347 | 15.000 → 15.000 | 0.008 → 0.008 | 10.000 → 10.000 |
| 4ly_trainer | coarse_only | 74.088 → 74.088 | 55.044 → 55.044 | 16.000 → 16.000 | 0.011 → 0.011 | 9.000 → 9.000 |

## Within-seed ablations

These are medians of **paired differences** (stateful minus the stated ablation), not differences between cohort medians. The memory ablation disables spatial memory while preserving module latches; no_traits jointly disables personalities and drives.

| Rig | Ablation | Paired X-range delta | Paired active-stall delta |
| --- | --- | ---: | ---: |
| runner | no_memory | 0.313 → 0.313 | -0.010 → -0.010 |
| runner | no_traits | 0.230 → 0.230 | -0.038 → -0.038 |
| runner | coarse_only | 1.196 → 1.196 | -0.025 → -0.025 |
| monowheel | no_memory | 0.074 → 0.074 | -0.066 → -0.066 |
| monowheel | no_traits | 15.859 → 15.859 | 0.036 → 0.036 |
| monowheel | coarse_only | 4.046 → 4.046 | -0.010 → -0.010 |
| 4ly_trainer | no_memory | 0.000 → 0.000 | -0.002 → -0.002 |
| 4ly_trainer | no_traits | -1.101 → -1.101 | 0.007 → 0.007 |
| 4ly_trainer | coarse_only | -2.297 → -2.297 | 0.000 → 0.000 |

## Adversarial 30-second episodes

| Layout / rig | Arm / seed | X range | Active stall | Internal failures | Withdrawal seconds | Eight-cell windows | Geometric home returns |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| sealed_goal / runner (30s) | stateful / 605 | 50.243 → 50.243 | 0.406 → 0.406 | 7.000 → 7.000 | 6.200 → 6.200 | 2 → 2 | 0 → 0 |
| sealed_goal / runner (30s) | no_memory / 605 | 35.738 → 35.738 | 0.803 → 0.803 | 0.000 → 0.000 | 0.000 → 0.000 | 0 → 0 | 0 → 0 |
| moved_material / runner (30s) | stateful / 605 | 49.526 → 49.526 | 0.065 → 0.065 | 0.000 → 0.000 | 0.000 → 0.000 | 0 → 0 | 0 → 0 |
| moved_material / runner (30s) | no_memory / 605 | 49.851 → 49.851 | 0.088 → 0.088 | 0.000 → 0.000 | 0.000 → 0.000 | 0 → 0 | 0 → 0 |
| blocked_route / runner (30s) | stateful / 605 | 65.590 → 65.590 | 0.248 → 0.248 | 5.000 → 5.000 | 9.100 → 9.100 | 3 → 3 | 0 → 0 |
| blocked_route / runner (30s) | no_memory / 605 | 33.193 → 33.193 | 0.930 → 0.930 | 0.000 → 0.000 | 0.000 → 0.000 | 0 → 0 | 0 → 0 |
| sealed_goal / runner (30s) | stateful / 1701 | 50.243 → 50.243 | 0.406 → 0.406 | 7.000 → 7.000 | 6.200 → 6.200 | 2 → 2 | 0 → 0 |
| sealed_goal / runner (30s) | no_memory / 1701 | 34.894 → 34.894 | 0.803 → 0.803 | 0.000 → 0.000 | 0.000 → 0.000 | 0 → 0 | 0 → 0 |
| moved_material / runner (30s) | stateful / 1701 | 49.526 → 49.526 | 0.065 → 0.065 | 0.000 → 0.000 | 0.000 → 0.000 | 0 → 0 | 0 → 0 |
| moved_material / runner (30s) | no_memory / 1701 | 49.851 → 49.851 | 0.088 → 0.088 | 0.000 → 0.000 | 0.000 → 0.000 | 0 → 0 | 0 → 0 |
| blocked_route / runner (30s) | stateful / 1701 | 65.717 → 65.717 | 0.248 → 0.248 | 5.000 → 5.000 | 9.100 → 9.100 | 3 → 3 | 0 → 0 |
| blocked_route / runner (30s) | no_memory / 1701 | 33.186 → 33.186 | 0.940 → 0.940 | 0.000 → 0.000 | 0.000 → 0.000 | 0 → 0 | 0 → 0 |

## Sustained 120/300-second episodes

| Layout / rig | Arm / seed | X range | Active stall | Internal failures | Withdrawal seconds | Eight-cell windows | Geometric home returns |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| pockets / runner (120s) | stateful / 1701 | 43.728 → 43.728 | 0.075 → 0.075 | 0.000 → 0.000 | 0.000 → 0.000 | 8 → 8 | 0 → 0 |
| pockets / runner (120s) | no_memory / 1701 | 42.098 → 42.098 | 0.096 → 0.096 | 0.000 → 0.000 | 0.000 → 0.000 | 2 → 2 | 0 → 0 |
| pockets / 4ly_trainer (120s) | stateful / 1701 | 184.370 → 193.009 | 0.050 → 0.013 | 1.000 → 0.000 | 0.000 → 0.000 | 1 → 0 | 2 → 1 |
| pockets / 4ly_trainer (120s) | no_memory / 1701 | 169.554 → 168.660 | 0.017 → 0.010 | 0.000 → 0.000 | 0.000 → 0.000 | 0 → 0 | 1 → 2 |
| pockets / monowheel (300s) | stateful / 1701 | 51.736 → 51.736 | 0.367 → 0.367 | 0.000 → 0.000 | 0.000 → 0.000 | 12 → 12 | 0 → 0 |
| pockets / monowheel (300s) | no_memory / 1701 | 52.199 → 52.199 | 0.456 → 0.456 | 0.000 → 0.000 | 0.000 → 0.000 | 14 → 14 | 0 → 0 |

### Adverse recovery and withdrawal timing

Recovery is the frozen sampled proxy: at least 8 cells displacement from a blocked-approach point within 5 seconds. It does not require movement away or certify that the original target became reachable. Exact sampled window endpoints and obstruction last-seen records are retained in the JSON.

| Layout | Arm / seed | Old recovery elapsed seconds | New recovery elapsed seconds | New withdrawal windows |
| --- | --- | --- | --- | --- |
| sealed_goal | stateful / 605 | 2.1, 2.8 | 2.1, 2.8 | [15.7, 18.8), [23.8, 26.9) |
| sealed_goal | no_memory / 605 | none | none | none |
| moved_material | stateful / 605 | none | none | none |
| moved_material | no_memory / 605 | none | none | none |
| blocked_route | stateful / 605 | 3.6, 3.1, 1.6 | 3.6, 3.1, 1.6 | [5.5, 8.5), [13.5, 16.5), [22.3, 25.4) |
| blocked_route | no_memory / 605 | none | none | none |
| sealed_goal | stateful / 1701 | 2.1, 2.8 | 2.1, 2.8 | [15.7, 18.8), [23.8, 26.9) |
| sealed_goal | no_memory / 1701 | none | none | none |
| moved_material | stateful / 1701 | none | none | none |
| moved_material | no_memory / 1701 | none | none | none |
| blocked_route | stateful / 1701 | 3.6, 3.1, 1.6 | 3.6, 3.1, 1.6 | [5.4, 8.4), [13.4, 16.4), [22.1, 25.2) |
| blocked_route | no_memory / 1701 | none | none | none |

## Social spacing and sampled groups

Forty-cell connected components are a spatial proximity measure. Exact-membership set changes and threshold crossings can produce formation/dissolution counts; these are not persistent social identities. Initial groups are reported separately.

| World family / actors | Arm / seed | Grouped actor fraction | Initial components | Later formation events | Dissolution events |
| --- | --- | ---: | --- | ---: | ---: |
| social / 4 | legacy / 605 | 0.891 → 0.891 | [[100, 101, 102, 103]] → [[100, 101, 102, 103]] | 45 → 45 | 45 → 45 |
| social / 4 | stateful / 605 | 0.947 → 0.947 | [[100, 101, 102, 103]] → [[100, 101, 102, 103]] | 10 → 10 | 10 → 10 |
| social / 4 | no_social / 605 | 0.443 → 0.443 | [[100, 101, 102, 103]] → [[100, 101, 102, 103]] | 15 → 15 | 16 → 16 |
| social / 4 | random / 605 | 0.902 → 0.902 | [[100, 101, 102, 103]] → [[100, 101, 102, 103]] | 12 → 12 | 11 → 11 |
| departure / 2 | stateful / 605 | 0.240 → 0.240 | [[100, 101]] → [[100, 101]] | 1 → 1 | 2 → 2 |
| departure / 2 | no_social / 605 | 0.343 → 0.343 | [[100, 101]] → [[100, 101]] | 1 → 1 | 2 → 2 |
| capacity / 8 | legacy / 605 | 0.915 → 0.915 | [[100, 101, 102, 103, 104, 105, 106, 107]] → [[100, 101, 102, 103, 104, 105, 106, 107]] | 73 → 73 | 73 → 73 |
| capacity / 8 | stateful / 605 | 0.856 → 0.856 | [[100, 101, 102, 103, 104, 105, 106, 107]] → [[100, 101, 102, 103, 104, 105, 106, 107]] | 20 → 20 | 18 → 18 |
| social / 4 | legacy / 1701 | 0.772 → 0.772 | [[100, 101, 102, 103]] → [[100, 101, 102, 103]] | 36 → 36 | 36 → 36 |
| social / 4 | stateful / 1701 | 0.944 → 0.944 | [[100, 101, 102, 103]] → [[100, 101, 102, 103]] | 12 → 12 | 11 → 11 |
| social / 4 | no_social / 1701 | 0.442 → 0.442 | [[100, 101, 102, 103]] → [[100, 101, 102, 103]] | 7 → 7 | 8 → 8 |
| social / 4 | random / 1701 | 1.000 → 1.000 | [[100, 101, 102, 103]] → [[100, 101, 102, 103]] | 8 → 8 | 7 → 7 |
| departure / 2 | stateful / 1701 | 0.187 → 0.187 | [[100, 101]] → [[100, 101]] | 2 → 2 | 3 → 3 |
| departure / 2 | no_social / 1701 | 0.323 → 0.323 | [[100, 101]] → [[100, 101]] | 0 → 0 | 1 → 1 |
| capacity / 8 | legacy / 1701 | 0.852 → 0.852 | [[100, 101, 102, 103, 104, 105, 106, 107]] → [[100, 101, 102, 103, 104, 105, 106, 107]] | 75 → 75 | 73 → 73 |
| capacity / 8 | stateful / 1701 | 0.699 → 0.699 | [[100, 101, 102, 103, 104, 105, 106, 107]] → [[100, 101, 102, 103, 104, 105, 106, 107]] | 16 → 16 | 15 → 15 |

## Production elapsed-call costs

These are medians across the listed Worlds. Sensor and core/adapter calls are disjoint subsets of production advance; they must not be added again to advance. Native and Rapier costs are per physical tick. One-actor pockets and four/eight-actor courtyards differ in geometry, so this table is not a controlled actor-count-only scaling experiment. Separate hosted wall-time changes are not evidence of a performance benefit from the recharge repair.

| Family / actors | Arm / Worlds | Sensor ms/sim-s | Core ms/sim-s | Advance ms/sim-s | Native ms/tick | Rapier ms/tick |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| capacity / 8 | legacy / 2 | 38.090 → 45.478 | 16.207 → 18.160 | 158.524 → 192.545 | 0.178 → 0.167 | 1.129 → 1.481 |
| capacity / 8 | stateful / 2 | 102.381 → 116.613 | 27.782 → 30.797 | 242.979 → 285.319 | 0.183 → 0.181 | 1.132 → 1.476 |
| main / 1 | legacy / 3 | 4.685 → 5.573 | 1.424 → 1.838 | 19.083 → 23.818 | 0.048 → 0.060 | 0.164 → 0.267 |
| main / 1 | stateful / 3 | 13.197 → 14.961 | 3.041 → 3.574 | 30.454 → 36.472 | 0.033 → 0.043 | 0.163 → 0.257 |
| social / 4 | legacy / 2 | 19.583 → 22.423 | 8.800 → 8.373 | 81.070 → 94.674 | 0.092 → 0.092 | 0.571 → 0.854 |
| social / 4 | no_social / 2 | 50.602 → 57.027 | 11.896 → 11.781 | 118.516 → 137.974 | 0.114 → 0.113 | 0.553 → 0.758 |
| social / 4 | stateful / 2 | 52.048 → 58.004 | 15.184 → 14.865 | 124.105 → 142.797 | 0.087 → 0.089 | 0.555 → 0.819 |

### Main stateful sensor/core costs per decision

| Rig | Sensor microseconds/decision | Core/adapter microseconds/decision |
| --- | ---: | ---: |
| runner | 1319.687 → 1496.060 | 304.080 → 357.380 |
| monowheel | 1224.557 → 1433.613 | 262.470 → 355.383 |
| 4ly_trainer | 1173.070 → 1323.330 | 264.050 → 334.170 |

## Catalogue descriptive subjects

One ordinary editable personality per 30-second World, each with one real passive companion. These sixteen subjects are descriptive demonstrations, not replicated estimates of personality-wide tendencies. Companions are excluded below.

| Profile | Rig | X range | Active stall | Selection-label changes | New selected-module seconds |
| --- | --- | ---: | ---: | ---: | --- |
| oil_moth | runner | 35.202 → 35.202 | 0.221 → 0.221 | 11 → 11 | seek_material: 21.3, escape_obstruction: 8.7 |
| shy_crawler | runner | 34.517 → 34.517 | 0.110 → 0.110 | 17 → 17 | wander: 22.7, avoid_material: 2.8, blend:wander: 2.5, escape_obstruction: 2.0 |
| curious_surveyor | runner | 54.781 → 54.781 | 0.081 → 0.081 | 16 → 16 | wander: 22.6, seek_material: 3.7, rest: 2.4, avoid_material: 1.3 |
| idle_mechanic | runner | 49.397 → 49.397 | 0.088 → 0.088 | 10 → 10 | wander: 14.4, rest: 12.7, avoid_material: 1.6, escape_obstruction: 1.3 |
| drifting_flyer | 4ly_trainer | 52.224 → 52.224 | 0.233 → 0.233 | 7 → 7 | wander: 25.0, maintain_altitude: 2.2, blend:wander: 1.6, avoid_material: 1.2 |
| social_roamer | runner | 26.152 → 26.152 | 0.302 → 0.302 | 128 → 128 | follow_actor: 15.6, wander: 14.4 |
| restless_explorer | runner | 65.795 → 65.795 | 0.233 → 0.233 | 16 → 16 | explore_unfamiliar: 14.8, withdraw_obstruction: 9.1, avoid_material: 6.0, wander: 0.1 |
| territorial_watcher | runner | 36.207 → 36.207 | 0.028 → 0.028 | 10 → 10 | wander: 14.0, observe_actor: 13.6, steer_obstacles: 1.5, avoid_material: 0.9 |
| social_drifter | runner | 28.761 → 28.761 | 0.145 → 0.145 | 76 → 76 | regroup: 11.7, wander: 8.8, observe_actor: 8.3, steer_obstacles: 1.1, align_peers: 0.1 |
| timid_follower | runner | 17.891 → 17.891 | 0.201 → 0.201 | 56 → 56 | observe_actor: 14.1, wander: 9.2, follow_actor: 3.3, blend:wander: 2.7, regroup: 0.7 |
| persistent_scavenger | runner | 43.728 → 43.728 | 0.071 → 0.071 | 18 → 18 | explore_unfamiliar: 16.2, investigate_material: 7.9, revisit_interest: 3.7, seek_material: 1.4, steer_obstacles: 0.8 |
| routine_patrol | runner | 22.673 → 22.673 | 0.049 → 0.049 | 23 → 23 | patrol_route: 19.0, avoid_material: 9.6, rest: 1.4 |
| independent_wanderer | runner | 42.894 → 42.894 | 0.027 → 0.027 | 22 → 22 | exploration_destination: 18.0, avoid_material: 7.5, wander: 4.1, avoid_crowding: 0.4 |
| cautious_flyer | 4ly_trainer | 147.723 → 147.723 | 0.004 → 0.004 | 16 → 16 | explore_unfamiliar: 19.2, investigate_material: 4.8, avoid_material: 4.7, maintain_altitude: 0.8, blend:: 0.5 |
| boundary_grazer | 4ly_trainer | 97.670 → 97.670 | 0.104 → 0.104 | 11 → 11 | exploration_destination: 13.6, follow_material_boundary: 7.1, revisit_interest: 5.2, steer_obstacles: 4.1 |
| homebody_keeper | runner | 36.871 → 36.871 | 0.042 → 0.042 | 14 → 14 | seek_home_drive: 7.3, exploration_destination: 6.7, investigate_material: 5.2, observe_actor: 4.9, wander: 3.0, steer_obstacles: 1.5, avoid_material: 1.4 |

## Exact identities

- Current application: `50c6df89528dc9ecdc5316d8c67abf203e192254`.
- Baseline application: `a7250e15495667b2fcf564cbed1eaa8dea217c45`.
- Current original artifact SHA-256: `e96d284ac7e44eea93ff9269461166a09cc40b8a352893cb43dc9975c24bf9ac`.
- Current raw report SHA-256: `1cfb085b65c9fbf295294fbf5360d7d8f0ac78f9b95039c384fe416bdc889137`.
- Current summary SHA-256: `298cc3977a5c318ab8530e983a05ce9c298f17a105a5690fd4bb3018b1938a91`.
- Baseline summary SHA-256: `80e563bb3349aa4a9f12f11bec118c99fe980e52c522330177147d8e6a272245`.
- Complete receipt-chain audit SHA-256: `b3d289d7cd9abbe22754f59f0550c48e39009bbae3fb96e0ebdd95a18a72cdc0`.
- Comparison reader SHA-256: `55ea114528056a0c1d04710a52e16a940fde414640fe6b8bfa9bb4bb31c2cf24`.
- Current source inputs / loaded project inputs: 1143 / 855.

Every table is backed by unrounded values and sampled recovery/withdrawal endpoints in `old-to-new-comparison.json`. The full original Actions artifact remains the authoritative source.
