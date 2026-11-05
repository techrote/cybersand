#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const dir=path.dirname(fileURLToPath(import.meta.url));
const p=JSON.parse(fs.readFileSync(path.join(dir,'pack.json'),'utf8'));
const pm=new Map(p.palette.map(m=>[m.id,m]));
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const rgba=m=>{const c=pm.get(m).rgba;return 'rgba('+c[0]+','+c[1]+','+c[2]+','+(c[3]/255).toFixed(3)+')';};
const apply=(f,v)=>{const variant=v?f.variants.find(q=>q.id===v):null;if(v&&!variant)throw Error('unknown variant '+v);return f.rectangles.map(a=>[...a.slice(0,4),variant?+(variant.swap[String(a[4])]??a[4]):a[4]]);};
const rects=(f,v,x,y,s)=>apply(f,v).map(([a,b,w,h,m])=>'<rect x="'+(x+a*s).toFixed(2)+'" y="'+(y+b*s).toFixed(2)+'" width="'+(w*s).toFixed(2)+'" height="'+(h*s).toFixed(2)+'" fill="'+rgba(m)+'"/>').join('');
const lines=['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1210" viewBox="0 0 1600 1210">'];
lines.push('<rect width="1600" height="1210" fill="#0b1017"/>','<text x="60" y="55" font-family="monospace" font-size="35" fill="#e6d8bb" font-weight="bold">IRONROOT NECROPOLIS</text>','<text x="62" y="83" font-family="monospace" font-size="16" fill="#a7b0aa">AVENUE OF SILENT FORGES / World Feature Collection 012 / Design-only</text>');
lines.push('<rect x="60" y="106" width="1480" height="349" rx="12" fill="#141c25" stroke="#444d52"/>','<text x="88" y="136" font-family="monospace" font-size="18" fill="#d7b77c">COMBINED DRY SCENE 1270 × 310 native cells / baseline 263</text>');
const sx=160,sy=147;
lines.push('<rect x="'+sx+'" y="'+sy+'" width="1270" height="310" fill="#0c131d"/>');
for(const pl of p.combined_scene.placements){const f=p.features.find(q=>q.id===pl.feature_id);lines.push(rects(f,pl.variant,sx+pl.origin[0],sy+pl.origin[1],1));}
lines.push('<line x1="'+sx+'" x2="'+(sx+1270)+'" y1="'+(sy+263)+'" y2="'+(sy+263)+'" stroke="#776747" stroke-width="1" stroke-dasharray="5 5"/>');
lines.push('<text x="62" y="503" font-family="monospace" font-size="21" fill="#d6c8a7">EIGHT MODULAR MOTIFS</text>','<text x="62" y="524" font-family="monospace" font-size="13" fill="#98a5a9">Source-catalogue colours · modules are schematics · dark space does not excavate host cells</text>');
for(let i=0;i<p.features.length;i++){
 const f=p.features[i],col=i%4,row=Math.floor(i/4),cx=58+col*384,cy=550+row*314;
 lines.push('<rect x="'+cx+'" y="'+cy+'" width="366" height="295" rx="10" fill="#141c25" stroke="#384651"/>','<text x="'+(cx+16)+'" y="'+(cy+27)+'" font-family="monospace" font-size="17" font-weight="bold" fill="#e0d0aa">'+String(i+1).padStart(2,'0')+' '+esc(f.title.split('/')[0].trim())+'</text>');
 lines.push('<text x="'+(cx+16)+'" y="'+(cy+48)+'" font-family="monospace" font-size="12" fill="#98a5a9">'+f.size.join(' × ')+' cells · '+f.kind+'</text>');
 const s=1.50,x=cx+(366-f.size[0]*s)/2,y=cy+68+(195-f.size[1]*s);
 lines.push('<rect x="'+(x-8)+'" y="'+(y-8)+'" width="'+(f.size[0]*s+16)+'" height="'+(f.size[1]*s+16)+'" fill="#0b121c"/>');
 lines.push(rects(f,null,x,y,s));
}
lines.push('<text x="62" y="1190" font-family="monospace" font-size="14" fill="#9faab1">Pinned main '+p.source.main_commit.slice(0,12)+' · dry scene substitutes Rust/Coal and Oil · native sim/collision NOT tested</text>','</svg>');
const result=lines.join('\n')+'\n';
const out=path.join(dir,'preview.svg');
if(process.argv.includes('--check')){if(fs.readFileSync(out,'utf8')!==result)throw Error('preview differs from reproducible renderer');console.log('PASS preview deterministic');}
else if(process.argv.includes('--write')){fs.writeFileSync(out,result);console.log('wrote',out);}
else process.stdout.write(result);
