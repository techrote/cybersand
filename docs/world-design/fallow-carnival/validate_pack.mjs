#!/usr/bin/env node
"use strict";
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto");
function validatePack(p,source=null){
 const fail=m=>{throw Error(m)},int=Number.isInteger;
 if(p.schema_id!=="cybersand.world-feature-pack.proposal"||p.schema_version!==1)fail("schema");
 if(!Array.isArray(p.features)||p.features.length!==8||!Array.isArray(p.palette))fail("feature count");
 const pal=new Map();for(const m of p.palette){if(!int(m.id)||pal.has(m.id)||!Array.isArray(m.rgba)||m.rgba.length!==4)fail("palette");pal.set(m.id,m)}
 if(source){const src=new Map(source.catalogue.native.materials.map(x=>[x.id,x]));const en=Object.fromEntries([...source.header.matchAll(/^\s*(\w+)\s*=\s*(\d+),/gm)].map(x=>[+x[2],x[1]]));for(const m of p.palette){const mm=src.get(m.id);if(!mm||!mm.valid||en[m.id]!==m.enum_name)fail("enum "+m.id);for(const k of ["name","state","rgba","movable","kernel","lateral_flow","viscosity_index","initial_state_a","initial_state_b"]){if(JSON.stringify(mm[k])!==JSON.stringify(m[k]))fail("source "+k+" "+m.id)}}}
 const fm=new Map();let total=0,active=0;
 for(const f of p.features){if(!f.id||fm.has(f.id)||!Array.isArray(f.size)||f.size.length!==2||f.size.some(x=>!int(x)||x<=0))fail("module");fm.set(f.id,f);
 if(f.anchor.point[0]!==Math.floor(f.size[0]/2)||f.anchor.point[1]!==f.size[1])fail("anchor");
 if(!Array.isArray(f.variants)||f.variants.length!==2||f.variants[0].id===f.variants[1].id)fail("variants");
 let moving=0,seen=new Set();
 for(const a of f.rectangles){if(!Array.isArray(a)||a.length!==5||a.some(x=>!int(x))||a[0]<0||a[1]<0||a[2]<1||a[3]<1||a[0]+a[2]>f.size[0]||a[1]+a[3]>f.size[1]||!pal.has(a[4])||a[4]===0)fail("geometry "+f.id);
 seen.add(a[4]);total++;if(pal.get(a[4]).movable||pal.get(a[4]).kernel!==0)moving++}
 if(f.kind==="inert-static"&&moving)fail("active static "+f.id);
 if(f.kind.startsWith("dynamic-")&&!moving)fail("dynamic missing material "+f.id);
 if(moving)active++;
 for(const v of f.variants){if(!v.id||!Object.keys(v.swap).length)fail("variant empty");for(const [a,b] of Object.entries(v.swap)){if(!seen.has(+a)||!pal.has(+b))fail("variant id "+f.id)}}}
 const sc=p.combined_scene;if(sc.placements.length!==8||!int(sc.baseline_y)||sc.size.length!==2)fail("scene");if(!Array.isArray(sc.backdrop_rectangles)||sc.backdrop_rectangles.length<50)fail("backdrop missing");
 for(const a of sc.backdrop_rectangles){if(!Array.isArray(a)||a.length!==5||a.some(x=>!int(x))||a[0]<0||a[1]<0||a[2]<1||a[3]<1||a[0]+a[2]>sc.size[0]||a[1]+a[3]>sc.size[1]||!pal.has(a[4])||pal.get(a[4]).movable||pal.get(a[4]).kernel!==0)fail("backdrop geometry / inertness");}const boxes=[],seen=new Set();
 for(const pl of sc.placements){let f=fm.get(pl.feature_id);if(!f||seen.has(pl.feature_id))fail("scene duplicate");seen.add(pl.feature_id);
 const [x,y]=pl.origin;if(!int(x)||!int(y)||x<0||y<0||x+f.size[0]>sc.size[0]||y+f.size[1]>sc.size[1])fail("scene bounds");
 if(pl.anchor_world[0]!==x+f.anchor.point[0]||pl.anchor_world[1]!==y+f.anchor.point[1]||pl.anchor_world[1]!==sc.baseline_y)fail("scene anchor");
 if(boxes.some(b=>x<b[0]+b[2]&&x+f.size[0]>b[0]&&y<b[1]+b[3]&&y+f.size[1]>b[1]))fail("scene collision");boxes.push([x,y,...f.size]);
 let v=pl.variant?f.variants.find(z=>z.id===pl.variant):null;if(pl.variant&&!v)fail("scene variant");
 for(const a of f.rectangles){let id=v&&v.swap[String(a[4])]!==undefined?+v.swap[String(a[4])]:a[4],m=pal.get(id);if(!m||m.movable||m.kernel!==0)fail("active combined scene "+f.id)}}
 if(seen.size!==8)fail("scene incomplete");
 for(const pattern of sc.patterns){if(pattern.sequence.some(id=>!fm.has(id))||pattern.spacing.length!==pattern.sequence.length-1||pattern.spacing.some(n=>!int(n)||n<20))fail("pattern")}

 const alt=p.alternate_scene;
 if(!alt||alt.id!=="the-unclaimed-procession"||!Array.isArray(alt.size)||alt.size[0]!==1420||alt.size[1]!==356||!Array.isArray(alt.rectangles)||alt.rectangles.length<300||!Array.isArray(alt.foreground_rectangles)||alt.placements.length!==8)fail("alternate schema");
 for(const [kind,rs] of [["terrain",alt.rectangles],["wear",alt.foreground_rectangles]])for(const a of rs){if(!Array.isArray(a)||a.length!==5||a.some(x=>!int(x))||a[0]<0||a[1]<0||a[2]<1||a[3]<1||a[0]+a[2]>alt.size[0]||a[1]+a[3]>alt.size[1]||!pal.has(a[4])||pal.get(a[4]).movable||pal.get(a[4]).kernel!==0)fail("alternate "+kind);}
 const altSeen=new Set(),altBoxes=[];
 for(const pl of alt.placements){const f=fm.get(pl.feature_id);if(!f||altSeen.has(pl.feature_id))fail("alternate feature duplicate");altSeen.add(pl.feature_id);
 const [x,y]=pl.origin;if(!int(x)||!int(y)||x<0||y<0||x+f.size[0]>alt.size[0]||y+f.size[1]>alt.size[1]||pl.anchor_world[0]!==x+f.anchor.point[0]||pl.anchor_world[1]!==y+f.anchor.point[1])fail("alternate origin/anchor");
 if(altBoxes.some(b=>x<b[0]+b[2]&&x+f.size[0]>b[0]&&y<b[1]+b[3]&&y+f.size[1]>b[1]))fail("alternate feature overlap");
 altBoxes.push([x,y,...f.size]);let v=pl.variant?f.variants.find(z=>z.id===pl.variant):null;if(pl.variant&&!v)fail("alternate variant");
 for(const r of f.rectangles){const id=v&&v.swap[String(r[4])]!==undefined?+v.swap[String(r[4])]:r[4],m=pal.get(id);if(!m||m.movable||m.kernel!==0)fail("alternate dynamic material");}
 }
 if(altSeen.size!==8)fail("alternate incomplete");
 return {features:fm.size,rectangles:total,materials:pal.size,variants:p.features.reduce((n,f)=>n+f.variants.length,0),active_experiments:active,patterns:sc.patterns.length,scene_size:sc.size,alternate_rectangles:alt.rectangles.length,alternate_wear:alt.foreground_rectangles.length};
}
function blobHash(s){let b=Buffer.from(s,"utf8");return crypto.createHash("sha1").update("blob "+b.length+"\0").update(b).digest("hex")}
const p=JSON.parse(fs.readFileSync(path.join(__dirname,"pack.json"),"utf8"));let src=null;
if(process.argv.includes("--source")){const root=path.resolve(__dirname,"../../.."),header=fs.readFileSync(path.join(root,p.source.native_material_enum),"utf8"),cat=fs.readFileSync(path.join(root,p.source.shadow_catalogue),"utf8");if(blobHash(header)!==p.source.native_enum_blob_sha||blobHash(cat)!==p.source.shadow_catalogue_blob_sha)throw Error("Pinned source blobs changed");src={header,catalogue:JSON.parse(cat)}}
const r=validatePack(p,src);
if(process.argv.includes("--negative")){let tests=[
 x=>x.features[0].rectangles[0][0]=-1,x=>x.features[0].rectangles[0][2]=0,x=>x.features[0].rectangles[0][2]=900,x=>x.features[0].rectangles[0][4]=10,x=>x.features[0].rectangles[0][0]=1.5,x=>x.features[0].id=x.features[1].id,x=>x.features[0].anchor.point[1]--,x=>x.features[1].variants[0].swap={"999":77},x=>x.features[6].kind="inert-static",x=>x.combined_scene.placements[0].anchor_world[1]--,x=>x.combined_scene.placements[0].variant="unknown",x=>x.combined_scene.placements[0].origin=[205,50],x=>x.combined_scene.placements[6].variant=null,x=>x.palette[0].kernel=255,x=>x.combined_scene.backdrop_rectangles[0][0]=-1,x=>x.combined_scene.backdrop_rectangles[0][2]=0,x=>x.combined_scene.backdrop_rectangles[0][4]=3,x=>x.combined_scene.backdrop_rectangles[0][1]=225,x=>x.alternate_scene.rectangles[0][0]=-1,x=>x.alternate_scene.foreground_rectangles[0][4]=3,x=>x.alternate_scene.placements[0].anchor_world[1]--,x=>x.alternate_scene.placements[0].variant="does-not-exist",x=>x.alternate_scene.rectangles[0][4]=14];let n=0;for(let fn of tests){let x=JSON.parse(JSON.stringify(p));fn(x);try{validatePack(x,src)}catch{n++}}if(n!==tests.length)throw Error("Negative test result "+n+"/"+tests.length);console.log("Negative mutations rejected: "+n+"/"+tests.length)}
console.log(JSON.stringify(r,null,2));
