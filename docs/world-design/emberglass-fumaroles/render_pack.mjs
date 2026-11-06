#!/usr/bin/env node
// Source-colour SVG generator. Preview is NOT a native/Godot runtime capture.
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
const dir=path.dirname(fileURLToPath(import.meta.url));
const pack=JSON.parse(fs.readFileSync(path.join(dir,"pack.json"),"utf8"));
function svgForPack(p){
 const esc=s=>String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
 const palette=new Map(p.palette.map(m=>[m.id,m]));
 const colour=id=>{const a=palette.get(id).rgba;return `rgb(${a[0]},${a[1]},${a[2]})`;};
 const alpha=id=>palette.get(id).rgba[3]/255;
 const rect=(x,y,w,h,id)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${colour(id)}" fill-opacity="${alpha(id).toFixed(3)}"/>`;
 const feature=(f,variant,x,y)=>{const v=f.variants.find(z=>z.id===variant);const sw=v?v.swap:{};return `<g transform="translate(${x} ${y})">`+f.rectangles.map(r=>rect(r[0],r[1],r[2],r[3],Object.prototype.hasOwnProperty.call(sw,String(r[4]))?sw[String(r[4])]:r[4])).join("")+"</g>";};
 const s=p.scene, W=1280;
 const parts=[`<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="1510" viewBox="0 0 1280 1510" role="img" aria-label="Emberglass Fumaroles combined volcanic scene and eight modular features">`,
 `<rect width="1280" height="853" fill="#0d1019"/>`,
 `<rect x="0" y="0" width="1280" height="94" fill="#151923"/>`,
 `<text x="66" y="42" font-family="monospace" font-size="27" font-weight="bold" fill="#f1dcb1">EMBERGLASS / FUMAROLES</text>`,
 `<text x="68" y="68" font-family="monospace" font-size="12" fill="#9fb3bb">CYBERSAND  •  WORLD-DESIGN COLLECTION 005  •  SOURCE-COLOUR / T=0 PROPOSAL</text>`,
 `<text x="68" y="106" font-family="monospace" font-size="12" fill="#d1a874">01 — COMBINED DRY STAGING SECTION  /  ${s.size[0]}×${s.size[1]} CELLS</text>`,
 `<rect x="64" y="114" width="1152" height="271" rx="8" fill="#090c16" stroke="#343743"/>`,
 `<g transform="translate(70 126) scale(1.08)">`,
 ...s.terrain_rectangles.map(r=>rect(...r)),
 ...s.placements.map(z=>feature(p.features.find(f=>f.id===z.feature),z.variant,z.x,z.y)),
 "</g>",
 `<text x="70" y="405" font-family="monospace" font-size="12" fill="#d1a874">02 — COMPONENT INDEX  /  ORIGINAL T=0 FORMS; SOME ARE ACTIVE AND NOT STABLE</text>`];
 const colWidth=284, x0=70, y0=435, rowHeight=204;
 p.features.forEach((f,i)=>{
  const x=x0+(i%4)*colWidth, y=y0+Math.floor(i/4)*rowHeight;
  parts.push(`<rect x="${x-6}" y="${y-19}" width="271" height="195" rx="6" fill="#12151f" stroke="#303744"/>`);
  parts.push(`<text x="${x+4}" y="${y+1}" font-family="monospace" font-size="13" font-weight="bold" fill="#e1d3ba">${String(i+1).padStart(2,"0")} ${esc(f.title.length>27?f.title.slice(0,26):f.title)}</text>`);
  parts.push(`<text x="${x+4}" y="${y+18}" font-family="monospace" font-size="10" fill="${f.kind==="active-dynamic"?"#f1a074":"#9fbbb2"}">${esc(f.id)}  |  ${f.size.join("×")}  |  ${f.kind==="active-dynamic"?"ACTIVE T=0":"INERT"}</text>`);
  const scale=Math.min(1.6,226/f.size[0],123/f.size[1]);
  const dx=x+8+(245-f.size[0]*scale)/2, dy=y+31+(129-f.size[1]*scale);
  parts.push(`<rect x="${x+3}" y="${y+27}" width="250" height="132" fill="#090c16"/>`);
  parts.push(`<g transform="translate(${dx.toFixed(2)} ${dy.toFixed(2)}) scale(${scale.toFixed(5)})">${f.rectangles.map(r=>rect(...r)).join("")}</g>`);
 });

 const alt=p.alternate_scene;
 parts.push('<text x="70" y="871" font-family="monospace" font-size="13" fill="#d1a874">03 — INVERTED KILN / SECOND DRY ASSEMBLY · SAME EIGHT MODULES</text>');
 parts.push('<rect x="64" y="885" width="1152" height="271" rx="8" fill="#090c16" stroke="#343743"/>');
 parts.push('<g transform="translate(70 897) scale(1.08)">');
 parts.push(...alt.terrain_rectangles.map(r=>rect(...r)));
 parts.push(...alt.placements.map(z=>feature(p.features.find(f=>f.id===z.feature),z.variant,z.x,z.y)));
 parts.push('</g>');
 const [aw,ah]=alt.size,cells=new Uint16Array(aw*ah);
 const paint=(r,ox=0,oy=0,sw={})=>{
  const [x,y,w,h,id]=r,m=Object.prototype.hasOwnProperty.call(sw,String(id))?sw[String(id)]:id;
  for(let yy=y+oy;yy<y+oy+h;yy++)cells.fill(m,yy*aw+x+ox,yy*aw+x+ox+w);
 };
 alt.terrain_rectangles.forEach(r=>paint(r));
 alt.placements.forEach(z=>{const f=p.features.find(f=>f.id===z.feature),v=f.variants.find(v=>v.id===z.variant);f.rectangles.forEach(r=>paint(r,z.x,z.y,v?v.swap:{}));});
 parts.push('<text x="70" y="1184" font-family="monospace" font-size="13" fill="#d1a874">04 — SOURCE-CELL DETAIL STUDIES / 2.4× · NOT ENGINE PIXELS</text>');
 for(const [px,sx,sy,label] of [[64,305,52,'CRUCIBLE / RUINED RETAINING ARCH'],[646,728,82,'EASTERN FAULT / SURVEY TERRACE']]){
  parts.push(`<rect x="${px}" y="1201" width="552" height="192" fill="#090c16" stroke="#343743"/>`);
  parts.push(`<g transform="translate(${px} 1201) scale(2.4)">`);
  for(let yy=0;yy<80;yy++){let xx=0;while(xx<230){let id=cells[(sy+yy)*aw+sx+xx],end=xx+1;while(end<230&&cells[(sy+yy)*aw+sx+end]===id)end++;if(id!==0)parts.push(rect(xx,yy,end-xx,1,id));xx=end;}}
  parts.push('</g>');parts.push(`<text x="${px+3}" y="1417" font-family="monospace" font-size="11" fill="#d1a874">${label}</text>`);
 }
 parts.push('<text x="70" y="1471" font-family="monospace" font-size="11" fill="#9fb3bb">ORDERED SOURCE-MATERIAL RECTANGLES · EMPTY CELLS DO NOT CLEAR HOST TERRAIN</text>');
 parts.push('<text x="70" y="1491" font-family="monospace" font-size="11" fill="#8c97a2">DESIGN ONLY / NO GODOT, THERMAL, FLUID, COLLISION OR PERFORMANCE QUALIFICATION</text></svg>');
 return parts.join("\n")+"\n";
}
const expected=svgForPack(pack);
const filename=path.join(dir,"preview.svg");
if(process.argv.includes("--check")){
 if(fs.readFileSync(filename,"utf8")!==expected){console.error("preview.svg stale");process.exitCode=1;}
 else console.log("preview.svg exact deterministic match / "+expected.length+" characters");
}else{
 fs.writeFileSync(filename,expected,"utf8");
 console.log("Wrote "+filename+" ("+expected.length+" characters)");
}
