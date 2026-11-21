# CI-OPT-002 candidate — complete applicable-check cohort

Exact PR head: `65aa1382a49bb01571177b4639f27b64f5dcb66d`. All **five** applicable workflows passed. The complete
observed event envelope was **2223s**,
using **299.600 unweighted
runner-minutes** across **73 executed jobs** and
**3 explicit conditional skips**.

| Workflow | Run | Event to final executed job | Runner-minutes | Executed / skipped jobs |
| --- | --- | ---: | ---: | ---: |
| Native | [44948729271](https://github.com/techrote/cybersand/actions/runs/44948729271) | 2223s | 102.533 | 9 / 1 |
| GDExtension | [44948729275](https://github.com/techrote/cybersand/actions/runs/44948729275) | 1140s | 172.717 | 54 / 2 |
| Documentation | [44948729294](https://github.com/techrote/cybersand/actions/runs/44948729294) | 436s | 7.217 | 1 / 0 |
| Palette GL/ANGLE | [44948729280](https://github.com/techrote/cybersand/actions/runs/44948729280) | 436s | 16.717 | 8 / 0 |
| Native source-scope advisory | [44948729310](https://github.com/techrote/cybersand/actions/runs/44948729310) | 28s | 0.417 | 1 / 0 |

The final workflow was **Native**, ending with **native**.
Workflow durations overlap, so they must not be summed to obtain elapsed
turnaround. All complete job pages are retained, including admission, build,
test, source aggregation and advisory retention work. Skipped scopes remain
explicit and are not treated as passed tests.

This is a descriptive candidate cohort. The contemporary control ran Native
alone; its before/after comparison is in `stage-b-native-paired-report.md`.
The older accepted-main baseline had seven workflows and cannot serve as a
like-for-like full-cohort runner-cost comparator. No full release, runtime
publication or research acceptance claim is made from this routine cohort.

The independent platform coverage report is retained at
`build/ci-opt-002/final-review/platform-gates-review.json`, with its exact hash
and every underlying metadata path recorded in `stage-b-candidate-cohort.json`.
