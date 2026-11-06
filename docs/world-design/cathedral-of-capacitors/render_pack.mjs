// Deterministic SVG authoring preview. Usage: node render_pack.mjs [output.svg]
import fs from 'node:fs';
const renderSVG=function renderSVG(p){
 const esc=s=>String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
 const colors=new Map(p.palette.map(m=>[m.id,m.rgba]));
 const rgba=id=>{const v=colors.get(id);return `fill="rgb(${v[0]},${v[1]},${v[2]})" fill-opacity="${(v[3]/255).toFixed(3)}"`};
 const placement=f=>{const q=p.combined_scene.placements.find(x=>x.feature_id===f.id);return q};
 const paint=(f,variant)=>{const va=variant?f.variants.find(v=>v.id===variant):null;return f.rectangles.map(([x,y,w,h,id])=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" ${rgba(Number(va?.swap?.[id]??id))}/>`).join("")};
 const sceneRectangles=rr=>(rr||[]).map(([x,y,w,h,id])=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" ${rgba(id)}/>`).join("");
 const scenePaint=(s)=>sceneRectangles(s.backdrop_rectangles)+s.placements.map(at=>{const f=p.features.find(v=>v.id===at.feature_id);return `<g transform="translate(${at.origin[0]},${at.origin[1]})">${paint(f,at.variant)}</g>`}).join("")+sceneRectangles(s.foreground_rectangles);
 const totalW=1500,totalH=2480;const items=[];
 items.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${totalW}" height="${totalH}" viewBox="0 0 ${totalW} ${totalH}">`);
 items.push(`<rect width="${totalW}" height="${totalH}" fill="#0b111b"/><rect x="26" y="24" width="1448" height="2452" rx="18" fill="#141d29" stroke="#344355"/>`);
 items.push(`<text x="56" y="72" fill="#e3eaf5" font-family="monospace" font-size="32" font-weight="700">CATHEDRAL OF CAPACITORS</text><text x="57" y="102" fill="#8fbcc9" font-family="monospace" font-size="15">WORLD DESIGN / COLLECTION 009 / SOURCE COLOURS / NON-SIMULATED GEOMETRY</text>`);
 items.push(`<rect x="54" y="130" width="1390" height="325" rx="12" fill="#0a1019" stroke="#344355"/>`);
 items.push(`<text x="74" y="157" fill="#abb9c8" font-family="monospace" font-size="16">PROCESSION OF ZERO CURRENT — 1240 × 278 cells, fixed-material variants</text>`);
 const scale=1.05,xx=100,yy=170;items.push(`<g transform="translate(${xx},${yy}) scale(${scale})"><path d="M0 ${p.combined_scene.baseline_y+2} H1240" stroke="#59707d" stroke-width="1.5"/>`);
 items.push(scenePaint(p.combined_scene));items.push(`</g>`);
 items.push(`<text x="73" y="431" fill="#637c8b" font-family="monospace" font-size="13">DRY SCENE: Spark→NeonCyan and Water→GlassBlock. No host clearing / physics / power asserted.</text>`);
 items.push(`<rect x="54" y="474" width="1390" height="495" rx="12" fill="#0a1019" stroke="#344355"/>`);
 items.push(`<text x="74" y="505" fill="#abb9c8" font-family="monospace" font-size="16">THE UNPOWERED RELIQUARY OF THE LOWER CHOIR — 1360 × 410 / STAGGERED ALTARS</text>`);
 items.push(`<g transform="translate(70,524) scale(0.994)"><path d="M0 397 H1360" stroke="#59707d" stroke-width="1"/>${scenePaint(p.alternate_scene)}</g>`);
 items.push(`<text x="74" y="956" fill="#637c8b" font-family="monospace" font-size="13">8 ORIGINAL MODULES / DRY VARIANTS / SOURCE COLOURS. STAGED SUPPORT IS DESIGN-ONLY.</text>`);
 const cardW=335,cardH=342,startX=54,startY=990,gapX=16,gapY=18;
 for(let i=0;i<p.features.length;i++){
  const f=p.features[i],col=i%4,row=Math.floor(i/4),x=startX+col*(cardW+gapX),y=startY+row*(cardH+gapY);
  items.push(`<rect x="${x}" y="${y}" width="${cardW}" height="${cardH}" rx="12" fill="#0a1019" stroke="#344355"/>`);
  items.push(`<text x="${x+17}" y="${y+27}" fill="#e3eaf5" font-family="monospace" font-size="15" font-weight="700">${esc(String(i+1).padStart(2,"0")+" "+f.title.split(" / ")[0])}</text>`);
  items.push(`<text x="${x+17}" y="${y+48}" fill="#7897aa" font-family="monospace" font-size="12">${esc(f.size.join("×")+" cells  |  "+f.kind)}</text>`);
  const s=Math.min(2.08,260/f.size[0],210/f.size[1]);const dx=x+(cardW-f.size[0]*s)/2,dy=y+64+Math.max(0,(205-f.size[1]*s)/2);
  items.push(`<g transform="translate(${dx.toFixed(2)},${dy.toFixed(2)}) scale(${s.toFixed(4)})">${paint(f,null)}</g>`);
  items.push(`<text x="${x+17}" y="${y+315}" fill="#718998" font-family="monospace" font-size="12">${esc(f.role.slice(0,43))}</text>`);
 }
 items.push(`<text x="55" y="1744" fill="#a9c0d0" font-family="monospace" font-size="17" font-weight="700">SOURCE-CELL DETAIL STUDIES / 1.8x / NO SHADERS</text>`);
 for(const [i,ox,oy,title]of [[0,523,40,"LOWER CHOIR / BROKEN DIELECTRIC CORONA"],[1,986,120,"UPPER TRANSEPT / OXIDISED OBSERVATORY"]]){
 const x=54+i*704,y=1770,cid="detail-"+i;
 items.push(`<rect x="${x}" y="${y}" width="688" height="288" rx="10" fill="#0a1019" stroke="#344355"/>`);
 items.push(`<text x="${x+16}" y="${y+25}" fill="#b7c9d3" font-family="monospace" font-size="13">${title}</text>`);
 items.push(`<defs><clipPath id="${cid}"><rect x="${x+13}" y="${y+37}" width="662" height="233"/></clipPath></defs>`);
 items.push(`<g clip-path="url(#${cid})"><g transform="translate(${x+13},${y+37}) scale(1.8) translate(${-ox},${-oy})">${scenePaint(p.alternate_scene)}</g></g>`);
 }
 items.push(`<text x="55" y="2092" fill="#a9c0d0" font-family="monospace" font-size="17" font-weight="700">SIX BURIED REGISTERS / STRUCTURAL DETAIL / 2.1x / FLAT MATERIAL COLOURS</text>`);
 for(const [i,ox,oy,title] of [[0,33,267,"WEST / BUS, RECTIFIER, BROKEN WINDING"],[1,565,259,"CENTRE / SEVERED RETURN SPAN"],[2,1125,264,"EAST / RECORDER AND TERMINAL COFFINS"]]){
  const x=54+i*468,y=2110,clipId="undervault-"+i;
  items.push(`<rect x="${x}" y="${y}" width="442" height="305" rx="9" fill="#0a1019" stroke="#344355"/>`);
  items.push(`<text x="${x+12}" y="${y+23}" fill="#b7c9d3" font-family="monospace" font-size="12">${title}</text>`);
  items.push(`<defs><clipPath id="${clipId}"><rect x="${x+10}" y="${y+34}" width="422" height="258"/></clipPath></defs>`);
  items.push(`<g clip-path="url(#${clipId})"><g transform="translate(${x+10},${y+34}) scale(2.1) translate(${-ox},${-oy})">${scenePaint(p.alternate_scene)}</g></g>`);
 }
 items.push(`<text x="55" y="2458" fill="#8096a6" font-family="monospace" font-size="13">DRAFT SOURCE-COLOUR PAINT ORDER / NOT NATIVE TICKS, GODOT SHADERS, ACTOR CLEARANCE OR IMPORTABLE WORLD.</text></svg>`);
 return items.join("\n")+"\n";
};
const pack=JSON.parse(fs.readFileSync(new URL('./pack.json',import.meta.url),'utf8'));
const text=renderSVG(pack);
const file=process.argv[2];
if(file){fs.writeFileSync(file,text);console.log('Wrote '+file+' ('+text.length+' bytes)');}else process.stdout.write(text);
