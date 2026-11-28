#!/usr/bin/env node
// Read-only independent reduction of the derived review index. This does not
// replace raw native cell-array or PNG verification.
import fs from "node:fs";
import path from "node:path";
const directory = process.argv[2];
if (!directory) throw new Error("Usage: node metadata-review.mjs EVIDENCE_DIRECTORY");
const read = name => JSON.parse(fs.readFileSync(path.join(directory,name),"utf8"));
const native=read("creative-native-summary.json");
const index=read("full-displayed-2743-receipt-review-index.json");
const campaign=read("summary.json");
const expectedSource="2743f89a0df6f6afcf7484e859c10790d521e74b", expectedTree="56687bcaa8eb58fbdf1bbeb673d74a40dcc9b634";
const ids=["industrial_repair","structural_facade","scifi_interior","revised_arcology","protected_courtyard","palette_foundry","stopped_workshop","staged_megaframe","xeno_vault"];
let checks=0;const failures=[];const ok=(cond,label)=>{checks++;if(!cond)failures.push(label);};
const same=(a,b)=>JSON.stringify(Object.keys(a).sort().map(k=>[k,a[k]]))===JSON.stringify(Object.keys(b).sort().map(k=>[k,b[k]]));
const src=r=>({generation:r.generation,revision:r.revision,tick:r.tick,authoring_generation:r.authoring_generation});
const scalar=r=>["requested","checked","changed","unchanged","excluded","refused","confirmed"].every(k=>Number.isInteger(r[k])&&r[k]>=0);
const nativeCase=campaign.cases.find(c=>c.name==="test_art_collaborative_native");
ok(campaign.source.commit===expectedSource&&campaign.source.tree===expectedTree&&campaign.source.tracked_source_clean===true,"source identity");
ok(index.source===expectedSource&&campaign.status==="passed"&&campaign.graphical===true,"source/displayed verdict");
ok(native.scenarios===9&&native.outcomes.length===9&&native.failures===0&&native.model_requests===0,"nine retained native scenarios");
ok(nativeCase.result.scenarios===9&&nativeCase.exit_code===0&&nativeCase.status==="passed","native terminal outcome");
ok(index.files.length===18,"all eighteen original receipt indexes");
const reports=[];
let totalNative=0,totalDirect=0,stagedUsec=0,directUsec=0,stagedChunks=0,directChunks=0;
for(let i=0;i<ids.length;i++){
 const o=native.outcomes[i],prefix=String(i).padStart(2,"0")+"-"+ids[i];
 ok(o.id===ids[i],"ordered scenario "+i);
 ok(o.constraint_preservation===true&&o.static_clearance===true,"declared exact constraints "+o.id);
 ok(o.preview.ok===true&&o.preview.zero_native_writes===true&&o.preview.conflict_count===0,"zero-write preview "+o.id);
 ok(o.preview.predicted_materials_sha256===o.after_materials_sha256,"predicted final plane "+o.id);
 ok(o.context_inspector.captured_cells===o.region[2]*o.region[3]&&o.context_inspector.captured_cells<=262144,"native plane capacity "+o.id);
 ok(o.context_inspector.bytes<=o.context_inspector.budget_bytes&&o.context_inspector.budget_bytes===24576,"context budget "+o.id);
 ok(o.stage_timings.reduce((n,v)=>n+v.native_execution_usec,0)===o.native_execution_usec&&o.elapsed_usec>=o.native_execution_usec,"timing scopes "+o.id);
 const direct=o.comparisons.find(a=>a.arm==="existing_direct_matched_geometry");
 ok(direct?.complete_material_plane_matches===true&&direct.material_sha256===o.after_materials_sha256,"matched direct final plane "+o.id);
 ok(o.comparisons.find(a=>a.arm==="knowledge_disabled_fixed_proposal")?.same_predicted_material_plane===true,"fixed packet ablation "+o.id);
 const perArm={};
 for(const [arm,suffix,summary] of [["staged","original-native-receipts.json",o],["direct","direct-original-native-receipts.json",direct]]){
   const f=index.files.find(f=>f.name===prefix+"-"+suffix);
   ok(!!f,"indexed file "+arm+" "+o.id);if(!f)continue;
   ok(f.original_sha256===nativeCase.artifacts_sha256[f.name],"original file custody "+f.name);
   const totals={requested:0,checked:0,changed:0,unchanged:0,excluded:0,refused:0,confirmed:0};
   let previous=null;
   for(let n=0;n<f.receipts.length;n++){
    const r=f.receipts[n],tag=arm+" "+o.id+" #"+n;
    ok(r.backend==="CyberNativeCellWorld"&&r.status==="completed"&&r.reason==="", "native completed backend "+tag);
    ok(scalar(r)&&r.checked===r.requested&&r.confirmed===r.checked&&r.excluded===0&&r.refused===0, "actual counter partition "+tag);
    ok(r.changed+r.unchanged===r.confirmed&&r.readback_review.count===r.confirmed&&/^[0-9a-f]{64}$/.test(r.readback_review.canonical_json_sha256),"indexed readback extent "+tag);
    ok(r.revision-r.before_source.revision===r.changed&&r.generation===r.before_source.generation&&r.tick===r.before_source.tick&&r.authoring_generation===r.before_source.authoring_generation,"native source advance "+tag);
    if(previous)ok(same(r.before_source,previous),"contiguous receipt source "+tag);
    previous=src(r); for(const key of Object.keys(totals))totals[key]+=r[key];
   }
   ok(totals.changed===summary.native_changed&&totals.checked===summary.native_checked&&f.receipts.length===summary.native_chunks,"reduced totals match summary "+arm+" "+o.id);
   if(arm==="staged"){
      ok(same(f.receipts[0].before_source,o.source_before)&&same(previous,o.source_after),"scenario source endpoints "+o.id);
      ok(totals.checked===o.preview.requested&&totals.changed===o.preview.predicted_changed&&totals.unchanged===o.preview.predicted_unchanged,"original totals match preview "+o.id);
      let cursor=0;
      for(const st of o.preview.stages){
       let requested=0,changed=0;
       while(cursor<f.receipts.length&&requested<st.requested){requested+=f.receipts[cursor].requested;changed+=f.receipts[cursor].changed;cursor++;}
       ok(requested===st.requested&&changed===st.predicted_changed,"original stage boundary "+o.id+"/"+st.id);
      }
      ok(cursor===f.receipts.length,"all staged chunks accounted "+o.id);
      totalNative+=totals.changed;stagedChunks+=f.receipts.length;
   }else {totalDirect+=totals.changed;directChunks+=f.receipts.length;}
   perArm[arm]={chunks:f.receipts.length,...totals};
 }
 ok(perArm.staged.changed===perArm.direct.changed&&perArm.staged.checked===perArm.direct.checked,"matched native work "+o.id);
 reports.push({id:o.id,stages:o.stages,changed:o.native_changed,checked:o.native_checked,chunks:o.native_chunks,direct_chunks:direct.native_chunks,staged_execution_ms:o.native_execution_usec/1000,direct_execution_ms:direct.native_execution_usec/1000,context_build_ms:o.context_inspector.elapsed_usec/1000,max_preview_poll_ms:o.preview.maximum_poll_usec/1000});
 stagedUsec+=o.native_execution_usec;directUsec+=direct.native_execution_usec;
}
const report={source:expectedSource,tree:expectedTree,evidence_commit:"39a7a1fb72b9c694f442963ca6852499e2f56eee",checks,failures,scope:"Independent reduction of derived receipt index and original summary; raw cell arrays and PNG bytes not yet independently read.",native_case_checks:nativeCase.result.checks,cases:campaign.cases.map(c=>({name:c.name,status:c.status,checks:c.result.checks})),totals:{staged_changed:totalNative,direct_changed:totalDirect,staged_chunks:stagedChunks,direct_chunks:directChunks,staged_execution_ms:stagedUsec/1000,direct_execution_ms:directUsec/1000},rows:reports,interpretation:"Matched deterministic geometry. Timing scope now matches executor intervals, but arm order and stage boundaries differ; no causal speed or model-creativity claim."};
process.stdout.write(JSON.stringify(report,null,2)+"\n");
process.exitCode=failures.length?1:0;
