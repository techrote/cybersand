#!/usr/bin/env node
// Deterministic source-colour illustration; does NOT run CyberSand or clear terrain.
import {readFileSync,writeFileSync} from "node:fs";
import {dirname,join} from "node:path";
import {fileURLToPath} from "node:url";
function renderSvg(pack){
 const lines=[],pal=new Map(pack.palette.map(m=>[m.id,m]));
 const esc=t=>String(t).replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;");
 const tint=id=>{const m=pal.get(id);if(!m)throw Error("Unknown palette id "+id);const c=m.rgba;return `rgba(${c[0]},${c[1]},${c[2]},${(c[3]/255).toFixed(3)})`};
 const rect=(x,y,w,h,fill,rx=0)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}"/>`;
 const txt=(x,y,t,size=14,fill="#e3ebe8",weight=400)=>`<text x="${x}" y="${y}" font-family="monospace" font-size="${size}" fill="${fill}" font-weight="${weight}">${esc(t)}</text>`;
 const draw=(f,x,y,scale,variant)=>{const v=f.variants.find(q=>q.id===variant);lines.push(`<g transform="translate(${x},${y}) scale(${scale})" shape-rendering="crispEdges">`);for(const [rx,ry,w,h,id] of f.rectangles){const target=v?.swap?.[String(id)]??id;lines.push(rect(rx,ry,w,h,tint(target)))}lines.push("</g>")};
 lines.push(`<svg xmlns="http://www.w3.org/2000/svg" width="1480" height="1110" viewBox="0 0 1480 1110" role="img" aria-label="Drowned Observatory eight modules and source-colour dry scene">`);
 lines.push(`<title>Drowned Observatory — Night of the Submerged Equator</title><desc>Source-colour illustration for staged map-authoring. Not a native simulation or Godot screenshot.</desc>`);
 lines.push(rect(0,0,1480,1110,"#091723"));
 lines.push(rect(30,20,1420,58,"#1d3041",7));lines.push(txt(51,57,"DROWNED OBSERVATORY / NIGHT OF THE SUBMERGED EQUATOR",24,"#ebebd9",700));
 lines.push(txt(1220,56,"COLLECTION 011",14,"#cbb779",700));lines.push(txt(50,110,"1320 × 280 CELLS / DRY STAGING / ALL ACTIVE CELLS SUBSTITUTED",14,"#b1c5c7",600));
 lines.push(rect(48,122,1384,326,"#132637",7));lines.push(rect(63,134,1354,292,"#0d1e2e",4));
 const ox=81,oy=146;for(const pos of pack.combined_scene.placements){const f=pack.features.find(q=>q.id===pos.feature_id);draw(f,ox+pos.origin[0],oy+pos.origin[1],1,pos.variant)}
 lines.push(`<path d="M${ox} ${oy+pack.combined_scene.baseline_y} h1320" stroke="#8da9ac" stroke-width="1" opacity=".3" stroke-dasharray="4 6"/>`);
 lines.push(txt(57,439,"PALETTE: SOURCE-MATCHED NATIVE IDS | BACKGROUND IS NOT A CELL STAMP | NO HOST CLEARING",10,"#98b4b9"));
 lines.push(txt(48,484,"EIGHT INDIVIDUAL MODULES / ORIGINAL t=0 INPUTS (NOT SIMULATED)",15,"#c8d8d8",600));
 for(let i=0;i<pack.features.length;i++){
   const f=pack.features[i],x=48+(i%4)*350,y=504+Math.floor(i/4)*271;
   lines.push(rect(x,y,338,257,"#1a2c3c",8));lines.push(rect(x+9,y+9,320,195,"#102131",6));
   const scale=Math.min(1.53,296/f.size[0],178/f.size[1]);
   const dx=+(x+(338-f.size[0]*scale)/2).toFixed(3);
   const dy=+(y+203-f.size[1]*scale).toFixed(3);
   draw(f,dx,dy,+scale.toFixed(4),null);
   lines.push(txt(x+13,y+224,`${String(i+1).padStart(2,"0")}  ${f.title.split(" / ")[0].toUpperCase()}`,12.5,"#e5ebe9",650));
   lines.push(txt(x+13,y+245,`${f.size[0]}×${f.size[1]} CELLS / ${f.kind==="inert-static"?"FIXED CANDIDATE":"DYNAMIC - UNTESTED"}`,10.5,f.kind==="inert-static"?"#a6c6c1":"#e4ba87"));
 }
 lines.push(txt(51,1083,"STAGING RESOURCE - ORDERED MATERIAL RECTANGLES, NOT LIGHTING, OPTICS, PRESSURE OR TICK EVIDENCE",11.5,"#91abb8"));
 lines.push("</svg>");
 return lines.join("\n")+"\n";
}
const d=dirname(fileURLToPath(import.meta.url));
const output=renderSvg(JSON.parse(readFileSync(join(d,"pack.json"),"utf8")));
const target=join(d,"preview.svg");
if(process.argv.includes("--check")){
 if(readFileSync(target,"utf8")!==output)throw Error("Preview reproducibility mismatch");
 console.log("PASS deterministic SVG",output.length,"characters");
}else if(process.argv.includes("--write")){
 writeFileSync(target,output);console.log("Updated preview.svg",output.length,"characters");
}else process.stdout.write(output);
