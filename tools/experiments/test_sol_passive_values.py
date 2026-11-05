#!/usr/bin/env python3
"""Portable analytic audit plus corrupt-evidence refusal controls."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sol_passive_values as v

def main():
    folder=v.ROOT/"docs/audits/sol-chamber-20261105"
    receipt=json.loads((folder/"passive-values.json").read_text(encoding="utf-8"))
    raw=(folder/receipt["common_observation"]["path"]).read_bytes()
    assert hashlib.sha256(raw).hexdigest()==receipt["common_observation"]["sha256"]
    for name,digest in receipt["input_sha256"].items():assert v.sha(v.ROOT/name)==digest,name
    profile=json.loads((v.ROOT/v.PROFILE).read_text(encoding="utf-8"));data=json.loads(raw)
    rows=v.audit(data,profile);assert len(rows)==25 and receipt["all_variant_parsed_observations_equal"]
    def mutate(identifier,fn):
        def run(value):fn(next(c for c in value["cases"] if c["id"]==identifier))
        return run
    mutations=[
        mutate("support-192",lambda c:c["observation"]["input_bins"][1].update(normal=[1,0])),
        mutate("front",lambda c:c["observation"]["input_bins"][0].update(count=63)),
        mutate("null",lambda c:c["observation"].update(null_bin=False)),
        mutate("overflow",lambda c:c["observation"]["input_bins"].pop()),
        mutate("max-one-node",lambda c:c["observation"]["result"].update(nodes=1,updates=8)),
        mutate("front",lambda c:c.update(replays_equal=False)),
        mutate("front",lambda c:c["observation"]["result"].update(impulse=[0,0])),
        mutate("front",lambda c:c["observation"]["input_bins"][0].update(state_b_min=0)),
        mutate("front",lambda c:c["observation"]["result"].update(energy_after=.01)),
        lambda value:value["cases"].reverse(),
    ]
    refused=0
    for change in mutations:
        value=deepcopy(data);change(value)
        try:v.audit(value,profile)
        except AssertionError:refused+=1
        else:raise AssertionError("Corrupted evidence accepted")
    assert refused==len(mutations)
    print(json.dumps(dict(source=receipt["source"],cases=25,compiled_variants=len(receipt["observations"]),corruptions_refused=refused,scope="portable value-only audit; not live authority or original SOL clearance")))

if __name__=="__main__":main()
