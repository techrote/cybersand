#!/usr/bin/env node
// Design-proposal structural/source validator. No dependencies, writes nothing.
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import {fileURLToPath} from "node:url";
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,"../../..");
const pack=JSON.parse(fs.readFileSync(path.join(here,"pack.json"),"utf8"));
function validatePack(p, sourceMaterials){
 const fail=(s)=>{throw new Error(s);};
 if(p.schema_id!=="cybersand.world-feature-pack.proposal"||p.schema_version!==1)fail("schema");
 if(p.features.length!==8||p.scene.placements.length!==8)fail("eight modules/placements");
 if(p.palette.length<12||!Array.isArray(p.scene.size))fail("palette/scene");
 const pal=new Map();
 for(const m of p.palette){
  if(pal.has(m.id)||!Number.isInteger(m.id)||!sourceMaterials[m.id]||!sourceMaterials[m.id].valid)fail("palette ID");
  const s=sourceMaterials[m.id];
  for(const k of ["name","state","movable","kernel","lateral_flow","viscosity_index"])if(s[k]!==m[k])fail("catalogue drift "+k+" "+m.id);
  if(JSON.stringify(s.rgba)!==JSON.stringify(m.rgba))fail("rgba drift "+m.id);
  pal.set(m.id,m);
 }
 const ids=new Set();
 function testRect(r,w,h,context){
  if(!Array.isArray(r)||r.length!==5||!r.every(Number.isInteger))fail("rectangle shape: "+context);
  const [x,y,rw,rh,id]=r;
  if(x<0||y<0||rw<=0||rh<=0||x+rw>w||y+rh>h||!pal.has(id))fail("rectangle bounds or material: "+context);
 }
 function mapVariant(f,id){
  if(id===null||id===undefined)return {};
  const v=f.variants.find(v=>v.id===id);
  if(!v)fail("unknown variant "+id);
  return v.swap;
 }
 let rectCount=0, variantCount=0;
 for(const f of p.features){
  if(ids.has(f.id)||!f.id||!f.title)fail("duplicate feature");
  ids.add(f.id);
  const [w,hh]=f.size;
  if(!Number.isInteger(w)||!Number.isInteger(hh)||w<=0||hh<=0)fail("size");
  if(f.anchor.type!=="ground"||f.anchor.point[1]!==hh||f.anchor.point[0]<0||f.anchor.point[0]>w)fail("anchor");
  if(!Array.isArray(f.neighbour_rules)||f.neighbour_rules.length<2||!f.clearance)fail("authoring rules");
  if(!["inert-static","active-dynamic"].includes(f.kind))fail("status");
  if(f.rectangles.length<12)fail("underdeveloped feature "+f.id);
  for(const rr of f.rectangles){testRect(rr,w,hh,f.id);rectCount++;if(f.kind==="inert-static"&&(pal.get(rr[4]).movable||pal.get(rr[4]).kernel!==0))fail("incorrect inert claim "+f.id);}
  if(f.variants.length!==2)fail("variant count "+f.id);
  const seen=new Set();
  for(const v of f.variants){if(seen.has(v.id))fail("duplicate variant");seen.add(v.id);variantCount++;
   if(Object.keys(v.swap).length===0)fail("empty variant");
   for(const [src,dst] of Object.entries(v.swap)){
    if(!pal.has(Number(src))||!pal.has(dst))fail("invalid swap");
    if(!f.rectangles.some(r=>r[4]===Number(src)))fail("swap no-op");
    if(Number(src)===dst)fail("same ID swap");
   }
  }
 }
 for(const rr of p.scene.terrain_rectangles){testRect(rr,...p.scene.size,"scene terrain");if(pal.get(rr[4]).movable||pal.get(rr[4]).kernel!==0)fail("reactive terrain");}
 const placed=new Set();
 let prevRight=-1;
 for(const place of p.scene.placements){
  const f=p.features.find(f=>f.id===place.feature);if(!f)fail("unknown feature");
  if(placed.has(f.id))fail("duplicate scene feature");placed.add(f.id);
  if(!Number.isInteger(place.x)||!Number.isInteger(place.y)||place.x<0||place.y<0||place.x+f.size[0]>p.scene.size[0]||place.y+f.size[1]>p.scene.size[1])fail("scene bounds");
  if(place.y+f.size[1]!==211)fail("ground seam");
  if(place.x<prevRight+7)fail("too little gallery separation");
  prevRight=place.x+f.size[0];
  const sw=mapVariant(f,place.variant);
  for(const rr of f.rectangles){const m=pal.get(Object.prototype.hasOwnProperty.call(sw,String(rr[4]))?sw[String(rr[4])]:rr[4]);
   if(m.movable||m.kernel!==0)fail("gallery not inert "+f.id+" "+m.id);}
 }
 const alt=p.alternate_scene;
 if(!alt||alt.size[0]!==p.scene.size[0]||alt.size[1]!==p.scene.size[1]||!Array.isArray(alt.terrain_rectangles)||alt.terrain_rectangles.length<200||alt.placements.length!==8)fail("alternate shape");
 for(const rr of alt.terrain_rectangles){testRect(rr,...alt.size,"alternate terrain");if(pal.get(rr[4]).movable||pal.get(rr[4]).kernel!==0)fail("active alternate terrain");}
 const seenAlt=new Set();let right=-1;
 for(const z of alt.placements){const f=p.features.find(f=>f.id===z.feature);if(!f||seenAlt.has(z.feature))fail("alternate duplicate/missing feature");seenAlt.add(z.feature);
 if(!Number.isInteger(z.x)||!Number.isInteger(z.y)||z.x<0||z.y<0||z.x+f.size[0]>alt.size[0]||z.y+f.size[1]>alt.size[1]||z.y+f.size[1]!==211||z.x<right+7)fail("alternate seam/clearance");
 right=z.x+f.size[0];const swap=mapVariant(f,z.variant);
 for(const rr of f.rectangles){let id=Object.prototype.hasOwnProperty.call(swap,String(rr[4]))?swap[String(rr[4])]:rr[4],m=pal.get(id);if(!m||m.movable||m.kernel!==0)fail("active alternate feature "+f.id);}
 }
 if(rectCount<135||variantCount!==16)fail("insufficient deliverables");
 return {features:ids.size,feature_rectangles:rectCount,terrain_rectangles:p.scene.terrain_rectangles.length,alternate_rectangles:alt.terrain_rectangles.length,variants:variantCount,placements:placed.size,palette:pal.size};
}
function blobSha(bytes){return crypto.createHash("sha1").update(Buffer.from("blob "+bytes.length+"\0")).update(bytes).digest("hex");}
function sourceMaterialCheck(){
 const checks=[[pack.source.native_material_enum,pack.source.native_enum_blob_sha],[pack.source.shadow_catalogue,pack.source.shadow_catalogue_blob_sha],[pack.source.interaction_rules,pack.source.interaction_rules_blob_sha]];
 for(const [f,expected] of checks){const bytes=fs.readFileSync(path.join(root,f));const actual=blobSha(bytes);if(actual!==expected)throw Error(f+": source blob drift "+actual+" != "+expected);}
 const cat=JSON.parse(fs.readFileSync(path.join(root,pack.source.shadow_catalogue),"utf8"));
 const enumSource=fs.readFileSync(path.join(root,pack.source.native_material_enum),"utf8").split("enum class Material :")[1].split("enum class MaterialState")[0];
 const em=new Map([...enumSource.matchAll(/^\s*(\w+)\s*=\s*(\d+),/gm)].map(m=>[Number(m[2]),m[1]]));
 for(const p of pack.palette){const en=em.get(p.id);if(!en||en.replace(/([a-z0-9])([A-Z])/g,"$1-$2").toLowerCase()!==p.name)throw Error("Native enum ID mismatch "+p.id);}
 return validatePack(pack,cat.native.materials);
}
function selfTest(){
 const mats=pack.palette.reduce((a,p)=>{a[p.id]={...p,valid:true};return a;},[]);
 let rejected=0;
 const mods=[
 p=>p.schema_version=2,
 p=>p.palette[1].rgba=[0,0,0,0],
 p=>p.palette[1].name="fiction",
 p=>p.features[0].rectangles[0][2]=99999,
 p=>p.features[0].rectangles[0][4]=10,
 p=>p.features[0].rectangles[0]=[0,0,0,1,100],
 p=>p.features[0].variants=[],
 p=>p.features[1].anchor.point[1]=0,
 p=>p.features[3].variants[0].swap={"36":666},
 p=>p.scene.placements[0].x=5000,
 p=>p.scene.placements[4].variant=null,
 p=>p.scene.placements[2].y=1,
 p=>p.scene.placements[1].x=5,
 p=>p.alternate_scene.terrain_rectangles[0][0]=-1,
 p=>p.alternate_scene.terrain_rectangles[1][4]=8,
 p=>p.alternate_scene.placements[0].x=9999,
 p=>p.alternate_scene.placements[1].feature=p.alternate_scene.placements[0].feature,
 p=>p.alternate_scene.placements[2].variant="invalid"
 ];
 for(const fn of mods){const v=structuredClone(pack);fn(v);try{validatePack(v,mats)}catch(e){rejected++;}}
 if(rejected!==mods.length)throw Error("Mutation refusal "+rejected+"/"+mods.length);
 return rejected;
}
const args=process.argv.slice(2);
try{
 const mats=args.includes("--source-check")?JSON.parse(fs.readFileSync(path.join(root,pack.source.shadow_catalogue),"utf8")).native.materials:pack.palette.reduce((a,p)=>{a[p.id]={...p,valid:true};return a;},[]);
 const out=validatePack(pack,mats);
 if(args.includes("--source-check"))sourceMaterialCheck();
 const n=args.includes("--self-test")?selfTest():0;
 process.stdout.write(JSON.stringify({status:"PASS",...out,mutation_rejections:n,source_check:args.includes("--source-check")})+"\n");
}catch(err){console.error(err);process.exitCode=1;}
