#!/usr/bin/env node
import fs from "node:fs";import path from "node:path";
const renderPack=function renderPack(p){
const esc=s=>String(s).replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll('"',"&quot;");
const pal=new Map(p.palette.map(x=>[x.id,x])),fm=new Map(p.features.map(x=>[x.id,x]));
function raster(size,rs,places=[]){const [w,h]=size,out=new Uint16Array(w*h);function paint(z,dx=0,dy=0,swap={}){let [x,y,rw,rh,id]=z;if(Object.prototype.hasOwnProperty.call(swap,String(id)))id=swap[String(id)];for(let yy=y+dy;yy<y+dy+rh;yy++)out.fill(id,yy*w+x+dx,yy*w+x+dx+rw)}for(const z of rs)paint(z);for(const q of places){const a=fm.get(q.feature),sw=a.variants.find(v=>v.id===q.variant)?.swap||{};for(const z of a.rectangles)paint(z,q.x,q.y,sw)}return out}
function draw(cells,size,ox,oy,s){const [w,h]=size,a=[];let active=new Map();function flush(key,y0,y1){const [x0,x1,id]=key.split(",").map(Number);const color=pal.get(id).rgba,c="#"+color.slice(0,3).map(z=>z.toString(16).padStart(2,"0")).join("");a.push(`<rect x="${(ox+x0*s).toFixed(2)}" y="${(oy+y0*s).toFixed(2)}" width="${((x1-x0)*s).toFixed(2)}" height="${((y1-y0)*s).toFixed(2)}" fill="${c}"${color[3]===255?"":` fill-opacity="${(color[3]/255).toFixed(3)}"`}/>`)}
for(let y=0;y<=h;y++){let row=new Map();if(y<h)for(let x=0;x<w;){let id=cells[y*w+x],end=x+1;while(end<w&&id===cells[y*w+end])end++;if(id)row.set(`${x},${end},${id}`,y);x=end;}for(const [k,top]of active)if(!row.has(k))flush(k,top,y);for(const k of row.keys())if(active.has(k))row.set(k,active.get(k));active=row;}return a.join("\n")}
const mainCells=raster(p.scene.size,p.scene.terrain_rectangles,p.scene.placements);
let out=[`<svg xmlns="http://www.w3.org/2000/svg" width="1040" height="2320" viewBox="0 0 1040 2320" role="img" aria-label="Carved Ice Choir world-feature concept sheet">`,`<rect width="1040" height="1900" fill="#0e1523"/>`,`<text x="34" y="49" font-family="monospace" font-size="30" font-weight="bold" fill="#e7eff9">CARVED ICE CHOIR</text>`,`<text x="34" y="72" font-family="monospace" font-size="12" fill="#8fa6bd">GLACIAL CAVERN · EIGHT MODULES · SOURCE-COLOUR SCHEMATIC · NOT A GAME SCREENSHOT</text>`,`<rect x="30" y="91" width="980" height="406" rx="7" fill="#131d2d" stroke="#3c546b"/>`,`<text x="46" y="114" font-family="monospace" font-size="14" fill="#bdd9e5">ICE CHOIR CAVERN 01</text>`,`<text x="992" y="114" font-family="monospace" text-anchor="end" font-size="11" fill="#849bb1">800 × 320 cells · dry exhibition variants</text>`,`<rect x="44" y="121" width="952" height="362" fill="#080b12"/>`,draw(mainCells,p.scene.size,44,121,1.19),`<text x="40" y="528" font-family="monospace" font-size="16" fill="#e3eefb">PARTS &amp; SILHOUETTES</text>`];
for(let i=0;i<p.features.length;i++){const x=p.features[i],col=i%4,row=(i/4)|0,cx=32+col*252,cy=543+row*208,s=Math.min(2.1,218/x.size[0],126/x.size[1]);out.push(`<rect x="${cx}" y="${cy}" width="232" height="190" rx="6" fill="#131d2d" stroke="#3c546b"/>`,`<text x="${cx+11}" y="${cy+20}" font-family="monospace" font-size="13" font-weight="bold" fill="#e7eff9">${esc(x.title.toUpperCase())}</text>`,`<text x="${cx+11}" y="${cy+37}" font-family="monospace" font-size="10" fill="${x.status==="active-dynamic"?"#f4c789":x.status==="reactive-fixed"?"#a6d5e8":"#9ad7bd"}">${x.status.toUpperCase()} · ${x.size.join("×")}</text>`,`<rect x="${cx+8}" y="${cy+45}" width="216" height="127" fill="#080b12"/>`,draw(raster(x.size,x.rectangles),x.size,cx+8+(216-x.size[0]*s)/2,cy+45+(127-x.size[1]*s)/2,s),`<text x="${cx+11}" y="${cy+185}" font-family="monospace" font-size="10" fill="#96aabf">${esc(x.id)}</text>`);}
const alt=p.alternate_scene,altCells=raster(alt.size,alt.terrain_rectangles,alt.placements);
out.push(`<rect x="30" y="1006" width="980" height="498" rx="7" fill="#131d2d" stroke="#3c546b"/>`,
`<text x="45" y="1032" font-family="monospace" font-size="16" font-weight="bold" fill="#e7eff9">THE DESCENDING ANTIPHON · FRACTURED TUNING CAGE</text>`,
`<text x="994" y="1050" font-family="monospace" text-anchor="end" font-size="11" fill="#849bb1">800 × 360 native cells · eight relocated source modules · dry alternatives</text>`,
`<rect x="44" y="1057" width="952" height="428" fill="#080b12"/>`,draw(altCells,alt.size,44,1057,1.19));
function cropCells(x0,y0,w,h){const c=new Uint16Array(w*h);for(let yy=0;yy<h;yy++)c.set(altCells.subarray((y0+yy)*alt.size[0]+x0,(y0+yy)*alt.size[0]+x0+w),yy*w);return c;}
for(const [x,label,sx,sy] of [[31,"DETAIL A · BROKEN TUNING CAGE",309,66],[533,"DETAIL B · LOWER GLACIAL REGISTER",538,190]]){
out.push(`<rect x="${x}" y="1520" width="476" height="338" rx="6" fill="#131d2d" stroke="#3c546b"/>`,
`<text x="${x+14}" y="1543" font-family="monospace" font-size="12" fill="#c5deeb">${label}</text>`,
`<rect x="${x+15}" y="1555" width="446" height="276" fill="#080b12"/>`,
draw(cropCells(sx,sy,180,108),[180,108],x+22,1562,2.4),
`<text x="${x+15}" y="1845" font-family="monospace" font-size="10" fill="#819ab0">180 × 108 source cells · 2.4× · not Godot</text>`);
}
function cropMain(x0,y0,cw,ch){const arr=new Uint16Array(cw*ch);for(let row=0;row<ch;row++)arr.set(mainCells.subarray((y0+row)*p.scene.size[0]+x0,(y0+row)*p.scene.size[0]+x0+cw),row*cw);return arr;}
out.push(`<text x="34" y="1912" font-family="monospace" font-size="15" fill="#e3eefb">BURIED COUNTERPOINT · THREE NATIVE-CELL FOUNDATION STUDIES</text>`);
for(const [x,sx,label]of [[31,78,"WEST · BROKEN BELL OSSUARY"],[361,286,"CENTRE · SEVERED LEDGER ARCH"],[691,600,"EAST · TWIN ECHO THROATS"]]){
out.push(`<rect x="${x}" y="1927" width="316" height="326" rx="6" fill="#131d2d" stroke="#3c546b"/>`,
`<text x="${x+11}" y="1947" font-family="monospace" font-size="11" fill="#c5deeb">${label}</text>`,
`<rect x="${x+10}" y="1960" width="294" height="260" fill="#080b12"/>`,
draw(cropMain(sx,208,128,112),[128,112],x+13,1963,2.25),
`<text x="${x+10}" y="2241" font-family="monospace" font-size="10" fill="#819ab0">128 × 112 fixed-source cells · 2.25×</text>`);}
out.push(`<text x="34" y="2293" font-family="monospace" font-size="11" fill="#819ab0">DRY SOURCE-COLOUR DESIGN · NO GODOT CAPTURE / ENGINE TICKS / PHYSICS / REFLECTION PROOF</text>`);
out.push(`<text x="34" y="976" font-family="monospace" font-size="11" fill="#819ab0">PINNED NATIVE IDs · OPEN AIR UNWRITTEN · NO ENGINE TICKS / THERMAL OR ACTOR PROOF</text>`,"</svg>");return out.join("\n")+"\n";
};
const here=path.dirname(new URL(import.meta.url).pathname),p=JSON.parse(fs.readFileSync(path.join(here,"pack.json"),"utf8"));
const output=renderPack(p),file=path.join(here,"preview.svg");
if(process.argv.includes("--check")){if(fs.readFileSync(file,"utf8")!==output){console.error("FAIL stale preview");process.exitCode=1;}else console.log("PASS SVG exact regeneration");}else{fs.writeFileSync(file,output);console.log("WROTE "+file);}