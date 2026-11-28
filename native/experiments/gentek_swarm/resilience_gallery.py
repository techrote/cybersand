#!/usr/bin/env python3
"""Audit and render every registered SWARM-003 native material result."""
from __future__ import annotations
import argparse
import base64
from collections import Counter, defaultdict
import csv
import hashlib
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw
from gallery import PALETTE, panel, raster
from negotiated_gallery import CATEGORIES, cats, decisions, grid, semantic

DIRECTIONS = ((1,0),(0,1),(-1,0),(0,-1))
# Frozen SWARM-001/002 MOSAIC passage/paired-arch grammar. Keeping the
# accepted input table here lets the evidence reader reject a self-consistent
# but altered grammar receipt rather than trusting the candidate's copy.
FROZEN_ADJACENCY = [
    [65471,33707,31765,33707,31765,64,33707,33707,33707,31765,33707,31765,31765,31765,31765,33707],
    [65535,65511,65511,25,25,65511,65511,65511,65511,65511,65511,65511,65511,65511,65511,65511],
    [65503,34251,31253,34251,31253,34251,32,34251,34251,34251,31253,31253,31253,31253,31253,34251],
    [65535,65511,65511,25,25,65511,65511,65511,65511,65511,65511,65511,65511,65511,65511,65511]]
FROZEN_CATEGORY_IDS = [0x4D4F534149430000 + i for i in range(16)]
FIXTURES = ("stepped_diagonal","concave_intrusion","protected_corridor","foreign_solid","island","narrow_neck")
PROFILES = ("sparse_regular","branching_irregular","dense_cohesive")
HISTORICAL_POLICIES = ("full_balanced","full_preferred_heavy","full_fallback_heavy","full_single",
            "native_original","native_balanced","native_preferred_heavy","native_fallback_heavy","native_single",
            "native_receiver_single")
CAPACITY_POLICIES = ("native_receiver_single","native_receiver_six","native_receiver_eight")
POLICIES = HISTORICAL_POLICIES + CAPACITY_POLICIES[1:]
DIAGNOSTICS = ("native_receiver_hard_only",)
TITLES = {"A":"A  Independent clipping","B":"B  Frozen SWARM-001","C":"C  Full negotiated control",
          "cap0":"Hard-only diagnostic","cap1":"Geometric cap one","cap2":"Geometric cap two","cap4":"Geometric cap four",
          "full_balanced":"Full offers: 2M + 2M recovery","full_preferred_heavy":"Full offers: 3M + 1M recovery",
          "full_fallback_heavy":"Full offers: 1M + 3M recovery","full_single":"Full offers: 4M single attempt",
          "native_original":"Native admission: original schedule","native_balanced":"Native admission: 2M + 2M core",
          "native_preferred_heavy":"Native admission: 3M + 1M core","native_fallback_heavy":"Native admission: 1M + 3M core",
          "native_single":"Native admission: 4M single",
          "native_receiver_single":"Required native receivers: 4M single",
          "native_receiver_six":"E6: six optional reservations, 4M single",
          "native_receiver_eight":"E8: eight optional reservations, 4M single",
          "native_receiver_hard_only":"Matched native-receiver hard-only"}

def causal_control_policy(policy):
    return "native_receiver_hard_only" if policy in (*CAPACITY_POLICIES,"native_receiver_hard_only") else "cap0"

def expected_options(policy):
    if policy=="native_receiver_hard_only":
        return {"admission":"compatibility-hard-only","schedule":"single-preferred","fallback":"hard-only","receivers":"required-original-native","optional_capacity":4}
    suffix=policy.removeprefix("native_").removeprefix("full_")
    schedule={"balanced":"balanced-recovery","preferred_heavy":"preferred-heavy","fallback_heavy":"fallback-heavy",
              "single":"single-preferred","receiver_single":"single-preferred","receiver_six":"single-preferred",
              "receiver_eight":"single-preferred","original":"original"}[suffix]
    return {"admission":"full" if policy.startswith("full_") else "compatibility-four","schedule":schedule,
            "fallback":"hard-only" if policy.startswith("full_") or policy=="native_original" else "native-core-two",
            "receivers":"required-original-native" if policy in CAPACITY_POLICIES else "closed-only",
            "optional_capacity":6 if policy=="native_receiver_six" else 8 if policy=="native_receiver_eight" else 4}

def policy_options_match(actual,policy,continuation):
    wanted=expected_options(policy)
    if not continuation:
        wanted.pop("optional_capacity")
    return actual==wanted

class Audit:
    def __init__(self):
        self.checks = self.paths = self.assignments = self.adjacencies = 0
    def require(self, condition, message):
        self.checks += 1
        if not condition:
            raise ValueError(message)

def metric(n,key):
    return n["metrics"].get(key,0)

def case_key(n):
    q=n["frame_request"]
    return f"{q['fixture']}_{q['profile']['name']}_{q['seed']}"

def native_sha(cells):
    return hashlib.sha256(b"".join(int(c).to_bytes(2,"little") for c in cells)).hexdigest()

def final_active_optional(doc):
    if doc.get("schema")==4:
        successful=[a for a in doc["trace"]["solver"]["attempts"] if a["solver"]["status"]=="complete"]
        return set(successful[-1]["optional_ids"]) if successful else set()
    n=doc.get("candidate",doc)
    if n["mosaic"]["result"]["status"]!="complete" or any(d["fallback"] for d in n["mosaic"]["domains"]):
        return set()
    required={s["id"] for s in n["frame"]["slots"] if s["required"] or s["hard"]}
    return {r["slot_id"] for r in n["mosaic"]["responses"] if r["admitted"] and r["slot_id"] not in required}

def assignment_valid(categories,domains,width,height,adjacency):
    if len(categories)!=width*height or len(domains)!=len(categories):
        return False
    for i,selected in enumerate(categories):
        if not 0<=selected<16 or not domains[i]&(1<<selected):
            return False
        x,y=i%width,i//width
        for direction,(dx,dy) in enumerate(DIRECTIONS):
            xx,yy=x+dx,y+dy
            if 0<=xx<width and 0<=yy<height:
                other=categories[yy*width+xx]
                if not 0<=other<16 or not adjacency[direction][selected]&(1<<other):
                    return False
    return True

def audit_solver(doc,audit):
    n,trace=doc["candidate"],doc["trace"]["solver"]
    require=audit.require
    label=case_key(n)
    require(trace["seed"]==n["mosaic_request"]["seed"],label+": seed changed")
    require(trace["aggregate_limit"]==n["mosaic_request"]["limits"]["solver_work"]==4_000_000,label+": categorical budget changed")
    require(trace["allocated_limit"]==trace["aggregate_limit"],label+": declared preferred/reserved allocation differs from ceiling")
    attempts=trace["attempts"]
    require(len(attempts)<=2,label+": more than two attempts")
    require(sum(a["solver"]["work_limit"] for a in attempts)<=4_000_000,label+": attempt limits exceed ceiling")
    require(sum(a["solver"]["work_limit"] for a in attempts if a["solver"]["attempted"])==trace["attempted_limit"],label+": attempted limit mismatch")
    require(trace["adjacency"]==FROZEN_ADJACENCY,label+": frozen native grammar changed")
    require(trace["category_ids"]==FROZEN_CATEGORY_IDS,label+": frozen category identity changed")
    mandatory={s["id"] for s in n["frame"]["slots"] if s["required"] or s["hard"]}
    slots={s["id"] for s in n["frame"]["slots"]}
    require(mandatory<=set(doc["trace"]["primary_selected_ids"]),label+": required reservation omitted")
    require(mandatory<=set(doc["trace"]["final_authorized_ids"]),label+": required join authority omitted")
    require(set(doc["trace"]["final_authorized_ids"])<=slots,label+": foreign join authority")
    require(set(doc["trace"]["final_authorized_ids"])==set(doc["trace"]["primary_selected_ids"]),label+": join authority expanded or removed after admission")
    admission=doc["trace"]["admission"]
    capacity=8 if doc["options"]["admission"]=="full" else 0 if doc["options"]["admission"]=="compatibility-hard-only" else doc["options"].get("optional_capacity",4)
    require(len(slots)<=8,label+": reservation universe enlarged")
    require(admission["optional_capacity"]==capacity,label+": local receipt changed the declared capacity")
    require(len(set(doc["trace"]["primary_selected_ids"])-mandatory)<=capacity,label+": optional capacity exceeded")
    require(len(set(admission["fallback_ids"])-mandatory)<=admission["fallback_optional_capacity"],label+": fallback capacity exceeded")
    completed=[]
    for i,attempt in enumerate(attempts):
        receipt=attempt["solver"]
        require(set(attempt["optional_ids"])<=slots-mandatory,label+": invalid optional identity")
        require(receipt["work_observed"]==(receipt["work"] is not None),label+": invented unavailable work")
        if receipt["attempted"] and receipt["status"]!="complete":
            require(receipt["work"] is None,label+": unavailable failed-attempt work")
        if receipt["work"] is not None:
            require(0<=receipt["work"]<=receipt["work_limit"],label+": work exceeds allocation")
        if i:
            require(attempts[i-1]["solver"]["status"] in ("unsat","exhausted") and attempt["fallback"],label+": invalid fallback trigger")
        if receipt["status"]=="complete":
            completed.append(attempt)
            require(assignment_valid(attempt["categories"],attempt["domains"],trace["width"],trace["height"],trace["adjacency"]),label+": illegal categorical assignment")
            audit.assignments+=1
            audit.adjacencies+=2*((trace["width"]-1)*trace["height"]+(trace["height"]-1)*trace["width"])
    if n["mosaic"]["result"]["status"]=="complete":
        require(len(completed)==1,label+": missing or multiple selected assignments")
        require(completed[-1]["categories"]==n["mosaic"]["categories"],label+": selected assignment changed")
        require(completed[-1]["domains"]==[d["modified_domain"] for d in n["mosaic"]["domains"]],label+": effective domains changed")
    if not attempts:
        require(n["mosaic"]["result"]["status"]!="complete",label+": complete without a solve")

def audit_receivers(doc,full,audit):
    """Check local receiver receipts without using a solver outcome as a rule."""
    n=doc["candidate"];require=audit.require;label=case_key(n)
    records=doc["trace"].get("receivers",[])
    if doc["options"].get("receivers","closed-only")=="closed-only":
        require(not records,label+": closed-only policy changed receiving decisions")
        return
    slots={s["id"]:s for s in n["frame"]["slots"]}
    required={i for i,s in slots.items() if s["hard"] or s["required"]}
    original={r["slot_id"]:r for r in full["mosaic"]["responses"]}
    responses={r["slot_id"]:r for r in n["mosaic"]["responses"]}
    original_domains=[d["original_domain"] for d in full["mosaic"]["domains"]]
    require([d["original_domain"] for d in n["mosaic"]["domains"]]==original_domains,label+": receiver policy altered original native domains")
    complete_preparation=bool(doc["trace"]["solver"]["attempts"]) or n["mosaic"]["result"]["status"]!="exhausted"
    ids=[r["slot_id"] for r in records]
    require(ids==sorted(set(ids)) and set(ids)<=required,label+": unstable or optional receiver amendment")
    if complete_preparation:
        require(set(ids)==required,label+": missing required receiver receipt")
    for slot_id in set(slots)-required:
        for field in ("slot_id","tile","contact","facing","compatible_domain"):
            require(responses[slot_id][field]==original[slot_id][field],label+": optional receiver geometry changed")
    width,height=doc["trace"]["solver"]["width"],doc["trace"]["solver"]["height"]
    current={i:dict(r) for i,r in original.items()}
    for r in records:
        slot_id=r["slot_id"];slot=slots[slot_id];old=original[slot_id]
        for field in ("tile","contact","compatible_domain","admitted"):
            require(r["original_"+field]==old[field],label+": original required receiver differs from frozen control")
        require(len(r["faces"])<=64 and r["work"]>=0,label+": receiver receipt bound exceeded")
        if not complete_preparation:
            continue
        pools=list(original_domains);other_hard=set()
        for other_id in sorted(required-{slot_id}):
            peer=current[other_id]
            if peer["admitted"]:
                tile=peer["tile"]
                pools[tile]=pools[tile]&peer["compatible_domain"] if tile in other_hard else peer["compatible_domain"]
                other_hard.add(tile)
        def support(tile,mask):
            if tile in other_hard:
                mask &= pools[tile]
            result=0;x,y=tile%width,tile//width
            for category in range(16):
                if not mask&(1<<category):
                    continue
                legal=True
                for direction,(dx,dy) in enumerate(DIRECTIONS):
                    xx,yy=x+dx,y+dy
                    if 0<=xx<width and 0<=yy<height:
                        neighbor=pools[yy*width+xx]
                        legal &= any(neighbor&(1<<b) and FROZEN_ADJACENCY[direction][category]&(1<<b) and
                                     FROZEN_ADJACENCY[(direction+2)%4][b]&(1<<category) for b in range(16))
                if legal:
                    result |= 1<<category
            return result
        original_support=support(old["tile"],old["compatible_domain"]) if old["admitted"] else 0
        require(r["original_supported_domain"]==original_support,label+": wrong original receiver support")
        ex,ey,ew,eh=slot["envelope"]
        selected_faces=[]
        for face in r["faces"]:
            x,y=face["contact"];tile=face["tile"]
            require(ex<=x<ex+ew and ey<=y<ey+eh,label+": receiver alternative left original envelope")
            require(0<=tile<len(original_domains) and face["original_domain"]==original_domains[tile],label+": receiver alternative changed original domain")
            facing=slot["facing"]
            termination=9 if facing[0]>0 else 10 if facing[0]<0 else 11 if facing[1]>0 else 12
            allowed=face["original_domain"]|(1<<8)|(1<<termination)
            require(face["compatible_domain"] and not(face["compatible_domain"]&~allowed),label+": unauthored receiver category")
            require(face["supported_domain"]==support(tile,face["compatible_domain"]),label+": incorrect local support mask")
            sx=max(min(slot["a"][0],slot["b"][0]),min(x,max(slot["a"][0],slot["b"][0])))
            sy=max(min(slot["a"][1],slot["b"][1]),min(y,max(slot["a"][1],slot["b"][1])))
            require(face["distance"]==abs(x-sx)+abs(y-sy),label+": incorrect receiver distance")
            if face["selected"]:
                selected_faces.append(face)
        if original_support:
            require(not r["changed"] and r["points_examined"]==0 and len(r["faces"])==1,label+": supported old face was searched or changed")
        else:
            require(r["points_examined"]==ew*eh,label+": incomplete original-envelope scan")
        supported=[face for face in r["faces"] if face["supported_domain"]]
        if supported:
            best=min(supported,key=lambda f:(-f["supported_domain"].bit_count(),f["distance"],*f["contact"],f["tile"]))
            require(selected_faces==[best],label+": required receiver selection violates registered ordering")
            for field in ("tile","contact","compatible_domain","supported_domain"):
                require(r["selected_"+field]==best[field],label+": selected receiver differs from selected face")
            current[slot_id].update(tile=best["tile"],contact=best["contact"],compatible_domain=best["compatible_domain"],admitted=True)
        else:
            require(not selected_faces and not r["changed"],label+": unsupported receiver was selected")
        for field in ("tile","contact","compatible_domain"):
            require(responses[slot_id][field]==r["selected_"+field],label+": candidate discarded recorded required receiver")
        changed=not old["admitted"] and bool(supported) or any(r["selected_"+field]!=old[field] for field in ("tile","contact","compatible_domain"))
        require(r["changed"]==changed,label+": required receiver change was hidden or invented")
    work=metric(n["mosaic"]["result"],"resilience_required_receiver_work")
    require(sum(r["work"] for r in records)<=work,label+": required receiver work uncharged")
    require(sum(r["changed"] for r in records)==metric(n["mosaic"]["result"],"resilience_required_receiver_changed"),label+": required receiver change count differs")

def audit_native(n,audit,*,no_receptor):
    require=audit.require
    q,mq=n["frame_request"],n["mosaic_request"]
    label=case_key(n);count=q["width"]*q["height"]
    frame,mosaic=n["final_frame"],n["final_mosaic"]
    core,pframe,pmosaic=n["frame"]["core"],n["frame"]["result"],n["mosaic"]["result"]
    vectors=(n["cells"],n["planned_cells"],frame["cells"],mosaic["cells"],core["cells"],
             pframe["cells"],pmosaic["cells"],q["context"],n["control"]["side"])
    require(all(len(v)==count for v in vectors),label+": incomplete arrays")
    preplanned=native_mosaic=shared=0
    for i in range(count):
        a,b=frame["cells"][i],mosaic["cells"][i]
        before,after=n["planned_cells"][i],n["cells"][i]
        context=q["context"][i]
        require(not(a and b),label+": overlapping ownership")
        require(not((a or b) and context),label+": context overwritten")
        require(not(a and n["control"]["side"][i]!=0) and not(b and n["control"]["side"][i]!=1),label+": territory crossed")
        require(after==(b or a or context),label+": composite differs from authors")
        require(before==(pmosaic["cells"][i] or pframe["cells"][i] or context),label+": prejoin differs from authors")
        require(not before or after==before,label+": frozen planned material replaced")
        require(not core["cells"][i] or a==core["cells"][i],label+": frame core changed")
        require(not pmosaic["cells"][i] or b==pmosaic["cells"][i],label+": solved masonry replaced")
        protected=q["protected"][i] or mq["protected"][i] or frame["boundary"]["protected"][i] or mosaic["boundary"]["protected"][i]
        require(not(after and protected),label+": protected geometry filled")
        require(0<=after<132,label+": invalid native material ID")
        preplanned+=bool(pframe["cells"][i] and not core["cells"][i])
        native_mosaic+=bool(pmosaic["cells"][i])
        shared+=bool(after and not before)
    if no_receptor:
        require(n["finished_cells"]==n["cells"] and not any(n["residual"]["cells"]),label+": residual finishing entered comparison")
    slots={s["id"]:s for s in n["frame"]["slots"]}
    require(len(slots)==len(n["frame"]["slots"])<=8,label+": invalid reservation universe")
    responses={r["slot_id"]:r for r in n["mosaic"]["responses"]}
    joined,interiors,endpoints=set(),set(),set()
    for seam in n["seams"]:
        if not seam["joined"]:
            continue
        audit.paths+=1
        slot_id=seam["left_affordance"]
        require(slot_id in slots and slot_id in responses,label+": joint lacks reservation/response")
        slot,response=slots[slot_id],responses[slot_id]
        path=[tuple(p) for p in seam["cells"]]
        require(2<=len(path)<=16 and len(set(path))==len(path),label+": unbounded or repeated path")
        require(path[0]==tuple(seam["a"]) and path[-1]==tuple(seam["b"])==tuple(response["contact"]),label+": wrong path endpoints")
        require(response["satisfied"] and response["admitted"] and response["tile"]==seam["right_affordance"],label+": unqualified response")
        require(path[0] not in endpoints and path[-1] not in endpoints,label+": reused endpoint")
        endpoints.update((path[0],path[-1]))
        require((path[1][0]-path[0][0],path[1][1]-path[0][1])==tuple(slot["facing"]),label+": source facing wrong")
        require((path[-2][0]-path[-1][0],path[-2][1]-path[-1][1])==tuple(response["facing"]),label+": receiving facing wrong")
        rx,ry=path[-1];fx,fy=response["facing"]
        inward=(ry-fy)*q["width"]+rx-fx;outward=(ry+fy)*q["width"]+rx+fx
        require(0<=rx-fx<q["width"] and 0<=ry-fy<q["height"] and pmosaic["cells"][inward],label+": receiving face lacks inward material")
        require(0<=rx+fx<q["width"] and 0<=ry+fy<q["height"] and not pmosaic["cells"][outward],label+": receiving face was not exposed")
        sx,sy=path[0]
        require(min(slot["a"][0],slot["b"][0])<=sx<=max(slot["a"][0],slot["b"][0]) and
                min(slot["a"][1],slot["b"][1])<=sy<=max(slot["a"][1],slot["b"][1]),label+": endpoint off reservation")
        ex,ey,ew,eh=slot["envelope"];clearance={tuple(p) for p in slot["clearance"]}
        for j,(x,y) in enumerate(path):
            require(0<=x<q["width"] and 0<=y<q["height"],label+": path out of bounds")
            require(ex<=x<ex+ew and ey<=y<ey+eh,label+": path outside envelope")
            index=y*q["width"]+x
            require(n["cells"][index] and q["transition"][index] and not q["context"][index] and (x,y) not in clearance,label+": illegal path material/clearance")
            if j:
                require(abs(path[j-1][0]-x)+abs(path[j-1][1]-y)==1,label+": disconnected path")
            if 0<j<len(path)-1:
                require(not n["planned_cells"][index] and index not in interiors,label+": shared interior overlaps existing material")
                require(n["cells"][index]==62,label+": shared joining material differs from native SteelPlate")
                interiors.add(index)
            else:
                owner=pframe if j==0 else pmosaic
                require(owner["cells"][index] and owner["roles"][index] not in (3,4),label+": absent/decorative structural endpoint")
        if slot["required"]:
            original=[c for c in frame["connectors"] if c["id"]==slot["connector"] and c["instance"]==slot["instance"] and
                      c["a"]==slot["a"] and c["b"]==slot["b"] and c["facing"]==slot["facing"]]
            require(len(original)==1 and original[0]["fulfilled"],label+": false mandatory fulfilment")
        joined.add(slot_id)
    require(shared==len(interiors)==metric(n,"shared_bridge_cells"),label+": unattributed shared material")
    require(len(joined)==metric(n,"joined_slots"),label+": joint count differs")
    unresolved=sum(c["required"] and not c["fulfilled"] for c in frame["connectors"])
    require(unresolved==frame["unresolved_joints"]==metric(n,"unresolved_mandatory_connectors"),label+": unresolved count differs")
    require(preplanned==metric(n,"frame_preplanned_addition_cells"),label+": terminal cell count differs")
    return {"joints":len(joined),"joint_ids":joined,"posthoc_cells":shared,"shared_join_cells":shared,
            "generator_adaptation_cells":0,"preplanned_frame_cells":preplanned,
            "native_mosaic_cells":native_mosaic,"mandatory_unresolved":unresolved,
            "native_material_sha256":native_sha(n["cells"]),"prejoin_material_sha256":native_sha(n["planned_cells"])}

def optional_causality(n,hard,active,joined):
    if n["mosaic"]["result"]["status"]!="complete" or hard["mosaic"]["result"]["status"]!="complete":
        return {"optional_causal_tiles":None,"active_optional_causal_joints":None,
                "newly_compatible_optional_responses":None,"active_newly_compatible_joints":None,"causal_joint_ids":[]}
    changed,causal,newly,newly_joined=set(),set(),set(),set()
    old=hard["mosaic"]["categories"];domains={d["tile"]:d for d in n["mosaic"]["domains"]}
    for response in n["mosaic"]["responses"]:
        slot_id,tile=response["slot_id"],response["tile"]
        if slot_id not in active or not response["satisfied"] or tile>=len(old):
            continue
        d=domains[tile]
        if d["modified_domain"]==d["hard_domain"]:
            continue
        if d["selected"]>=0 and old[tile]>=0 and d["selected"]!=old[tile]:
            changed.add(tile)
            if slot_id in joined:
                causal.add(slot_id)
        x,y=response["contact"]
        before=hard["mosaic"]["result"]["cells"][y*n["frame_request"]["width"]+x]
        if old[tile]<0 or not response["compatible_domain"]&(1<<old[tile]) or not before:
            newly.add(slot_id)
            if slot_id in joined:
                newly_joined.add(slot_id)
    return {"optional_causal_tiles":len(changed),"active_optional_causal_joints":len(causal),
            "newly_compatible_optional_responses":len(newly),"active_newly_compatible_joints":len(newly_joined),
            "causal_joint_ids":sorted(causal)}

def row_for(record,doc,full,hard,audit,hard_policy="cap0",closed=None):
    n=doc.get("candidate",doc)
    audit.require(n["frame"]==full["frame"] and n["frame_request"]==full["frame_request"],record["file"]+": frame changed")
    audit.require(n["control"]==full["control"],record["file"]+": B changed")
    audit.require(n["mosaic_request"]==full["mosaic_request"],record["file"]+": nonpolicy request changed")
    facts=audit_native(n,audit,no_receptor=record["policy"]!="C");joined=facts.pop("joint_ids")
    cjoined={s["left_affordance"] for s in full["seams"] if s["joined"]}
    mandatory={s["id"] for s in n["frame"]["slots"] if s["required"] or s["hard"]}
    active=final_active_optional(doc)
    receiver_work=receiver_changes=receiver_points=domain_prep=shared_prep=0
    join_limit=2_000_000
    if doc.get("schema")==4:
        audit_solver(doc,audit)
        audit_receivers(doc,full,audit)
        authorized=set(doc["trace"]["final_authorized_ids"])
        audit.require(joined<=authorized,record["file"]+": unadmitted join")
        audit.require(doc["preparation_work"]+doc["join_work_limit"]==2_000_000,record["file"]+": shared ceiling changed")
        audit.require(metric(n,"shared_work")<=doc["join_work_limit"],record["file"]+": shared work exceeded")
        local_work,solver_prep=doc["trace"]["admission"]["work"],doc["trace"]["solver"]["preparation_work"]
        receiver_work=metric(n["mosaic"]["result"],"resilience_required_receiver_work")
        receiver_changes=sum(r["changed"] for r in doc["trace"].get("receivers",[]))
        receiver_points=sum(r["points_examined"] for r in doc["trace"].get("receivers",[]))
        domain_prep=metric(n["mosaic"]["result"],"resilience_domain_preparation_work")
        shared_prep,join_limit=doc["preparation_work"],doc["join_work_limit"]
        audit.require(n["mosaic"]["result"]["work"]<=n["mosaic_request"]["limits"]["work"],record["file"]+": MOSAIC work overrun")
        audit.require(local_work+solver_prep+receiver_work+domain_prep<=n["mosaic"]["result"]["work"],record["file"]+": uncharged preparation")
        audit.require(metric(n,"candidate_charged_work_upper_bound")==10_000_000,record["file"]+": structural charged ceiling changed")
        selected=set(doc["trace"]["primary_selected_ids"]);dropped=set(doc["trace"]["dropped_preference_ids"])
    elif "admission" in doc:
        selected=authorized=set(doc["admission"]["selected_ids"]);dropped=selected-mandatory-active
        local_work,solver_prep=doc["admission"]["work"],0
        shared_prep,join_limit=doc["admission"]["work"],doc["admission"]["join_work_limit"]
    else:
        selected=authorized={s["id"] for s in n["frame"]["slots"]};dropped=selected-mandatory-active
        local_work=solver_prep=0
    causal=optional_causality(n,hard,active,joined);attempts=n["mosaic"]["attempts"]
    old={d["tile"]:d for d in full["mosaic"]["domains"]}
    changed=sum(d["tile"] in old and d["selected"]>=0 and old[d["tile"]]["selected"]>=0 and d["selected"]!=old[d["tile"]]["selected"] for d in n["mosaic"]["domains"])
    status,cstatus=n["mosaic"]["result"]["status"],full["mosaic"]["result"]["status"]
    recovery=cstatus!="complete" and status=="complete"
    result={**record,**facts,**causal,"full_c_status":cstatus,"b_status":full["control"]["right"]["status"],
            "policy_role":"diagnostic" if record["policy"] in DIAGNOSTICS or record["policy"]=="cap0" else "candidate" if record["policy"] in POLICIES else "control",
            "causal_control_policy":hard_policy,
            "hard_only_status":hard["mosaic"]["result"]["status"],"recovered_from_c":recovery,
            "complete_with_zero_unresolved_mandatory":status=="complete" and facts["mandatory_unresolved"]==0,
            "regressed_from_c":cstatus=="complete" and status!="complete","recovered_from_exhaustion":cstatus=="exhausted" and status=="complete",
            "required_receiver_recovery":recovery and bool(receiver_changes),
            "meaningful_optional_recovery":recovery and not receiver_changes and bool(causal["active_optional_causal_joints"]),
            "new_receiving_motif_recovery":recovery and not receiver_changes and bool(causal["active_newly_compatible_joints"]),
            "selected_optional":len(selected-mandatory),"authorized_optional":len(authorized-mandatory),
            "optional_capacity":doc["trace"]["admission"]["optional_capacity"] if doc.get("schema")==4 else doc.get("admission",{}).get("optional_cap",8),
            "active_optional_preferences":len(active),"dropped_optional_preferences":len(dropped),
            "optional_joint_ids":len(joined-mandatory),"retained_c_joint_ids":len(joined&cjoined),"new_joint_ids_vs_c":len(joined-cjoined),
            "changed_categories_vs_c":changed,"first_attempt_limit":next((a["work_limit"] for a in attempts if a["attempted"]),0),
            "solver_attempt_limits":";".join(str(a["work_limit"]) for a in attempts),
            "solver_attempt_statuses":";".join(a["status"] for a in attempts),
            "observed_successful_solver_work":sum(a["work"] for a in attempts if a["work"] is not None),
            "failed_attempt_work_unavailable":sum(a["attempted"] and a["work"] is None for a in attempts),
            "local_admission_work":local_work,"solver_preparation_work":solver_prep,
            "required_receiver_work":receiver_work,"required_receiver_changes":receiver_changes,"required_receiver_points_examined":receiver_points,
            "domain_preparation_work":domain_prep,"shared_preparation_work":shared_prep,"shared_join_work_limit":join_limit,
            "charged_structural_work_limit":metric(n,"candidate_charged_work_upper_bound"),
            "mosaic_generator_work":n["mosaic"]["result"]["work"],"shared_join_work":metric(n,"shared_work"),
            "same_prejoin_as_c":n["planned_cells"]==full["planned_cells"],"same_final_as_c":n["cells"]==full["cells"],
            "category_assignment_sha256":hashlib.sha256(json.dumps(n["mosaic"]["categories"],separators=(",",":")).encode()).hexdigest(),
            "effective_domains_sha256":hashlib.sha256(json.dumps([d["modified_domain"] for d in n["mosaic"]["domains"]],separators=(",",":")).encode()).hexdigest(),
            "joint_ids":sorted(joined),"active_optional_ids":sorted(active),"authorized_ids":sorted(authorized)}
    if closed is not None:
        original=closed["candidate"]
        result.update(closed_native_single_status=original["mosaic"]["result"]["status"],
                      recovered_vs_closed_native_single=original["mosaic"]["result"]["status"]!="complete" and status=="complete",
                      same_prejoin_as_closed_native_single=n["planned_cells"]==original["planned_cells"],
                      same_final_as_closed_native_single=n["cells"]==original["cells"])
    if doc.get("schema")==4 and status=="complete":
        trace=doc["trace"]["solver"]
        result["assignment_satisfies_original_c_preferred"]=assignment_valid(n["mosaic"]["categories"],[d["preferred_domain"] for d in full["mosaic"]["domains"]],trace["width"],trace["height"],trace["adjacency"])
    else:
        result["assignment_satisfies_original_c_preferred"]=None
    return result

def aggregate(rows):
    numeric=("joints","posthoc_cells","shared_join_cells","generator_adaptation_cells","preplanned_frame_cells","native_mosaic_cells","mandatory_unresolved",
             "retained_c_joint_ids","new_joint_ids_vs_c","selected_optional","authorized_optional","active_optional_preferences",
             "dropped_optional_preferences","optional_joint_ids","changed_categories_vs_c","optional_causal_tiles",
             "active_optional_causal_joints","newly_compatible_optional_responses","active_newly_compatible_joints",
             "observed_successful_solver_work","failed_attempt_work_unavailable","local_admission_work","solver_preparation_work",
             "required_receiver_work","required_receiver_changes","required_receiver_points_examined",
             "domain_preparation_work","shared_preparation_work","mosaic_generator_work","shared_join_work")
    boolean=("recovered_from_c","regressed_from_c","recovered_from_exhaustion","meaningful_optional_recovery",
             "new_receiving_motif_recovery","same_prejoin_as_c","same_final_as_c","complete_with_zero_unresolved_mandatory",
             "required_receiver_recovery","recovered_vs_closed_native_single","same_prejoin_as_closed_native_single","same_final_as_closed_native_single")
    return {"cases":len(rows),"statuses":dict(sorted(Counter(r["mosaic_status"] for r in rows).items())),
            **{k:sum(r.get(k) or 0 for r in rows) for k in numeric+boolean},
            "optional_causality_comparable_cases":sum(r.get("optional_causal_tiles") is not None for r in rows),
            "maximum_local_admission_work":max((r["local_admission_work"] for r in rows),default=0),
            "maximum_solver_preparation_work":max((r["solver_preparation_work"] for r in rows),default=0),
            "maximum_required_receiver_work":max((r.get("required_receiver_work",0) for r in rows),default=0),
            "maximum_domain_preparation_work":max((r.get("domain_preparation_work",0) for r in rows),default=0),
            "maximum_shared_preparation_work":max((r.get("shared_preparation_work",0) for r in rows),default=0),
            "maximum_mosaic_generator_work":max((r.get("mosaic_generator_work",0) for r in rows),default=0),
            "maximum_charged_structural_work_limit":max((r.get("charged_structural_work_limit",0) for r in rows),default=0)}

def table(headers,rows):
    return "<div class='scroll'><table><thead><tr>"+"".join(f"<th>{html.escape(str(h))}</th>" for h in headers)+"</tr></thead><tbody>"+"".join(
        "<tr>"+"".join(f"<td>{html.escape(str(v))}</td>" for v in row)+"</tr>" for row in rows)+"</tbody></table></div>"

def result_panel(n,title,before=False):
    caption=f"{n['mosaic']['result']['status']} | {metric(n,'joined_slots')} joints | {metric(n,'candidate_posthoc_cells')} late | {metric(n,'unresolved_mandatory_connectors')} mandatory open"
    if before:
        caption="Native plans frozen; shared joining has not run"
    return panel(raster(n["planned_cells"] if before else n["cells"],n["frame_request"]),title,caption)

def offer_overlay(doc):
    n=doc["candidate"];image=decisions(n);draw=ImageDraw.Draw(image)
    active=final_active_optional(doc);authorized=set(doc["trace"]["final_authorized_ids"])
    for slot in n["frame"]["slots"]:
        color=(245,194,89) if slot["required"] or slot["hard"] else (91,233,163) if slot["id"] in active else (130,160,220) if slot["id"] in authorized else (128,135,147)
        a,b=[tuple(v*3+1 for v in p) for p in (slot["a"],slot["b"])]
        draw.line((a,b),fill=color,width=3)
        draw.ellipse((a[0]-3,a[1]-3,a[0]+3,a[1]+3),outline=color,width=2)
    return image

def decision_tables(doc,full,hard):
    n=doc["candidate"];admission=doc["trace"]["admission"]
    receivers=doc["trace"].get("receivers",[])
    receiver_table=table(["Required slot","Original face / tile","Selected face / tile","Original raw / support","Selected raw / support","Changed","Examined points","Charged work","Reason"],
        [[r["slot_id"],f'{r["original_contact"]} / {r["original_tile"]}',f'{r["selected_contact"]} / {r["selected_tile"]}',
          f'{cats(r["original_compatible_domain"])} / {cats(r["original_supported_domain"])}',
          f'{cats(r["selected_compatible_domain"])} / {cats(r["selected_supported_domain"])}',
          r["changed"],r["points_examined"],r["work"],r["reason"]] for r in receivers]) if receivers else ""
    local=table(["Slot","Hard","Local decision","Primary","Fallback core","Domain changed","Tile","Native alternatives","Local support","Reason"],
                [[d["slot_id"],d["hard"],d["disposition"],d["selected"],d["fallback_selected"],d["domain_changed"],d["tile"],
                  cats(d["compatible_domain"]),cats(d["locally_supported_domain"]),d["reason"]] for d in admission["decisions"]])
    before={d["tile"]:d for d in full["mosaic"]["domains"]};rows=[]
    for d in n["mosaic"]["domains"]:
        c=before.get(d["tile"])
        if not d["influences"] and (not c or not c["influences"]):
            continue
        hcat=hard["mosaic"]["categories"][d["tile"]] if d["tile"]<len(hard["mosaic"]["categories"]) else -1
        rows.append([d["tile"],d["origin"],",".join(str(i["slot_id"]) for i in d["influences"]),cats(d["original_domain"]),
                     cats(d["hard_domain"]),cats(d["preferred_domain"]),cats(d["modified_domain"]),
                     c["selected_name"] if c else "none",CATEGORIES[hcat] if hcat>=0 else "unselected",d["selected_name"]])
    return receiver_table+local+table(["Tile","Origin","Offer IDs","Original","Hard","Preferred","Effective","Full C","Matched hard-only","Selected"],rows)

def image_tag(path,relative):
    data=base64.b64encode(path.read_bytes()).decode()
    return f"<a href='{html.escape(relative)}'><img loading='lazy' src='data:image/png;base64,{data}'></a>"

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory",type=Path)
    parser.add_argument("--selected-policy",choices=POLICIES)
    parser.add_argument("--focus-policy",choices=POLICIES,help="Illustrative development comparison without claiming policy selection")
    args=parser.parse_args();out=args.directory.resolve()
    if args.focus_policy and args.selected_policy and args.focus_policy!=args.selected_policy:
        parser.error("A frozen selected policy must also be the comparison focus")
    campaign=json.loads((out/"campaign.json").read_text());audit=Audit()
    audit.require(campaign["result"]=="PASS","Native campaign did not pass")
    policies=[p["id"] for p in campaign["registered_policies"]]
    continuation=campaign.get("schema",1)>=2
    if campaign["lane"]=="primary":
        expected_policies=list(POLICIES if continuation else HISTORICAL_POLICIES)
    elif campaign["lane"]=="regression" and continuation:
        expected_policies=list(CAPACITY_POLICIES)
    else:
        expected_policies=[campaign["selected_policy"]]
        audit.require(campaign["lane"]=="validation" and expected_policies[0] in (CAPACITY_POLICIES if continuation else HISTORICAL_POLICIES),"Unexpected campaign lane or frozen policy")
    audit.require(policies==expected_policies,"Unexpected policy registry")
    diagnostics=[p["id"] for p in campaign["diagnostic_policies"]]
    audit.require(diagnostics==list(DIAGNOSTICS),"Unexpected matched diagnostic registry")
    for record in campaign["registered_policies"]+campaign["diagnostic_policies"]:
        audit.require(policy_options_match({k:v for k,v in record.items() if k!="id"},record["id"],continuation),"Registered policy options differ from preregistered row")
    seeds=[605,1701] if campaign["lane"]=="primary" else [8191,12289] if continuation and campaign["lane"]=="validation" else [2718,4099]
    audit.require(campaign["seeds"]==seeds,"Unexpected registered seed universe")
    expected={f"{f}_{p}_{s}" for f in FIXTURES for p in PROFILES for s in seeds}
    by_case=defaultdict(dict)
    for record in campaign["records"]:
        audit.require(record["case"] in expected,"Unregistered case")
        audit.require(record["policy"] not in by_case[record["case"]],"Duplicate policy record")
        path=(out/record["file"]).resolve()
        audit.require(path.is_relative_to(out) and path.is_file(),"Escaping or missing corpus file")
        by_case[record["case"]][record["policy"]]=record
    audit.require(set(by_case)==expected,"Missing registered cases")
    controls={"C","cap0","cap4"}|({"cap1","cap2"} if campaign["lane"]=="primary" else set())
    for key,group in by_case.items():
        audit.require(set(group)==controls|set(policies)|set(diagnostics),key+": incomplete fixed policy matrix")
    images=out/"images";images.mkdir(exist_ok=True)
    rows,cards,definitions=[],[],set()
    selected=args.selected_policy or campaign["selected_policy"] or None
    if selected:
        audit.require(selected in policies,"Selected focus is outside the registered lane")
    focus=selected or args.focus_policy or ("native_receiver_single" if continuation else "native_balanced")
    audit.require(focus in policies,"Illustrative focus is outside the registered lane")
    for key,group in sorted(by_case.items()):
        docs={p:json.loads((out/r["file"]).read_text()) for p,r in group.items()}
        full=docs["C"];q=full["frame_request"];case_rows={}
        for capacity_policy in CAPACITY_POLICIES:
            if capacity_policy not in docs:
                continue
            candidate,matched=docs[capacity_policy],docs["native_receiver_hard_only"]
            audit.require(candidate["trace"]["receivers"]==matched["trace"]["receivers"],key+": optional admission changed required receiver choice")
            audit.require([d["hard_domain"] for d in candidate["candidate"]["mosaic"]["domains"]]==
                          [d["hard_domain"] for d in matched["candidate"]["mosaic"]["domains"]],key+": receiver hard-only control has different mandatory domains")
        for policy,doc in docs.items():
            n=doc.get("candidate",doc)
            audit.require(n["frame_request"]["source"]==campaign["source"] and case_key(n)==key,"Case/source identity mismatch")
            if policy in policies or policy in diagnostics:
                audit.require(doc.get("schema")==4 and doc.get("type")=="resilient_negotiation","Unexpected resilience schema")
                audit.require(policy_options_match(doc["options"],policy,continuation),"Raw policy options differ from registered row")
            hard_policy=causal_control_policy(policy);hard=docs[hard_policy]["candidate"]
            row=row_for(group[policy],doc,full,hard,audit,hard_policy,docs.get("native_single"))
            rows.append(row);case_rows[policy]=row
            definitions.update((n["frame"]["result"]["definition"],n["mosaic"]["result"]["definition"]))
            for stage,field in (("before","planned_cells"),("after","cells")):
                raster(n[field],q).resize((q["width"]*4,q["height"]*4),Image.Resampling.NEAREST).save(images/f"{key}_{policy}_{stage}.png")
        if "native_receiver_single" in case_rows:
            baseline=case_rows["native_receiver_single"]
            for capacity_policy in CAPACITY_POLICIES:
                if capacity_policy not in case_rows:
                    continue
                row=case_rows[capacity_policy]
                row.update(recovered_vs_e4=baseline["mosaic_status"]!="complete" and row["mosaic_status"]=="complete",
                           regressed_vs_e4=baseline["mosaic_status"]=="complete" and row["mosaic_status"]!="complete",
                           mandatory_unresolved_delta_vs_e4=row["mandatory_unresolved"]-baseline["mandatory_unresolved"],
                           gained_joint_ids_vs_e4=sorted(set(row["joint_ids"])-set(baseline["joint_ids"])),
                           lost_joint_ids_vs_e4=sorted(set(baseline["joint_ids"])-set(row["joint_ids"])))
        b=full["control"]
        b_row={"file":group["C"]["file"],"case":key,"fixture":q["fixture"],"profile":q["profile"]["name"],"seed":q["seed"],
               "policy":"B","policy_role":"control","mosaic_status":b["right"]["status"],"joints":metric(full,"control_joined_interfaces"),
               "posthoc_cells":metric(full,"control_posthoc_cells"),"preplanned_frame_cells":0,
               "shared_join_cells":b["bridge_cells"],"generator_adaptation_cells":metric(full,"control_posthoc_cells")-b["bridge_cells"],
               "native_mosaic_cells":sum(bool(v) for v in b["initial_right"]["cells"]),
               "mandatory_unresolved":b["left"]["unresolved_joints"],"local_admission_work":0,"solver_preparation_work":0}
        b_row["complete_with_zero_unresolved_mandatory"]=b_row["mosaic_status"]=="complete" and b_row["mandatory_unresolved"]==0
        rows.append(b_row);case_rows["B"]=b_row
        title=f"{q['fixture']} / {q['profile']['name']} / seed {q['seed']}"
        subtitle=f"{campaign['lane']} | source {campaign['source']} | exact native material IDs; RECEPTOR excluded"
        panels=[panel(raster(b["cells"],q),TITLES["B"],f"{b['right']['status']} | {b_row['joints']} joints | {b_row['posthoc_cells']} late cells"),
                result_panel(full,TITLES["C"]),result_panel(docs["cap4"]["candidate"],TITLES["cap4"])]
        display=["native_original",*policies[:4],*policies[5:],*diagnostics,"cap0"] if campaign["lane"]=="primary" else [*policies,*diagnostics,"cap0"]
        panels.extend(result_panel(docs[p]["candidate"],TITLES[p]) for p in display)
        comparison=f"comparison_{key}.png";grid(panels,title,subtitle).save(images/comparison)
        focus_doc=docs[focus];n=focus_doc["candidate"];fr=case_rows[focus]
        focus_hard_policy=causal_control_policy(focus);hard=docs[focus_hard_policy]["candidate"]
        selected_picture = ""
        if (selected or args.focus_policy) and campaign["lane"]=="primary":
            solver_control="full_single" if focus in CAPACITY_POLICIES else "full_"+focus.removeprefix("native_")
            if solver_control not in docs:
                solver_control="full_balanced"
            intervention_controls=[
                result_panel(docs["native_original"]["candidate"],"Native admission alone: closed receivers"),
                result_panel(docs[solver_control]["candidate"],"Solver schedule alone: "+solver_control.removeprefix("full_"))]
            selected_name=f"selected_{key}_{focus}.png"
            selected_panels=panels[:3]+intervention_controls+[
                result_panel(n,"E  Selected candidate" if selected else "E  Registered candidate under review"),
                result_panel(n,"E  Before shared meshing",True),
                panel(semantic(n),"Semantic contributions","Blue frame | gold endings | tan masonry | cyan joins"),
                panel(offer_overlay(focus_doc),"Reservations and selected native motifs","Gold hard | green active | blue relaxed | grey withheld")]
            grid(selected_panels,title+" / fixed candidate comparison",subtitle).save(images/selected_name)
            selected_picture=image_tag(images/selected_name,"images/"+selected_name)
        detail=f"causal_{key}_{focus}.png"
        grid([panel(raster(b["clipped_cells"],q),TITLES["A"],f"{b['clipped_right']['status']} | no preplanned cooperation"),
              result_panel(hard,TITLES[focus_hard_policy]),result_panel(n,"Selected policy before shared joins" if selected else "Fixed policy focus before joins",True),
              result_panel(n,TITLES[focus]),panel(semantic(n),"Semantic contributions","Blue frame | gold endings | tan masonry | cyan joins"),
              panel(offer_overlay(focus_doc),"Reservations, domains and selected motifs","Gold hard | green active | blue relaxed | grey withheld")],
             title+" / causal evidence",subtitle).save(images/detail)
        detail_html=[]
        for p in policies+diagnostics:
            doc=docs[p];r=case_rows[p]
            policy_hard=docs[causal_control_policy(p)]["candidate"]
            snippet={"options":doc["options"],"preparation_work":doc["preparation_work"],"join_work_limit":doc["join_work_limit"],"trace":doc["trace"]}
            reasons=" ".join(s["reason"] for s in doc["candidate"]["seams"] if not s["joined"])
            detail_html.append(f"<details><summary>{html.escape(TITLES[p])}: {r['mosaic_status']} · {r['joints']} joints · {r['mandatory_unresolved']} mandatory unresolved</summary>"
                f"<p>Matched causal control: {html.escape(TITLES[causal_control_policy(p)])}. Changed required receivers {r['required_receiver_changes']}. "
                f"Active optional preferences {r['active_optional_preferences']}; authorized optional contacts {r['authorized_optional']}; active category-changing optional joints {r['active_optional_causal_joints']}; newly compatible optional joints {r['active_newly_compatible_joints']}. "
                f"Failed-attempt work unavailable: {r['failed_attempt_work_unavailable']}. First attempt {r['first_attempt_limit']:,}.</p>"
                +decision_tables(doc,full,policy_hard)+"<h4>Complete local admission and solver receipts</h4><pre>"+html.escape(json.dumps(snippet,indent=2))+"</pre>"
                +f"<h4>Unresolved geometry</h4><p>{html.escape(reasons or 'None')}</p><p><a href='{group[p]['file']}'>Raw JSON</a> · "
                +f"<a href='images/{key}_{p}_before.png'>Before shared meshing</a> · <a href='images/{key}_{p}_after.png'>After shared meshing</a></p></details>")
        search=" ".join([title,*policies,*diagnostics,*[r["mosaic_status"] for r in case_rows.values()],
                         *[s["reason"] for p in policies for s in docs[p]["candidate"]["seams"] if not s["joined"]]])
        cards.append(f"<article data-search='{html.escape(search,quote=True)}'><h2>{html.escape(title)}</h2>"
                     +(selected_picture or image_tag(images/comparison,"images/"+comparison))
                     +((f"<details><summary>All {len(policies)} registered candidates and matched diagnostics</summary>"+image_tag(images/comparison,"images/"+comparison)+"</details>") if selected_picture else "")
                     +f"<p>Focus: {html.escape(TITLES[focus])}. {'Frozen selected policy.' if selected else 'Same illustrative focus for every case; no default selected.'} "
                     +f"Optional causal joints {fr['active_optional_causal_joints']}; newly compatible qualified optional joints {fr['active_newly_compatible_joints']}; retained original C joints {fr['retained_c_joint_ids']}.</p>"
                     +"<details><summary>Before/after, semantic contributions and complete decision receipts</summary>"
                     +image_tag(images/detail,"images/"+detail)+"".join(detail_html)+"</details></article>")
    all_policies=["B","C","cap0"]+(["cap1","cap2"] if campaign["lane"]=="primary" else [])+["cap4",*policies,*diagnostics]
    common={key for key in expected if all(r["mosaic_status"]=="complete" for r in rows if r["case"]==key)}
    selected_cohort_policies=["B","C","cap4",focus]
    selected_common={key for key in expected if all(r["mosaic_status"]=="complete" for r in rows if r["case"]==key and r["policy"] in selected_cohort_policies)}
    capacity_comparisons={}
    for policy in CAPACITY_POLICIES[1:]:
        if policy not in policies or "native_receiver_single" not in policies:
            continue
        comparison_rows=[r for r in rows if r["policy"] in ("native_receiver_single",policy)]
        cohort={key for key in expected if all(r["mosaic_status"]=="complete" for r in comparison_rows if r["case"]==key)}
        changes=[r for r in comparison_rows if r["policy"]==policy]
        capacity_comparisons[policy]={"reference":"native_receiver_single","common_success_cases":sorted(cohort),
            "common_success":{p:aggregate([r for r in comparison_rows if r["policy"]==p and r["case"] in cohort]) for p in ("native_receiver_single",policy)},
            "completion_regressions":[r["case"] for r in changes if r["regressed_vs_e4"]],
            "completion_recoveries":[r["case"] for r in changes if r["recovered_vs_e4"]],
            "mandatory_increases":[{"case":r["case"],"delta":r["mandatory_unresolved_delta_vs_e4"]} for r in changes if r["mandatory_unresolved_delta_vs_e4"]>0],
            "joint_changes":[{"case":r["case"],"gained":r["gained_joint_ids_vs_e4"],"lost":r["lost_joint_ids_vs_e4"]} for r in changes if r["gained_joint_ids_vs_e4"] or r["lost_joint_ids_vs_e4"]]}
    summary={"programme":campaign["programme"],"source":campaign["source"],"lane":campaign["lane"],"seeds":seeds,"selected_policy":selected,"focus_policy":focus,
             "capacity_comparisons":capacity_comparisons,
             "matched_cases":len(expected),"new_policy_records":len(policies)*len(expected),"diagnostic_records":len(diagnostics)*len(expected),"total_rows":len(rows),"definitions":sorted(definitions),
             "registered_policies":campaign["registered_policies"],"diagnostic_policies":campaign["diagnostic_policies"],
             "policies":{p:aggregate([r for r in rows if r["policy"]==p]) for p in all_policies},
             "per_fixture":{f:{p:aggregate([r for r in rows if r["fixture"]==f and r["policy"]==p]) for p in all_policies} for f in FIXTURES},
             "common_all_policies_cases":sorted(common),"common_all_policies":{p:aggregate([r for r in rows if r["policy"]==p and r["case"] in common]) for p in all_policies},
             "per_policy_common_with_c":{p:aggregate([r for r in rows if r["policy"]==p and r.get("full_c_status")==r["mosaic_status"]=="complete"]) for p in policies},
             "focus_common_with_b_c_cap4_cases":sorted(selected_common),
             "focus_common_with_b_c_cap4":{p:aggregate([r for r in rows if r["policy"]==p and r["case"] in selected_common]) for p in selected_cohort_policies+[causal_control_policy(focus)]},
             "audit":{"result":"PASS","checks":audit.checks,"qualified_paths_checked":audit.paths,"complete_assignments_checked":audit.assignments,"directed_adjacencies_checked":audit.adjacencies},
             "claims":"MOSAIC completion is distinct from whole-frame success. Failed-attempt work stays unavailable. Optional causal joints require a retained effective preference, changed directly affected native category versus the matched mandatory-preserving hard-only rule, and a qualified material path. New required-receiver changes use native_receiver_hard_only; earlier policies use historical cap0. Required receiver completion gains are separately counted and never included in optional-caused recovery counts. Multiple retained optional offers may share one changed tile, so these are set-level optional effects, not proofs that every individual offer was necessary. Coincidental contacts after hard-only fallback are not causal recovery. No aesthetic score or physical stability claim."}
    (out/"resilience_summary.json").write_text(json.dumps(summary,indent=2)+"\n")
    (out/"resilience_rows.json").write_text(json.dumps(rows,indent=2)+"\n")
    fields=sorted(set().union(*(r.keys() for r in rows)))
    with (out/"resilience_metrics.csv").open("w",newline="") as stream:
        writer=csv.DictWriter(stream,fields);writer.writeheader()
        writer.writerows({k:";".join(map(str,v)) if isinstance(v,list) else v for k,v in row.items()} for row in rows)
    overview=table(["Policy","Complete","UNSAT","Exhausted","Invalid","Joints","All late cells","Shared joining cells","Generator adaptation cells","Mandatory open","Recoveries","Required receiver recoveries","Optional-influence recoveries","Regressions"],
        [[TITLES[p],s["statuses"].get("complete",0),s["statuses"].get("unsat",0),s["statuses"].get("exhausted",0),s["statuses"].get("invalid",0),
          s["joints"],s["posthoc_cells"],s["shared_join_cells"],s["generator_adaptation_cells"],s["mandatory_unresolved"],s["recovered_from_c"],
          s["required_receiver_recovery"],s["meaningful_optional_recovery"],s["regressed_from_c"]] for p,s in summary["policies"].items()])
    page="""<!doctype html><html lang='en'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>SWARM-003 native research evidence</title><style>body{max-width:1600px;margin:32px auto;padding:0 24px;background:#0d1219;color:#dfe6ef;font:16px system-ui;line-height:1.5}h1{font-size:34px}h2{font-size:22px}a{color:#51ddbf}article{border-top:1px solid #334052;margin:36px 0;padding-top:20px}img{width:100%;height:auto}table{border-collapse:collapse;font-size:13px}td,th{padding:8px;border:1px solid #334052;vertical-align:top}th{background:#182435}.scroll{overflow:auto}details{background:#141b24;padding:16px;margin:8px 0}summary{cursor:pointer}input{padding:12px;font:inherit;background:#182435;color:white;border:1px solid #526379;width:min(90%,600px)}pre{white-space:pre-wrap;overflow-wrap:anywhere;max-height:600px;overflow:auto}.notice{border-left:4px solid #edc15b;padding:10px 20px;background:#1d2630}code{overflow-wrap:anywhere}</style>"""
    page+=f"<h1>SWARM-003: resilient negotiated architecture</h1><p>Draft / HOLD · {html.escape(campaign['lane'])} · source <code>{html.escape(campaign['source'])}</code></p>"
    page+="<div class='notice'>Every registered case and policy is retained, including failure. Images are deterministic native material arrays; no AI imagery or simulation screenshots. MOSAIC completion does not resolve every FRAMEWEAVER connector. Mandatory-open counts refer to FRAMEWEAVER. B late additions include generator adaptation and shared joins, shown separately; C/E late additions are shared joining cells after the native plans are frozen. A relaxed optional offer may still receive a material contact; that contact is separate from active optional causal influence. Required receiver completion gains remain separate from optional-influence gains. All schedules retain the 4M aggregate categorical ceiling. Different first-attempt allocations remain visible.</div>"
    page+=f"<p>Selected fixed policy: <strong>{html.escape(selected or 'none in this exploration')}</strong>. Independent array/path/assignment audit: {audit.checks:,} checks, {audit.paths:,} paths, {audit.assignments:,} successful assignments.</p>"
    page+="<p><a href='resilience_metrics.csv'>All-case CSV</a> · <a href='resilience_rows.json'>Detailed rows</a> · <a href='resilience_summary.json'>Per-fixture and common-success aggregates</a> · <a href='campaign.json'>Registered corpus/source receipt</a></p>"
    page+=overview+f"<p>The common-success cohort across every row contains {len(common)} cases; separate policy-versus-C cohorts are in the summary. Counts include all 36 cases per policy. Preview PNGs are embedded for offline viewing; original PNGs and raw JSON are alongside this page.</p>"
    page+="<p><input id='filter' aria-label='Filter cases' placeholder='Filter fixture, profile, seed, failure status or reason'></p>"+"".join(cards)
    page+="<script>document.getElementById('filter').addEventListener('input',e=>{const terms=e.target.value.toLowerCase().split(/\\s+/);document.querySelectorAll('article').forEach(a=>a.hidden=!terms.every(t=>a.dataset.search.toLowerCase().includes(t)))})</script></html>"
    (out/"index.html").write_text(page)
    (out/"material_palette.json").write_text(json.dumps({str(i):{"name":name,"rgb":rgb} for i,(name,rgb) in PALETTE.items()},indent=2)+"\n")
    print(f"Audited {len(rows)} rows; {audit.checks:,} checks; {audit.paths} paths; {audit.assignments} complete assignments. Retained {len(list(images.glob('*.png')))} exact PNGs.")

if __name__=="__main__":
    main()
