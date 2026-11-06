#!/usr/bin/env node
"use strict";
const fs=require("node:fs"),path=require("node:path");
function renderSvg(p){
 const colors=new Map(p.palette.map(m=>[m.id,"#"+m.rgba.slice(0,3).map(v=>v.toString(16).padStart(2,"0")).join("")]));
 const out=[],rect=(x,y,w,h,c,attr="")=>out.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${c}" ${attr}/>`),escape=s=>String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;"),txt=(x,y,s,z=14,c="#e5e9f5")=>out.push(`<text x="${x}" y="${y}" font-family="monospace" font-size="${z}" fill="${c}">${escape(s)}</text>`);
 function stamp(f,x,y,z,variant){const v=variant?f.variants.find(v=>v.id===variant):null;for(const [rx,ry,w,h,mid] of f.rectangles){const id=v&&v.swap[String(mid)]!==undefined?+v.swap[String(mid)]:mid;rect(x+rx*z,y+ry*z,w*z,h*z,colors.get(id))}}
 out.push('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="2320" viewBox="0 0 1600 2320" role="img" aria-label="Fallow Carnival eight CyberSand source-colour modules and dry panorama">');
 rect(0,0,1600,2320,"#0c0e1b");rect(0,0,1600,76,"#181627");txt(35,43,"FALLOW CARNIVAL  /  THE LAST LIGHTS OF THE MIDWAY",27);txt(36,66,"WORLD DESIGN 015  |  FIXED MATERIAL SOURCE COLOURS  |  DESIGN PREVIEW, NOT SIMULATION",12,"#bda8ce");
 rect(28,88,1544,344,"#191b2a",'rx="8"');txt(46,113,"PANORAMA / DRY NO-MOTION PROPOSAL / 1420 x 226 cells",16,"#ddd1ec");const sc=p.combined_scene,z=1.043,x0=46,y0=137;
 rect(x0,y0,sc.size[0]*z,sc.size[1]*z,"#090e1a");rect(x0,y0+sc.baseline_y*z,sc.size[0]*z,1,"#7c7987");
 for(const [rx,ry,w,h,mid] of sc.backdrop_rectangles)rect(x0+rx*z,y0+ry*z,w*z,h*z,colors.get(mid));
 for(const pl of sc.placements){stamp(p.features.find(f=>f.id===pl.feature_id),x0+pl.origin[0]*z,y0+pl.origin[1]*z,z,pl.variant)}
 txt(36,459,"EIGHT ORIGINAL MODULES / MOBILE MATERIALS REMAIN EXPERIMENTAL",17,"#d9c8e0");
 for(let i=0;i<p.features.length;i++){const f=p.features[i],x=28+(i%4)*388,y=480+Math.floor(i/4)*308;rect(x,y,376,296,"#1a2032",'rx="10"');
 txt(x+14,y+27,`${String(i+1).padStart(2,"0")}  ${f.title}`,13);txt(x+14,y+48,`${f.size[0]} x ${f.size[1]}   /   ${f.kind}   /   ${f.rectangles.length} rects`,11,"#9ca6c5");
 rect(x+14,y+60,348,195,"#0a101d");const k=Math.min(2.02,334/f.size[0],180/f.size[1]);stamp(f,x+20+(336-f.size[0]*k)/2,y+66+(181-f.size[1]*k)/2,k,null);
 txt(x+15,y+277,"2 variants  |  ground anchor  |  no physics proof",11,"#b3b8d0")}
 txt(36,1112,"ENLARGED SOURCE-COLOUR STUDIES / LANDMARK + CRAFT DETAILS",15,"#d9c8e0");
 for(const c of [{x:28,title:"STALLED WHEEL / BROKEN SKYWAY",view:"135 60 420 137"},{x:812,title:"BROKEN MIDWAY / LOST PRIZES",view:"610 64 480 137"}]){
   rect(c.x,1128,760,252,"#191b2a",'rx="8"');txt(c.x+12,1150,c.title,13,"#c6cadd");
   out.push(`<svg x="${c.x+12}" y="1161" width="736" height="203" viewBox="${c.view}">`);
   rect(0,0,sc.size[0],sc.size[1],"#090e1a");
   for(const [rx,ry,w,h,mid] of sc.backdrop_rectangles)rect(rx,ry,w,h,colors.get(mid));
   for(const pl of sc.placements)stamp(p.features.find(f=>f.id===pl.feature_id),pl.origin[0],pl.origin[1],1,pl.variant);
   out.push("</svg>");
 }
 txt(36,1414,"SCHEMATIC ONLY. No ride motion, lighting/reflection, collision, water or dust qualification.",13,"#b6afc6");

 const alt=p.alternate_scene;
 txt(36,1480,"ALTERNATE / THE UNCLAIMED PROCESSION / DRY RUINED FAIR ON TWO LEVELS",16,"#d9c8e0");
 rect(28,1493,1544,454,"#191b2a",'rx="8"');
 const az=1.035,ax=46,ay=1511;
 rect(ax,ay,alt.size[0]*az,alt.size[1]*az,"#090e1a");
 for(const [rx,ry,w,h,mid] of alt.rectangles)rect(ax+rx*az,ay+ry*az,w*az,h*az,colors.get(mid));
 for(const pl of alt.placements)stamp(p.features.find(f=>f.id===pl.feature_id),ax+pl.origin[0]*az,ay+pl.origin[1]*az,az,pl.variant);
 for(const [rx,ry,w,h,mid] of alt.foreground_rectangles)rect(ax+rx*az,ay+ry*az,w*az,h*az,colors.get(mid));
 txt(47,1912,"Two-level dry diorama: lost procession, broken inspection viaduct, failed wheel lift and emptied arcades.",12,"#b3b8d0");
 txt(36,1975,"ALTERNATE CLOSE STUDIES / SOURCE COLOURS ONLY",16,"#d9c8e0");
 for(const c of [{x:28,title:"STRANDED MECHANISM / FRACTURED WHEEL CROWN",view:"590 30 380 310"},{x:812,title:"LAST FARE / BROKEN EASTERN CLAIM ATRIUM",view:"1030 76 390 241"}]){
   rect(c.x,1987,760,265,"#191b2a",'rx="8"');
   txt(c.x+12,2009,c.title,13,"#c6cadd");
   out.push(`<svg x="${c.x+12}" y="2022" width="736" height="211" viewBox="${c.view}">`);
   rect(0,0,alt.size[0],alt.size[1],"#090e1a");
   for(const [rx,ry,w,h,mid] of alt.rectangles)rect(rx,ry,w,h,colors.get(mid));
   for(const pl of alt.placements)stamp(p.features.find(f=>f.id===pl.feature_id),pl.origin[0],pl.origin[1],1,pl.variant);
   for(const [rx,ry,w,h,mid] of alt.foreground_rectangles)rect(rx,ry,w,h,colors.get(mid));
   out.push("</svg>");
 }
 txt(36,2280,"ILLUSTRATIVE ONLY. No ride, simulated motion, light, reflection, collision, leak or performance result.",13,"#b6afc6");
 out.push("</svg>");return out.join("\n")+"\n";
}
const p=JSON.parse(fs.readFileSync(path.join(__dirname,"pack.json"),"utf8")),output=path.join(__dirname,"preview.svg"),svg=renderSvg(p);
if(process.argv.includes("--check")){if(fs.readFileSync(output,"utf8")!==svg)throw Error("SVG preview drift");console.log("Preview matches deterministic renderer")}
else if(process.argv.includes("--write")){fs.writeFileSync(output,svg,"utf8");console.log("Wrote preview.svg")}
else console.log("SVG bytes: "+Buffer.byteLength(svg,"utf8"));
