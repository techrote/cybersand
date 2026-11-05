// Deterministic SVG authoring preview. Usage: node render_pack.mjs [output.svg]
import fs from 'node:fs';
const renderSVG=function renderSVG(p){
 const esc=s=>String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
 const colors=new Map(p.palette.map(m=>[m.id,m.rgba]));
 const rgba=id=>{const v=colors.get(id);return `fill="rgb(${v[0]},${v[1]},${v[2]})" fill-opacity="${(v[3]/255).toFixed(3)}"`};
 const placement=f=>{const q=p.combined_scene.placements.find(x=>x.feature_id===f.id);return q};
 const paint=(f,variant)=>{const va=variant?f.variants.find(v=>v.id===variant):null;return f.rectangles.map(([x,y,w,h,id])=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" ${rgba(Number(va?.swap?.[id]??id))}/>`).join("")};
 const totalW=1500,totalH=1250;const items=[];
 items.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${totalW}" height="${totalH}" viewBox="0 0 ${totalW} ${totalH}">`);
 items.push(`<rect width="${totalW}" height="${totalH}" fill="#0b111b"/><rect x="26" y="24" width="1448" height="1202" rx="18" fill="#141d29" stroke="#344355"/>`);
 items.push(`<text x="56" y="72" fill="#e3eaf5" font-family="monospace" font-size="32" font-weight="700">CATHEDRAL OF CAPACITORS</text><text x="57" y="102" fill="#8fbcc9" font-family="monospace" font-size="15">WORLD DESIGN / COLLECTION 009 / SOURCE COLOURS / NON-SIMULATED GEOMETRY</text>`);
 items.push(`<rect x="54" y="130" width="1390" height="325" rx="12" fill="#0a1019" stroke="#344355"/>`);
 items.push(`<text x="74" y="157" fill="#abb9c8" font-family="monospace" font-size="16">PROCESSION OF ZERO CURRENT — 1240 × 278 cells, fixed-material variants</text>`);
 const scale=1.05,xx=100,yy=170;items.push(`<g transform="translate(${xx},${yy}) scale(${scale})"><path d="M0 ${p.combined_scene.baseline_y+2} H1240" stroke="#59707d" stroke-width="1.5"/>`);
 for(const at of p.combined_scene.placements){const f=p.features.find(v=>v.id===at.feature_id);items.push(`<g transform="translate(${at.origin[0]},${at.origin[1]})">${paint(f,at.variant)}</g>`);}items.push(`</g>`);
 items.push(`<text x="73" y="431" fill="#637c8b" font-family="monospace" font-size="13">DRY SCENE: Spark→NeonCyan and Water→GlassBlock. No host clearing / physics / power asserted.</text>`);
 const cardW=335,cardH=342,startX=54,startY=482,gapX=16,gapY=18;
 for(let i=0;i<p.features.length;i++){
  const f=p.features[i],col=i%4,row=Math.floor(i/4),x=startX+col*(cardW+gapX),y=startY+row*(cardH+gapY);
  items.push(`<rect x="${x}" y="${y}" width="${cardW}" height="${cardH}" rx="12" fill="#0a1019" stroke="#344355"/>`);
  items.push(`<text x="${x+17}" y="${y+27}" fill="#e3eaf5" font-family="monospace" font-size="15" font-weight="700">${esc(String(i+1).padStart(2,"0")+" "+f.title.split(" / ")[0])}</text>`);
  items.push(`<text x="${x+17}" y="${y+48}" fill="#7897aa" font-family="monospace" font-size="12">${esc(f.size.join("×")+" cells  |  "+f.kind)}</text>`);
  const s=Math.min(2.08,260/f.size[0],210/f.size[1]);const dx=x+(cardW-f.size[0]*s)/2,dy=y+64+Math.max(0,(205-f.size[1]*s)/2);
  items.push(`<g transform="translate(${dx.toFixed(2)},${dy.toFixed(2)}) scale(${s.toFixed(4)})">${paint(f,null)}</g>`);
  items.push(`<text x="${x+17}" y="${y+315}" fill="#718998" font-family="monospace" font-size="12">${esc(f.role.slice(0,43))}</text>`);
 }
 items.push(`<text x="55" y="1220" fill="#8096a6" font-family="monospace" font-size="13">READ pack.json + README.md. STATIC DESIGN PREVIEW ≠ NATIVE SIMULATION, GODOT LIGHTING OR IMPORTABLE LEVEL.</text></svg>`);
 return items.join("\n")+"\n";
};
const pack=JSON.parse(fs.readFileSync(new URL('./pack.json',import.meta.url),'utf8'));
const text=renderSVG(pack);
const file=process.argv[2];
if(file){fs.writeFileSync(file,text);console.log('Wrote '+file+' ('+text.length+' bytes)');}else process.stdout.write(text);
