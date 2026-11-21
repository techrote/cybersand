# B4-009 — Source-derived percentile order-statistic admission

**10 November 2026. Experimental B4 / Draft HOLD.** No native execution, production change, physical hash, worker-participation claim, memory allocation measurement, new algorithmic speedup, or physics acceptance.

## Reproducible source identity and bounded falsifier

- Accepted CyberSand `main`: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
- Pre-edit B4 Draft #554: `391be51bf7dd40f21943a86a2b62d4b70d2c02dd`.
- Actual profiler: `godot/scripts/hard_surface_packet_profile.gd` Git blob `e5d226c946157410e256ba24fe6de0a34f32c883`, inspected read-only.
- Original November 6 hosted [#470 A/B/B/A job 128182806453](https://github.com/techrote/cybersand/actions/runs/42302283599/job/128182806453), wrapped in `hs470_abba_profiles.json`, **unchanged** Git blob `40e0813ed6b80bef6feb8d721c196e43ea8d0517`. Two actual native binary/source identities, ordered control/candidate/candidate/control, 12 records.
- Prior B4-008 reducer blob `0120d9d8a718e22a3f72f735444fce4183baef9b`; regression file blob `d4d4dda343e8847a500e27d02f91f51faacfbe03`.
- [Falsifier registration](https://github.com/techrote/cybersand/pull/554#issuecomment-6760152076) before writes.

**Question:** Can profiles preserving run, source, binary, host, order, sample counts, nonnegative statistics, median<=p95<=max, and mean<=max still be mathematically impossible under the actual percentile producer? Yes: two independent deterministic adversarial changes both pass the old predicate but cannot arise from any sorted array of the claimed count.

## Necessary bounded theorem: ordered-sample envelope

Let `n>=1` finite, sorted real durations `0<=x[0]<=...<=x[n-1]`, `i=floor(.50*(n-1)+.5)`, `j=floor(.95*(n-1)+.5)`, `p=x[i]`, `q=x[j]`, `M=x[n-1]`, and `mu=sum(x)/n`. The last two indices use the actual profiler's nearest integer rounding of nonnegative ranks (not interpolated percentiles).

Required **rank collisions**: `i==j => p==q`, and `j==n-1 => q==M`. Required **mean envelope**:

```text
((j-i)*p + (n-1-j)*q + M) / n <= mu
mu <= ((i+1)*p + (j-i)*q + (n-1-j)*M) / n
```

**Proof:** for the lower bound, positions `i..j-1` are each at least `p`; `j..n-2` are each at least `q`; the last position equals `M`; earlier positions are nonnegative. For the upper bound, positions `0..i` are each at most `p`; positions `i+1..j` at most `q`; positions `j+1..n-1` at most `M`. The rank coincidences are equality of an identical selected sample. Therefore the constraints hold for every finite `n` of nonnegative samples: a standard order-statistic fact, **not a novel physics theorem**.

The implementation uses a constant `1e-8 ms` arithmetic tolerance for the mean envelope. It does not certify raw sample provenance or that reported summaries were genuinely measured.

## Bounded actual experiment and negative controls

Independent JavaScript reduction of the exact 12-record blob checked all **60** source-instrumented metric summaries; every one satisfied the newly derived predicates. An independent local CPython 3.13 order-statistic oracle exhaustively checked **1,286** nondecreasing integer-valued sample arrays, with `n=1..8` and values `0..4`: all satisfied the theorem. This is a finite implementation control; the proof above supplies the infinite-family result.

| Input | Existing reducer semantic checks | New source-derived guard |
|---|---|---|
| Original 60 historical summary records | Admit | 60/60 admit |
| Stress candidate record 5, `n=1`, `p50=.010,p95=.020,mean=max=.093` | Admits | **REFUSE**: one sample cannot yield distinct quantiles |
| Stress control record 2, `n=4`, `p50=1.598,p95=max=1.627,mean=1.620` | Admits | **REFUSE**: maximal feasible mean is **1.60525 ms** |
| Stress candidate record 8, `n=4`, `p50=.159,p95=.160,max=.165` | Admits | **REFUSE**: source's p95 index is last, thus p95 must equal max |

The changes to the fixture above are **adversarial in-memory mutations**, not alterations of historical Git evidence. Under the genuine fixture, the #470 bench packet-stage result stays `STAGE_ONLY`, stress stays `HOLD_LOW_SAMPLE`, and my-canvas stays `NO_PACKET_EVENTS`. This work does not derive a new whole-tick performance result.

## Replay, resource bound and limitations

```sh
cd research/solver-certificates/performance
python3 -m unittest -v test_reduce_hs470_abba.py
python3 reduce_hs470_abba.py hs470_abba_profiles.json
```

The verification adds **O(1) per profile metric** arithmetic after validating finite source-bounded `n <= 100000`; it is not installed on a native cell/worker path. Three adversarial methods and one original-coverage method are added to the existing Python tests.

**Execution disclosure:** the read-only all-60 JSON analysis and the independent 1,286-case local CPython theorem checker were executed; the new full, exact published B4 reducer/unittest suite was **authored but not executed** in the current tool environment. Source-pinned native rerun, actual 1/4 worker participation, hash/quantity/contact parity, RSS, allocation profiles and B2/B3 candidate throughput remain **unavailable**, not positive.

**GO:** source-specific statistic evidence gate is stronger and the original fixture remains admitted. **HOLD:** any causally attributed tick/FPS improvement, new B2/B3 speedup, production merge, and source-qualified full-module replay. Historical 3.089x B2 high-churn abstract-cost regression and #470 zero-packet placebo remain negative controls.

**Independent B5 request:** replay the exact B4 Python test suite at the published head, verify source rank-selection (including Godot half-integer tie behavior), and challenge the envelope on source-derived or forged JSON. Require original per-tick timings and genuine worker/physical-parity evidence before considering future B2/B3 native improvements.
