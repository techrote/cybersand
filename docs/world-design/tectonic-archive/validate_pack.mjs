#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=path.dirname(fileURLToPath(import.meta.url));
const p=JSON.parse(fs.readFileSync(path.join(dir,'pack.json'),'utf8'));
function need(x,msg){if(!x)throw Error(msg)}
function validate(p){
 need(p.schema_id==='cybersand.world-feature-pack.proposal'&&p.schema_version===1,'schema');
 const mat=new Map(p.palette.map(x=>[x.id,x])), fm=new Map(p.features.map(f=>[f.id,f]));
 need(mat.size===p.palette.length&&p.palette.length===25,'palette');
 need(fm.size===8&&p.features.length===8,'features');
 let count=0;
 for(const f of p.features){
  const [w,h]=f.size;need(f.anchor.point[0]===Math.floor(w/2)&&f.anchor.point[1]===h,'anchor '+f.id);
  need(f.rectangles.length>=20&&f.variants.length===2,'module content '+f.id);
  for(const a of f.rectangles){
   const [x,y,ww,hh,id]=a;
   need(a.length===5&&a.every(Number.isInteger)&&x>=0&&y>=0&&ww>0&&hh>0&&x+ww<=w&&y+hh<=h&&mat.has(id),'rectangle '+f.id);count++;
   if(f.kind==='inert-static'){const m=mat.get(id);need(!m.movable&&m.kernel===0,'static original '+f.id);}
  }
  for(const v of f.variants){need(v.id&&Object.keys(v.swap).length,'variant');for(const [src,dst] of Object.entries(v.swap))need(mat.has(+src)&&mat.has(dst),'swap '+v.id);}
 }
 need(p.combined_scene.placements.length===8,'placements');
 let lastEnd=-1;
 for(const pl of p.combined_scene.placements){
  const f=fm.get(pl.feature_id);need(!!f,'missing module');
  const variant=pl.variant?f.variants.find(v=>v.id===pl.variant):null;
  need(!pl.variant||!!variant,'missing scene variant');
  need(pl.origin[1]+f.size[1]===p.combined_scene.baseline_y&&pl.origin[0]>=lastEnd+20&&pl.origin[0]+f.size[0]<=p.combined_scene.size[0],'scene bounds/spacing');
  lastEnd=pl.origin[0]+f.size[0];
  need(pl.anchor_world[0]===pl.origin[0]+f.anchor.point[0]&&pl.anchor_world[1]===p.combined_scene.baseline_y,'anchor world');
  for(const a of f.rectangles){const target=variant?+(variant.swap[String(a[4])]??a[4]):a[4];const m=mat.get(target);need(!!m&&!m.movable&&m.kernel===0,'dynamic dry scene '+f.id);}
 }
 const sc=p.combined_scene;let artCount=0;
 for(const key of ['backdrop_rectangles','foreground_rectangles']){
  need(Array.isArray(sc[key])&&sc[key].length>=100,'scene art presence '+key);
  for(const a of sc[key]){
   need(Array.isArray(a)&&a.length===5&&a.every(Number.isInteger),'scene art integer '+key);
   const [x,y,w,h,id]=a,m=mat.get(id);
   need(x>=0&&y>=0&&w>0&&h>0&&x+w<=sc.size[0]&&y+h<=sc.size[1],'scene art bounds '+key);
   need(!!m&&!m.movable&&m.kernel===0,'scene art fixed material '+key);
   artCount++;
  }
 }
 need(artCount>=400,'scene art depth');
 const alt=p.alternate_scene;
 need(alt&&alt.id==='synclinal-rebinding'&&alt.size[0]===1360&&alt.size[1]===420,'alternate identity');
 need(alt.placements.length===8&&new Set(alt.placements.map(z=>z.feature_id)).size===8,'alternate eight modules');
 const tiers=[];
 for(const pl of alt.placements){const f=fm.get(pl.feature_id);need(!!f,'alt module');const v=pl.variant?f.variants.find(z=>z.id===pl.variant):null;need(!pl.variant||!!v,'alt variant');need(pl.origin.length===2&&pl.origin.every(Number.isInteger)&&pl.origin[0]>=0&&pl.origin[1]>=0&&pl.origin[0]+f.size[0]<=1360&&pl.origin[1]+f.size[1]<=420,'alt placement bounds');need(pl.anchor_world[0]===pl.origin[0]+f.anchor.point[0]&&pl.anchor_world[1]===pl.origin[1]+f.size[1],'alt anchor');tiers.push(pl.origin[1]+f.size[1]);for(const a of f.rectangles){const id=v?+(v.swap[String(a[4])]??a[4]):a[4];const m=mat.get(id);need(!!m&&!m.movable&&m.kernel===0,'alt dynamic module');}}
 need(tiers.filter(z=>z===187).length===4&&tiers.filter(z=>z===375).length===4,'alternate distinct tiers');
 need(alt.backdrop_rectangles.length>=400&&alt.foreground_rectangles.length>=40,'alternate authored geometry');
 for(const k of ['backdrop_rectangles','foreground_rectangles'])for(const a of alt[k]){need(Array.isArray(a)&&a.length===5&&a.every(Number.isInteger),'alt stamp shape');const [x,y,w,h,id]=a,m=mat.get(id);need(x>=0&&y>=0&&w>0&&h>0&&x+w<=1360&&y+h<=420,'alt stamp bounds');need(!!m&&!m.movable&&m.kernel===0,'alt active stamp');}
 return count;
}
const count=validate(p);
if(process.argv.includes('--source')){
 const native=fs.readFileSync(path.resolve(dir,'../../../native/include/cybersand/material.hpp'),'utf8');
 const catalogue=JSON.parse(fs.readFileSync(path.resolve(dir,'../../../materials/catalogue/catalogue.json'),'utf8')).native.materials;
 const enums=native.slice(native.indexOf('enum class Material :'),native.indexOf('enum class MaterialState'));
 const ids=new Map([...enums.matchAll(/^\s*(\w+)\s*=\s*(\d+),/gm)].map(m=>[+m[2],m[1]]));
 for(const v of p.palette){
  const actual=catalogue.find(x=>x.id===v.id);
  need(actual&&actual.valid&&ids.get(v.id)===v.enum_name,'source enum '+v.id);
  for(const k of ['name','state','movable','kernel','lateral_flow','viscosity_index','initial_state_a','initial_state_b'])need(actual[k]===v[k],'catalogue '+v.id+' '+k);
  need(JSON.stringify(actual.rgba)===JSON.stringify(v.rgba),'colour '+v.id);
 }
}
if(process.argv.includes('--negative')){
 const edits=[
  p=>p.features[0].rectangles[0][0]=-1,
  p=>p.features[0].rectangles[0][2]=0,
  p=>p.features[1].rectangles[0][0]=999,
  p=>p.features[2].rectangles[0][4]=999,
  p=>p.features[3].anchor.point[1]=0,
  p=>p.features[4].variants[0].swap['49']=999,
  p=>p.combined_scene.placements[6].variant=null,
  p=>p.combined_scene.placements[7].variant=null,
  p=>p.combined_scene.placements[0].origin[1]=0,
  p=>p.combined_scene.placements[1].feature_id='unknown',
  p=>p.combined_scene.placements[2].origin[0]=50,
  p=>p.features[5].rectangles[0][3]=900,
  p=>p.palette.push({...p.palette[0]}),
  p=>p.combined_scene.backdrop_rectangles[0][0]=-1,
  p=>p.combined_scene.foreground_rectangles[0][2]=0,
  p=>p.combined_scene.backdrop_rectangles[1][4]=3,
  p=>p.alternate_scene.placements.pop(),
  p=>p.alternate_scene.placements[0].origin[0]=-1,
  p=>p.alternate_scene.placements[1].variant='unknown',
  p=>p.alternate_scene.placements[2].anchor_world[0]=-1,
  p=>p.alternate_scene.backdrop_rectangles[0][4]=3,
  p=>p.alternate_scene.foreground_rectangles[0][2]=0,
  p=>p.alternate_scene.foreground_rectangles[0][1]=900,
    p=>p.combined_scene.foreground_rectangles[1][1]=900
 ];
 let rejected=0;
 for(const edit of edits){const copy=structuredClone(p);edit(copy);try{validate(copy)}catch{rejected++}}
 need(rejected===edits.length,'negative rejection '+rejected+'/'+edits.length);
 console.log(rejected+'/'+edits.length,'bad mutations correctly rejected');
}
console.log('PASS',p.features.length,'features,',count,'rectangles,',p.palette.length,'materials; dry scene fixed');
console.log('PASS composed art',p.combined_scene.backdrop_rectangles.length,'backdrop,',p.combined_scene.foreground_rectangles.length,'foreground fixed scene rectangles');
