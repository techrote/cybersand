#!/usr/bin/env node
"use strict";
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto");
function validatePack(p,source=null){
 const fail=m=>{throw Error(m)};if(p.schema_id!=="cybersand.world-feature-pack.proposal"||p.schema_version!==1)fail("schema");
 const pal=new Map();for(const m of p.palette){if(!Number.isInteger(m.id)||pal.has(m.id)||!Array.isArray(m.rgba)||m.rgba.length!==4)fail("palette");pal.set(m.id,m)}
 if(source){const src=new Map(source.native.materials.map(x=>[x.id,x]));const en=Object.fromEntries([...source.header.matchAll(/^\s*(\w+)\s*=\s*(\d+),/gm)].map(x=>[+x[2],x[1]]));for(const m of p.palette){let mm=src.get(m.id);if(!mm||!mm.valid||en[m.id]!==m.enum_name)fail("enum "+m.id);for(const k of ["name","state","rgba","movable","kernel","lateral_flow","viscosity_index","initial_state_a","initial_state_b"]){if(JSON.stringify(mm[k])!==JSON.stringify(m[k]))fail("source "+k+" "+m.id)}}}
 let fm=new Map(),rects=0,moving=0;
 for(const f of p.features){if(!f.id||fm.has(f.id)||f.size.length!==2||f.size.some(x=>!Number.isInteger(x)||x<=0))fail("feature");fm.set(f.id,f);if(f.anchor.point[0]!==Math.floor(f.size[0]/2)||f.anchor.point[1]!==f.size[1])fail("anchor");if(f.variants.length!==2||f.variants[0].id===f.variants[1].id)fail("variants");
 let used=new Set(),mob=0;for(const a of f.rectangles){if(a.length!==5||a.some(x=>!Number.isInteger(x))||a[0]<0||a[1]<0||a[2]<=0||a[3]<=0||a[0]+a[2]>f.size[0]||a[1]+a[3]>f.size[1]||!pal.has(a[4])||a[4]===0)fail("shape "+f.id);used.add(a[4]);rects++;if(pal.get(a[4]).movable||pal.get(a[4]).kernel!==0)mob++}
 if(f.kind==="inert-static"&&mob)fail("active static "+f.id);if(f.kind.startsWith("dynamic")&&!mob)fail("missing dynamics");if(mob)moving++;
 for(const v of f.variants){if(!v.id||!Object.keys(v.swap).length)fail("variant");for(const [a,b] of Object.entries(v.swap)){if(!used.has(+a)||!pal.has(+b))fail("variant ID "+f.id+" "+a)}}}
 if(p.features.length!==8||p.combined_scene.placements.length!==8)fail("count");
 const scene=p.combined_scene,seen=new Set(),boxes=[];
 if(!Array.isArray(scene.terrain_rectangles)||!scene.terrain_rectangles.length)fail("terrain absent");
 for(const a of scene.terrain_rectangles){if(!Array.isArray(a)||a.length!==5||a.some(v=>!Number.isInteger(v))||a[0]<0||a[1]<0||a[2]<1||a[3]<1||a[0]+a[2]>scene.size[0]||a[1]+a[3]>scene.size[1]||!pal.has(a[4])||pal.get(a[4]).movable||pal.get(a[4]).kernel!==0)fail("terrain shape/material");}
 for(const pl of scene.placements){const f=fm.get(pl.feature_id);if(!f||seen.has(pl.feature_id))fail("duplicate/missing placement");seen.add(pl.feature_id);const [x,y]=pl.origin;if(!Number.isInteger(x)||!Number.isInteger(y)||x<0||y<0||x+f.size[0]>scene.size[0]||y+f.size[1]>scene.size[1])fail("placement bounds");
 if(pl.anchor_world[0]!==x+f.anchor.point[0]||pl.anchor_world[1]!==y+f.anchor.point[1]||pl.anchor_world[1]!==scene.baseline_y)fail("anchor world");
 if(boxes.some(b=>x<b.x+b.w&&x+f.size[0]>b.x&&y<b.y+b.h&&y+f.size[1]>b.y))fail("overlap");boxes.push({x,y,w:f.size[0],h:f.size[1]});
 let v=pl.variant?f.variants.find(z=>z.id===pl.variant):null;if(pl.variant&&!v)fail("unknown variant");
 for(const a of f.rectangles){let id=v&&v.swap[String(a[4])]!==undefined?+v.swap[String(a[4])]:a[4],m=pal.get(id);if(!m||m.movable||m.kernel!==0)fail("moving dry material "+f.id)}}
 if(seen.size!==8)fail("scene incomplete");for(const pattern of scene.patterns){if(pattern.sequence.some(id=>!fm.has(id))||pattern.spacing.length!==pattern.sequence.length-1)fail("pattern")}
 return {modules:p.features.length,rectangles:rects,materials:p.palette.length,variants:p.features.reduce((n,f)=>n+f.variants.length,0),dynamic_modules:moving,patterns:scene.patterns.length,scene_cells:scene.size};
}
function blobHash(s){let b=Buffer.from(s,"utf8");return crypto.createHash("sha1").update("blob "+b.length+"\0").update(b).digest("hex")}
const root=path.resolve(__dirname,"../../.."),p=JSON.parse(fs.readFileSync(path.join(__dirname,"pack.json"),"utf8"));
let src=null;
if(process.argv.includes("--source")){
 let h=fs.readFileSync(path.join(root,p.source.native_material_enum),"utf8"),
 c=fs.readFileSync(path.join(root,p.source.shadow_catalogue),"utf8");
 if(blobHash(h)!==p.source.native_enum_blob_sha||blobHash(c)!==p.source.shadow_catalogue_blob_sha)throw Error("Source pin mismatch");
 src={native:JSON.parse(c).native,header:h};
}
let report=validatePack(p,src);
if(process.argv.includes("--negative")){
 const tests=[
 x=>x.features[0].rectangles[0][0]=-1,x=>x.features[0].rectangles[0][2]=0,
 x=>x.features[0].rectangles[0][2]=999,x=>x.features[0].rectangles[0][4]=10,
 x=>x.features[0].rectangles[0][0]=.4,x=>x.features[0].id=x.features[1].id,
 x=>x.features[0].anchor.point[1]--,x=>x.features[1].variants[0].swap={"999":54},
 x=>x.features[6].variants[0].swap={"3":3},x=>x.combined_scene.placements[0].origin=[190,180],
 x=>x.combined_scene.placements[0].anchor_world[1]--,
 x=>x.combined_scene.placements[7].feature_id=x.features[0].id,
 x=>x.combined_scene.placements[0].variant="wrong",x=>x.palette[0].kernel=99,
 x=>x.combined_scene.terrain_rectangles[0][0]=-1,
 x=>x.combined_scene.terrain_rectangles[0][2]=9999,
 x=>x.combined_scene.terrain_rectangles[0][4]=3
 ];
 let n=0;for(let fn of tests){let x=JSON.parse(JSON.stringify(p));fn(x);try{validatePack(x,src)}catch{n++}}
 if(n!==tests.length)throw Error("Negative tests "+n+"/"+tests.length);
 console.log("Negative tests: "+n+"/"+tests.length+" rejected");
}
console.log(JSON.stringify(report));
