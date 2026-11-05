#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const dir=path.dirname(fileURLToPath(import.meta.url));
const pack=JSON.parse(fs.readFileSync(path.join(dir,'pack.json'),'utf8'));
function need(test,why){if(!test)throw Error(why)}
function validate(p){
 need(p.schema_id==='cybersand.world-feature-pack.proposal' && p.schema_version===1,'schema');
 const material=new Map(p.palette.map(v=>[v.id,v]));
 need(material.size===p.palette.length,'duplicate palette');
 const feature=new Map(p.features.map(v=>[v.id,v]));
 need(feature.size===8,'feature count');
 for(const f of p.features){
  const [w,h]=f.size;
  need(f.anchor.point[0]===Math.floor(w/2)&&f.anchor.point[1]===h,'anchor '+f.id);
  for(const a of f.rectangles){
   const [x,y,ww,hh,m]=a;
   need(a.length===5&&a.every(Number.isInteger)&&x>=0&&y>=0&&ww>0&&hh>0&&x+ww<=w&&y+hh<=h&&material.has(m),'rectangle '+f.id);
  }
  for(const v of f.variants)for(const [from,to] of Object.entries(v.swap))need(material.has(+from)&&material.has(+to),'variant '+v.id);
 }
 for(const pl of p.combined_scene.placements){
  const f=feature.get(pl.feature_id);need(!!f,'unknown scene module');
  need(pl.origin[1]+f.size[1]===p.combined_scene.baseline_y,'baseline');
  need(pl.origin[0]>=0&&pl.origin[0]+f.size[0]<=p.combined_scene.size[0],'scene x');
  const v=pl.variant?f.variants.find(v=>v.id===pl.variant):null;
  need(!pl.variant||!!v,'unknown variant');
  for(const a of f.rectangles){
   const m=material.get(v?+(v.swap[String(a[4])]??a[4]):a[4]);
   need(!!m&&!m.movable&&m.kernel===0,'dynamic material in dry gallery '+f.id+' '+a[4]);
  }
 }
 return true;
}
validate(pack);
if(process.argv.includes('--source')){
 const native=fs.readFileSync(path.resolve(dir,'../../../native/include/cybersand/material.hpp'),'utf8');
 const source=JSON.parse(fs.readFileSync(path.resolve(dir,'../../../materials/catalogue/catalogue.json'),'utf8')).native.materials;
 const part=native.slice(native.indexOf('enum class Material :'),native.indexOf('enum class MaterialState'));
 const ids=new Map([...part.matchAll(/^\s*(\w+)\s*=\s*(\d+),/gm)].map(m=>[+m[2],m[1]]));
 for(const v of pack.palette){
  const s=source.find(x=>x.id===v.id);
  need(!!s&&s.valid&&ids.get(v.id)===v.enum_name,'missing enum '+v.id);
  for(const k of ['name','state','movable','kernel','lateral_flow','viscosity_index','initial_state_a','initial_state_b'])need(s[k]===v[k],'catalogue mismatch '+v.id+'/'+k);
  need(JSON.stringify(s.rgba)===JSON.stringify(v.rgba),'colour mismatch '+v.id);
 }
}
if(process.argv.includes('--negative')){
 let rejected=0;
 const edits=[
  p=>p.features[0].rectangles[0][0]=-1,
  p=>p.features[0].rectangles[0][2]=0,
  p=>p.features[0].rectangles[0][4]=250,
  p=>p.features[2].rectangles[0][0]=99999,
  p=>p.features[3].anchor.point[1]=0,
  p=>p.features[4].variants[0].swap['49']=250,
  p=>p.combined_scene.placements[6].variant=null,
  p=>p.combined_scene.placements[7].variant=null,
  p=>p.combined_scene.placements[0].origin[1]=0,
  p=>p.combined_scene.placements[1].feature_id='unknown'
 ];
 for(const change of edits){
  const cp=structuredClone(pack);change(cp);
  try{validate(cp)}catch{rejected++}
 }
 need(rejected===edits.length,'negative cases rejected '+rejected+'/'+edits.length);
 console.log('10/10 deliberately-invalid mutations rejected');
}
console.log('PASS',pack.features.length,'features,',pack.features.reduce((n,f)=>n+f.rectangles.length,0),'rectangles,',pack.palette.length,'source IDs, dry scene fixed');
