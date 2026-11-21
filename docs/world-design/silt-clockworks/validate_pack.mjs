#!/usr/bin/env node
import fs from "node:fs";import path from "node:path";import crypto from "node:crypto";import {fileURLToPath} from "node:url";
const dir=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(dir,"../../..");
const p=JSON.parse(fs.readFileSync(path.join(dir,"pack.json"),"utf8")),sourceCheck=process.argv.includes("--source-check");
let source=sourceCheck?JSON.parse(fs.readFileSync(path.join(root,p.source.shadow_catalogue),"utf8")).native.materials:p.palette.reduce((a,m)=>{a[m.id]={...m,valid:true};return a},[]);
if(sourceCheck){
 for(const [name,expected] of [[p.source.native_material_enum,p.source.native_enum_blob_sha],[p.source.shadow_catalogue,p.source.shadow_catalogue_blob_sha],[p.source.interaction_rules,p.source.interaction_rules_blob_sha]]){
 const b=fs.readFileSync(path.join(root,name));
 const sha=crypto.createHash("sha1").update(Buffer.from("blob "+b.length+"\0")).update(b).digest("hex");
 if(sha!==expected)throw Error("Source identity drift "+name+" "+sha)}
 const enumText=fs.readFileSync(path.join(root,p.source.native_material_enum),"utf8").split("enum class Material :")[1].split("enum class MaterialState")[0];
 const enumMap=new Map([...enumText.matchAll(/^\s*(\w+)\s*=\s*(\d+),/gm)].map(m=>[Number(m[2]),m[1]]));
 for(const m of p.palette){const enumName=enumMap.get(m.id)?.replace(/([a-z0-9])([A-Z])/g,"$1-$2").toLowerCase();if(enumName!==m.name)throw Error("enum mismatch "+m.id)}
}
function validate(p,source){
 if(p.schema_id!=="cybersand.world-feature-pack.proposal"||p.schema_version!==1)throw Error("schema");
 if(p.features.length!==8||p.scene.placements.length!==8||p.repeatable_patterns.length!==3)throw Error("count");
 const mats=new Map(p.palette.map(m=>[m.id,m])),feats=new Map(p.features.map(f=>[f.id,f]));
 if(mats.size!==p.palette.length||feats.size!==p.features.length)throw Error("duplicate IDs");
 for(const m of p.palette){const s=source[m.id];if(!s?.valid)throw Error("unavailable material "+m.id);
 for(const k of ["name","state","movable","kernel","lateral_flow","viscosity_index"])if(s[k]!==m[k])throw Error("source mismatch "+m.id+" "+k);
 if(JSON.stringify(s.rgba)!==JSON.stringify(m.rgba))throw Error("RGBA drift "+m.id)}
 function checkRect(r,w,h){if(!Array.isArray(r)||r.length!==5||!r.every(Number.isInteger))throw Error("shape");const [x,y,rw,rh,id]=r;if(x<0||y<0||rw<1||rh<1||x+rw>w||y+rh>h||!mats.has(id))throw Error("rectangle "+r)}
 let count=0, vcount=0;
 for(const f of p.features){
 if(f.anchor.point[1]!==f.size[1]||f.rectangles.length<15||f.neighbour_rules.length<2)throw Error("underdeveloped "+f.id);
 for(const rect of f.rectangles){checkRect(rect,...f.size);count++;const m=mats.get(rect[4]);if(f.kind==="inert-static"&&(m.movable||m.kernel!==0))throw Error("reactive static "+f.id)}
 if(f.variants.length!==2)throw Error("variant count");
 for(const v of f.variants){vcount++;if(!Object.keys(v.swap).length)throw Error("empty variant");
 for(const [a,b] of Object.entries(v.swap))if(!mats.has(b)||!f.rectangles.some(r=>r[4]===Number(a))||Number(a)===b)throw Error("invalid swap "+v.id+" "+a)}
 }
 let last=-18;for(const z of p.scene.placements){const f=feats.get(z.feature);if(!f)throw Error("missing feature");const v=f.variants.find(v=>v.id===z.variant);if(!v||z.y+f.size[1]!==226||z.x<last+18||z.x+f.size[0]>p.scene.size[0])throw Error("placement "+z.feature);
 last=z.x+f.size[0];for(const rr of f.rectangles){const m=mats.get(v.swap[String(rr[4])]??rr[4]);if(m.movable||m.kernel!==0)throw Error("gallery active "+f.id)}
 }
 for(const rr of p.scene.terrain_rectangles){checkRect(rr,...p.scene.size);const m=mats.get(rr[4]);if(m.movable||m.kernel!==0)throw Error("active terrain")}
 const alt=p.alternate_scene;
 if(!alt||alt.id!=="the-underflow-reliquary"||alt.size[0]!==1184||alt.size[1]!==420)throw Error("alternate identity/bounds");
 if(!Array.isArray(alt.placements)||alt.placements.length!==8||!Array.isArray(alt.terrain_rectangles)||alt.terrain_rectangles.length<250)throw Error("alternate count");
 const seenAlt=new Set(),boxes=[];let upper=0,lower=0;
 for(const z of alt.placements){
   const f=feats.get(z.feature);if(!f||seenAlt.has(z.feature))throw Error("alternate reuse "+z.feature);
   seenAlt.add(z.feature);const v=f.variants.find(v=>v.id===z.variant);if(!v)throw Error("alternate variant "+z.feature);
   if(!Number.isInteger(z.x)||!Number.isInteger(z.y)||z.x<0||z.y<0||z.x+f.size[0]>alt.size[0]||z.y+f.size[1]>alt.size[1])throw Error("alternate placement bounds");
   const b=[z.x,z.y,z.x+f.size[0],z.y+f.size[1]];
   if(boxes.some(a=>b[0]<a[2]&&b[2]>a[0]&&b[1]<a[3]&&b[3]>a[1]))throw Error("alternate module overlap");
   boxes.push(b);if(z.y<180)upper++;if(z.y>240)lower++;
   for(const rr of f.rectangles){const m=mats.get(v.swap[String(rr[4])]??rr[4]);if(m.movable||m.kernel!==0)throw Error("alternate active "+f.id)}
 }
 if(upper!==4||lower!==4)throw Error("alternate two-tier architecture");
 for(const rr of alt.terrain_rectangles){checkRect(rr,...alt.size);const m=mats.get(rr[4]);if(m.movable||m.kernel!==0)throw Error("alternate active terrain")}
 if(count<165||vcount!==16)throw Error("below substantive minimum");
 return {modules:p.features.length,rectangles:count,variants:vcount,material_ids:p.palette.length,patterns:p.repeatable_patterns.length,scene_rectangles:p.scene.terrain_rectangles.length,alternate_rectangles:alt.terrain_rectangles.length,alternate_placements:alt.placements.length};
}
const out=validate(p,source);let rejected=0;
if(process.argv.includes("--self-test")){const bad=[
p=>p.schema_version=2,p=>p.palette[0].name="fiction",p=>p.palette[0].rgba=[1,2,3,4],
p=>p.features[0].rectangles[0][2]=9999,p=>p.features[0].rectangles[0][4]=500,
p=>p.features[0].variants=[],p=>p.features[1].anchor.point[1]=1,
p=>p.features[3].variants[0].swap={"999":54},p=>p.scene.placements[3].x=1,
p=>p.scene.placements[5].variant=null,p=>p.scene.placements[2].y=0,
p=>p.scene.terrain_rectangles.push([0,0,5,5,3]),p=>p.features[7].rectangles[0][3]=0,p=>p.alternate_scene.terrain_rectangles.push([0,0,3,3,3]),p=>p.alternate_scene.terrain_rectangles[0][2]=9000,p=>p.alternate_scene.placements[0].x=-1,p=>p.alternate_scene.placements[5].feature="tide-gauge",p=>p.alternate_scene.placements[7].variant="missing",p=>p.alternate_scene.placements[0].y=275,p=>p.alternate_scene.placements[1].x=85];
for(const edit of bad){const clone=structuredClone(p);edit(clone);try{validate(clone,source)}catch(e){rejected++}}
if(rejected!==bad.length)throw Error("refusal count "+rejected+"/"+bad.length)}
console.log(JSON.stringify({status:"PASS",...out,source_check:sourceCheck,mutation_rejections:rejected}));
