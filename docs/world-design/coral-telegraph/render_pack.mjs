#!/usr/bin/env node
"use strict";
const fs=require("node:fs"),path=require("node:path");
function makeSvg(p){
 const colors=new Map(p.palette.map(m=>[m.id,"#"+m.rgba.slice(0,3).map(v=>v.toString(16).padStart(2,"0")).join("")]));let out=[];
 const rect=(x,y,w,h,c,attr="")=>out.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${c}" ${attr}/>`);
 const txt=(x,y,s,sz=14,c="#e6edf7")=>out.push(`<text x="${x}" y="${y}" font-family="monospace" font-size="${sz}" fill="${c}">${String(s).replaceAll("&","&amp;").replaceAll("<","&lt;")}</text>`);
 function stamp(f,x,y,k,variant){const v=variant?f.variants.find(v=>v.id===variant):null;for(const [xx,yy,w,h,id] of f.rectangles){let mid=v&&v.swap[String(id)]!==undefined?+v.swap[String(id)]:id;rect(x+xx*k,y+yy*k,w*k,h*k,colors.get(mid))}}
 out.push('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1130" viewBox="0 0 1600 1130" role="img" aria-label="Coral Telegraph eight modular material-only feature designs and dry combined environment">');
 rect(0,0,1600,1130,"#08121f");txt(38,44,"CORAL TELEGRAPH  /  THE SILENT CABLE TRANSEPT",29);txt(38,69,"WORLD DESIGN 014  •  SOURCE-COLOUR SCHEMATIC  •  NOT NATIVE SIMULATION",13,"#82a4b8");
 rect(30,86,1540,383,"#122438",'rx="10"');txt(47,111,"DRY COMBINED SEAFLOOR / 1370 x 324 native cells",17);
 const sc=p.combined_scene,z=1.085,x0=54,y0=128;rect(x0,y0,sc.size[0]*z,sc.size[1]*z,"#081724");rect(x0,y0+sc.baseline_y*z,sc.size[0]*z,1,"#506679");
 for(const place of sc.placements){const f=p.features.find(f=>f.id===place.feature_id);stamp(f,x0+place.origin[0]*z,y0+place.origin[1]*z,z,place.variant)}
 txt(38,491,"EIGHT ORIGINAL MODULES  /  experiments have active materials, unlike the dry composite",16,"#a5bdcc");
 for(let i=0;i<p.features.length;i++){const f=p.features[i],x=30+(i%4)*390,y=509+Math.floor(i/4)*292;rect(x,y,378,280,"#13273c",'rx="10"');
 txt(x+15,y+26,`${String(i+1).padStart(2,"0")}  ${f.title}`,13);txt(x+15,y+45,`${f.size[0]}x${f.size[1]}  |  ${f.kind}  |  ${f.rectangles.length} rects`,11,"#9ab6ce");
 rect(x+18,y+60,342,176,"#091a28");let k=Math.min(2.05,330/f.size[0],164/f.size[1]);stamp(f,x+24+(330-f.size[0]*k)/2,y+64+(165-f.size[1]*k)/2,k,null);txt(x+16,y+257,"2 palette variants  /  grounded  /  0 degrees",11,"#9eb4ce")}
 txt(36,1110,"Static proposal art only. Host clearing, material reactions, underwater physics and player collision are unqualified.",12,"#9aabbf");out.push("</svg>");return out.join("\n")+"\n";
}
const p=JSON.parse(fs.readFileSync(path.join(__dirname,"pack.json"),"utf8")),out=path.join(__dirname,"preview.svg"),s=makeSvg(p);
if(process.argv.includes("--write")){fs.writeFileSync(out,s,"utf8");console.log("Wrote preview.svg")}
else if(process.argv.includes("--check")){if(fs.readFileSync(out,"utf8")!==s)throw Error("Preview drift");console.log("Preview matches deterministic generator")}
else console.log("SVG size "+s.length);
