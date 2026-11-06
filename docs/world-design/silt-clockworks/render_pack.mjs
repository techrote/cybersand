#!/usr/bin/env node
import fs from "node:fs";import path from "node:path";import {fileURLToPath} from "node:url";
const dir=path.dirname(fileURLToPath(import.meta.url));
function render(p){
 const palette=new Map(p.palette.map(m=>[m.id,m]));
 const rect=r=>{const [x,y,w,h,id]=r,m=palette.get(id),a=m.rgba;return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="rgb(${a[0]},${a[1]},${a[2]})" fill-opacity="${(a[3]/255).toFixed(3)}"/>`};
 const s=p.scene,alt=p.alternate_scene,sceneInk=(scene)=>[...scene.terrain_rectangles.map(rect),...scene.placements.map(z=>{const f=p.features.find(f=>f.id===z.feature),v=f.variants.find(v=>v.id===z.variant);return `<g transform="translate(${z.x} ${z.y})">${f.rectangles.map(r=>rect([r[0],r[1],r[2],r[3],v.swap[String(r[4])]??r[4]])).join("")}</g>`})].join(""),parts=[
 `<svg xmlns="http://www.w3.org/2000/svg" width="1380" height="1760" viewBox="0 0 1380 1760" role="img" aria-label="Silt Clockworks material-feature design sheet">`,
 `<rect width="1380" height="930" fill="#0b131c"/>`,
 `<rect x="0" y="0" width="1380" height="100" fill="#15212c"/>`,
 `<text x="54" y="40" font-family="monospace" font-weight="bold" font-size="30" fill="#e5d6ab">SILT / CLOCKWORKS</text>`,
 `<text x="55" y="68" font-family="monospace" font-size="13" fill="#91b7b8">CYBERSAND • WORLD-DESIGN COLLECTION 006 • MATERIAL-CELL / T=0 PROPOSAL</text>`,
 `<text x="55" y="120" font-family="monospace" font-size="15" fill="#d8b881">01 — FROZEN TIDE REGULATOR / DRY COMBINED SCENE (${s.size.join("×")} CELLS)</text>`,
 `<rect x="48" y="134" width="1284" height="303" rx="9" fill="#080e18" stroke="#38505a" stroke-width="2"/>`,
 `<g transform="translate(58 148) scale(1.065)">`,sceneInk(s),`</g>`,
 `<text x="58" y="475" font-family="monospace" font-size="15" fill="#d8b881">02 — UNDERFLOW RELIQUARY / TWO-LEVEL DRY COMPOSITION (${alt.size.join("×")} CELLS)</text>`,
 `<rect x="48" y="488" width="1284" height="464" rx="9" fill="#080e18" stroke="#38505a" stroke-width="2"/>`,
 `<g transform="translate(58 500) scale(1.065)">`,sceneInk(alt),`</g>`,
 `<text x="58" y="997" font-family="monospace" font-size="14" fill="#d8b881">03 — EIGHT REUSABLE ORIGINAL MODULES / ACTIVE T=0 FORMS BELOW</text>`];
 for(let i=0;i<p.features.length;i++){const f=p.features[i],x=57+(i%4)*320,y=1034+Math.floor(i/4)*207,active=f.kind==="active-dynamic";
 parts.push(`<rect x="${x-6}" y="${y-23}" width="306" height="197" rx="8" fill="#14232c" stroke="#34505c"/>`);
 parts.push(`<text x="${x+3}" y="${y-5}" font-family="monospace" font-size="14" font-weight="bold" fill="#e8ddbe">${String(i+1).padStart(2,"0")} ${f.title.slice(0,30).replaceAll("&","&amp;")}</text>`);
 parts.push(`<text x="${x+3}" y="${y+15}" font-family="monospace" font-size="11" fill="${active?"#eea177":"#8bbdb3"}">${f.size.join("×")} • ${active?"ACTIVE T=0 / UNVALIDATED":"FIXED MATERIALS"}</text>`);
 parts.push(`<rect x="${x+2}" y="${y+25}" width="278" height="137" fill="#09151f"/>`);
 const sc=Math.min(1.46,267/f.size[0],128/f.size[1]),ox=x+8+(268-f.size[0]*sc)/2,oy=y+29+(130-f.size[1]*sc);
 parts.push(`<g transform="translate(${ox.toFixed(3)} ${oy.toFixed(3)}) scale(${sc.toFixed(5)})">${f.rectangles.map(rect).join("")}</g>`)}
 const crops=[{name:"04 — FRACTURED TIDAL INDEX / SHAFT",x:460,y:217,w:332,h:150},{name:"05 — EAST SWITCHWORK / STRUCTURAL DAMAGE",x:692,y:240,w:332,h:122}];
 for(let i=0;i<crops.length;i++){const c=crops[i],bx=48+i*652;
 parts.push(`<rect x="${bx}" y="1485" width="629" height="215" rx="8" fill="#101b25" stroke="#38505a" stroke-width="2"/>`);
 parts.push(`<text x="${bx+12}" y="1508" font-family="monospace" font-size="13" fill="#dbc58f">${c.name}</text>`);
 parts.push(`<svg x="${bx+10}" y="1521" width="606" height="162" viewBox="${c.x} ${c.y} ${c.w} ${c.h}" preserveAspectRatio="xMidYMid meet">`,sceneInk(alt),`</svg>`);
 }
 parts.push(`<text x="58" y="1744" font-family="monospace" font-size="12" fill="#90a5aa">DESIGN ONLY • DRY INSETS ARE SOLID MATERIALS • NO NATIVE WATER/CHEMISTRY OR GODOT VALIDATION</text>`,`</svg>`);
 return parts.join("\n")+"\n";
}
const actual=render(JSON.parse(fs.readFileSync(path.join(dir,"pack.json"),"utf8"))),file=path.join(dir,"preview.svg");
if(process.argv.includes("--check")){if(fs.readFileSync(file,"utf8")!==actual){console.error("FAIL preview drift");process.exitCode=1}else console.log("PASS deterministic preview "+actual.length+" chars")}
else{fs.writeFileSync(file,actual);console.log("Wrote "+file)}
