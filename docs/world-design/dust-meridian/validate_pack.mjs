#!/usr/bin/env node
import fs from 'node:fs';
const validate=function validate(p,src){
 const bad=s=>{throw Error(s)};if(p.schema_version!==1||p.schema_id!=="cybersand.world-feature-pack.proposal")bad("schema");
 const pm=new Map(p.palette.map(x=>[x.id,x]));if(pm.size!==p.palette.length)bad("palette duplicates");
 const ids=new Set();let rectangles=0,variants=0;
 const check=(a,size)=>{if(a.length!==5||a.some(x=>!Number.isSafeInteger(x)))bad("rectangle type");const[x,y,w,h,id]=a;if(x<0||y<0||w<=0||h<=0||x+w>size[0]||y+h>size[1])bad("rectangle bounds");if(!pm.has(id))bad("rectangle material")};
 if(p.features.length!==8)bad("module count");
 for(const f of p.features){if(ids.has(f.id))bad("duplicate module");ids.add(f.id);if(f.anchor.point[1]!==f.size[1])bad("anchor");if(f.rectangles.length<10||f.variants.length!==2)bad("module size/variants");
  for(const a of f.rectangles){check(a,f.size);rectangles++}
  for(const v of f.variants){variants++;for(const [a,b] of Object.entries(v.swap)){if(!pm.has(+a)||!pm.has(b)||!f.rectangles.some(x=>x[4]===+a))bad("variant material")}}
 }
 if(variants!==16)bad("variant count");
 for(const a of p.scene.terrain_rectangles){check(a,p.scene.size);if(pm.get(a[4]).movable||pm.get(a[4]).kernel!==0)bad("terrain mobile")}
 const seen=new Set();
 for(const pl of p.scene.placements){const f=p.features.find(x=>x.id===pl.feature);if(!f||seen.has(pl.feature))bad("scene feature");seen.add(pl.feature);
  if(pl.x<0||pl.y<0||pl.x+f.size[0]>p.scene.size[0]||pl.y+f.size[1]>p.scene.size[1])bad("scene placement bounds");
  const v=f.variants.find(x=>x.id===pl.variant);if(!v)bad("scene variant");
  for(const a of f.rectangles){const n=+(v.swap[String(a[4])]??a[4]),m=pm.get(n);if(!m||m.movable||m.kernel!==0)bad("scene mobile "+pl.feature+" "+n)}
 }
 if(seen.size!==8)bad("scene coverage");
 for(const recipe of p.repeatable_patterns)if(recipe.modules.some(x=>!ids.has(x)))bad("pattern");
 if(src)for(const x of p.palette){const m=src.native.materials.find(y=>y.id===x.id&&y.valid);if(!m)bad("missing source");
  for(const key of ["name","state","movable","kernel","rgba","lateral_flow","viscosity_index","initial_state_a","initial_state_b"])if(JSON.stringify(x[key])!==JSON.stringify(m[key]))bad("catalogue drift "+x.id+" "+key)}
 return {features:p.features.length,rectangles,variants,palette:p.palette.length,placements:seen.size};
};
const [,,packPath='pack.json',cataloguePath,flag]=process.argv;
const p=JSON.parse(fs.readFileSync(packPath,'utf8'));
const src=cataloguePath&&cataloguePath!=='-'?JSON.parse(fs.readFileSync(cataloguePath,'utf8')):null;
const report=validate(p,src);
if(flag==='--negative'){
 const mutations=[
 p=>p.schema_version=2,p=>p.features[0].rectangles[0][0]=-1,p=>p.features[1].rectangles[0][2]=999,
 p=>p.features[2].rectangles[0][4]=999,p=>p.features[0].id=p.features[1].id,
 p=>p.features[4].variants[0].swap={"118":888},p=>p.features[6].variants[0].swap={"99":2},
 p=>p.scene.placements[6].variant="dust-hour",p=>p.scene.placements[7].variant="salt-inscription",
 p=>p.scene.placements[0].x=9999,p=>p.scene.placements.splice(1,1),p=>p.scene.terrain_rectangles[0][4]=2];
 let n=0;for(const f of mutations){const q=structuredClone(p);f(q);try{validate(q,src)}catch{n++}}
 if(n!==mutations.length)throw Error('negative test failure '+n+'/'+mutations.length);
 console.log('negative mutations rejected '+n+'/'+mutations.length);
}
console.log('PASS '+JSON.stringify(report)+(src?' source matched':' structure only'));
