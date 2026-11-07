#!/usr/bin/env python3
"""Create a diagnostic-only copy of the PR532 native replay driver.

The production source and retained benchmark stay unchanged. This helper adds
owner-reduced cache admission/cost counters to a temporary C++ copy built by
the branch-scoped diagnostic workflow.
"""
from __future__ import annotations
import argparse
from pathlib import Path

def once(text: str, before: str, after: str, name: str) -> str:
    if text.count(before) != 1:
        raise RuntimeError(f"{name}: expected one anchor, found {text.count(before)}")
    return text.replace(before, after, 1)

def main() -> int:
    p=argparse.ArgumentParser()
    p.add_argument("--source",type=Path,required=True)
    p.add_argument("--out",type=Path,required=True)
    a=p.parse_args()
    text=a.source.read_text()
    text=once(text,
        '"gas_reuses,gas_component_reuses,gas_member_validations,gas_invalidation_pairs,gas_component_invalidations,gas_cache_builds,gas_valid_components,gas_members,seed_cells,bfs_cells,relabel_cells,workers_observed\\n";',
        '"gas_reuses,gas_component_reuses,gas_member_validations,gas_invalidation_pairs,gas_component_invalidations,gas_cache_builds,gas_valid_components,gas_members,gas_dirty_chunks,gas_dirty_chunks_queued,gas_capacity_fallbacks,gas_budget_fallbacks,gas_cache_build_cells,gas_member_initializations,gas_member_builds,gas_component_proof_checks,gas_restart_fallbacks,seed_cells,bfs_cells,relabel_cells,workers_observed\\n";',
        "csv header")
    text=once(text,
        '<<world.pressure_optimization_snapshot().gas_members<<\',\'\n                     <<a.gas_seed_cells<<\',\'<<a.gas_bfs_cells<<\',\'<<a.gas_relabel_cells<<\',\'',
        '<<world.pressure_optimization_snapshot().gas_members<<\',\'\n                     <<world.pressure_optimization_snapshot().gas_dirty_chunks<<\',\'\n                     <<a.gas_dirty_chunks_queued<<\',\'<<a.gas_capacity_fallbacks<<\',\'<<a.gas_budget_fallbacks<<\',\'\n                     <<a.gas_cache_build_cells<<\',\'<<a.gas_member_initializations<<\',\'<<a.gas_member_builds<<\',\'\n                     <<a.gas_component_proof_checks<<\',\'<<a.gas_restart_fallbacks<<\',\'\n                     <<a.gas_seed_cells<<\',\'<<a.gas_bfs_cells<<\',\'<<a.gas_relabel_cells<<\',\'',
        "csv counters")
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(text)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
