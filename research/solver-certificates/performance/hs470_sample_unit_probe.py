#!/usr/bin/env python3
"""B4 research-only source-gated historical profile sample-unit audit.

Usage from B4 subtree:
  python3 hs470_sample_unit_probe.py hs470_abba_profiles.json
  python3 hs470_sample_unit_probe.py --self-test

This is a producer-admission falsifier, not a native tick benchmark. The
lower bound applies if tick_index is monotone within each profiling window;
otherwise a rewind/restart is itself an unqualified sampling condition.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

PINNED_PROFILE_BLOB = '40e0813ed6b80bef6feb8d721c196e43ea8d0517'
PINNED_PRODUCER_BLOB = 'e5d226c946157410e256ba24fe6de0a34f32c883'
PINNED_B4_HEAD = '78cd86cb804772ca7a5b7a9172e04d767f4f3b6b'

# Independent small self-check uses published counts, not full source bytes.
OBSERVED_BY_RUN = (256, 259, 232, 256, 255, 232, 256, 256, 235, 255, 255, 236)

def git_blob_id(raw: bytes) -> str:
    return hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()

def audit(profile: dict) -> dict:
    records = profile['records']
    assert profile['schema'] == 'b4-hs470-verbatim-profiles-v1'
    assert len(records) == 12
    rows = []
    for i, item in enumerate(records):
        p = item['profile']
        assert type(p['requested_sample_ticks']) is int and p['requested_sample_ticks'] > 0
        assert type(p['observed_snapshots']) is int and p['observed_snapshots'] >= 0
        # End tick MAY appear once: the loop tests its stop predicate before
        # await process_frame, and only then observes the latest snapshot.
        at_most_distinct = p['requested_sample_ticks'] + 1
        excess = max(0, p['observed_snapshots'] - at_most_distinct)
        rows.append(dict(run=item['run_index'], arm=item['arm'], canvas=p['canvas'],
                         observed=p['observed_snapshots'], distinct_tick_upper=at_most_distinct,
                         min_repeated_or_rewound=excess,
                         fraction_lower_bound=round(excess / max(1, p['observed_snapshots']), 6)))
    return dict(profile_blob=PINNED_PROFILE_BLOB, producer_blob=PINNED_PRODUCER_BLOB,
                baseline_b4_head=PINNED_B4_HEAD, records=len(rows),
                total_observed=sum(x['observed'] for x in rows),
                min_repeated_or_rewound=sum(x['min_repeated_or_rewound'] for x in rows),
                all_records_exceed_window=all(x['min_repeated_or_rewound'] > 0 for x in rows),
                rows=rows, verdict='NO_GO_AS_INDEPENDENT_PER_TICK_DISTRIBUTION')

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('profile', nargs='?', type=Path)
    ap.add_argument('--self-test', action='store_true')
    args = ap.parse_args()
    if args.self_test:
        assert len(OBSERVED_BY_RUN) == 12
        excess = [max(0, n - 181) for n in OBSERVED_BY_RUN]
        assert sum(OBSERVED_BY_RUN) == 2983
        assert sum(excess) == 811
        assert min(excess) == 51 and max(excess) == 78
        assert all(excess)
        print('SELF_TEST_PASS: 12/12 source-reported counts; 811 minimum excess serial publications')
        return
    if args.profile is None:
        ap.error('pin the exact historical profile JSON or use --self-test')
    raw = args.profile.read_bytes()
    actual = git_blob_id(raw)
    if actual != PINNED_PROFILE_BLOB:
        raise SystemExit(f'SOURCE_MISMATCH: {actual} != {PINNED_PROFILE_BLOB}')
    report = audit(json.loads(raw))
    assert [x['observed'] for x in report['rows']] == list(OBSERVED_BY_RUN)
    print(json.dumps(report, indent=2, sort_keys=True))

if __name__ == '__main__':
    main()
