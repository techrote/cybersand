"""Deterministic case expansion from a retained, post-freeze 32-byte entropy value.
This module never runs a native generator or redraws based on any result.
"""
import hashlib

def expand(plan, exclusions, entropy):
    if len(entropy) != 32:
        raise ValueError("Expected exactly32 bytes of retained entropy")
    rejected = set(exclusions["known_revealed_seeds"]) | set(exclusions["conservative_in_namespace_source_literals"])
    selected = set()
    cases = []
    counter = 0
    for fixture in plan["fixtures"]:
        for profile in plan["profiles"]:
            for _ in range(plan["replicates_per_stratum"]):
                while True:
                    digest = hashlib.sha256(b"GENTEK-SWARM-006-HOLDOUT-001\0" + entropy + counter.to_bytes(8, "little")).digest()
                    counter += 1
                    seed = (1 << 30) + int.from_bytes(digest[:8], "little") % (1 << 30)
                    if seed not in rejected and seed not in selected:
                        selected.add(seed)
                        break
                cases.append({"fixture": fixture, "profile": profile, "seed": seed})
    if len(cases) != plan["case_count"]:
        raise ValueError("Case denominator changed")
    return cases, counter
