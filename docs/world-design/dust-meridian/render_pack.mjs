#!/usr/bin/env node
import fs from 'node:fs';
const render=function render(p){
 const escape=s=>String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&apos;"}[c]));
 const colors=new Map(p.palette.map(m=>[m.id,m.rgba]));
 const rs=a=>{const [x,y,w,h,id]=a,c=colors.get(id);return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="rgba(${c[0]},${c[1]},${c[2]},${(c[3]/255).toFixed(3)})"/>`};
 const draw=(f,v,x,y,s)=>`<g transform="translate(${x} ${y}) scale(${s})">${f.rectangles.map(a=>rs([...a.slice(0,4),+(v?.swap?.[String(a[4])]??a[4])])).join("")}</g>`;
 const z=[`<svg xmlns="http://www.w3.org/2000/svg" width="1480" height="2445" viewBox="0 0 1480 2445">`,`<rect width="1480" height="2445" fill="#131b23"/>`,`<text x="45" y="60" font-family="monospace" font-size="43" font-weight="bold" fill="#f1d199">DUST MERIDIAN</text>`,`<text x="46" y="88" font-family="monospace" font-size="17" fill="#b5b4ad">CYBERSAND WORLD DESIGN 008 • DESERT SURVEY RELICS • DRAFT SCHEMATIC</text>`];
 p.features.forEach((f,i)=>{const x=45+i%4*348,y=125+Math.floor(i/4)*195,s=Math.min(1.25,280/f.size[0],126/f.size[1]);z.push(`<rect x="${x}" y="${y}" width="332" height="182" rx="5" fill="#252f37" stroke="#52606a"/>`);z.push(draw(f,null,x+(332-f.size[0]*s)/2,y+7+132-f.size[1]*s,s));z.push(`<text x="${x+10}" y="${y+156}" font-family="monospace" font-size="16" fill="#f2dcc1">${i+1}. ${escape(f.title.split(" / ")[0])}</text>`);z.push(`<text x="${x+10}" y="${y+173}" font-family="monospace" font-size="12" fill="#a0afa9">${f.size.join(" x ")} cells • ${escape(f.kind)}</text>`)});
 z.push(`<rect x="45" y="530" width="1380" height="382" rx="5" fill="#232d35" stroke="#52606a"/>`,`<text x="62" y="566" font-family="monospace" font-size="21" fill="#f1d199">LATITUDE OF BROKEN NORTH — COMBINED FIXED-ONLY DESERT</text>`);
 z.push(`<g transform="translate(50 585) scale(1.04)"><rect width="${p.scene.size[0]}" height="${p.scene.size[1]}" fill="#343d44"/>`);
 for(const a of p.scene.terrain_rectangles)z.push(rs(a));
 for(const pl of p.scene.placements){const f=p.features.find(x=>x.id===pl.feature),v=f.variants.find(x=>x.id===pl.variant);z.push(draw(f,v,pl.x,pl.y,1))}
 z.push(`</g>`);
 const sceneAlt=s=>{
 const q=[`<rect width="${s.size[0]}" height="${s.size[1]}" fill="#343d44"/>`];
 for(const a of s.terrain_rectangles)q.push(rs(a));
 for(const pl of s.placements){const f=p.features.find(x=>x.id===pl.feature),v=f.variants.find(x=>x.id===pl.variant);q.push(draw(f,v,pl.x,pl.y,1))}
 return q.join("\n");
 };
 z.push(`<rect x="45" y="932" width="1380" height="538" rx="5" fill="#232d35" stroke="#52606a"/>`,`<text x="62" y="968" font-family="monospace" font-size="21" fill="#f1d199">THE SUNKEN AZIMUTH — DESCENDING DRY ALTERNATE</text>`);
 z.push(`<g transform="translate(50 991) scale(1.04)">`,sceneAlt(p.alternate_scene),`</g>`);
 z.push(`<text x="58" y="1498" font-family="monospace" font-size="18" fill="#f1d199">DETAIL STUDIES • SOURCE-COLOUR PIXEL GEOMETRY, NOT GODOT</text>`);
 const crop=(x,label,view)=>{z.push(`<rect x="${x}" y="1516" width="670" height="263" rx="5" fill="#232d35" stroke="#52606a"/>`,`<text x="${x+12}" y="1540" font-family="monospace" font-size="15" fill="#e9ceab">${label}</text>`,`<svg x="${x+8}" y="1548" width="654" height="219" viewBox="${view}" preserveAspectRatio="xMidYMid slice">`,sceneAlt(p.alternate_scene),`</svg>`)};
 crop(45,'01 / fractured cardinal wheel and rigging','690 50 370 124');
 crop(755,'02 / lower archive and survey marks','100 285 370 124');
 z.push(`<text x="58" y="1797" font-family="monospace" font-size="18" fill="#f1d199">FLAGSHIP UNDERCROFT • SOURCE-CELL STUDIES, NOT GODOT</text>`);
 const mainCrop=(x,label,view)=>{z.push(`<rect x="${x}" y="1815" width="670" height="264" rx="5" fill="#232d35" stroke="#52606a"/>`,`<text x="${x+12}" y="1836" font-family="monospace" font-size="15" fill="#e9ceab">${label}</text>`,`<svg x="${x+8}" y="1845" width="654" height="220" viewBox="${view}" preserveAspectRatio="xMidYMid slice">`,sceneAlt(p.scene),`</svg>`)};
 mainCrop(45,'03 / star-chart and eroded bearing undercrofts','70 186 465 95');
 mainCrop(755,'04 / compass and transit-ledger undercrofts','792 186 475 95');
 z.push(`<text x="58" y="2101" font-family="monospace" font-size="18" fill="#f1d199">INVERTED SIGHTLINES • ALTERNATE CELLAR STUDIES, NOT GODOT</text>`);
 const vaultCrop=(x,label,view)=>{z.push(`<rect x="${x}" y="2118" width="670" height="266" rx="5" fill="#232d35" stroke="#52606a"/>`,`<text x="${x+12}" y="2140" font-family="monospace" font-size="15" fill="#e9ceab">${label}</text>`,`<svg x="${x+8}" y="2148" width="654" height="224" viewBox="${view}" preserveAspectRatio="xMidYMid slice">`,sceneAlt(p.alternate_scene),`</svg>`)};
 vaultCrop(45,'05 / fractured lift and blind-sidereal orrery','270 355 472 91');
 vaultCrop(755,'06 / cartographic reliquary and quartz sighting sump','857 355 430 91');
 z.push(`<text x="46" y="2423" font-family="monospace" font-size="12" fill="#aab5af">SOURCE-CELL SCHEMATIC • NOT GODOT • NO CLEARANCE, OPTICS, PHYSICS OR PERFORMANCE CLAIM</text>`,`</svg>`)
 return z.join("\n")+"\n";
};
const [,,packPath='pack.json',output='preview.svg',flag]=process.argv;
const p=JSON.parse(fs.readFileSync(packPath,'utf8'));
const result=render(p);
if(flag==='--check'){if(fs.readFileSync(output,'utf8')!==result)throw Error('preview mismatch');console.log('PASS identical generated SVG');}
else {fs.writeFileSync(output,result);console.log('wrote '+output);}
