#!/usr/bin/env node
// Staging-only structural/source checker; does not run native simulation.
import {readFileSync} from "node:fs";
import {dirname,join,resolve} from "node:path";
import {fileURLToPath} from "node:url";
function validatePack(p,source,header){
 const assert=(cond,msg)=>{if(!cond)throw Error(msg)};
 const dMap=new Map(source.native.materials.map(x=>[x.id,x]));const eText=header.split("enum class Material :")[1]?.split("};")[0]||"";
 const eMap=new Map(Array.from(eText.matchAll(/^\s*(\w+)\s*=\s*(\d+)\s*,/gm),m=>[Number(m[2]),m[1]]));
 assert(p.schema_id==="cybersand.world-feature-pack.proposal"&&p.schema_version===1,"schema mismatch");
 assert(p.features.length>=4&&p.features.length<=10,"feature count");assert(p.palette.length>5,"palette absent");
 const materials=new Map(); for(const a of p.palette){const d=dMap.get(a.id);assert(d&&d.valid,"unknown palette id "+a.id);assert(!materials.has(a.id),"duplicate palette id");assert(eMap.get(a.id)===a.enum_name,"native enum mismatch "+a.id);for(const key of ["name","state","movable","kernel","lateral_flow","viscosity_index","initial_state_a","initial_state_b"]){assert(JSON.stringify(a[key])===JSON.stringify(d[key]),"catalogue mismatch "+a.id+"."+key)}assert(JSON.stringify(a.rgba)===JSON.stringify(d.rgba),"colour mismatch "+a.id);materials.set(a.id,a)}
 const fs=new Map();let total=0;for(const f of p.features){assert(!fs.has(f.id)&&typeof f.id==="string"&&f.id.length>0,"duplicate feature");fs.set(f.id,f);const [W,H]=f.size;assert(Number.isInteger(W)&&W>0&&Number.isInteger(H)&&H>0,"bad dimensions");assert(f.anchor.point[0]===Math.floor(W/2)&&f.anchor.point[1]===H,"invalid anchor");assert(Array.isArray(f.rectangles)&&f.rectangles.length>=10,"empty module");let active=false;
 for(const rect of f.rectangles){assert(rect.length===5&&rect.every(Number.isInteger),"bad rect");const[x,y,w,h,id]=rect;assert(x>=0&&y>=0&&w>0&&h>0&&x+w<=W&&y+h<=H,"rectangle out of feature "+f.id);assert(materials.has(id),"unknown stamp id "+id);const m=materials.get(id);active ||= m.movable || m.kernel!==0;total++}
 assert(f.variants.length===2,"expected two variants");const names=new Set();for(const v of f.variants){assert(v.id&&!names.has(v.id),"duplicate variant");names.add(v.id);assert(Object.keys(v.swap).length>0,"empty swap");for(const [old,target] of Object.entries(v.swap)){assert(materials.has(Number(old))&&materials.has(target),"bad variant target");assert(f.rectangles.some(r=>r[4]===Number(old)),"unused variant source "+old);assert(target!==Number(old),"no-op variant")}}
 assert(f.kind==="inert-static"?!active:active,"classification differs from source flags "+f.id);}
 const s=p.combined_scene;assert(s.placements.length===p.features.length,"scene must include every feature");const placements=new Set();let dry=0;
 for(const loc of s.placements){const f=fs.get(loc.feature_id);assert(f&&!placements.has(f.id),"duplicate or unknown placement");placements.add(f.id);const [x,y]=loc.origin,[W,H]=f.size;assert(Number.isInteger(x)&&Number.isInteger(y)&&x>=0&&y>=0&&x+W<=s.size[0]&&y+H<=s.size[1],"scene placement out of bounds");assert(y+H===s.baseline_y&&loc.anchor_world[0]===x+f.anchor.point[0]&&loc.anchor_world[1]===s.baseline_y,"scene ground anchor mismatch");const v=loc.variant==null?null:f.variants.find(x=>x.id===loc.variant);assert(loc.variant===null||v,"unknown variant");for(const rect of f.rectangles){const id=v&&v.swap[String(rect[4])]!==undefined?v.swap[String(rect[4])]:rect[4],mat=materials.get(id);assert(mat&&!mat.movable&&mat.kernel===0,"active material in dry gallery "+f.id+" "+id);dry+=rect[2]*rect[3]}}
 for(const pattern of s.patterns){assert(pattern.sequence.length>=2&&pattern.spacing.length===pattern.sequence.length-1,"bad pattern");for(const fid of pattern.sequence)assert(fs.has(fid),"unknown pattern feature")}
 for(const group of ["terrain_rectangles","foreground_rectangles"]){
  assert(Array.isArray(s[group])&&s[group].length>=10,"missing authored scene group "+group);
  for(const r of s[group]){assert(Array.isArray(r)&&r.length===5&&r.every(Number.isInteger),"bad scene rectangle");
   const [x,y,w,h,id]=r;assert(x>=0&&y>=0&&w>0&&h>0&&x+w<=s.size[0]&&y+h<=s.size[1],"scene bounds");
   const m=materials.get(id);assert(m&&!m.movable&&m.kernel===0,"active or unknown scene material "+id);
  }
 }
 return {terrain:s.terrain_rectangles.length,foreground:s.foreground_rectangles.length,features:p.features.length,rectangles:total,variants:p.features.reduce((n,f)=>n+f.variants.length,0),materials:p.palette.length,scene_placements:s.placements.length,scene_rect_area:dry,patterns:s.patterns.length};
}
const dir=dirname(fileURLToPath(import.meta.url));
const p=JSON.parse(readFileSync(join(dir,"pack.json"),"utf8"));
const c=JSON.parse(readFileSync(resolve(dir,"../../../materials/catalogue/catalogue.json"),"utf8"));
const h=readFileSync(resolve(dir,"../../../native/include/cybersand/material.hpp"),"utf8");
const normal=validatePack(p,c,h);
console.log("PASS",JSON.stringify(normal));
if(process.argv.includes("--negative")){
 const mutate=[
 p=>p.features[0].rectangles[0][0]=-1,
 p=>p.features[0].rectangles[0][2]=9999,
 p=>p.features[0].rectangles[0][4]=10,
 p=>p.features[0].variants[0].swap["122"]=777,
 p=>p.features[0].variants[0].swap["122"]=122,
 p=>p.features[0].variants[0].id=p.features[0].variants[1].id,
 p=>p.features[0].kind="dynamic-powder",
 p=>p.palette[0].rgba[0]=0,
 p=>p.palette[0].kernel=999,
 p=>p.combined_scene.placements[0].origin[0]=-5,
 p=>p.combined_scene.placements[0].anchor_world[1]=-1,
 p=>p.combined_scene.placements[6].variant=null,
 p=>p.combined_scene.patterns[0].sequence[0]="nonexistent",
 p=>p.combined_scene.terrain_rectangles[0][0]=-1,
 p=>p.combined_scene.terrain_rectangles[0][2]=5000,
 p=>p.combined_scene.foreground_rectangles[0][4]=3
 ];
 let refused=0;
 for(const damage of mutate){const invalid=structuredClone(p);damage(invalid);try{validatePack(invalid,c,h)}catch{refused++}}
 if(refused!==mutate.length)throw Error(`negative test regression: ${refused}/${mutate.length}`);
 console.log(`PASS ${refused}/${mutate.length} negative mutations refused`);
}
