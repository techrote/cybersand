#!/usr/bin/env node
// Deterministic source-colour SVG. Not a simulation/rendering or authoring importer.
import {readFileSync,writeFileSync} from "node:fs";
import {dirname,join} from "node:path";
import {fileURLToPath} from "node:url";
function renderSvg(p){
 const escape=t=>String(t).replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;");
 const pal=new Map(p.palette.map(m=>[m.id,m]));
 const color=id=>{const rgba=pal.get(id)?.rgba;if(!rgba)throw Error("no source-colour "+id);return `rgba(${rgba[0]},${rgba[1]},${rgba[2]},${(rgba[3]/255).toFixed(3)})`};
 const c=[];const put=s=>c.push(s);
 const srcRect=(x,y,w,h,id)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${color(id)}"/>`;
 const draw=(f,x,y,scale,variant)=>{const v=f.variants.find(e=>e.id===variant);put(`<g transform="translate(${x},${y}) scale(${scale})" shape-rendering="crispEdges">`);for(const [rx,ry,w,h,id] of f.rectangles){const next=(v&&v.swap[String(id)]!==undefined)?v.swap[String(id)]:id;put(srcRect(rx,ry,w,h,next))}put("</g>")};
 const rect=(x,y,w,h,fill,rx=0)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${fill}"/>`;
 const text=(x,y,content,size=16,fill="#dae9eb",weight=400,anchor="start")=>`<text x="${x}" y="${y}" font-family="ui-monospace,SFMono-Regular,Consolas,monospace" font-size="${size}" font-weight="${weight}" text-anchor="${anchor}" fill="${fill}">${escape(content)}</text>`;
 const W=1490,H=2405;put(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" role="img" aria-label="Mirror Marsh world design staging sheet, all eight modules and a dry composition">`);put(`<title>Mirror Marsh — source-colour feature collection 010</title><desc>Design-stage illustration only, not native simulation, optical reflection, lighting or a Godot screenshot. Non-stamped background is visual framing.</desc>`);
 put(rect(0,0,W,H,"#0b1720"));put(rect(32,22,W-64,49,"#152a31",9));put(text(54,55,"MIRROR MARSH / RELIQUARIES OF THE STILL TIDE",26,"#e3efe8",700));put(text(1438,54,"PACK 010 / DESIGN ONLY",13,"#79b9b4",600,"end"));
 put(text(51,100,"THE LAST CAUSEWAY  ·  1320 × 308 DRY CELLS  ·  FICTIONAL OPTICS",14,"#a3babd",600));put(rect(49,111,1392,343,"#14232b",8));put(rect(60,122,1370,318,"#101e28",3));
 const fx=75,fy=134;put(`<path d="M${fx} ${fy+p.combined_scene.baseline_y+0.5} h1320" stroke="#54837d" opacity=".35" stroke-dasharray="4 5" fill="none"/>`);
 for(const r of p.combined_scene.terrain_rectangles||[])put(srcRect(fx+r[0],fy+r[1],r[2],r[3],r[4]));
 for(const loc of p.combined_scene.placements){const f=p.features.find(q=>q.id===loc.feature_id);draw(f,fx+loc.origin[0],fy+loc.origin[1],1,loc.variant)}
 for(const r of p.combined_scene.foreground_rectangles||[])put(srcRect(fx+r[0],fy+r[1],r[2],r[3],r[4]));
 put(text(69,429,"SOURCE COLOURS · NO IMPLIED OPTICAL REFLECTION · BASELINE / REFERENCE ONLY",11,"#9eb3ae"));
 put(text(52,486,"INDIVIDUAL MODULES · ORIGINAL t=0 STAMPS (EXPERIMENTAL MODULES NOT TICKED)",15,"#a8c8c3",600));
 const cardW=337,cardH=242,sep=12,left=51,top=504;
 for(let i=0;i<p.features.length;i++){const f=p.features[i],col=i%4,row=Math.floor(i/4),x=left+col*(cardW+sep),y=top+row*(cardH+10);
 put(rect(x,y,cardW,cardH,"#172b32",8));put(rect(x+9,y+9,cardW-18,181,"#10232b",5));
 const scale=Math.min(1.45, (cardW-43)/f.size[0],164/f.size[1]); const dx=x+(cardW-f.size[0]*scale)/2,dy=y+188-f.size[1]*scale;
 draw(f,Number(dx.toFixed(2)),Number(dy.toFixed(2)),Number(scale.toFixed(5)),null);
 put(text(x+14,y+211,`${String(i+1).padStart(2,"0")}  ${f.title.split(" / ")[0].toUpperCase()}`,13,"#e6eee8",650));
 put(text(x+14,y+230,`${f.size[0]}×${f.size[1]} CELLS  ·  ${f.kind==="inert-static"?"FIXED-CANDIDATE":f.kind==="dynamic-liquid"?"LIQUID / UNTESTED":"POWDER / UNTESTED"}`,10,f.kind==="inert-static"?"#96c7be":"#eeb479",500))}
 put(text(53,1042,"03 / AUTHOR-DIRECTED CLOSE STUDIES  ·  SOURCE COLOURS, ~1.85× CELL SCALE",14,"#a8c8c3",600));
 const crop=(x,label,vx,vy)=>{put(text(x,1064,label,12,"#c9d9d4",650));put(rect(x,1073,672,194,"#172b32",7));put(`<svg x="${x+7}" y="1080" width="658" height="180" viewBox="${vx} ${vy} 356 97" preserveAspectRatio="none" aria-label="${escape(label)}">`);
 put(rect(vx,vy,356,97,"#101e28"));
 for(const r of p.combined_scene.terrain_rectangles||[])put(srcRect(r[0],r[1],r[2],r[3],r[4]));
 for(const loc of p.combined_scene.placements){const f=p.features.find(q=>q.id===loc.feature_id);draw(f,loc.origin[0],loc.origin[1],1,loc.variant)}
 for(const r of p.combined_scene.foreground_rectangles||[])put(srcRect(r[0],r[1],r[2],r[3],r[4]));
 put("</svg>");};
 crop(51,"I / FERRY-TO-CHAPEL TOLL LINE / SEVERED CROSSING",184,59);
 crop(767,"II / RUINED REED BANK, LENSES & SALT LEVEE",835,149);
 put(text(54,1316,"PINNED NATIVE MATERIAL PALETTE  ·  SOURCE CELL STAMPS  ·  NOT A GODOT IMAGE OR PHYSICAL PROOF",12,"#83a7a2"));
 const alt=p.alternate_scene;
 put(text(51,1360,"02 / THE RECEDING MIRROR  ·  ALTERNATE INLAND RELIQUARY",15,"#a8c8c3",600));
 put(text(53,1380,"REVERSED PILGRIMAGE  ·  UNEQUAL LANDINGS  ·  GEODETIC CROWN  ·  DRY FIXED STAMPS",12,"#9eb3ae"));
 put(rect(49,1390,1392,342,"#14232b",8));put(rect(60,1401,1370,318,"#101e28",3));
 const ax=75,ay=1406;
 put('<path d="M'+ax+' '+(ay+alt.baseline_y+0.5)+' h1320" stroke="#54837d" opacity=".3" stroke-dasharray="4 5" fill="none"/>');
 for(const r of alt.terrain_rectangles)put(srcRect(ax+r[0],ay+r[1],r[2],r[3],r[4]));
 for(const loc of alt.placements){const f=p.features.find(q=>q.id===loc.feature_id);draw(f,ax+loc.origin[0],ay+loc.origin[1],1,loc.variant)}
 for(const r of alt.foreground_rectangles)put(srcRect(ax+r[0],ay+r[1],r[2],r[3],r[4]));
 put(text(69,1722,"EIGHT REARRANGED MODULES  ·  GAPS ARE UNSTAMPED, NOT HOST CLEARANCE",11,"#9eb3ae"));
 put(text(53,1765,"04 / ALTERNATE CLOSE STUDIES  ·  SOURCE COLOURS, NO ENGINE LIGHTING",14,"#a8c8c3",600));
 const altCrop=(x,label,vx,vy)=>{put(text(x,1790,label,12,"#c9d9d4",650));put(rect(x,1799,672,245,"#172b32",7));
 put('<svg x="'+(x+7)+'" y="1806" width="658" height="231" viewBox="'+vx+' '+vy+' 356 125" preserveAspectRatio="none" aria-label="'+escape(label)+'">');put(rect(vx,vy,356,125,"#101e28"));
 for(const r of alt.terrain_rectangles)put(srcRect(r[0],r[1],r[2],r[3],r[4]));
 for(const loc of alt.placements){const f=p.features.find(q=>q.id===loc.feature_id);draw(f,loc.origin[0],loc.origin[1],1,loc.variant)}
 for(const r of alt.foreground_rectangles)put(srcRect(r[0],r[1],r[2],r[3],r[4]));put("</svg>");};
 altCrop(51,"III / SIX BURIED REGISTERS / BLIND LUNAR ARCHIVE",196,183);
 altCrop(767,"IV / BLIND INCLINOMETERS AND SALT-RETURN COFFER",951,181);
 put(text(53,2094,"05 / THE UNGIVEN TIDE CHIMES  ·  WESTERN REED-BANK RELIQUARY",14,"#a8c8c3",600));
 const chimeCrop=(x,label,vx,vy,vw,vh)=>{put(text(x,2123,label,12,"#c9d9d4",650));put(rect(x,2133,672,225,"#172b32",7));
 put('<svg x="'+(x+7)+'" y="2140" width="658" height="210" viewBox="'+vx+' '+vy+' '+vw+' '+vh+'" preserveAspectRatio="xMidYMid meet" aria-label="'+escape(label)+'">');
 put(rect(vx,vy,vw,vh,"#101e28"));for(const r of alt.terrain_rectangles)put(srcRect(r[0],r[1],r[2],r[3],r[4]));
 for(const loc of alt.placements){const f=p.features.find(q=>q.id===loc.feature_id);draw(f,loc.origin[0],loc.origin[1],1,loc.variant)}
 for(const r of alt.foreground_rectangles)put(srcRect(r[0],r[1],r[2],r[3],r[4]));put("</svg>");};
 chimeCrop(51,"V / FRACTURED TALLY CANOPY AND REED-BANK MAST",90,18,318,141);
 chimeCrop(767,"VI / STRANDED CHIMES AND LOST PILGRIM STAIRS",133,73,234,123);
 put(text(54,2384,"TWO SOURCE-COLOUR DIORAMAS · NO GODOT / OPTICS / WATER / SOUND / CLEARANCE CLAIM",12,"#83a7a2"));
put("</svg>");
 return c.join("\n")+"\n";
}
const dir=dirname(fileURLToPath(import.meta.url));
const next=renderSvg(JSON.parse(readFileSync(join(dir,"pack.json"),"utf8")));
const file=join(dir,"preview.svg");
if(process.argv.includes("--check")){
 const old=readFileSync(file,"utf8");
 if(old!==next)throw Error("Preview reproducibility mismatch");
 console.log("PASS deterministic SVG",next.length,"characters");
}else if(process.argv.includes("--write")){
 writeFileSync(file,next);
 console.log("Updated preview.svg",next.length,"characters");
}else{
 process.stdout.write(next);
}
