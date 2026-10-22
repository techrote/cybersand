#!/usr/bin/env bash
# usage: suite2.sh <build dir> [env assignments...]  -> runs all scenarios in parallel
B=$1; shift
export LAB_QUIET=1
for s in "pool 2400" "calm 600" "column 2400" "utube 4000" "basin 2400" "cloud 1500" "rain 800"; do
  set -- $s
  env "$@" >/dev/null 2>&1
  ( "$B/probe.exe" $1 $2 1 | python -c "import json,sys;d=json.loads(sys.stdin.read().strip().splitlines()[-1]);print(d['scenario'].ljust(7),' '.join(f'{k}={d[k]}' for k in ['mass0','mass','level_tick','sleep_tick','final_spread','late_changed']))" ) &
done
wait
