"""Seal the already reviewed passive stage; no gameplay or analysis reruns."""
from __future__ import annotations
import hashlib, io, json, os, re, signal, stat, sys, threading, time, zipfile
from pathlib import Path, PurePosixPath
import passive_evidence as core

ROOT=core.ROOT
EVIDENCE=core.EVIDENCE
HERE=core.ARCHIVES
SEAL=ROOT/"passive-seal"
OUTPUT=ROOT/"deliverables/CyberSand-goblin-campaign-evidence.zip"
MANIFEST=Path(__file__).with_name("passive-seal-manifest.json")
PHASE1_SOURCE="2a627a3131be72fcb876acec0d0b848a7e42c3e3"
PHASE1_TREE="4ffce44157122ead0ac8bb559aa7f74557ce30d7"
PHASE1_DRIVER="6b9c3e327437f5426776da78abef02ef62636212"
PHASE1_MANIFEST="9784b984e04eeac2c4d48977c28a73f042eb53bc"
STAGE_ID=15005776720
STAGE_RUN=45579669046
STAGE_BYTES=942877571
STAGE_SHA="8621cf2811e14fdda3e98749f84b7d0887228f0c64b91967ae67485627552da9"
STAGE_ROOTS=("evidence","passive-supervision","review-B-lineage-repair",
             "review-B-full142-5ee","review-B-action-coverage-5ee","review-B-decision-5ee")
MAX_STAGE=2*1024**3
MAX_COMPACT=8*1024**2
REQUIRED_DOCS={
 "docs/research/gip014-goblin-002-decision.md",
 "docs/research/gip014-goblin-002.md",
 "tools/gip014/decision-index-002.json",
 "docs/research/goblin002-exploration-handover.md",
 "docs/research/goblin002-gameplay-handover.md",
 "docs/research/goblin002-replay-delivery-handover.md",
}
REPORTS={
 "evidence/request11-linux-independent/analysis.json":(1040902,"c32ab2dcbd84f969a8dff36c9e0b31122a0e7664e70516d7fc0334d9046306dd"),
 "evidence/request11-linux-independent/memory-analysis.json":(123204,"6d60a463843c99ba3eb1cb30596ed7d0085f5314de77f1fb4e4df9dfdc565ccb"),
 "review-B-lineage-repair/after-audit/request11-linux-source-review.json":(125105,"d84834fa7aaa34bcbb365b0bd4ef4c6947498fa567a69918d172dff0534f1c5e"),
 "evidence/review-c-linux-request11/report.json":(66553,"37b91339a5cf53b5dd0c8df0ebedda8d33fc1df717d947fe2065e54c61ce1c95"),
}
core.OWNED=(*core.OWNED,SEAL)
core.MAX_DISK=6*1024**3
core.MAX_EXPANDED=MAX_STAGE
sys.dont_write_bytecode=True

def load_manifest():
    with MANIFEST.open("rb") as stream:raw=stream.read(512*1024+1)
    core.require(len(raw)<=512*1024,"seal manifest size")
    m=json.loads(raw)
    core.require(m["schema"]=="cybersand-goblin-passive-phase2-manifest-v1" and m["activation_enabled"] is True,"seal activation disabled")
    core.require(m["qualified_source"]==core.SOURCE and m["qualified_tree"]==core.TREE,"qualified source changed")
    core.require(m["phase1_source"]==PHASE1_SOURCE and m["stage_artifact"]==
       {"id":STAGE_ID,"run_id":STAGE_RUN,"bytes":STAGE_BYTES,"sha256":STAGE_SHA},"fixed stage identity changed")
    core.require(re.fullmatch("[a-f0-9]{40}",m["results_commit"]) and re.fullmatch("[a-f0-9]{40}",m["results_tree"]),"RESULTS source shape")
    docs=m["documents"]
    core.require(6<=len(docs)<=24 and REQUIRED_DOCS.issubset({d["path"] for d in docs}),"required owner documentation missing")
    for d in docs:
        p=core.safe_name(d["path"])
        core.require(d["path"] in REQUIRED_DOCS or
          (d["path"].startswith("tools/gip014/evidence/passive/") and p.suffix in (".json",".log",".md")),
          "document outside closed source/review catalogue")
        core.require(type(d["bytes"]) is int and 0<d["bytes"]<=2*1024**2 and
          re.fullmatch("[a-f0-9]{40}",d["git_blob"]) and re.fullmatch("[a-f0-9]{64}",d["sha256"]),"document identity")
    core.require(sum(d["bytes"] for d in docs)<=MAX_COMPACT,"documentation closure bound")
    return m,raw

def download_stage():
    meta=core.api("/repos/techrote/cybersand/actions/artifacts/"+str(STAGE_ID))
    wr=meta.get("workflow_run",{})
    core.require(meta.get("id")==STAGE_ID and meta.get("size_in_bytes")==STAGE_BYTES
       and meta.get("digest")=="sha256:"+STAGE_SHA and not meta.get("expired")
       and wr.get("id")==STAGE_RUN and wr.get("head_sha")==PHASE1_SOURCE,"stage metadata identity")
    target=core.local(SEAL/"phase1-stage-original.zip");partial=target.with_suffix(".zip.partial")
    core.require(not target.exists() and not partial.exists(),"stage download target exists")
    url=core.api("/repos/techrote/cybersand/actions/artifacts/"+str(STAGE_ID)+"/zip",redirect=True)
    response,host=core.storage(url)
    started=time.monotonic();h=hashlib.sha256();count=0
    with response,partial.open("xb") as out:
        for block in iter(lambda:response.read(1024*1024),b""):
            count+=len(block)
            core.require(count<=STAGE_BYTES and count<=MAX_STAGE and time.monotonic()-started<=600,"stage transfer bound")
            out.write(block);h.update(block)
    core.require(count==STAGE_BYTES and h.hexdigest()==STAGE_SHA,"stage actual bytes changed")
    os.link(partial,target);partial.unlink()
    core.json_new(SEAL/"download.json",{"artifact_id":STAGE_ID,"run_id":STAGE_RUN,"source_commit":PHASE1_SOURCE,
       "bytes":count,"sha256":h.hexdigest(),"storage_host":host,"elapsed_seconds":time.monotonic()-started})
    # No token is passed to the builder or any later child.
    os.environ.pop(core.TOKEN_NAME,None)
    return target

def restore_stage(path):
    for name in STAGE_ROOTS:
        target=ROOT/name
        core.require(not target.exists() and not target.is_symlink(),"stage restoration would overwrite evidence")
    with zipfile.ZipFile(path) as z:
        for item in z.infolist():
            p=core.safe_name(item.filename)
            core.require(p.parts[0] in STAGE_ROOTS,"stage contains an unapproved root")
    inspected=core.inspect_zip(path,ROOT)
    lookup={x["member"]:x for x in inspected["files"]}
    index_name="passive-supervision/passive-final-index.json"
    core.require(index_name in lookup,"stage closure index missing")
    index=core.read_json(ROOT/index_name,4*1024**2)
    core.require(index["schema"]=="cybersand-goblin-passive-final-index-v1"
       and index["source_commit"]==core.SOURCE and index["source_tree"]==core.TREE
       and index["no_new_gameplay"] is True,"stage index source")
    rows=index["files"]
    core.require(len(rows)<=10000 and len({x["path"] for x in rows})==len(rows),"stage index duplicate/count")
    core.require(set(lookup)=={x["path"] for x in rows}|{index_name},"stage/index complete member closure")
    for item in rows:
        recorded=lookup[item["path"]]
        core.require(recorded["bytes"]==item["bytes"] and recorded["sha256"]==item["sha256"],"stage indexed bytes changed")
    original_manifest_raw=(HERE/"phase1-manifest.json").read_bytes()
    core.require(core.git_oid(original_manifest_raw)==PHASE1_MANIFEST,"activated phase1 manifest changed")
    core.require(core.git_oid((HERE/"passive_evidence.py").read_bytes())==PHASE1_DRIVER,"phase1 driver bytes changed")
    p1=json.loads(original_manifest_raw)
    result=core.read_json(EVIDENCE/"passive-phase1-result.json")
    core.require(result["status"]=="reviews_pass" and result["original_artifacts_verified"]==13
       and result["original_compressed_bytes_verified"]==661216192
       and result["driver"]["driver_commit"]==PHASE1_SOURCE and result["driver"]["driver_tree"]==PHASE1_TREE
       and result["source_commit"]==core.SOURCE and result["source_tree"]==core.TREE,"phase1 result/source contract")
    core.require(len(result["reviews"])==5 and all(r["process"]["status"]=="pass"
       and not r["process"]["surviving_owned_pids"] and not r["process"]["interrupted"] for r in result["reviews"]),
       "phase1 fixed reader receipt failure")
    for row in p1["artifacts"]:
        relative=Path(row["path"]).relative_to(ROOT).as_posix()
        actual=lookup[relative]
        core.require(actual["bytes"]==row["bytes"] and actual["sha256"]==row["sha256"],"original artifact closure")
    for name,(size,sha) in REPORTS.items():
        core.require(lookup[name]["bytes"]==size and lookup[name]["sha256"]==sha,"adjudicated report bytes changed")
    receipt={"status":"pass","stage_artifact_id":STAGE_ID,"stage_sha256":STAGE_SHA,"members":len(lookup),
       "expanded_bytes":inspected["expanded_bytes"],"index_sha256":lookup[index_name]["sha256"],
       "originals":13,"original_bytes":661216192,"report_identities":REPORTS,
       "source_commit":core.SOURCE,"source_tree":core.TREE,"no_reader_rerun":True}
    core.json_new(SEAL/"stage-closure.json",receipt)
    return p1,lookup

def zip_info(name):
    core.safe_name(name)
    value=zipfile.ZipInfo(name,date_time=(2026,11,25,0,0,0))
    value.compress_type=zipfile.ZIP_DEFLATED
    value.external_attr=(stat.S_IFREG|0o644)<<16
    return value

def compact_bundle(target, entries, scope):
    core.require(not target.exists(),"compact output exists")
    core.require(1<=len(entries)<=1000 and len({name.casefold() for name,_ in entries})==len(entries),"compact file catalogue")
    total=sum(len(raw) for _,raw in entries)
    core.require(total<=32*1024**2,"compact expanded byte bound")
    records=[{"path":name,"bytes":len(raw),"sha256":core.fingerprint(raw)} for name,raw in entries]
    manifest=(json.dumps({"schema":"cybersand-goblin-passive-compact-v1","scope":scope,"files":records},sort_keys=True,indent=2)+"\n").encode()
    core.require(all(name!="manifest.json" for name,_ in entries),"reserved compact manifest path")
    with zipfile.ZipFile(target,"x") as z:
        z.writestr(zip_info("manifest.json"),manifest)
        for name,raw in entries:z.writestr(zip_info(name),raw)
    core.require(target.stat().st_size<=MAX_COMPACT,"compact ZIP bound")
    with zipfile.ZipFile(target) as z:
        core.require(set(z.namelist())=={"manifest.json",*(x["path"] for x in records)},"compact ZIP closure")
        for row in records:
            raw=z.read(row["path"])
            core.require(len(raw)==row["bytes"] and core.fingerprint(raw)==row["sha256"],"compact ZIP changed member")
        core.require(z.read("manifest.json")==manifest,"compact manifest changed")
    return {"path":str(target),"bytes":target.stat().st_size,"sha256":core.digest(target),
            "member":"reviews/"+target.name,"expanded_bytes":total,"files":len(entries),"scope":scope}

def documentation_snapshot(m):
    core.require(core.git(["rev-parse",m["results_commit"]+"^{tree}"],core.DRIVER).decode().strip()==m["results_tree"],"RESULTS tree identity")
    core.git(["merge-base","--is-ancestor",m["results_commit"],"HEAD"],core.DRIVER)
    entries=[]
    for row in sorted(m["documents"],key=lambda x:x["path"]):
        raw=core.git(["show",m["results_commit"]+":"+row["path"]],core.DRIVER,maximum=2*1024**2)
        core.require(len(raw)==row["bytes"] and core.git_oid(raw)==row["git_blob"]
          and core.fingerprint(raw)==row["sha256"],"RESULTS document bytes changed")
        entries.append((row["path"],raw))
    meta={"results_commit":m["results_commit"],"results_tree":m["results_tree"],
          "qualified_runtime_commit":core.SOURCE,"phase1_driver_commit":PHASE1_SOURCE,
          "scope":"Exact pre-seal RESULTS documentation; no future archive digest or DELIVERY commit is implied."}
    entries.append(("snapshot-identity.json",(json.dumps(meta,sort_keys=True,indent=2)+"\n").encode()))
    return compact_bundle(HERE/"pre-seal-RESULTS-documentation.zip",entries,meta["scope"])

def actual_review_bundle(lookup):
    prefixes=("evidence/request11-linux-independent/","evidence/review-c-linux-request11/",
              "evidence/passive-downloads/","passive-supervision/")
    exact={"evidence/passive-driver-identity.json","evidence/passive-restoration.json",
       "evidence/passive-artifact-catalogue.json","evidence/passive-phase1-result.json",
       "evidence/durable-data-archive/phase1-manifest.json","evidence/durable-data-archive/passive_evidence.py",
       "evidence/durable-data-archive/proposed-plan.json"}
    for name in ("request11-linux-source-review.json","request11-linux-source-review.log","request11-linux-source-review-process.json"):
        exact.add("review-B-lineage-repair/after-audit/"+name)
    selected=sorted(name for name in lookup if name in exact or name.startswith(prefixes))
    core.require(exact.issubset(selected),"actual review closure missing fixed inputs")
    entries=[]
    for name in selected:
        core.require(lookup[name]["bytes"]<=MAX_COMPACT,"individual compact report bound")
        raw=(ROOT/name).read_bytes()
        core.require(core.fingerprint(raw)==lookup[name]["sha256"],"actual review bytes changed")
        entries.append((name,raw))
    return compact_bundle(HERE/"passive-Linux11-actual-reviews.zip",entries,
       "Complete already-executed A/B/C reports, exact log/process receipts, download receipts and stage index; no analysis rerun.")

def reviews_from_stage(p1):
    rows=[]
    for key in ("A","B","C"):
        spec=p1["bundles"][key]
        rows.append({"path":str(HERE/spec["zip_name"]),"member":"reviews/"+spec["zip_name"],
                     "bytes":spec["zip_bytes"],"sha256":spec["zip_sha256"],
                     "scope":"Unchanged immutable specialist review bundle"})
    for item in p1["fixed_data"]:
        if Path(item["target"]).name=="build_archive.py":continue
        rows.append({"path":item["target"],"member":"reviews/"+Path(item["target"]).name,
                     "bytes":item["bytes"],"sha256":item["sha256"],"source_blob":item["git_blob"]})
    return rows

def worker():
    m,mraw=load_manifest();identity=core.check_source();mod=core.monitor()
    core.require(core.git_oid((core.DRIVER/"tools/gip014/passive_evidence.py").read_bytes())==PHASE1_DRIVER,"reviewed helper changed")
    stage=download_stage();p1,lookup=restore_stage(stage)
    for name in ("plan.json","archive-receipt.json","evidence-index.json","README.md","phase2-manifest.json","passive_seal.py"):
        core.require(not (HERE/name).exists(),"sealing metadata output already exists")
    core.require(not OUTPUT.exists() and not OUTPUT.with_suffix(".zip.partial").exists(),"final archive output exists")
    core.write_new(HERE/"phase2-manifest.json",mraw)
    core.write_new(HERE/"passive_seal.py",Path(__file__).read_bytes())
    docs=documentation_snapshot(m);actual=actual_review_bundle(lookup)
    plan=core.read_json(HERE/"proposed-plan.json")
    core.require(len(plan["existing_inputs"])==13 and {r["artifact_id"] for r in plan["existing_inputs"]}==set(core.CATALOGUE),"plan original catalogue changed")
    core.require(set(m["artifact_classifications"])=={str(x) for x in core.CATALOGUE},"root adjudication catalogue missing")
    for row in plan["existing_inputs"]:
        row["classification"]=m["artifact_classifications"][str(row["artifact_id"])]
    reviews=reviews_from_stage(p1)+[docs,actual]
    for path in (HERE/"phase2-manifest.json",HERE/"passive_seal.py",HERE/"build_archive.py"):
        reviews.append({"path":str(path),"member":"reviews/"+path.name,"bytes":path.stat().st_size,"sha256":core.digest(path)})
    plan.update(status="ready_for_root_review",pending_inputs=[],review_inputs=reviews,
       compact_reviews=m["compact_review_notes"],pre_seal_results_commit=m["results_commit"],
       pre_seal_results_tree=m["results_tree"],passive_stage_artifact_id=STAGE_ID,
       passive_stage_sha256=STAGE_SHA,phase2_driver=identity)
    core.json_new(HERE/"plan.json",plan)
    core.json_new(SEAL/"input-approval.json",{"status":"root_manifest_bound","manifest_sha256":core.fingerprint(mraw),
       "plan_sha256":core.digest(HERE/"plan.json"),"results_commit":m["results_commit"],
       "original_artifacts":13,"review_inputs":len(reviews),"archive_bytes_not_yet_known":True})
    builder=HERE/"build_archive.py"
    core.require(core.digest(builder)==core.BUILDER_SHA,"unchanged builder identity")
    result=mod.execute([sys.executable,"-B",str(builder)],core.clean_env(),SEAL/"builder.log",
        180,cwd=ROOT,memory_limit_mib=512)
    core.json_new(SEAL/"builder-process.json",result)
    if result.get("interrupted"):raise KeyboardInterrupt()
    core.require(result["status"]=="pass" and not result["surviving_owned_pids"],"passive builder did not qualify")
    receipt=core.read_json(HERE/"archive-receipt.json")
    core.require(receipt["status"]=="pass" and receipt["original_artifact_count"]==13
       and receipt["review_count"]==len(reviews) and receipt["post_write_member_hashes_verified"] is True
       and receipt["all_original_bytes_preserved"] is True
       and OUTPUT.stat().st_size==receipt["bytes"] and core.digest(OUTPUT)==receipt["sha256"],"final archive custody")
    final={"schema":"cybersand-goblin-passive-phase2-result-v1","status":"pass",
       "qualified_source":core.SOURCE,"qualified_tree":core.TREE,
       "phase1_source":PHASE1_SOURCE,"phase1_artifact_id":STAGE_ID,"phase1_sha256":STAGE_SHA,
       "results_commit":m["results_commit"],"results_tree":m["results_tree"],"driver":identity,
       "archive":receipt,"builder_process":result,"no_new_gameplay":True,"reader_reruns":0,
       "original_artifact_redownloads":0,"missing_historical_bytes":p1["missing_historical_bytes"],
       "library_upload_performed":False}
    core.json_new(SEAL/"result.json",final)
    print("PASSIVE_SEAL_RESULT "+json.dumps(final,sort_keys=True),flush=True)
    return 0

def main():
    if sys.argv[1:]==["--worker"]:
        try:return worker()
        except KeyboardInterrupt:
            core.json_new(SEAL/"cancelled.json",{"status":"cancelled","reader_reruns":0});return 130
        except Exception as error:
            message=str(error) if isinstance(error,core.SafeFailure) else "Unexpected "+type(error).__name__+"; private details withheld"
            core.json_new(SEAL/"failure.json",{"status":"failure","message":message,"reader_reruns":0})
            print("PASSIVE_SEAL_FAILURE "+json.dumps({"message":message}),flush=True);return 2
    core.require(not sys.argv[1:] and ROOT.is_dir() and not ROOT.is_symlink(),"fixed seal invocation/root")
    core.require(not SEAL.exists(),"seal requires a fresh owned directory")
    SEAL.mkdir()
    signal.signal(signal.SIGTERM,lambda *_:(_ for _ in ()).throw(KeyboardInterrupt()))
    signal.signal(signal.SIGALRM,lambda *_:(_ for _ in ()).throw(KeyboardInterrupt()))
    signal.alarm(1500)
    core.check_source();mod=core.monitor()
    cancel=SEAL/"resource-stop";done=threading.Event();fence={}
    def watch():
        while not done.wait(.5):
            try:core.measure()
            except Exception as error:
                fence["failure"]=str(error) if isinstance(error,core.SafeFailure) else type(error).__name__
                if not cancel.exists():core.write_new(cancel,b"passive seal resource bound\n")
                return
    thread=threading.Thread(target=watch,daemon=True);thread.start()
    result=None
    try:
        env=core.clean_env()
        for key in ("GITHUB_WORKSPACE","GITHUB_SHA",core.TOKEN_NAME):
            if key in os.environ:env[key]=os.environ[key]
        result=mod.execute([sys.executable,"-B",str(Path(__file__).resolve()),"--worker"],env,
            SEAL/"worker.log",1200,cwd=core.DRIVER,memory_limit_mib=1536,cancel_path=cancel)
        core.json_new(SEAL/"process.json",result)
    finally:
        done.set();thread.join(12)
        try:measurement=core.measure()
        except Exception as error:
            measurement={"error":str(error) if isinstance(error,core.SafeFailure) else type(error).__name__}
            fence["final"]=measurement
        core.json_new(SEAL/"resource-fence.json",{"failure":fence,"measurement":measurement,"thread_alive":thread.is_alive()})
    core.require(not thread.is_alive(),"seal resource watcher survived")
    with (SEAL/"worker.log").open("rb") as stream:raw=stream.read(16*1024**2+1)
    core.require(len(raw)<=16*1024**2,"seal log bound")
    for line in raw.splitlines():
        if line.startswith(b"PASSIVE_SEAL_"):
            core.require(len(line)<=256*1024,"seal summary bound")
            print(line.decode(),flush=True)
    signal.alarm(0)
    print("PASSIVE_SEAL_SUPERVISOR "+json.dumps({"process":result,"resource_fence":fence},sort_keys=True),flush=True)
    if result and result.get("interrupted"):return 130
    return 0 if result and result["status"]=="pass" and not fence else 2

if __name__=="__main__":
    try:raise SystemExit(main())
    except KeyboardInterrupt:raise SystemExit(130)
    except Exception as error:
        message=str(error) if isinstance(error,core.SafeFailure) else type(error).__name__
        print("PASSIVE_SEAL_SETUP_FAILURE "+message,flush=True)
        raise SystemExit(2)
