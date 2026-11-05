#!/usr/bin/env node
// Source-sensitive design-stage checks. This does not run native or Godot simulation.
import {readFileSync} from "node:fs";
import {dirname,join,resolve} from "node:path";
import {fileURLToPath} from "node:url";
function validatePack(p,c,h){
 const check=(c,m)=>{if(!c)throw Error(m)};
 const mMap=new Map(c.native.materials.map(q=>[q.id,q]));
 const enumSection=h.split("enum class Material :")[1]?.split("};")[0]||"";
 const enumMap=new Map([...enumSection.matchAll(/^\s*(\w+)\s*=\s*(\d+)\s*,/gm)].map(m=>[+m[2],m[1]]));
 check(p.schema_id==="cybersand.world-feature-pack.proposal"&&p.schema_version===1,"schema");
 check(p.features.length>=4&&p.features.length<=10,"feature count");
 check(p.source.native_enum_blob_sha&&p.source.shadow_catalogue_blob_sha,"missing source blobs");
 const mats=new Map();
 for(const q of p.palette){
  const m=mMap.get(q.id);check(m&&m.valid&&!mats.has(q.id),"material ID "+q.id);
  check(q.enum_name===enumMap.get(q.id),"native enum mismatch "+q.id);
  for(const k of ["name","rgba","state","movable","kernel","lateral_flow","viscosity_index","initial_state_a","initial_state_b"])
   check(JSON.stringify(m[k])===JSON.stringify(q[k]),"catalogue mismatch "+q.id+"."+k);
  mats.set(q.id,q);
 }
 let total=0;const seen=new Map();
 for(const f of p.features){
  check(!seen.has(f.id),"duplicate feature");seen.set(f.id,f);
  const [W,H]=f.size;
  check(Number.isInteger(W)&&Number.isInteger(H)&&W>0&&H>0,"invalid size");
  check(f.anchor.point[0]===Math.floor(W/2)&&f.anchor.point[1]===H,"invalid feature anchor");
  check(f.rectangles.length>=10,"empty feature "+f.id);
  let active=false;
  for(const r of f.rectangles){
   check(r.length===5&&r.every(Number.isInteger),"noninteger rectangles");
   const [x,y,w,h,id]=r;
   check(x>=0&&y>=0&&w>0&&h>0&&x+w<=W&&y+h<=H,"rectangle bounds "+f.id+" "+JSON.stringify(r));
   check(mats.has(id),"unknown stamp material "+id);
   const m=mats.get(id);active ||= m.movable||m.kernel!==0;total++;
  }
  check((f.kind==="inert-static")===!active,"kind is not source-matched "+f.id);
  check(f.variants.length===2,"variant count "+f.id);
  check(f.variants[0].id!==f.variants[1].id,"duplicate variant");
  for(const v of f.variants){
   check(Object.keys(v.swap).length>0,"empty swap");
   for(const [original,target] of Object.entries(v.swap)){
    check(mats.has(+original)&&mats.has(target)&&+original!==target,"bad swap IDs");
    check(f.rectangles.some(r=>r[4]===+original),"variant source unused "+original);
   }
  }
 }
 const scene=p.combined_scene,placed=new Set();
 for(const position of scene.placements){
  const f=seen.get(position.feature_id);
  check(f&&!placed.has(f.id),"invalid/duplicate scene module");placed.add(f.id);
  const [x,y]=position.origin,[W,H]=f.size;
  check(Number.isInteger(x)&&Number.isInteger(y)&&x>=0&&y>=0&&x+W<=scene.size[0]&&y+H<=scene.size[1],"scene bounds");
  check(y+H===scene.baseline_y&&position.anchor_world[0]===x+Math.floor(W/2)&&position.anchor_world[1]===scene.baseline_y,"scene anchor");
  const variant=f.variants.find(v=>v.id===position.variant);
  check(position.variant===null||variant,"unknown scene variant");
  for(const rect of f.rectangles){const id=variant?.swap?.[String(rect[4])]??rect[4];const m=mats.get(id);check(m&&!m.movable&&m.kernel===0,"active material in dry scene "+id+" / "+f.id)}
 }
 check(placed.size===p.features.length,"combined scene omitted a feature");
 for(const pattern of scene.patterns){
  check(pattern.sequence.length>=2&&pattern.spacing.length===pattern.sequence.length-1,"pattern spacing");
  for(const f of pattern.sequence)check(seen.has(f),"unknown pattern module "+f);
 }
 return {features:seen.size,rectangles:total,materials:mats.size,variants:p.features.reduce((a,f)=>a+f.variants.length,0),dry_scene_placements:placed.size,patterns:scene.patterns.length};
}
const directory=dirname(fileURLToPath(import.meta.url));
const p=JSON.parse(readFileSync(join(directory,"pack.json"),"utf8"));
const c=JSON.parse(readFileSync(resolve(directory,"../../../materials/catalogue/catalogue.json"),"utf8"));
const h=readFileSync(resolve(directory,"../../../native/include/cybersand/material.hpp"),"utf8");
const info=validatePack(p,c,h);
console.log("PASS authoring geometry/source fields",JSON.stringify(info));
if(process.argv.includes("--negative")){
 const mutations=[
 p=>p.features[0].rectangles[0][0]=-1,
 p=>p.features[0].rectangles[0][2]=5000,
 p=>p.features[0].rectangles[0][4]=10,
 p=>p.features[0].kind="dynamic-liquid",
 p=>p.features[0].variants[0].swap["122"]=777,
 p=>p.features[0].variants[0].swap["122"]=122,
 p=>p.features[0].variants[0].id=p.features[0].variants[1].id,
 p=>p.palette[0].rgba[0]=0,
 p=>p.palette[0].kernel=999,
 p=>p.combined_scene.placements[0].origin[0]=-2,
 p=>p.combined_scene.placements[0].anchor_world[1]=-1,
 p=>p.combined_scene.placements[6].variant=null,
 p=>p.combined_scene.patterns[0].sequence[0]="unknown"
 ];
 let denied=0;
 for(const change of mutations){const damaged=JSON.parse(JSON.stringify(p));change(damaged);try{validatePack(damaged,c,h)}catch{denied++}}
 if(denied!==mutations.length)throw Error("Negative-test rejection regression "+denied+"/"+mutations.length);
 console.log("PASS",denied+"/"+mutations.length,"deliberately invalid mutants refused");
}