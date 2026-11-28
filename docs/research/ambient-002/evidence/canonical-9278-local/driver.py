import json,sys,types,pathlib,hashlib
sys.path.insert(0,str(pathlib.Path.cwd()/"tools/ambient"))
import run_episodes as r
import analyze_episodes as a
root=pathlib.Path.cwd().resolve()
out=pathlib.Path("/tmp/ambient-002/evidence/perception/canonical-9278-preflights")
args=types.SimpleNamespace(root=root,source_sha="9278de5757b29b9df40a089e11a4daef744990f7",
 godot=pathlib.Path("/tmp/ambient-002/runtime/Godot_v4.7-stable_linux.x86_64"),case_timeout=1800)
custody=r.full_custody(args)
out.mkdir(parents=True,exist_ok=True)
r.write(out/"custody.json",custody)
custody_sha=r.sha(out/"custody.json")
registry,record,path=r.run_process(args,"registry","",out/"registry",custody_sha)
r.verify_committed(root,registry["source_identity"],args.source_sha)
assert len(registry["registration"])==122
assert sum(c["actor_count"] for c in registry["registration"])==194
receipts=[]
for case_id in ("main-pockets-runner-s1701-t30-n1-stateful","main-pockets-4ly_trainer-s1701-t30-n1-stateful"):
 item=next(c for c in registry["registration"] if c["id"]==case_id)
 report,record,path=r.run_process(args,"full",case_id,out/case_id,custody_sha)
 assert report["registration"]==[item]
 assert r.identity_key(report["source_identity"])==r.identity_key(registry["source_identity"])
 r.verify_committed(root,report["source_identity"],args.source_sha)
 rows=a.validate(report,source_root=root)
 summary=a.summarize(report,rows)
 r.write(path.parent/"analysis.json",summary)
 receipts.append({"case_id":case_id,"source":args.source_sha,"checks":report["checks"],"complete":report["complete"],
   "report_sha256":r.sha(path),"execution_sha256":r.sha(path.parent/"execution.json"),
   "console_sha256":r.sha(path.parent/"console.log"),"metrics":summary["episodes"][0]})
 print(json.dumps(receipts[-1]),flush=True)
assert r.full_custody(args)==custody
r.write(out/"preflight-receipt.json",{"source":args.source_sha,"scope":"two actual canonical integration shards outside hosted194",
 "custody_sha256":custody_sha,"expected_hosted_campaigns":122,"expected_hosted_actor_episodes":194,
 "registry_executes_zero_actors":True,"episodes":receipts,"complete":True})
print("AMBIENT2_CANONICAL_PREFLIGHTS "+json.dumps({"complete":True,"actual_actor_episodes":2,"source":args.source_sha}),flush=True)

