function renderSvg(pack) {
  const escape = s => String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/"/g,"&quot;");
  const color = m => {
    const a=m.rgba, h=n=>n.toString(16).padStart(2,"0");
    return 'fill="#'+h(a[0])+h(a[1])+h(a[2])+'"'+(a[3]===255?'':' fill-opacity="'+(a[3]/255).toFixed(3)+'"');
  };
  const pal=new Map(pack.palette.map(m=>[m.id,m]));
  const fMap=new Map(pack.features.map(f=>[f.id,f]));
  const rects=(list,sw={})=>list.map(r=>{
    const [x,y,w,h,id]=r,mid=Object.prototype.hasOwnProperty.call(sw,String(id))?sw[id]:id;
    const m=pal.get(mid);
    if(!m)throw Error("unknown material "+mid);
    return '<rect x="'+x+'" y="'+y+'" width="'+w+'" height="'+h+'" '+color(m)+'/>';
  }).join('');
  const modules=pack.features.map((f,i)=>'<g id="module-'+i+'">'+rects(f.rectangles)+'</g>').join('');
  const placements=pack.scene.placements.map(a=>{
    const f=fMap.get(a.feature),v=f.variants.find(v=>v.id===a.variant);
    if(a.variant!=="base"&&!v)throw Error("unknown variant "+a.feature+"/"+a.variant);
    return '<g transform="translate('+a.x+' '+a.y+')">'+rects(f.rectangles,v?v.swap:{})+'</g>';
  }).join('');
  const scenery=rects(pack.scene.rectangles)+placements;
  const alternate=pack.alternate_scene;
  const altPlacements=alternate.placements.map(a=>{const f=fMap.get(a.feature),v=f.variants.find(v=>v.id===a.variant);if(a.variant!=="base"&&!v)throw Error("unknown alternate variant "+a.feature+"/"+a.variant);return '<g transform="translate('+a.x+' '+a.y+')">'+rects(f.rectangles,v?v.swap:{})+'</g>';}).join('');
  const alternateScenery=rects(alternate.rectangles)+altPlacements;
  const clips=[0,1,2].map(i=>'<clipPath id="crop-'+i+'"><rect x="'+(54+i*482)+'" y="1393" width="455" height="284" rx="5"/></clipPath>').join('');
  let s='<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1540 2205" width="1540" height="2205" role="img" aria-label="The Lumen Fault two geological sections and eight source-colour modules, not engine captures">';
  s+='<defs><g id="atlas-scene">'+scenery+'</g><g id="alternate-scene">'+alternateScenery+'</g>'+modules+clips+'</defs>';
  s+='<rect width="1540" height="1585" fill="#0b1019"/><path d="M54 81H1486" stroke="#2b424b" stroke-width="2"/>';
  s+='<text x="54" y="54" fill="#f0f1ed" font-family="monospace" font-size="36" font-weight="bold">THE LUMEN FAULT</text>';
  s+='<text x="1456" y="51" text-anchor="end" fill="#9ab6b4" font-family="monospace" font-size="16">THE GLASS SCAR / 001</text>';
  s+='<text x="54" y="108" fill="#9ab3b5" font-family="monospace" font-size="14">01 — FRACTURED SURVEY CITADEL / SOURCE-COLOUR DRY PROPOSAL / 640 × 256 NATIVE CELLS</text>';
  s+='<rect x="54" y="125" width="1432" height="532" rx="7" fill="#080b12" stroke="#4b6467" stroke-width="2"/>';
  s+='<g transform="translate(130 135) scale(2)"><use xlink:href="#atlas-scene"/></g>';
  s+='<text x="54" y="691" fill="#eef0e8" font-family="monospace" font-size="18">FAULT / VOID / RELIC — a severed calibration city above a split basalt foundation</text>';
  s+='<text x="54" y="721" fill="#83999d" font-family="monospace" font-size="14">STATIC DRY COMPOSITE · ORIGINAL WATER MODULE RETAINED BUT NOT SIMULATION-QUALIFIED</text>';
  s+='<text x="54" y="758" fill="#d7e3e1" font-family="monospace" font-size="18">02 — THE RISING DATUM / CONTRASTING DRY OBSERVATORY SECTION · 640 × 256</text>';
  s+='<rect x="54" y="775" width="1432" height="532" rx="7" fill="#080b12" stroke="#4b6467" stroke-width="2"/>';
  s+='<g transform="translate(130 785) scale(2)"><use xlink:href="#alternate-scene"/></g>';
  s+='<text x="54" y="1337" fill="#eef0e8" font-family="monospace" font-size="18">INVERSE STRATA / WITNESS VAULT / SHATTERED DATUM HALO</text>';
  s+='<text x="54" y="1367" fill="#83999d" font-family="monospace" font-size="14">EIGHT REUSED MODULES · NO ACTIVE WATER PLACED · NO PHYSICS OR LIGHT CLAIMS</text>';
  s+='<text x="54" y="1377" fill="#d7e3e1" font-family="monospace" font-size="18">03 — MATERIAL-SOURCE DETAIL STUDIES / VECTOR CROPS (NOT GODOT)</text>';
  const crops=[
    {x:260,y:19,w:121,h:77,label:"SEVERED ROOF · GLASS-SCAR VEINS"},
    {x:325,y:134,w:125,h:78,label:"THE RIFT · ABANDONED WALKWAY"},
    {x:422,y:121,w:210,h:131,label:"ALT · WITNESS ADITS / BROKEN FOOTING"}
  ];
  crops.forEach((c,i)=>{
    const px=54+i*482, py=1393, sc=455/c.w;
    s+='<rect x="'+px+'" y="'+py+'" width="455" height="284" rx="5" fill="#080b12" stroke="#415960"/>';
    s+='<g clip-path="url(#crop-'+i+')"><g transform="translate('+px+' '+py+') scale('+sc+') translate('+-c.x+' '+-c.y+')"><use xlink:href="#'+(i===2?"alternate-scene":"atlas-scene")+'"/></g></g>';
    s+='<text x="'+(px+6)+'" y="1701" fill="#b6c9c9" font-family="monospace" font-size="14">'+escape(c.label)+'</text>';
  });
  s+='<text x="54" y="1756" fill="#d9e9e5" font-family="monospace" font-size="18">04 — EIGHT REUSABLE MODULES / BASE GEOMETRY · VARIANTS PRESERVED</text>';
  pack.features.forEach((f,i)=>{
    const col=i%4,row=Math.floor(i/4),x=54+col*362,y=1773+row*188;
    s+='<rect x="'+x+'" y="'+y+'" width="342" height="173" rx="6" fill="#111b24" stroke="#304953"/>';
    s+='<g transform="translate('+(x+18)+' '+(y+14)+') scale(1.6)"><use xlink:href="#module-'+i+'"/></g>';
    s+='<text x="'+(x+176)+'" y="'+(y+42)+'" fill="#e4eae6" font-size="13" font-family="monospace">'+escape(f.id)+'</text>';
    s+='<text x="'+(x+176)+'" y="'+(y+66)+'" fill="#9bb5b4" font-size="12" font-family="monospace">'+f.size[0]+'×'+f.size[1]+' native cells</text>';
    s+='<text x="'+(x+176)+'" y="'+(y+91)+'" fill="#9bb5b4" font-size="12" font-family="monospace">'+escape(f.status)+'</text>';
    s+='<text x="'+(x+176)+'" y="'+(y+116)+'" fill="#80969b" font-size="12" font-family="monospace">2 preserved variants</text>';
  });
  s+='<text x="54" y="2190" fill="#83989c" font-family="monospace" font-size="12">GEOMETRY SVG · SHADOW MATERIAL RGBA · LAST RECTANGLE WINS · NO SHADERS / NATIVE TICKS / CLEARANCE CLAIMS</text></svg>\n';
  return s;
}
// NODE_CLI — run from this directory: node render_pack.mjs [--check]
import fs from 'node:fs';
const pack=JSON.parse(fs.readFileSync(new URL('./pack.json',import.meta.url),'utf8'));
const output=renderSvg(pack);
const dest=new URL('./preview.svg',import.meta.url);
if(process.argv.includes('--check')){
  const committed=fs.readFileSync(dest,'utf8');
  if(committed!==output){console.error('FAIL: preview.svg differs from deterministic pack geometry');process.exitCode=1;}
  else console.log('PASS: deterministic SVG matches pack.json byte-for-byte');
}else{fs.writeFileSync(dest,output,'utf8');console.log('RENDERED: preview.svg ('+output.length+' UTF-16 units)');}
