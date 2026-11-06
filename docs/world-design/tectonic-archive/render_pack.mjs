#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const dir=path.dirname(fileURLToPath(import.meta.url));
const pack=JSON.parse(fs.readFileSync(path.join(dir,'pack.json'),'utf8'));
const mat=new Map(pack.palette.map(m=>[m.id,m]));
const esc=x=>String(x).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const color=id=>{const c=mat.get(id).rgba;return 'rgba('+c[0]+','+c[1]+','+c[2]+','+(c[3]/255).toFixed(3)+')'};
const geometry=(f,v)=>{const variation=v?f.variants.find(z=>z.id===v):null;if(v&&!variation)throw Error('variant not found '+v);return f.rectangles.map(a=>[...a.slice(0,4),variation?+(variation.swap[String(a[4])]??a[4]):a[4]])};
const draw=(f,v,x,y,s)=>geometry(f,v).map(([a,b,w,h,m])=>'<rect x="'+(x+a*s).toFixed(2)+'" y="'+(y+b*s).toFixed(2)+'" width="'+(w*s).toFixed(2)+'" height="'+(h*s).toFixed(2)+'" fill="'+color(m)+'"/>').join('');
const drawArt=(arr,x,y,s)=>arr.map(([a,b,w,h,m])=>'<rect x="'+(x+a*s).toFixed(2)+'" y="'+(y+b*s).toFixed(2)+'" width="'+(w*s).toFixed(2)+'" height="'+(h*s).toFixed(2)+'" fill="'+color(m)+'"/>').join('');
const lines=['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="2690" viewBox="0 0 1600 2690">'];
lines.push('<rect width="1600" height="1210" fill="#0c111b"/>','<text x="62" y="60" font-family="monospace" font-size="36" fill="#e9e0cf" font-weight="bold">TECTONIC ARCHIVE</text>','<text x="65" y="87" font-family="monospace" font-size="16" fill="#c1ad7d">ARCHIVE OF THE SPLIT MOUNTAIN / COLLECTION 013 / DESIGN ONLY</text>');
lines.push('<rect x="50" y="110" width="1500" height="373" rx="12" fill="#181f2c" stroke="#4a5361"/>','<text x="72" y="139" font-family="monospace" font-size="17" fill="#e4c789">SPLIT-MOUNTAIN STRATIGRAPHIC VAULT · 1360 × 316 CELLS</text>');
const sx=115,sy=153;
lines.push('<rect x="'+sx+'" y="'+sy+'" width="1360" height="316" fill="#0a1420"/>');
lines.push(drawArt(pack.combined_scene.backdrop_rectangles,sx,sy,1));
for(const pl of pack.combined_scene.placements){const f=pack.features.find(z=>z.id===pl.feature_id);lines.push(draw(f,pl.variant,sx+pl.origin[0],sy+pl.origin[1],1));}
lines.push(drawArt(pack.combined_scene.foreground_rectangles,sx,sy,1));
lines.push('<line x1="'+sx+'" x2="'+(sx+1360)+'" y1="'+(sy+282)+'" y2="'+(sy+282)+'" stroke="#ab8458" stroke-width="1" stroke-dasharray="6 6"/>');
lines.push('<rect x="50" y="497" width="1500" height="489" rx="12" fill="#181f2c" stroke="#4a5361"/>','<text x="72" y="526" font-family="monospace" font-size="18" fill="#e4c789">THE SYNCLINAL REBINDING / 1360 × 420 / TWO-LEVEL DRY ALT</text>');
const ALT=pack.alternate_scene;lines.push('<rect x="115" y="550" width="1360" height="420" fill="#0a1420"/>',drawArt(ALT.backdrop_rectangles,115,550,1));for(const pl of ALT.placements){const f=pack.features.find(z=>z.id===pl.feature_id);lines.push(draw(f,pl.variant,115+pl.origin[0],550+pl.origin[1],1));}lines.push(drawArt(ALT.foreground_rectangles,115,550,1));
lines.push('<text x="60" y="1060" font-family="monospace" font-size="22" fill="#f0e3cb">EIGHT LITHIC FEATURE MODULES</text>','<text x="60" y="1082" font-family="monospace" font-size="14" fill="#abb6bd">Colours reflect source materials; empty pixels do not carve terrain; geology is not simulated.</text>');
for(let i=0;i<pack.features.length;i++){
 const f=pack.features[i],col=i%4,row=Math.floor(i/4),cx=54+col*384,cy=1101+row*293;
 lines.push('<rect x="'+cx+'" y="'+cy+'" width="368" height="277" rx="10" fill="#18212d" stroke="#485466"/>','<text x="'+(cx+14)+'" y="'+(cy+29)+'" font-family="monospace" font-size="17" fill="#ebd8b5">'+String(i+1).padStart(2,'0')+' '+esc(f.title.split('/')[0].trim())+'</text>');
 lines.push('<text x="'+(cx+14)+'" y="'+(cy+49)+'" font-family="monospace" font-size="12" fill="#a2b1bc">'+f.size.join(' × ')+' cells · '+esc(f.kind)+'</text>');
 const s=1.36,x=cx+(368-f.size[0]*s)/2,y=cy+64+(191-f.size[1]*s);
 lines.push('<rect x="'+(x-8)+'" y="'+(y-6)+'" width="'+(f.size[0]*s+16)+'" height="'+(f.size[1]*s+12)+'" fill="#0c1623"/>',draw(f,null,x,y,s));
}

lines.push('<text x="60" y="1719" font-family="monospace" font-size="22" fill="#f0e3cb">THE UNBOUND AEON GATE / FAULT-FACING FOLIOS · APPROX 2×</text>');
const closeup=(px,py,vx,vy,vw,vh,alternate=false)=>{
 const sc=alternate?pack.alternate_scene:pack.combined_scene;
 lines.push('<rect x="'+(px-3)+'" y="'+(py-3)+'" width="722" height="246" rx="8" fill="#18212d" stroke="#485466"/>');
 lines.push('<svg xmlns="http://www.w3.org/2000/svg" x="'+px+'" y="'+py+'" width="716" height="240" viewBox="'+vx+' '+vy+' '+vw+' '+vh+'" preserveAspectRatio="xMidYMid meet">','<rect width="'+sc.size[0]+'" height="'+sc.size[1]+'" fill="#0a1420"/>',drawArt(sc.backdrop_rectangles,0,0,1));
 for(const pl of sc.placements){const f=pack.features.find(z=>z.id===pl.feature_id);lines.push(draw(f,pl.variant,pl.origin[0],pl.origin[1],1));}
 lines.push(drawArt(sc.foreground_rectangles,0,0,1),'</svg>');
};
closeup(60,1741,518,36,355,124);
closeup(822,1741,816,18,345,116);
lines.push('<text x="60" y="2010" font-family="monospace" font-size="22" fill="#f0e3cb">SYNCLINAL REBINDING / DRY ALTERNATE DETAIL SECTIONS</text>');
closeup(60,2040,160,183,340,114,true);
closeup(822,2040,790,180,340,114,true);
lines.push('<text x="60" y="2380" font-family="monospace" font-size="22" fill="#f0e3cb">FOUR UNSHELVED UNDERCRYPTS / SOURCE-COLOUR CUT STUDIES</text>');
closeup(60,2400,103,304,455,116,true);
closeup(822,2400,770,304,476,116,true);
lines.push('<text x="61" y="2673" font-family="monospace" font-size="14" fill="#aebac5">PINNED MAIN '+pack.source.main_commit.slice(0,12)+' · DRY COLOURS ONLY · NO GODOT / PHYSICS / TERRAIN CLEARANCE PROOF</text>','</svg>');
const result=lines.join('\n')+'\n';
const file=path.join(dir,'preview.svg');
if(process.argv.includes('--check')){if(fs.readFileSync(file,'utf8')!==result)throw Error('preview drift');console.log('PASS deterministic SVG');}
else if(process.argv.includes('--write')){fs.writeFileSync(file,result);console.log('wrote '+file);}
else process.stdout.write(result);
