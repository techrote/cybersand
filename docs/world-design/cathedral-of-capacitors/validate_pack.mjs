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
const validateScene=(scene,name,staggered)=>{
 check(scene?.placements?.length===p.features?.length,name+" missing feature placements");
 const sw=scene?.size?.[0],sh=scene?.size?.[1];
 check(Number.isInteger(sw)&&sw>0&&Number.isInteger(sh)&&sh>0,name+" invalid scene size");
 check(Number.isInteger(scene.baseline_y)&&scene.baseline_y>0&&scene.baseline_y<=sh,name+" baseline");
 const seen=new Set();let rectCount=0;
 for(const at of scene.placements||[]){
  const f=fmap.get(at.feature_id);check(!!f,name+" unknown feature "+at.feature_id);if(!f)continue;
  check(!seen.has(f.id),name+" duplicated module "+f.id);seen.add(f.id);
  const[x,y]=at.origin||[];check(Number.isInteger(x)&&Number.isInteger(y)&&x>=0&&y>=0&&x+f.size[0]<=sw&&y+f.size[1]<=sh,name+" extent "+f.id);
  if(staggered){
   check(at.anchor_world?.[0]===x+Math.floor(f.size[0]/2)&&at.anchor_world?.[1]===y+f.size[1],name+" staged anchor "+f.id);
   check(y+f.size[1]<=scene.baseline_y,name+" below staging datum "+f.id);
  }else check(y+f.size[1]===scene.baseline_y,name+" ground mismatch "+f.id);
  const va=at.variant?f.variants.find(v=>v.id===at.variant):null;check(!at.variant||!!va,name+" variant "+f.id);
  for(const v of f.rectangles){const id=Number(va?.swap?.[v[4]]??v[4]),m=map.get(id);check(!!m&&!m.movable&&m.kernel===0,name+" unsafe module "+f.id+" id:"+id);rectCount++;}
 }
 check(seen.size===p.features?.length,name+" lost module");check(rectCount>=150,name+" insufficient composition");
 for(const layerName of ["backdrop_rectangles","foreground_rectangles"]){
  const layer=scene[layerName];check(Array.isArray(layer),name+" missing "+layerName);
  if(!Array.isArray(layer))continue;
  check(layer.length>10,name+" sparse "+layerName);
  for(const [i,v]of layer.entries()){
   const shape=Array.isArray(v)&&v.length===5&&v.every(Number.isInteger);check(shape,name+" invalid rectangle "+layerName+"#"+i);if(!shape)continue;
   const[x,y,w,h,id]=v;check(x>=0&&y>=0&&w>0&&h>0&&x+w<=sw&&y+h<=sh,name+" bounds "+layerName+"#"+i);
   const m=map.get(id);check(!!m&&!m.movable&&m.kernel===0,name+" unsafe material "+layerName+"#"+i);
  }
 }
};
validateScene(p.combined_scene||{},"flagship",false);
check(!!p.alternate_scene,"alternate composition missing");
if(p.alternate_scene)validateScene(p.alternate_scene,"alternate",true);
return errors;
};
const pack=JSON.parse(fs.readFileSync(new URL('./pack.json',import.meta.url),'utf8'));
const cat=process.argv[2]?JSON.parse(fs.readFileSync(process.argv[2],'utf8')):null;
const en=process.argv[3]?fs.readFileSync(process.argv[3],'utf8'):null;
const errors=validatePack(pack,cat,en);
if(errors.length){console.error(errors.join('\n'));process.exitCode=1;}else console.log('PASS: '+pack.features.length+' features, '+pack.palette.length+' source-pinned palette materials, '+pack.features.reduce((a,f)=>a+f.rectangles.length,0)+' rectangles; dry combined scene');

if(process.argv.includes("--negative")){
 const defects=[p=>p.combined_scene.backdrop_rectangles[0][0]=-1,p=>p.combined_scene.backdrop_rectangles[0][2]=0,p=>p.combined_scene.backdrop_rectangles[0][3]=999,p=>p.combined_scene.backdrop_rectangles[0][4]=34,p=>p.combined_scene.foreground_rectangles[0][4]=3,p=>p.combined_scene.foreground_rectangles[0][4]=999,p=>p.combined_scene.foreground_rectangles[0][0]=1250,p=>p.combined_scene.foreground_rectangles[0]=[0,0,1,2],p=>p.combined_scene.foreground_rectangles=[],p=>p.alternate_scene.backdrop_rectangles[0][0]=-1,p=>p.alternate_scene.backdrop_rectangles[1][2]=0,p=>p.alternate_scene.backdrop_rectangles[2][4]=34,p=>p.alternate_scene.foreground_rectangles[2][4]=3,p=>p.alternate_scene.foreground_rectangles[3][3]=900,p=>p.alternate_scene.placements[0].origin[0]=-2,p=>p.alternate_scene.placements[3].variant=null,p=>p.alternate_scene.placements[4].anchor_world[1]++,p=>p.alternate_scene.placements[6].feature_id=p.alternate_scene.placements[0].feature_id,p=>p.alternate_scene.placements.pop()];
 let refused=0;for(const breakOne of defects){const altered=JSON.parse(JSON.stringify(pack));breakOne(altered);if(validatePack(altered,cat,en).length)refused++}
 if(refused!==defects.length){console.error("FAIL negatives "+refused+"/"+defects.length);process.exitCode=1}else console.log("PASS "+refused+"/"+defects.length+" negative scene mutations refused");
}
