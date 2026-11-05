#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import {fileURLToPath} from "node:url";
const validate=function validate(p){
const errors=[],pm=new Map(p.palette.map(x=>[x.id,x])),fm=new Map(p.features.map(x=>[x.id,x]));
function check(z,w,h,label){if(!Array.isArray(z)||z.length!==5||z.some(n=>!Number.isInteger(n)))errors.push(label+" invalid tuple");else if(z[0]<0||z[1]<0||z[2]<=0||z[3]<=0||z[0]+z[2]>w||z[1]+z[3]>h||!pm.has(z[4]))errors.push(label+" bounds/material");}
if(p.schema_version!==1||p.schema_id!=="cybersand.world-feature-pack.proposal")errors.push("schema");
if(p.features.length!==8||fm.size!==8||pm.size!==p.palette.length)errors.push("duplicate feature/palette");
for(let f of p.features){if(!Array.isArray(f.size)||f.size.some(n=>!Number.isInteger(n)||n<=0))continue;
for(let z of f.rectangles)check(z,...f.size,f.id);
if(f.anchor.point[1] !== (f.anchor.type==="ground"?f.size[1]:0))errors.push("anchor "+f.id);
if(f.variants.length<2||new Set(f.variants.map(x=>x.id)).size!==f.variants.length)errors.push("variants "+f.id);
for(let v of f.variants)for(let [from,to] of Object.entries(v.swap))if(!pm.has(Number(from))||!pm.has(to))errors.push("variant unknown material "+f.id);
if(f.status==="inert-static"&&f.rectangles.some(z=>pm.get(z[4]).kernel!==0||pm.get(z[4]).movable))errors.push("not inert "+f.id);
}
for(let z of p.scene.terrain_rectangles){check(z,...p.scene.size,"terrain");if(pm.get(z[4])&&(pm.get(z[4]).movable||pm.get(z[4]).kernel!==0))errors.push("reactive exhibition terrain");}
const placed=[];
for(let q of p.scene.placements){const f=fm.get(q.feature),v=f?.variants.find(x=>x.id===q.variant);
if(!f||!v||!Number.isInteger(q.x)||!Number.isInteger(q.y)||q.x<0||q.y<0||q.x+f.size[0]>p.scene.size[0]||q.y+f.size[1]>p.scene.size[1]){errors.push("placement bounds or variant");continue;}
for(let z of f.rectangles){let id=v.swap[String(z[4])]??z[4];if(!pm.has(id)||pm.get(id).movable||pm.get(id).kernel!==0)errors.push("non-inert exhibition "+f.id+":"+id);}
if(f.anchor.type==="ground"&&q.y+f.size[1]!==296)errors.push("ground placement "+f.id);
if(f.anchor.type==="ceiling"&&q.y!==30)errors.push("ceiling placement "+f.id);
if(f.anchor.type==="ground"){if(placed.some(x=>!(q.x>=x.end+8||q.x+f.size[0]+8<=x.start)))errors.push("ground margin "+f.id);placed.push({start:q.x,end:q.x+f.size[0]});}
}
if(p.scene.placements.length!==8||new Set(p.scene.placements.map(x=>x.feature)).size!==8)errors.push("missing gallery feature");
if(!p.features.some(f=>f.rectangles.some(z=>z[4]===3))||!p.features.some(f=>f.rectangles.some(z=>z[4]===19)))errors.push("no dynamic demonstrations");
return errors;
};
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,"../../..");
const p=JSON.parse(fs.readFileSync(path.join(here,"pack.json"),"utf8")),errors=validate(p);
if(process.argv.includes("--source-check")) {
 for(let [label,file,expected] of [["enum",p.source.native_material_enum,p.source.native_enum_blob_sha],["catalogue",p.source.shadow_catalogue,p.source.shadow_catalogue_blob_sha],["interaction",p.source.interaction_rules,p.source.interaction_rules_blob_sha]]){
  try {let b=fs.readFileSync(path.join(root,file)),actual=crypto.createHash("sha1").update(Buffer.from("blob "+b.length+"\\0".replace("\\0","\0"))).update(b).digest("hex");if(actual!==expected)errors.push("Source identity drift: "+label+" "+actual);}
  catch(e){errors.push("Source file unreadable "+label+": "+e.message);}
 }
 try {let a=new Map(JSON.parse(fs.readFileSync(path.join(root,p.source.shadow_catalogue),"utf8")).native.materials.map(x=>[x.id,x]));
 for(let q of p.palette){let x=a.get(q.id);if(!x||x.name!==q.name||JSON.stringify(x.rgba)!==JSON.stringify(q.rgba)||x.movable!==q.movable||x.kernel!==q.kernel||x.state!==q.state||x.lateral_flow!==q.lateral_flow)errors.push("palette source drift material "+q.id);}}
 catch(e){errors.push("catalogue comparison error: "+e.message);}
}
if(process.argv.includes("--self-test")) {
 const mutations=[p=>p.features[0].rectangles[0][4]=10,p=>p.features[0].rectangles[0][3]=9999,p=>p.features[0].variants[0].swap["11"]=10,p=>p.features[7].rectangles[0][4]=19,p=>p.scene.placements[0].x=-1,p=>p.scene.placements[0].y=0,p=>p.scene.placements[1].variant="missing",p=>p.scene.placements[2].x=160,p=>p.features[0].variants[1].id="petrified",p=>p.schema_version=2];
 mutations.forEach((fn,i)=>{let q=structuredClone(p);fn(q);if(!validate(q).length)errors.push("negative control accepted "+i);});
}
if(errors.length){console.error(errors.join("\n"));process.exitCode=1;}
else console.log("PASS: "+p.features.length+" features / "+p.features.reduce((n,x)=>n+x.rectangles.length,0)+" rectangles / 16 variants / "+p.scene.placements.length+" inert gallery placements. Structural"+(process.argv.includes("--source-check")?" + source":"")+" only.");
