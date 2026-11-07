#!/usr/bin/env python3
"""Verify same-binary long-window C1024 vs C2048 Godot workbench+Rapier runs."""
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
head = sys.argv[2]
expected_native = (root/"native-binary.sha256").read_text().split()[0]
expected_rapier = "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a"
def check(ok, message):
    if not ok:
        raise AssertionError(message)
reports = {}
for capacity in (1024,2048):
    path = root/f"workbench-C{capacity}.log"
    check(path.is_file(), f"missing original run for C{capacity}")
    contents = path.read_text(errors="replace")
    parsed = []
    for line in contents.splitlines():
        marker="PF_C2048_WORKBENCH_PROFILE "
        if marker in line:
            payload=line.split(marker,1)[1].strip()
            if payload.startswith("{"):
                parsed.append(json.loads(payload))
    check(len(parsed)==2 and [x.get("canvas") for x in parsed]==["my-canvas","stress-canvas"],
          f"C{capacity}: original authored canvas/actor run missing")
    for x in parsed:
        scene=x["canvas"]
        w=f"C{capacity}/{scene}"
        check(x.get("schema")=="pf-c2048-extended-workbench-v1",f"{w}: wrong schema")
        check(x.get("source_sha")==head and x.get("capacity")==capacity, f"{w}: wrong source/profile")
        rt=x.get("runtime",{})
        check(rt.get("os")=="Linux" and rt.get("native_sha256")==expected_native
              and rt.get("rapier_sha256")==expected_rapier, f"{w}: different runtime/dependency")
        expected_extent=[512,512] if scene=="my-canvas" else [2048,1024]
        expected_actors=2 if scene=="my-canvas" else 8
        check(x.get("extent")==expected_extent and x.get("actual_installed_extent")==expected_extent
              and x.get("actors_requested")==expected_actors
              and x.get("actual_installed_actor_count")==expected_actors,
              f"{w}: wrong authored extent or installed actor roster")
        check(x.get("warmup_ticks")==24 and x.get("requested_sample_ticks")==240,
              f"{w}: changed sample duration")
        p=x.get("pressure",{})
        check(p.get("family")=="pressure_flow_v1" and p.get("variant")=="cached_dormant"
              and p.get("gas_enabled") is True
              and p.get("parameters",{}).get("compartment_capacity")==capacity,
              f"{w}: PF variant, gas or capacity not actually applied")
        check(x.get("ballistic_enabled") is True and x.get("spray_enabled") is True
              and x.get("jet_enabled") is True, f"{w}: missing ballistic/spray options")
        ledger=x.get("ballistic_ledger",{})
        check(ledger.get("launched_parcels",0)+ledger.get("injected_parcels",0)>0,
              f"{w}: no live ballistic work executed")
        check(x.get("observed_actor_samples",0)>20 and x.get("actual_actor_steps",0)>20,
              f"{w}: no genuine Rapier actor execution")
        check(x.get("accepted_edit_requests",0)>=45 and x.get("observed_hard_revision_changes",0)>=35,
              f"{w}: insufficient actual deterministic hard edits")
        packet_minimum = 5 if capacity==1024 and scene=="stress-canvas" and x.get("native_failed") else 40
        check(x.get("packet",{}).get("samples",0)>=packet_minimum,
              f"{w}: insufficient real hard-packet samples")
        if scene=="my-canvas":
            check(x.get("native_failed") is False, f"{w}: simple canvas failed")
        if capacity==2048:
            check(x.get("native_failed") is False and x.get("observed_snapshots",0)>=200,
                  f"{w}: raised-capacity full-window execution incomplete")
    reports[capacity]=parsed
low,high=reports[1024][1],reports[2048][1]
classification="not-reproduced"
if low.get("native_failed"):
    reason=str(low.get("native_failure_error",""))
    if "pressure gas compartment capacity exhausted" in reason:
        classification="capacity-exhaustion-confirmed"
    else:
        classification="reproduced-other-or-undetermined"
check(classification=="capacity-exhaustion-confirmed",
      "C1024 actual 8-actor long-window failure is not yet independently attributed to capacity: "
      +str(low.get("native_failure_error")))
check(low.get("actual_actor_steps",0)<high.get("actual_actor_steps",0),
      "C2048 actor run did not outlast previously failing C1024 control")
for scene in ("my-canvas","stress-canvas"):
    a=next(x for x in reports[1024] if x["canvas"]==scene)
    b=next(x for x in reports[2048] if x["canvas"]==scene)
    check(a["pressure"]["policy_hash"]==b["pressure"]["policy_hash"],
          f"{scene}: policy law/variant hash differs across capacity-only arms")
record={"schema":"pf-c2048-actual-workbench-v1",
        "result":"C1024 reproduced capacity exhaustion; C2048 completed extended identical workbench workload",
        "classification":classification,
        "exact_source":head,"native_binary_sha256":expected_native,
        "original_log_sha256":{f"C{c}":hashlib.sha256((root/f"workbench-C{c}.log").read_bytes()).hexdigest()
                               for c in (1024,2048)},
        "runs":reports,
        "limitations":"observed edit/packet timing counts need not be identical despite same test script; source-identical binary and fixture/policy/actors are required"}
(root/"workbench-readback.json").write_text(json.dumps(record,indent=2,sort_keys=True)+"\n")
print("PF_C2048_WORKBENCH_COMPARISON_PASS",classification,
      "C1024_actor_steps",low["actual_actor_steps"],"C2048_actor_steps",high["actual_actor_steps"])
