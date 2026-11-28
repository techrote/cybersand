"""Passive fixed-catalogue evidence restoration and frozen Python analysis.

No game, editor, compiler, native library, shell, or Library upload is launched.
Phase1 preserves original artifacts and emits a proposed plan; sealing is a
separate root-approved phase after a RESULTS documentation commit.
"""
from __future__ import annotations
import argparse, base64, hashlib, importlib.util, io, json, lzma, os
from pathlib import Path, PurePosixPath
import platform, re, shutil, signal, stat, subprocess, sys, threading, time
import urllib.error, urllib.parse, urllib.request, zipfile

ROOT = Path("/home/agent/goblin002")
EVIDENCE = ROOT / "evidence"
SUPERVISION = ROOT / "passive-supervision"
ARCHIVES = EVIDENCE / "durable-data-archive"
RAW = EVIDENCE / "hosted-qualification11/linux/extracted"
SOURCE = "6f359ce2b24291ee219810773c641d53802fd31d"
TREE = "a4f389cd3cc1a21dfe3d5566703eb946b66734ed"
REPO = ROOT / "cybersand"
DRIVER = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("passive-evidence-manifest.json")
MONITOR_OID = "d6f61d20c47c95ae1c36bd73df3fd7f91608d503"
MONITOR_SHA = "3badcf6e7f04bac69a4a7bf03f6cd332a47de1abc4c05f8a9ace235ec1c6bb6d"
A_CONTRACT_OID = "d7b2165b8921fe58cf4a7df4d55156bb4986338e"
B_CONTRACT_OID = "6f47f3de8b8ee57b1e665fa17eb515fa77282e46"
C_READER_SHA = "80c3d813938a38b9028db0ed7c0e77494b466ac2f0e25b682ab60f6fe4d63745"
BUILDER_SHA = "fe0d2a6fcee1fe0d94d0385c4293d9e5b0cbebd748a225125915e22d49756456"
TOKEN_NAME = "GOBLIN_ARTIFACT_READ_TOKEN"
CATALOGUE = {
  14990308987: "hosted-qualification3/linux.zip",
  14994110507: "hosted-historical-702/historical-evidence.zip",
  14995732784: "retained-clock-request3/evidence.zip",
  14998227645: "hosted-qualification9/linux/evidence.zip",
  14994352640: "retained-clock-request1/evidence.zip",
  14995746214: "retained-clock-request2/evidence.zip",
  14997564894: "hosted-qualification9/windows.zip",
  15000115723: "hosted-qualification8/linux/evidence.zip",
  14998773016: "hosted-qualification10/linux/evidence.zip",
  15000825524: "hosted-qualification11/windows-evidence.zip",
  14958249728: "predecessor-original-windows/predecessor-qualified-windows-original.zip",
  14959436637: "predecessor-original-windows/predecessor-windows-evidence-original.zip",
  15003384515: "hosted-qualification11/linux/evidence.zip",
}
OWNED = (
 EVIDENCE, SUPERVISION, ROOT/"deliverables",
 ROOT/"review-B-lineage-repair", ROOT/"review-B-full142-5ee",
 ROOT/"review-B-action-coverage-5ee", ROOT/"review-B-decision-5ee",
)
MAX_INPUT = 2 * 1024**3
MAX_DISK = 4 * 1024**3
MIN_FREE = 2 * 1024**3
MAX_MEMBER = 256 * 1024**2
MAX_EXPANDED = 1024**3
MAX_ENTRIES = 10000
MAX_REVIEW_OUTPUT = 64 * 1024**2
START = time.monotonic()
sys.dont_write_bytecode = True

class SafeFailure(Exception):
    pass

def require(value, message):
    if not value:
        raise SafeFailure(message)

def fingerprint(raw):
    return hashlib.sha256(raw).hexdigest()

def git_oid(raw):
    return hashlib.sha1(b"blob "+str(len(raw)).encode()+b"\0"+raw).hexdigest()

def digest(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""): h.update(b)
    return h.hexdigest()

def read_json(path, maximum=32*1024**2):
    with path.open("rb") as f: raw=f.read(maximum+1)
    require(len(raw)<=maximum,"bounded JSON input exceeded")
    return json.loads(raw)

def local(path):
    path=Path(path)
    require(path.is_absolute() and ".." not in path.parts,"noncanonical write path")
    require(path==path.resolve(strict=False),"write path resolves through an alias")
    require(any(path.is_relative_to(root) for root in OWNED),"write outside fixed evidence roots")
    current=path
    while current != ROOT:
        require(not current.is_symlink(),"symlink in fixed evidence path")
        current=current.parent
    require(not ROOT.is_symlink(),"linked fixed root")
    return path

def write_new(path, raw):
    path=local(path)
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("xb") as f: f.write(raw)

def json_new(path, value):
    write_new(path,(json.dumps(value,sort_keys=True,indent=2)+"\n").encode())

def clean_env():
    # Preserve only ordinary interpreter/temp/locale inputs. No GitHub, Actions,
    # Library, proxy, upload, signing or runtime authentication reaches readers.
    keep=("PATH","LANG","LC_ALL","LC_CTYPE","SYSTEMROOT","WINDIR","TEMP","TMP","TMPDIR")
    env={k:os.environ[k] for k in keep if k in os.environ}
    env.update(PYTHONDONTWRITEBYTECODE="1",PYTHONNOUSERSITE="1",
               GIT_LFS_SKIP_SMUDGE="1",GIT_TERMINAL_PROMPT="0",
               GIT_CONFIG_GLOBAL=os.devnull,GIT_CONFIG_SYSTEM=os.devnull)
    return env

def git(args, cwd, maximum=8*1024**2):
    result=subprocess.run(["git",*args],cwd=cwd,env=clean_env(),
                          stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
    require(result.returncode==0,"fixed read-only Git command failed")
    require(len(result.stdout)<=maximum and len(result.stderr)<=65536,"Git output bound exceeded")
    return result.stdout

def load_manifest():
    with MANIFEST.open("rb") as stream:raw=stream.read(256*1024+1)
    require(len(raw)<=256*1024,"manifest bound")
    m=json.loads(raw)
    require(m["schema"]=="cybersand-goblin-passive-phase1-manifest-v1","manifest schema")
    require(m["activation_enabled"] is True and m["phase"]=="restore_analyze","phase1 activation is disabled")
    require(m["source_commit"]==SOURCE and m["source_tree"]==TREE,"qualified source mismatch")
    rows=m["artifacts"]
    require(len(rows)==13 and {r["artifact_id"] for r in rows}==set(CATALOGUE),"closed artifact catalogue mismatch")
    require(sum(r["bytes"] for r in rows)<=MAX_INPUT,"compressed catalogue bound")
    for r in rows:
        require(type(r["artifact_id"]) is int and type(r["run_id"]) is int,"artifact identity type")
        require(type(r["bytes"]) is int and 0<r["bytes"]<=256*1024**2,"artifact byte bound")
        require(re.fullmatch("[a-f0-9]{64}",r["sha256"]) and re.fullmatch("[a-f0-9]{40}",r["source_commit"]) and re.fullmatch("[a-f0-9]{40}",r["workflow_head"]),"artifact digest/source shape")
    require(rows[0]["artifact_id"]==15003384515,"current Linux evidence must be downloaded first")
    return m,raw

def check_source():
    checkout=Path(os.environ["GITHUB_WORKSPACE"])/"qualified-source"
    require(checkout.is_dir() and not checkout.is_symlink(),"fixed qualified checkout missing")
    require(git(["rev-parse","HEAD"],checkout).decode().strip()==SOURCE,"source checkout commit")
    require(git(["rev-parse","HEAD^{tree}"],checkout).decode().strip()==TREE,"source checkout tree")
    require(not git(["status","--porcelain"],checkout).strip(),"source checkout dirty")
    require(DRIVER != checkout.resolve(),"driver and qualified checkout must be separate")
    require(git(["rev-parse","HEAD"],DRIVER).decode().strip()==os.environ["GITHUB_SHA"],"driver head mismatch")
    if REPO.exists() or REPO.is_symlink():
        require(REPO.is_symlink() and REPO.resolve()==checkout.resolve(),"fixed source path already occupied")
    else:
        REPO.symlink_to(checkout,target_is_directory=True)
    return {"driver_commit":git(["rev-parse","HEAD"],DRIVER).decode().strip(),
            "driver_tree":git(["rev-parse","HEAD^{tree}"],DRIVER).decode().strip(),
            "qualified_commit":SOURCE,"qualified_tree":TREE,"qualified_dirty":False}

def monitor():
    path=REPO/"tools/gip014/owned_process.py";raw=path.read_bytes()
    require(git_oid(raw)==MONITOR_OID and fingerprint(raw)==MONITOR_SHA,"owned monitor source changed")
    spec=importlib.util.spec_from_file_location("passive_owned_process",path)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    require(mod.psutil is not None and mod.psutil.__version__=="7.2.2","pinned process monitor dependency missing")
    return mod

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None

def api(path, redirect=False):
    require(re.fullmatch(r"/repos/techrote/cybersand/actions/artifacts/[0-9]+(?:/zip)?",path),"API path outside fixed artifact endpoint")
    token=os.environ.get(TOKEN_NAME)
    require(bool(token),"artifact read token missing")
    request=urllib.request.Request("https://api.github.com"+path,headers={
        "Authorization":"Bearer "+token,"Accept":"application/vnd.github+json",
        "X-GitHub-Api-Version":"2022-11-28","User-Agent":"cybersand-goblin-passive-evidence"})
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect())
    try:
        response=opener.open(request,timeout=30)
    except urllib.error.HTTPError as error:
        if redirect and error.code in (301,302,303,307,308):
            location=error.headers.get("Location");error.close()
            require(isinstance(location,str),"artifact redirect missing")
            return location
        code=error.code;error.close()
        raise SafeFailure("GitHub artifact API HTTP status "+str(code))
    except (urllib.error.URLError,OSError):
        raise SafeFailure("GitHub artifact API transport failure")
    with response:
        require(not redirect and response.status==200,"artifact API response shape")
        raw=response.read(2*1024**2+1)
        require(len(raw)<=2*1024**2,"artifact API metadata bound")
        return json.loads(raw)

def storage_host(url):
    try:
        parsed=urllib.parse.urlsplit(url)
        host=(parsed.hostname or "").lower()
        valid=parsed.scheme=="https" and not parsed.username and not parsed.password
        valid=valid and parsed.port in (None,443) and not parsed.fragment
    except (ValueError,TypeError):
        raise SafeFailure("malformed artifact storage redirect")
    require(valid,"unsafe artifact storage redirect")
    require(re.fullmatch(r"productionresultssa[0-9]+\.blob\.core\.windows\.net",host)
            is not None,"artifact redirect host not in fixed GitHub storage allowlist")
    return host

def storage(url):
    # Fresh unauthenticated request; redirects must retain the API-selected host.
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect())
    initial_host=storage_host(url)
    for _ in range(4):
        host=storage_host(url)
        require(host==initial_host,"cross-host artifact storage redirect")
        request=urllib.request.Request(url,headers={"User-Agent":"cybersand-goblin-passive-evidence","Accept":"application/octet-stream"})
        try:
            response=opener.open(request,timeout=30)
        except urllib.error.HTTPError as error:
            if error.code in (301,302,303,307,308):
                next_url=error.headers.get("Location");error.close()
                require(isinstance(next_url,str),"storage redirect missing")
                url=urllib.parse.urljoin(url,next_url)
                continue
            code=error.code;error.close()
            raise SafeFailure("Artifact storage HTTP status "+str(code)+" on "+host)
        except (urllib.error.URLError,OSError):
            raise SafeFailure("Artifact storage transport failure on "+host)
        require(response.status==200,"artifact storage response status")
        return response,host
    raise SafeFailure("artifact storage redirect count exceeded")

def safe_name(name):
    require(isinstance(name,str) and name and "\0" not in name and "\\" not in name and ":" not in name,"unsafe archive name")
    trimmed=name[:-1] if name.endswith("/") else name
    p=PurePosixPath(trimmed)
    require(trimmed and not p.is_absolute() and all(s not in ("",".","..") for s in trimmed.split("/"))
            and p.as_posix()==trimmed,"noncanonical archive path")
    return p

def inspect_zip(path, extraction=None):
    seen=set();nodes={};records=[];expanded=0
    with zipfile.ZipFile(path) as z:
        infos=z.infolist()
        require(len(infos)<=MAX_ENTRIES,"archive entry count exceeded")
        for item in infos:
            name=item.filename;p=safe_name(name);canonical=p.as_posix()
            require(canonical.casefold() not in seen,"duplicate/case-aliased archive member")
            seen.add(canonical.casefold())
            for index in range(1,len(p.parts)+1):
                node="/".join(p.parts[:index]);key=node.casefold()
                is_dir=index<len(p.parts) or item.is_dir()
                if key in nodes:
                    require(nodes[key]==(node,True) and is_dir,"archive parent/alias collision")
                else:nodes[key]=(node,is_dir)
            mode=stat.S_IFMT(item.external_attr>>16)
            require(mode in (0,stat.S_IFREG,stat.S_IFDIR) and not item.flag_bits&1,"special/encrypted archive member")
            require(mode!=stat.S_IFDIR or item.is_dir(),"archive directory encoding mismatch")
            require(item.compress_type in (zipfile.ZIP_STORED,zipfile.ZIP_DEFLATED),"unsupported archive compression")
            require(0<=item.file_size<=MAX_MEMBER,"archive member size exceeded")
            expanded+=item.file_size
            require(expanded<=MAX_EXPANDED,"archive expansion exceeded")
        for item in infos:
            if item.is_dir():
                require(item.file_size==0,"nonempty archive directory")
                continue
            target=local(extraction/item.filename) if extraction else None
            if target:target.parent.mkdir(parents=True,exist_ok=True)
            h=hashlib.sha256();count=0
            with z.open(item) as source:
                output=target.open("xb") if target else None
                try:
                    for b in iter(lambda:source.read(1024*1024),b""):
                        count+=len(b);require(count<=item.file_size,"streamed member bound")
                        h.update(b)
                        if output:output.write(b)
                finally:
                    if output:output.close()
            require(count==item.file_size,"archive member truncated")
            records.append({"member":item.filename,"bytes":count,"sha256":h.hexdigest()})
    return {"members":len(records),"expanded_bytes":expanded,"crc_path_and_size_checks":True,
            "extracted":extraction is not None,"files":records}

def download(row):
    ident=row["artifact_id"];meta=api("/repos/techrote/cybersand/actions/artifacts/"+str(ident))
    require(meta.get("id")==ident and meta.get("size_in_bytes")==row["bytes"] and not meta.get("expired"),"artifact metadata identity/expiry")
    require(meta.get("digest")=="sha256:"+row["sha256"],"artifact metadata digest")
    wr=meta.get("workflow_run",{})
    require(wr.get("id")==row["run_id"] and wr.get("head_sha")==row["workflow_head"],"artifact workflow/source mismatch")
    target=local(EVIDENCE/CATALOGUE[ident]);partial=local(target.with_suffix(".zip.partial"))
    target.parent.mkdir(parents=True,exist_ok=True)
    require(not target.exists() and not partial.exists(),"duplicate download target")
    url=api("/repos/techrote/cybersand/actions/artifacts/"+str(ident)+"/zip",redirect=True)
    response,host=storage(url);count=0;h=hashlib.sha256();started=time.monotonic()
    with response,partial.open("xb") as out:
        for b in iter(lambda:response.read(1024*1024),b""):
            count+=len(b)
            require(count<=row["bytes"] and time.monotonic()-started<=240,"artifact transfer bound")
            out.write(b);h.update(b)
    require(count==row["bytes"] and h.hexdigest()==row["sha256"],"downloaded artifact does not match fixed bytes")
    os.link(partial,target);partial.unlink()
    inspected=inspect_zip(target,RAW if ident==15003384515 else None)
    receipt={"artifact_id":ident,"run_id":row["run_id"],"workflow_head":row["workflow_head"],"source_commit":row["source_commit"],
             "bytes":count,"sha256":h.hexdigest(),"storage_host":host,"path":str(target),
             "elapsed_seconds":round(time.monotonic()-started,3),**inspected}
    json_new(EVIDENCE/"passive-downloads"/(str(ident)+".json"),receipt)
    print("PASSIVE_ARTIFACT "+json.dumps({k:receipt[k] for k in ("artifact_id","run_id","source_commit","bytes","sha256","members","expanded_bytes","extracted")}),flush=True)
    return receipt

def blob_file(relative, oid, sha, size):
    path=DRIVER/relative
    require(path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(DRIVER),"anchored data path")
    with path.open("rb") as stream:raw=stream.read(size+1)
    require(len(raw)==size and git_oid(raw)==oid and fingerprint(raw)==sha,"anchored data bytes changed")
    return raw

def contract(text, oid):
    require(git_oid(text.encode())==oid,"frozen contract bytes changed")
    return json.loads(text)

def restore_bundle(spec, selections):
    raw=blob_file(spec["driver_path"],spec["git_blob"],spec["sha256"],spec["bytes"])
    if spec["format"]=="xz":
        dec=lzma.LZMADecompressor(memlimit=128*1024**2)
        data=dec.decompress(raw,max_length=8*1024**2+1)
        require(dec.eof and not dec.unused_data and len(data)<=8*1024**2,"bounded XZ closure")
    else:
        require(spec["format"]=="zip","bundle format")
        data=raw
    require(len(data)==spec["zip_bytes"] and fingerprint(data)==spec["zip_sha256"],"review ZIP identity")
    destination=ARCHIVES/spec["zip_name"];write_new(destination,data)
    # Validate every passive bundle member, not just the files selected to run.
    inspected=inspect_zip(destination)
    require(sum(r["sha256"]==spec["manifest_sha256"] for r in inspected["files"])==1,"review ZIP manifest identity")
    lookup={r["member"]:r for r in inspected["files"]}
    restored=[]
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for item in selections:
            require(item["member"] in lookup,"fixed restored member missing")
            raw=z.read(item["member"])
            require(fingerprint(raw)==item["sha256"],"fixed restored source hash")
            if "bytes" in item:require(len(raw)==item["bytes"],"fixed restored source size")
            if "git_blob" in item:require(git_oid(raw)==item["git_blob"],"fixed restored Git blob")
            target=Path(item["target"])
            require(target.is_relative_to(ROOT) and target!=REPO and not target.is_relative_to(REPO),"restore cannot target qualified checkout")
            write_new(target,raw)
            restored.append({"path":str(target),"member":item["member"],"bytes":len(raw),"sha256":fingerprint(raw)})
    return {"bundle":spec["zip_name"],"sha256":spec["zip_sha256"],"restored":restored,"all_members_checked":len(lookup)}

def fixed_review(mod, ident, argv, cwd, log, receipt, seconds, memory, expected_sha, report=None):
    script=Path(argv[2] if argv[1]=="-B" else argv[1])
    require(digest(script)==expected_sha,"executable reader source changed before launch")
    for p in (log,receipt,report):
        if p is not None:
            local(Path(p));require(not Path(p).exists(),"existing review output would be overwritten")
    if Path(cwd)!=ROOT:local(Path(cwd)).mkdir(parents=True,exist_ok=True)
    result=mod.execute(argv,clean_env(),Path(log),seconds,cwd=Path(cwd),memory_limit_mib=memory)
    json_new(Path(receipt),result)
    require(digest(script)==expected_sha,"executable reader source changed during review")
    print("PASSIVE_REVIEW "+json.dumps({"id":ident,"process":result},sort_keys=True),flush=True)
    if result.get("interrupted") or result["status"]=="cancelled":raise KeyboardInterrupt()
    return result

def memory_preflight(a):
    directory=RAW/"memory-experiment"
    if not directory.is_dir():
        return {"status":"not_attempted","reason":"actual memory experiment directory absent"}
    expected={k:v["sha256"] for k,v in a["reader_closures"]["memory"].items()}
    checked=[];missing=[]
    for name in ("experiment-owner.json","experiment.json"):
        path=directory/name
        if not path.is_file():
            missing.append(name);continue
        value=read_json(path)
        require(isinstance(value,dict) and value.get("expected_source")==SOURCE
                and value.get("expected_tree")==TREE,"memory source/tree preflight")
        if name=="experiment.json":
            p=value.get("provenance")
            if p is None:missing.append("experiment.json:provenance")
            else:
                require(isinstance(p,dict) and p.get("source_commit")==SOURCE
                        and p.get("source_tree")==TREE and p.get("source_dirty") is False,
                        "memory clean provenance preflight")
        if "reader_sha256" in value:require(value["reader_sha256"]==expected,"memory recorded reader closure")
        else:missing.append(name+":reader_sha256")
        checked.append({"path":name,"sha256":digest(path)})
    return {"status":"missing_source_evidence" if missing else "present_source_records_checked",
            "records":checked,"missing":missing,
            "meaning":"Missing wrapper custody evidence prevents outer completeness. The frozen analyzer result is retained unchanged; no identity is synthesized."}

def transport(label, value, report=None):
    raw=json.dumps(value,sort_keys=True,separators=(",",":"))
    require(len(raw.encode())<=256*1024,"bounded existing-field projection exceeded")
    if report is not None:
        path=Path(report)
        print("PASSIVE_REPORT_"+label+" "+json.dumps({"path":str(path),"bytes":path.stat().st_size,"sha256":digest(path)},sort_keys=True),flush=True)
    print("PASSIVE_SUMMARY_"+label+" "+raw,flush=True)

def project_primary(value):
    keys=("status","source_commit","source_tree","queue_status","plan_sha256","queue_sha256","analysis_script_sha256",
          "consumed_file_manifest_sha256","analysis_programme","cohort_accounting","terminal_inventory_latest",
          "terminal_inventory_all_retained_attempts","deduplicated_observed_coverage_unions","episode_measurements","limits")
    result={k:value[k] for k in keys if k in value}
    paired=value.get("validated_standard_paired_comparison",{})
    if "all_attempt_cost" in paired:result["all_attempt_cost"]=paired["all_attempt_cost"]
    result["long_horizon_details"]=[]
    ak=("attempt_number","latest_selected","result_status","recorded_episode_classification","process_status",
        "process_exit_code","completion_marker","coverage_availability","attempted_budget_completed",
        "summary_termination","tape_validated","recorded_terminal","recorded_controller_terminal","transcript_bytes",
        "fraction_of_32MiB_transcript_limit","observed_fixture_ids","pending_action","last_row","failing_assertions",
        "row_status_counts","row_classification_counts")
    tk=("all_attempted_row_duration_usec","completed_admitted_row_duration_usec","recorded_frame_timing",
        "frame_samples_hit_cap","requested_first_last_64")
    for row in value.get("long_horizon_details",[]):
        item={k:row[k] for k in ("episode","measurements") if k in row}
        if "attempt_details" in row:
            details=row["attempt_details"]
            require(details is None or isinstance(details,dict),"primary attempt projection shape")
            item["attempt_details"]=None if details is None else {k:details[k] for k in ak if k in details}
        if "timing" in row:
            timing=row["timing"]
            require(timing is None or isinstance(timing,dict),"primary timing projection shape")
            item["timing"]=None if timing is None else {k:timing[k] for k in tk if k in timing}
        result["long_horizon_details"].append(item)
    return result

def project_memory(value):
    keys=("status","experiment_status","source_commit","planned_gameplay_episodes","retained_gameplay_results",
       "registered_gameplay_slots","not_registered_gameplay_slots","measured_slots_without_result",
       "budget_complete_valid_gameplay_episodes","retained_measured_results","retained_attempts","evidence_kind",
       "failure_kind","source_custody_failure","operator_cancelled","error","selection","cultivation",
       "training_prefix_proof","frozen_corpus_sha256","measured_episodes","hints_only_actual_choice_comparison",
       "paired_differences","terminal_inventory","process_status_inventory","tape_termination_inventory",
       "all_observed_gameplay_process_seconds_including_training","attempts_missing_process_cost","limits")
    result={k:value[k] for k in keys if k in value}
    if "provenance" in value:
        p=value["provenance"]
        require(p is None or isinstance(p,dict),"memory provenance projection shape")
        result["provenance"]=None if p is None else {k:p[k] for k in ("source_commit","source_tree") if k in p}
    pk=("status","exit_code","elapsed_seconds","peak_tree_rss_bytes","surviving_owned_pids","interrupted")
    for name in ("training_cost","supervisor","import_process"):
        if isinstance(value.get(name),dict):result[name]={k:value[name][k] for k in pk if k in value[name]}
    return result

def report_transport(label, path, projection):
    path=Path(path)
    if not path.is_file():
        transport(label,{"status":"report_missing","path":str(path)})
        return False
    try:
        value=read_json(path)
        transport(label,projection(value),path)
        return True
    except Exception as error:
        message=str(error) if isinstance(error,SafeFailure) else type(error).__name__
        transport(label,{"status":"projection_failed","path":str(path),"bytes":path.stat().st_size,
                         "sha256":digest(path),"error":message})
        return False

def artifact_attempt(row):
    try:return download(row)
    except KeyboardInterrupt:raise
    except Exception as error:
        message=str(error) if isinstance(error,SafeFailure) else "Unexpected "+type(error).__name__
        target=EVIDENCE/CATALOGUE[row["artifact_id"]]
        partial=target.with_suffix(".zip.partial")
        files=[]
        for p in (target,partial):
            if p.is_file():
                files.append({"path":str(p),"bytes":p.stat().st_size,"sha256":digest(p)})
        result={"status":"unverified_download_or_inspection","artifact_id":row["artifact_id"],
                "workflow_head":row["workflow_head"],"run_id":row["run_id"],
                "expected_bytes":row["bytes"],"expected_sha256":row["sha256"],
                "error":message,"retained_files":files}
        json_new(EVIDENCE/"passive-downloads"/(str(row["artifact_id"])+".failure.json"),result)
        print("PASSIVE_ARTIFACT_FAILURE "+json.dumps(result,sort_keys=True),flush=True)
        return result

def predecessor_metadata(receipts):
    records=[]
    for r in receipts:
        if r["artifact_id"] not in (14958249728,14959436637) or not r.get("crc_path_and_size_checks"):
            continue
        selected=[];total=0
        with zipfile.ZipFile(r["path"]) as z:
            for info in z.infolist():
                p=PurePosixPath(info.filename);name=p.name.lower()
                if info.is_dir() or not name.endswith(".json") or not ("qualification" in name or "manifest" in name):
                    continue
                if info.file_size>2*1024**2 or len(selected)>=32 or total+info.file_size>8*1024**2:
                    continue
                raw=z.read(info);json.loads(raw)
                target=EVIDENCE/"predecessor-original-windows/selected-metadata"/str(r["artifact_id"])/info.filename
                write_new(target,raw);total+=len(raw)
                selected.append({"member":info.filename,"path":str(target),"bytes":len(raw),"sha256":fingerprint(raw)})
        records.append({"artifact_id":r["artifact_id"],"outer_archive_sha256":r["sha256"],"selected":selected,
          "scope":"Bounded existing outer qualification/manifest JSON only; no binary extraction or execution. Empty selection is unavailable metadata, not a qualification claim."})
    json_new(EVIDENCE/"predecessor-original-windows/metadata-selection.json",records)

def analyze_fixed(a,b,restored,mod):
    output=EVIDENCE/"request11-linux-independent";output.mkdir()
    preflight=memory_preflight(a);json_new(output/"memory-preflight.json",preflight)
    results=[];a_started=time.monotonic();transport_ok=True
    for command in a["commands"]:
        require(time.monotonic()-a_started<=240,"A aggregate analysis time bound")
        if command["id"]=="memory7_read_only" and preflight["status"]=="not_attempted":
            results.append({"id":command["id"],"status":"not_attempted"});continue
        argv=[sys.executable,*command["argv"][1:]]
        script=Path(argv[2] if argv[1]=="-B" else argv[1])
        expected=next(r["sha256"] for r in restored[0]["restored"] if r["path"]==str(script))
        result=fixed_review(mod,command["id"],argv,command["cwd"],command["log"],command["process_receipt"],
                            60,3072,expected,command.get("report"))
        results.append({"id":command["id"],"process":result})
        require(time.monotonic()-a_started<=240,"A aggregate analysis time bound")
        require(tree_bytes(output)<=MAX_REVIEW_OUTPUT,"A aggregate analysis output bound")
        if command["id"]=="memory7_read_only":
            with Path(command["log"]).open("rb") as stream:raw=stream.read(16*1024**2+1)
            require(len(raw)<=16*1024**2,"memory diagnostic log bound")
            records=[]
            for line in raw.splitlines():
                try:value=json.loads(line)
                except (ValueError,UnicodeError):continue
                if isinstance(value,dict):records.append((line,value))
            if len(records)==1:
                write_new(Path(command["report"]),records[0][0]+b"\n")
                transport_ok=report_transport("MEMORY",command["report"],project_memory) and transport_ok
            else:
                transport("MEMORY",{"status":"report_missing_or_ambiguous","complete_JSON_objects":len(records),
                                    "raw_log_sha256":digest(Path(command["log"]))})
                transport_ok=False
        elif command["id"]=="long8_primary":
            transport_ok=report_transport("LONG8",command["report"],project_primary) and transport_ok
    lineage=b["lineage"];argv=[sys.executable,"-B",*lineage["argv"][1:]]
    results.append({"id":"B_authored_lineage","process":fixed_review(mod,"B_authored_lineage",argv,
       b["restore"]["review_root"],lineage["owned_log"],lineage["owned_process_receipt"],60,512,
       lineage["script_sha256"],lineage["out"])})
    transport_ok=report_transport("LINEAGE",lineage["out"],lambda v:v) and transport_ok
    cr=EVIDENCE/"review-c-linux-request11"
    results.append({"id":"C_custody","process":fixed_review(mod,"C_custody",[sys.executable,"-B",str(cr/"audit.py")],
       ROOT,cr/"audit.log",cr/"process.json",60,1024,C_READER_SHA,cr/"report.json")})
    transport_ok=report_transport("CUSTODY",cr/"report.json",lambda v:v) and transport_ok
    return results,transport_ok,preflight

def worker():
    m,mraw=load_manifest();identity=check_source()
    for path in OWNED:
        if path!=SUPERVISION:require(not path.exists() and not path.is_symlink(),"phase1 requires fresh owned output roots")
    EVIDENCE.mkdir();ARCHIVES.mkdir()
    mod=monitor()
    identity["runtime"]={"python_version":sys.version,"python_executable":sys.executable,
       "platform":platform.platform(),"psutil_version":mod.psutil.__version__,
       "psutil_module_path":str(Path(mod.psutil.__file__).resolve()),
       "psutil_module_sha256":digest(Path(mod.psutil.__file__)),
       "owned_monitor_sha256":MONITOR_SHA}
    json_new(EVIDENCE/"passive-driver-identity.json",{**identity,"manifest_sha256":fingerprint(mraw),"driver_sha256":digest(Path(__file__))})
    write_new(ARCHIVES/"phase1-manifest.json",mraw)
    write_new(ARCHIVES/"passive_evidence.py",Path(__file__).read_bytes())
    a=contract(m["a_contract"],A_CONTRACT_OID);b=contract(m["b_contract"],B_CONTRACT_OID)
    ar=a["restoration"];spec=m["bundles"]["A"]
    require((spec["git_blob"],spec["bytes"],spec["sha256"],spec["zip_bytes"],spec["zip_sha256"],spec["manifest_sha256"])==
       (ar["archive_blob"],ar["compressed_bytes"],ar["compressed_sha256"],ar["zip_bytes"],ar["zip_sha256"],ar["zip_manifest_sha256"]),
       "A bundle differs from frozen contract")
    bs=m["bundles"]["B"]
    require((bs["git_blob"],bs["bytes"],bs["sha256"],bs["manifest_sha256"])==
       (b["bundle"]["blob"],b["bundle"]["bytes"],b["bundle"]["sha256"],b["bundle"]["manifest_sha256"]),
       "B bundle differs from frozen contract")
    restored=[restore_bundle(spec,ar["member_map"])]
    restored.append(restore_bundle(bs,m["b_restore"]))
    restored.append(restore_bundle(m["bundles"]["C"],m["c_restore"]))
    for item in m["fixed_data"]:
        raw=blob_file(item["driver_path"],item["git_blob"],item["sha256"],item["bytes"])
        write_new(Path(item["target"]),raw)
    json_new(EVIDENCE/"passive-restoration.json",restored)
    require(digest(ARCHIVES/"build_archive.py")==BUILDER_SHA,"passive sealer bytes changed")
    receipts=[artifact_attempt(m["artifacts"][0])]
    results=[];transport_ok=False;preflight={"status":"not_attempted"}
    if receipts[0].get("crc_path_and_size_checks"):
        # Current result analysis is independent of historical download availability.
        results,transport_ok,preflight=analyze_fixed(a,b,restored,mod)
    else:
        transport("CURRENT_ANALYSIS",{"status":"not_attempted","reason":"current Linux artifact custody failed"})
    for row in m["artifacts"][1:]:receipts.append(artifact_attempt(row))
    os.environ.pop(TOKEN_NAME,None)
    json_new(EVIDENCE/"passive-artifact-catalogue.json",receipts)
    predecessor_metadata(receipts)
    for group in restored:
        for item in group["restored"]:require(digest(Path(item["path"]))==item["sha256"],"restored reader/input changed")
    source_after=check_source()
    require(source_after["qualified_dirty"] is False,"qualified source changed during passive review")
    verified=[r for r in receipts if r.get("crc_path_and_size_checks")]
    complete=len(verified)==13 and transport_ok and preflight["status"]=="present_source_records_checked" and all(r.get("process",{}).get("status")=="pass" for r in results)
    summary={"schema":"cybersand-goblin-passive-phase1-result-v1","status":"reviews_pass" if complete else "review_findings",
       "source_commit":SOURCE,"source_tree":TREE,"driver":identity,"original_artifacts_planned":13,
       "original_artifacts_verified":len(verified),"original_compressed_bytes_verified":sum(x["bytes"] for x in verified),
       "reviews":results,"summary_transport_complete":transport_ok,"memory_source_preflight":preflight,
       "new_gameplay_actions":0,"native_or_editor_processes_launched":0,"archive_assembled":False,
       "sealing_requires":"Root adjudication and an exact RESULTS documentation commit; separate phase2.",
       "missing_historical_bytes":m["missing_historical_bytes"]}
    json_new(EVIDENCE/"passive-phase1-result.json",summary)
    plan=dict(m["archive_seed_plan"])
    plan.update(status="awaiting_root_RESULTS_commit_and_actual_review_adjudication",
      pending_inputs=[{"id":"root_adjudication"},{"id":"pre_seal_RESULTS_documentation_commit"}],
      passive_phase1_result_sha256=digest(EVIDENCE/"passive-phase1-result.json"))
    json_new(ARCHIVES/"proposed-plan.json",plan)
    transport("PHASE1",summary,EVIDENCE/"passive-phase1-result.json")
    return 0 if complete else 2

def tree_bytes(root):
    total=0;count=0;started=time.monotonic()
    if not root.exists():return 0
    require(not root.is_symlink(),"owned root became linked")
    for parent,dirs,files in os.walk(root,followlinks=False):
        require(time.monotonic()-started<=10,"disk scan time bound")
        for name in dirs+files:
            p=Path(parent)/name;count+=1
            require(count<=100000,"owned tree entry bound")
            try:details=p.lstat()
            except FileNotFoundError:continue
            mode=details.st_mode
            require(not stat.S_ISLNK(mode),"owned tree link")
            if stat.S_ISREG(mode):total+=details.st_size
            elif not stat.S_ISDIR(mode):raise SafeFailure("nonregular owned output")
    return total

def measure():
    started=time.monotonic();total=0
    for root in OWNED:
        total+=tree_bytes(root)
        require(time.monotonic()-started<=10,"aggregate disk scan time bound")
    require(total<=MAX_DISK,"owned disk output bound")
    require(shutil.disk_usage(ROOT).free>=MIN_FREE,"minimum free disk reserve")
    require(tree_bytes(EVIDENCE/"request11-linux-independent")<=MAX_REVIEW_OUTPUT,"A aggregate analysis output bound")
    return {"bytes":total}

def final_index():
    rows=[]
    for root in OWNED:
        if not root.exists():continue
        for p in sorted(root.rglob("*")):
            if not p.is_file():continue
            local(p)
            if p==SUPERVISION/"passive-final-index.json":continue
            rows.append({"path":p.relative_to(ROOT).as_posix(),"bytes":p.stat().st_size,"sha256":digest(p)})
    json_new(SUPERVISION/"passive-final-index.json",{"schema":"cybersand-goblin-passive-final-index-v1","files":rows,
             "no_new_gameplay":True,"source_commit":SOURCE,"source_tree":TREE})

def main():
    if sys.argv[1:]==["--worker"]:
        try:return worker()
        except KeyboardInterrupt:
            json_new(SUPERVISION/"passive-worker-cancelled.json",{"status":"cancelled","next_child_launched":False});return 130
        except Exception as error:
            message=str(error) if isinstance(error,SafeFailure) else "Unexpected "+type(error).__name__+"; details withheld to avoid transfer credential disclosure"
            json_new(SUPERVISION/"passive-worker-failure.json",{"status":"failure","error_type":type(error).__name__,"message":message,"new_gameplay_actions":0})
            print("PASSIVE_FAILURE "+json.dumps({"type":type(error).__name__,"message":message}),flush=True);return 2
    require(not sys.argv[1:],"no arbitrary passive arguments")
    require(ROOT.is_dir() and not ROOT.is_symlink(),"workflow must create the fixed disposable parent")
    require(not SUPERVISION.exists(),"supervision path already exists")
    SUPERVISION.mkdir()
    signal.signal(signal.SIGTERM,lambda *_:(_ for _ in ()).throw(KeyboardInterrupt()))
    signal.signal(signal.SIGALRM,lambda *_:(_ for _ in ()).throw(KeyboardInterrupt()))
    signal.alarm(2100)
    check_source();mod=monitor()
    cancel=SUPERVISION/"resource-stop";stop=threading.Event();fence={}
    def watch():
        while not stop.wait(.5):
            try:measure()
            except Exception as error:
                fence["error"]=str(error) if isinstance(error,SafeFailure) else type(error).__name__
                if not cancel.exists():write_new(cancel,b"owned output/resource fence\n")
                return
    thread=threading.Thread(target=watch,daemon=True);thread.start()
    result=None
    try:
        env=clean_env()
        for key in ("GITHUB_WORKSPACE","GITHUB_SHA",TOKEN_NAME):
            if key in os.environ:env[key]=os.environ[key]
        result=mod.execute([sys.executable,"-B",str(Path(__file__).resolve()),"--worker"],env,
             SUPERVISION/"worker.log",1800,cwd=DRIVER,memory_limit_mib=4096,cancel_path=cancel)
        json_new(SUPERVISION/"process.json",result)
    finally:
        stop.set();thread.join(12)
        try:measurement=measure()
        except Exception as error:
            measurement={"error":str(error) if isinstance(error,SafeFailure) else type(error).__name__}
            fence["final"]=measurement
        json_new(SUPERVISION/"resource-fence.json",{"failure":fence,"measurement":measurement,"thread_alive":thread.is_alive()})
    require(not thread.is_alive(),"resource scanner failed to terminate")
    final_index();signal.alarm(0)
    # Worker output is file-directed; expose only our bounded JSON custody lines.
    with (SUPERVISION/"worker.log").open("rb") as stream:raw=stream.read(16*1024**2+1)
    require(len(raw)<=16*1024**2,"outer worker diagnostic bound")
    emitted=0
    for line in raw.splitlines():
        if not line.startswith(b"PASSIVE_"):continue
        require(len(line)<=256*1024+128,"summary line transport bound")
        emitted+=len(line);require(emitted<=2*1024**2,"aggregate job-log projection bound")
        print(line.decode("utf-8"),flush=True)
    print("PASSIVE_SUPERVISOR "+json.dumps({"process":result,"resource_fence":fence},sort_keys=True),flush=True)
    if result and result.get("interrupted"):return 130
    return 0 if result and result["status"]=="pass" and not fence else 2

if __name__=="__main__":
    try:raise SystemExit(main())
    except KeyboardInterrupt:raise SystemExit(130)
    except SafeFailure as error:
        print("PASSIVE_SETUP_FAILURE "+str(error),flush=True);raise SystemExit(2)
    except Exception as error:
        print("PASSIVE_SETUP_FAILURE Unexpected "+type(error).__name__+"; private transport details withheld",flush=True)
        raise SystemExit(2)
