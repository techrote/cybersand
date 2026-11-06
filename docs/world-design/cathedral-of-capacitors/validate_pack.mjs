// Structural and optional exact-source validation. Usage: node validate_pack.mjs [catalogue.json] [material.hpp]
import fs from 'node:fs';
const validatePack=function validatePack(p,sourceCatalogue=null,headerText=null){
const errors=[];const check=(condition,msg)=>{if(!condition)errors.push(msg)};
check(p.schema_id==="cybersand.world-feature-pack.proposal","schema mismatch");check(p.schema_version===1,"version mismatch");
const map=new Map((p.palette||[]).map(m=>[m.id,m]));check(map.size===p.palette?.length,"duplicate palette IDs");
for(const m of p.palette||[]){check(Number.isInteger(m.id)&&m.id>=0&&m.id<132&&m.id!==10,"invalid material ID "+m.id);check(typeof m.name==="string"&&Array.isArray(m.rgba)&&m.rgba.length===4,"invalid palette entry "+m.id);
 if(sourceCatalogue){const native=sourceCatalogue.native?.materials?.find(x=>x.id===m.id&&x.valid);check(!!native,"absent source ID "+m.id);if(native)for(const k of ["name","rgba","state","movable","kernel","lateral_flow","viscosity_index","initial_state_a","initial_state_b"])check(JSON.stringify(m[k])===JSON.stringify(native[k]),"source mismatch "+m.id+"."+k);}
 if(headerText)check(new RegExp("\\b"+m.enum_name+"\\s*=\\s*"+m.id+"\\b").test(headerText),"enum mismatch "+m.id);
}
const fmap=new Map((p.features||[]).map(f=>[f.id,f]));check(fmap.size===p.features?.length,"duplicate features");
for(const f of p.features||[]){const[w,h]=f.size||[];check(Number.isInteger(w)&&w>0&&Number.isInteger(h)&&h>0,"invalid feature size "+f.id);check(f.anchor?.point?.[0]===Math.floor(w/2)&&f.anchor?.point?.[1]===h,"anchor "+f.id);check(f.rectangles?.length>10,"incomplete geometry "+f.id);
 for(const [i,v] of (f.rectangles||[]).entries()){const[x,y,rw,rh,id]=v;check([x,y,rw,rh,id].every(Number.isInteger)&&x>=0&&y>=0&&rw>0&&rh>0&&x+rw<=w&&y+rh<=h,"rectangle bounds "+f.id+"#"+i);check(map.has(id),"unknown rectangle material "+f.id+"#"+i);}
 for(const va of f.variants||[]){for(const [from,to] of Object.entries(va.swap||{})){check(map.has(Number(from))&&map.has(to),"unknown variant swap "+f.id);check(f.rectangles.some(r=>r[4]===Number(from)),"unused variant swap "+f.id);}}
 if(f.kind==="inert-static")for(const r of f.rectangles){const m=map.get(r[4]);check(m&&!m.movable&&m.kernel===0,"unsafe fixed feature "+f.id)}
}
const scene=p.combined_scene||{};check(scene.placements?.length===p.features?.length,"scene not composed of all modules");const sw=scene.size?.[0],sh=scene.size?.[1];
let rectCount=0;
for(const at of scene.placements||[]){const f=fmap.get(at.feature_id);check(!!f,"unknown scene feature "+at.feature_id);if(!f)continue;const[x,y]=at.origin;check(x>=0&&y>=0&&x+f.size[0]<=sw&&y+f.size[1]<=sh,"scene extent "+f.id);check(y+f.size[1]===scene.baseline_y,"scene ground mismatch "+f.id);const va=at.variant?f.variants.find(v=>v.id===at.variant):null;check(!at.variant||!!va,"unknown scene variant "+f.id);for(const v of f.rectangles){const id=Number(va?.swap?.[v[4]]??v[4]),m=map.get(id);check(!!m&&!m.movable&&m.kernel===0,"unsafe combined scene "+f.id+" id:"+id);rectCount++;}}
check(rectCount>=150,"insufficient scene composition");
for(const layerName of ["backdrop_rectangles","foreground_rectangles"]){
 const layer=scene[layerName];check(Array.isArray(layer),"missing scene layer "+layerName);
 if(!Array.isArray(layer))continue;
 check(layer.length>10,"insufficient scene layer "+layerName);
 for(const [i,r] of layer.entries()){
  const shape=Array.isArray(r)&&r.length===5&&r.every(Number.isInteger);
  check(shape,"invalid art rectangle "+layerName+"#"+i);if(!shape)continue;
  const [x,y,w,h,id]=r;
  check(x>=0&&y>=0&&w>0&&h>0&&x+w<=sw&&y+h<=sh,"scene rectangle bounds "+layerName+"#"+i);
  const m=map.get(id);check(!!m&&!m.movable&&m.kernel===0,"nonfixed scene material "+layerName+"#"+i);
 }
}
return errors;
};
const pack=JSON.parse(fs.readFileSync(new URL('./pack.json',import.meta.url),'utf8'));
const cat=process.argv[2]?JSON.parse(fs.readFileSync(process.argv[2],'utf8')):null;
const en=process.argv[3]?fs.readFileSync(process.argv[3],'utf8'):null;
const errors=validatePack(pack,cat,en);
if(errors.length){console.error(errors.join('\n'));process.exitCode=1;}else console.log('PASS: '+pack.features.length+' features, '+pack.palette.length+' source-pinned palette materials, '+pack.features.reduce((a,f)=>a+f.rectangles.length,0)+' rectangles; dry combined scene');

if(process.argv.includes("--negative")){
 const defects=[p=>p.combined_scene.backdrop_rectangles[0][0]=-1,p=>p.combined_scene.backdrop_rectangles[0][2]=0,p=>p.combined_scene.backdrop_rectangles[0][3]=999,p=>p.combined_scene.backdrop_rectangles[0][4]=34,p=>p.combined_scene.foreground_rectangles[0][4]=3,p=>p.combined_scene.foreground_rectangles[0][4]=999,p=>p.combined_scene.foreground_rectangles[0][0]=1250,p=>p.combined_scene.foreground_rectangles[0]=[0,0,1,2],p=>p.combined_scene.foreground_rectangles=[]];
 let refused=0;for(const breakOne of defects){const altered=JSON.parse(JSON.stringify(pack));breakOne(altered);if(validatePack(altered,cat,en).length)refused++}
 if(refused!==defects.length){console.error("FAIL negatives "+refused+"/"+defects.length);process.exitCode=1}else console.log("PASS "+refused+"/"+defects.length+" negative scene mutations refused");
}
