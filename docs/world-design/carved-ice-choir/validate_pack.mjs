#!/usr/bin/env node
import fs from "node:fs";import path from "node:path";import crypto from "node:crypto";
const validatePack=function validatePack(p){
const errors=[],need=(b,msg)=>{if(!b)errors.push(msg)},pal=new Map(p.palette.map(x=>[x.id,x])),ids=new Set();
need(p.schema_id==="cybersand.world-feature-pack.proposal"&&p.schema_version===1,"schema");need(pal.size===p.palette.length,"duplicate palette");need(pal.has(0),"empty 0 missing");
function checkRect(z,size,label){need(Array.isArray(z)&&z.length===5,label+" shape");if(!Array.isArray(z)||z.length!==5)return;need(z.every(Number.isInteger),label+" noninteger");need(z[0]>=0&&z[1]>=0&&z[2]>0&&z[3]>0&&z[0]+z[2]<=size[0]&&z[1]+z[3]<=size[1],label+" bounds");need(pal.has(z[4]),label+" unknown ID "+z[4]);}
for(const x of p.features){need(!ids.has(x.id),"duplicate module");ids.add(x.id);need(["inert-static","reactive-fixed","active-dynamic"].includes(x.status),"class");need(x.rectangles.length>=8,"too few rects");for(const z of x.rectangles)checkRect(z,x.size,x.id);need(x.anchor.point[0]>=0&&x.anchor.point[0]<=x.size[0]&&x.anchor.point[1]>=0&&x.anchor.point[1]<=x.size[1],"anchor");const v=new Set();for(const alt of x.variants){need(!v.has(alt.id),"duplicate variant");v.add(alt.id);for(const [from,to]of Object.entries(alt.swap)){need(pal.has(+from)&&pal.has(to),x.id+" swap unknown");need(x.rectangles.some(q=>q[4]===+from),x.id+" unused swap "+from);}}need(x.variants.length>=2,"missing variants");if(x.status==="inert-static"){for(const z of x.rectangles)need(pal.get(z[4])?.kernel===0,x.id+" noninert");for(const alt of x.variants)for(const target of Object.values(alt.swap))need(pal.get(target)?.kernel===0,x.id+" noninert variant");}if(x.status==="active-dynamic")need(x.rectangles.some(z=>pal.get(z[4])?.movable),x.id+" no movable");}
need(p.features.length>=4&&p.features.length<=10,"module count");need(p.scene.placements.length===p.features.length,"placement count");for(const z of p.scene.terrain_rectangles)checkRect(z,p.scene.size,"terrain");const count={};for(const place of p.scene.placements){const x=p.features.find(x=>x.id===place.feature);need(!!x,"unknown feature "+place.feature);if(!x)continue;count[x.id]=(count[x.id]||0)+1;need(Number.isInteger(place.x)&&Number.isInteger(place.y)&&place.x>=0&&place.y>=0&&place.x+x.size[0]<=p.scene.size[0]&&place.y+x.size[1]<=p.scene.size[1],"placed bounds "+x.id);need(place.variant===null||x.variants.some(v=>v.id===place.variant),"bad placed variant "+x.id);}for(const x of p.features)need(count[x.id]===1,"feature not placed once "+x.id);
const alt=p.alternate_scene;
need(!!alt,"alternate missing");
if(alt){
 need(alt.id!==p.scene.id,"alternate duplicate id");
 need(Array.isArray(alt.size)&&alt.size.length===2&&alt.size.every(z=>Number.isInteger(z)&&z>0&&z<=2048),"alternate size");
 if(Array.isArray(alt.terrain_rectangles))for(const z of alt.terrain_rectangles){checkRect(z,alt.size,"alternate terrain");if(Array.isArray(z)&&z.length===5)need(pal.get(z[4])?.kernel===0&&!pal.get(z[4])?.movable,"alternate terrain noninert");}
 else need(false,"alternate terrain missing");
 const used={};
 if(Array.isArray(alt.placements)){
 need(alt.placements.length===p.features.length,"alternate placement count");
 for(const q of alt.placements){
 const f=p.features.find(f=>f.id===q.feature);
 need(!!f,"alternate unknown feature");if(!f)continue;
 used[f.id]=(used[f.id]||0)+1;
 need(Number.isInteger(q.x)&&Number.isInteger(q.y)&&q.x>=0&&q.y>=0&&q.x+f.size[0]<=alt.size[0]&&q.y+f.size[1]<=alt.size[1],"alternate bounds "+f.id);
 need(q.variant===null||f.variants.some(v=>v.id===q.variant),"alternate variant "+f.id);
 const sw=f.variants.find(v=>v.id===q.variant)?.swap||{};
 for(const z of f.rectangles){const id=Object.prototype.hasOwnProperty.call(sw,String(z[4]))?sw[String(z[4])]:z[4];need(pal.get(id)?.kernel===0&&!pal.get(id)?.movable,"alternate active cell "+f.id+" "+id);}
 }
 }else need(false,"alternate placements missing");
 for(const f of p.features)need(used[f.id]===1,"alternate missing/duplicate "+f.id);
}
return errors;
};
const here=path.dirname(new URL(import.meta.url).pathname),pack=JSON.parse(fs.readFileSync(path.join(here,"pack.json"),"utf8"));
const errors=validatePack(pack);
if(process.argv.includes("--repo-root")){const root=process.argv[process.argv.indexOf("--repo-root")+1];for(const [label,p,expected]of [["native",pack.source.native_material_enum,pack.source.native_enum_blob_sha],["shadow",pack.source.shadow_catalogue,pack.source.shadow_catalogue_blob_sha],["interactions",pack.source.interaction_rules,pack.source.interaction_rules_blob_sha]]){const bytes=fs.readFileSync(path.join(root,p));const head=Buffer.from("blob "+bytes.length+"\0","utf8");const actual=crypto.createHash("sha1").update(head).update(bytes).digest("hex");if(actual!==expected)errors.push(label+" source identity drift: "+actual);}}
if(errors.length){console.error(errors.join("\n"));process.exitCode=1;}else console.log("PASS: "+pack.features.length+" modules / "+pack.features.reduce((s,f)=>s+f.rectangles.length,0)+" rects / "+pack.scene.placements.length+" placements. Structural only.");