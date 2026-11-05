#!/usr/bin/env node
"use strict";
const fs=require("node:fs"),path=require("node:path");
function renderSvg(p){
 const colors=new Map(p.palette.map(m=>[m.id,"#"+m.rgba.slice(0,3).map(v=>v.toString(16).padStart(2,"0")).join("")]));
 const out=[],rect=(x,y,w,h,c,attr="")=>out.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${c}" ${attr}/>`),escape=s=>String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;"),txt=(x,y,s,z=14,c="#e5e9f5")=>out.push(`<text x="${x}" y="${y}" font-family="monospace" font-size="${z}" fill="${c}">${escape(s)}</text>`);
 function stamp(f,x,y,z,variant){const v=variant?f.variants.find(v=>v.id===variant):null;for(const [rx,ry,w,h,mid] of f.rectangles){const id=v&&v.swap[String(mid)]!==undefined?+v.swap[String(mid)]:mid;rect(x+rx*z,y+ry*z,w*z,h*z,colors.get(id))}}
 out.push('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1150" viewBox="0 0 1600 1150" role="img" aria-label="Fallow Carnival eight CyberSand source-colour modules and dry panorama">');
 rect(0,0,1600,1150,"#0c0e1b");rect(0,0,1600,76,"#181627");txt(35,43,"FALLOW CARNIVAL  /  THE LAST LIGHTS OF THE MIDWAY",27);txt(36,66,"WORLD DESIGN 015  |  FIXED MATERIAL SOURCE COLOURS  |  DESIGN PREVIEW, NOT SIMULATION",12,"#bda8ce");
 rect(28,88,1544,344,"#191b2a",'rx="8"');txt(46,113,"PANORAMA / DRY NO-MOTION PROPOSAL / 1420 x 226 cells",16,"#ddd1ec");const sc=p.combined_scene,z=1.043,x0=46,y0=137;
 rect(x0,y0,sc.size[0]*z,sc.size[1]*z,"#090e1a");rect(x0,y0+sc.baseline_y*z,sc.size[0]*z,1,"#7c7987");
 for(const pl of sc.placements){stamp(p.features.find(f=>f.id===pl.feature_id),x0+pl.origin[0]*z,y0+pl.origin[1]*z,z,pl.variant)}
 txt(36,459,"EIGHT ORIGINAL MODULES / MOBILE MATERIALS REMAIN EXPERIMENTAL",17,"#d9c8e0");
 for(let i=0;i<p.features.length;i++){const f=p.features[i],x=28+(i%4)*388,y=480+Math.floor(i/4)*308;rect(x,y,376,296,"#1a2032",'rx="10"');
 txt(x+14,y+27,`${String(i+1).padStart(2,"0")}  ${f.title}`,13);txt(x+14,y+48,`${f.size[0]} x ${f.size[1]}   /   ${f.kind}   /   ${f.rectangles.length} rects`,11,"#9ca6c5");
 rect(x+14,y+60,348,195,"#0a101d");const k=Math.min(2.02,334/f.size[0],180/f.size[1]);stamp(f,x+20+(336-f.size[0]*k)/2,y+66+(181-f.size[1]*k)/2,k,null);
 txt(x+15,y+277,"2 variants  |  ground anchor  |  no physics proof",11,"#b3b8d0")}
 txt(36,1121,"SOURCE-PINNED SCHEMATIC ONLY. No ride motion, lighting, optical reflection, collision, water or dust qualification.",13,"#b6afc6");
 out.push("</svg>");return out.join("\n")+"\n";
}
const p=JSON.parse(fs.readFileSync(path.join(__dirname,"pack.json"),"utf8")),output=path.join(__dirname,"preview.svg"),svg=renderSvg(p);
if(process.argv.includes("--check")){if(fs.readFileSync(output,"utf8")!==svg)throw Error("SVG preview drift");console.log("Preview matches deterministic renderer")}
else if(process.argv.includes("--write")){fs.writeFileSync(output,svg,"utf8");console.log("Wrote preview.svg")}
else console.log("SVG bytes: "+Buffer.byteLength(svg,"utf8"));
