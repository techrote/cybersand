#!/usr/bin/env node
"use strict";
const fs=require("node:fs"),path=require("node:path");
function makeSvg(p){
 const colors=new Map(p.palette.map(m=>[m.id,"#"+m.rgba.slice(0,3).map(v=>v.toString(16).padStart(2,"0")).join("")]));let out=[];
 const rect=(x,y,w,h,c,attr="")=>out.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${c}" ${attr}/>`);
 const txt=(x,y,s,sz=14,c="#e6edf7")=>out.push(`<text x="${x}" y="${y}" font-family="monospace" font-size="${sz}" fill="${c}">${String(s).replaceAll("&","&amp;").replaceAll("<","&lt;")}</text>`);
 function stamp(f,x,y,k,variant){const v=variant?f.variants.find(v=>v.id===variant):null;for(const [xx,yy,w,h,id] of f.rectangles){let mid=v&&v.swap[String(id)]!==undefined?+v.swap[String(id)]:id;rect(x+xx*k,y+yy*k,w*k,h*k,colors.get(mid))}}
 out.push('<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="2280" viewBox="0 0 1600 2280" role="img" aria-label="Coral Telegraph eight modular material-only feature designs and dry combined environment">');
 rect(0,0,1600,2280,"#08121f");txt(38,44,"CORAL TELEGRAPH  /  THE SILENT CABLE TRANSEPT",29);txt(38,69,"WORLD DESIGN 014  •  SOURCE-COLOUR SCHEMATIC  •  NOT NATIVE SIMULATION",13,"#82a4b8");
 rect(30,86,1540,383,"#122438",'rx="10"');txt(47,111,"DRY COMBINED SEAFLOOR / 1370 x 324 native cells",17);
 const sc=p.combined_scene,z=1.04,x0=54,y0=128;rect(x0,y0,sc.size[0]*z,sc.size[1]*z,"#081724");rect(x0,y0+sc.baseline_y*z,sc.size[0]*z,1,"#506679");
 for(const [tx,ty,tw,th,tid] of sc.terrain_rectangles||[])rect(x0+tx*z,y0+ty*z,tw*z,th*z,colors.get(tid));
 for(const place of sc.placements){const f=p.features.find(f=>f.id===place.feature_id);stamp(f,x0+place.origin[0]*z,y0+place.origin[1]*z,z,place.variant)}
 txt(38,491,"EIGHT ORIGINAL MODULES  /  experiments have active materials, unlike the dry composite",16,"#a5bdcc");
 for(let i=0;i<p.features.length;i++){const f=p.features[i],x=30+(i%4)*390,y=509+Math.floor(i/4)*292;rect(x,y,378,280,"#13273c",'rx="10"');
 txt(x+15,y+26,`${String(i+1).padStart(2,"0")}  ${f.title}`,13);txt(x+15,y+45,`${f.size[0]}x${f.size[1]}  |  ${f.kind}  |  ${f.rectangles.length} rects`,11,"#9ab6ce");
 rect(x+18,y+60,342,176,"#091a28");let k=Math.min(2.05,330/f.size[0],164/f.size[1]);stamp(f,x+24+(330-f.size[0]*k)/2,y+64+(165-f.size[1]*k)/2,k,null);txt(x+16,y+257,"2 palette variants  /  grounded  /  0 degrees",11,"#9eb4ce")}
 txt(38,1125,"DETAIL WINDOWS / 2.15x dry source-colour geometry / not engine captures",15,"#a5bdcc");
 function crop(x,y,originX,originY,label,clipId){
   rect(x-5,y-5,757,249,"#13273c",'rx="9"');rect(x,y,746,236,"#091a28");
   out.push('<defs><clipPath id="'+clipId+'"><rect x="'+x+'" y="'+y+'" width="746" height="236"/></clipPath></defs>');
   out.push('<g clip-path="url(#'+clipId+')">');
   const z=2.15,sx=x-originX*z,sy=y-originY*z;
   for(const [tx,ty,tw,th,tid] of sc.terrain_rectangles||[])rect(sx+tx*z,sy+ty*z,tw*z,th*z,colors.get(tid));
   for(const place of sc.placements){const f=p.features.find(f=>f.id===place.feature_id);stamp(f,sx+place.origin[0]*z,sy+place.origin[1]*z,z,place.variant)}
   out.push('</g>');txt(x+10,y+224,label,12,"#e1edf4");
 }
 crop(46,1152,500,41,"A / fractured splice crown and severed cables","ct-crop-a");
 crop(817,1152,970,174,"B / salt ledger and distressed exchange masonry","ct-crop-b");
 txt(36,1415,"Dry source-colour design only; physics, materials, underwater appearance, lighting, signalling and actor clearance unqualified.",12,"#9aabbf");
 const alt=p.alternate_scene,za=0.99,ax=54,ay=1497;
 rect(30,1439,1540,496,"#122438",'rx="10"');
 txt(47,1469,"THE BROKEN RETURN  /  1370 x 420  /  DRY CABLE CRYPT",17);
 rect(ax,ay,alt.size[0]*za,alt.size[1]*za,"#081724");
 for(const [x,y,w,h,id] of alt.backdrop_rectangles)rect(ax+x*za,ay+y*za,w*za,h*za,colors.get(id));
 for(const pl of alt.placements){const feature=p.features.find(f=>f.id===pl.feature_id);stamp(feature,ax+pl.origin[0]*za,ay+pl.origin[1]*za,za,pl.variant)}
 for(const [x,y,w,h,id] of alt.foreground_rectangles)rect(ax+x*za,ay+y*za,w*za,h*za,colors.get(id));
 txt(40,1957,"ALTERNATE CLOSE STUDIES  /  2.15x FLAT SOURCE MATERIAL COLOURS",15,"#a5bdcc");
 function altCrop(x,y,ox,oy,label,clip){
  rect(x-5,y-5,757,247,"#13273c",'rx="9"');rect(x,y,746,236,"#091a28");
  out.push('<defs><clipPath id="'+clip+'"><rect x="'+x+'" y="'+y+'" width="746" height="236"/></clipPath></defs>');
  out.push('<g clip-path="url(#'+clip+')">');
  const z=2.15,sx=x-ox*z,sy=y-oy*z;
  for(const [a,b,w,h,id] of alt.backdrop_rectangles)rect(sx+a*z,sy+b*z,w*z,h*z,colors.get(id));
  for(const pl of alt.placements){const feature=p.features.find(f=>f.id===pl.feature_id);stamp(feature,sx+pl.origin[0]*z,sy+pl.origin[1]*z,z,pl.variant)}
  for(const [a,b,w,h,id] of alt.foreground_rectangles)rect(sx+a*z,sy+b*z,w*z,h*z,colors.get(id));
  out.push('</g>');txt(x+10,y+223,label,12,"#e1edf4");
 }
 altCrop(46,1983,473,67,"A / fractured crown, cable joints and bearing seats","ct-alt-a");
 altCrop(817,1983,800,265,"B / lower ledger chambers and petrified dry test basins","ct-alt-b");
 txt(36,2253,"Art only: no Godot image, physics, signals, reflection, pressure, fluid or clearance claims.",12,"#9aabbf");
out.push("</svg>");return out.join("\n")+"\n";
}
const p=JSON.parse(fs.readFileSync(path.join(__dirname,"pack.json"),"utf8")),out=path.join(__dirname,"preview.svg"),s=makeSvg(p);
if(process.argv.includes("--write")){fs.writeFileSync(out,s,"utf8");console.log("Wrote preview.svg")}
else if(process.argv.includes("--check")){if(fs.readFileSync(out,"utf8")!==s)throw Error("Preview drift");console.log("Preview matches deterministic generator")}
else console.log("SVG size "+s.length);
