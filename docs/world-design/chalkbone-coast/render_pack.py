#!/usr/bin/env python3
"""Flat catalogue-colour SVG schematic for Chalkbone Coast (not a Godot frame)."""
import argparse
import html
import json
from pathlib import Path
from validate_pack import check
HERE=Path(__file__).resolve().parent

def raster(size, rows, features, placements=()):
    w,h=size
    pixels=[0]*(w*h)
    def paint(rect,offset_x=0,offset_y=0,swap=None):
        x,y,rw,rh,mat=rect
        mat=(swap or {}).get(str(mat),mat)
        for yy in range(y+offset_y,y+offset_y+rh):
            pixels[yy*w+x+offset_x: yy*w+x+offset_x+rw] = [mat]*rw
    for r in rows: paint(r)
    for placement in placements:
        f=features[placement['feature']]
        swap=next((v['swap'] for v in f['variants'] if v['id']==placement['variant']),{})
        for r in f['rectangles']:paint(r,placement['x'],placement['y'],swap)
    return pixels

def runrects(pixels,wh,px,py,scale,palette):
    """Greedy exact pixel rectangle partition; fewer SVG elements than row strips."""
    w,h=wh
    rects=[];active={}
    def flush(key, top, bottom):
        x0,x1,mid=key
        if mid==0:return
        c=palette[mid]['rgba'];op=c[3]/255
        col='#'+''.join(f'{n:02X}' for n in c[:3])
        rects.append(f'<rect x="{px+x0*scale:g}" y="{py+top*scale:g}" width="{(x1-x0)*scale:g}" height="{(bottom-top)*scale:g}" fill="{col}"'+(f' fill-opacity="{op:.3f}"' if op<1 else '')+'/>')
    for y in range(h+1):
        runs=set()
        if y<h:
            row=pixels[y*w:(y+1)*w];x=0
            while x<w:
                mat=row[x];end=x+1
                while end<w and row[end]==mat:end+=1
                runs.add((x,end,mat));x=end
        nxt={}
        for key in sorted(runs):
            nxt[key]=active[key] if key in active else y
        for key,start in active.items():
            if key not in nxt:flush(key,start,y)
        active=nxt
    return '\n'.join(rects)

def generate(pack):
    palette={x['id']:x for x in pack['palette']}
    features={f['id']:f for f in pack['features']}
    parts=['''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="2400" viewBox="0 0 1200 2400" role="img" aria-label="Chalkbone Coast combined shore scene and eight modular design schematics">
<rect width="1200" height="2400" fill="#0B1521"/>
<text x="28" y="46" fill="#F0E4D4" font-family="monospace" font-size="28" font-weight="bold">CHALKBONE COAST // DESIGN SHEET 002</text>
<text x="28" y="70" fill="#B7C5CC" font-family="monospace" font-size="13">SOURCE-COLOUR RECTANGLES · NOT GAMEPLAY / PHYSICS / GODOT CAPTURE</text>
<text x="28" y="102" fill="#DBD6C8" font-family="monospace" font-size="17">COMBINED LITTORAL SECTION · 768 × 256 CELLS</text>
<rect x="24" y="116" width="1152" height="384" fill="#0D2029" stroke="#4F7580" stroke-width="1"/>''']
    sr=pack['scene'];pw=raster(sr['size'],sr['rectangles'],features,sr['placements'])
    parts.append(runrects(pw,sr['size'],24,116,1.5,palette))
    for place in sr['placements']:
        f=features[place['feature']];tx=24+place['x']*1.5;ty=116+place['y']*1.5
        parts.append(f'<rect x="{tx-2:g}" y="{max(127,ty-21):g}" width="{min(180, len(f["id"])*6+8):g}" height="14" fill="#0B1521" opacity="0.9"/>')
        parts.append(f'<text x="{tx+2:g}" y="{max(138,ty-11):g}" fill="#F5ECDD" font-family="monospace" font-size="10">{html.escape(f["id"])}</text>')
    parts += ['<text x="28" y="531" fill="#DBD6C8" font-family="monospace" font-size="17">MODULAR ATLAS · SAME MATERIAL IDS / LOCAL CELL COORDINATES</text>']
    for i,f in enumerate(pack['features']):
        col=i%4;row=i//4;x=24+294*col;y=555+245*row
        parts.append(f'<rect x="{x}" y="{y}" width="276" height="226" rx="5" fill="#102632" stroke="#315563" stroke-width="1"/>')
        parts.append(f'<text x="{x+11}" y="{y+23}" fill="#EBD8BE" font-family="monospace" font-size="14" font-weight="bold">{i+1:02d}  {html.escape(f["id"])}</text>')
        parts.append(f'<text x="{x+11}" y="{y+42}" fill="#A6C4C7" font-family="monospace" font-size="11">{f["size"][0]}×{f["size"][1]}  {html.escape(f["status"])}</text>')
        scale=min(2.2,250/f['size'][0],138/f['size'][1]);fw=f['size'][0]*scale;fh=f['size'][1]*scale
        ox=x+(276-fw)/2;oy=y+190-fh
        parts.append(f'<rect x="{ox:g}" y="{oy:g}" width="{fw:g}" height="{fh:g}" fill="#0D2029"/>')
        parts.append(runrects(raster(f['size'],f['rectangles'],features),f['size'],ox,oy,scale,palette))
        parts.append(f'<text x="{x+11}" y="{y+213}" fill="#9CAFB0" font-family="monospace" font-size="10">BASE VARIANT · NO SIM TEST</text>')
    parts.append('<text x="28" y="1060" fill="#92ADB7" font-family="monospace" font-size="12">Flat RGBA from pinned shadow catalogue. Visual overlaps use last-write-wins rastering. ID 24 Brine and ID 23 Salt are mobile in the native catalogue.</text>')
    parts.append('<text x="28" y="1116" fill="#DBD6C8" font-family="monospace" font-size="17">THE LOST BONE TIDE · TRUE NATIVE-CELL HEADLAND DETAIL CROPS</text>')
    for ox, sx, sy, title in ((36, 0, 0, 'WIND-CUT WITNESS HALL · CALCITE RELIEF'), (624, 210, 0, 'SHEARED VERTEBRAL SPAN · CHALK ARCHIVE')):
        crop = []
        for cy in range(sy, sy+100):
            crop.extend(pw[cy*sr['size'][0]+sx:cy*sr['size'][0]+sx+240])
        parts.append(f'<rect x="{ox}" y="1150" width="480" height="200" fill="#0D2029" stroke="#4F7580" stroke-width="1"/>')
        parts.append(runrects(crop,(240,100),ox,1150,2,palette))
        parts.append(f'<text x="{ox+2}" y="1376" fill="#EBD8BE" font-family="monospace" font-size="12">{title}</text>')
    parts.append('<text x="28" y="1402" fill="#92ADB7" font-family="monospace" font-size="12">Inert scene substitutions only. Flat palette schematics: no Godot/physics/water/reflection/clearance qualification.</text>')
    # Separate source-colour illustration of a second, spatially different placement.
    # No Godot shaders, living liquids or accepted importer are involved.
    ar=pack['alternate_scene']; aw,ah=ar['size']
    alt_pixels=raster(ar['size'],ar['rectangles'],features,ar['placements'])
    parts.append('<text x="28" y="1458" fill="#DBD6C8" font-family="monospace" font-size="17">ALTERNATE SHORE · THE SPIRAL BREACH · 768 × 352 CELLS</text>')
    parts.append('<rect x="24" y="1470" width="1152" height="528" fill="#0D2029" stroke="#4F7580" stroke-width="1"/>')
    parts.append(runrects(alt_pixels,ar['size'],24,1470,1.5,palette))
    for placement in ar['placements']:
        tx=24+placement['x']*1.5;ty=1470+placement['y']*1.5
        parts.append(f'<text x="{tx+2:g}" y="{max(1484,ty-8):g}" fill="#EBD8BE" font-family="monospace" font-size="10">{html.escape(placement["feature"])}</text>')
    parts.append('<text x="28" y="2040" fill="#DBD6C8" font-family="monospace" font-size="17">SPIRAL FOSSIL / LEFT ERODED COAST · TRUE NATIVE-CELL CROPS</text>')
    for ox,sx,sy,title in ((36,270,99,'SPIRAL SHELL · DISCONTINUOUS CALYX'),(624,0,153,'LEFT SEDIMENT SCARP · CAVITIES CUT WITH ID 0')):
        crop=[]
        for cy in range(sy,sy+100):
            crop.extend(alt_pixels[cy*aw+sx:cy*aw+sx+240])
        parts.append(f'<rect x="{ox}" y="2062" width="480" height="200" fill="#0D2029" stroke="#4F7580" stroke-width="1"/>')
        parts.append(runrects(crop,(240,100),ox,2062,2,palette))
        parts.append(f'<text x="{ox+2}" y="2290" fill="#EBD8BE" font-family="monospace" font-size="12">{title}</text>')
    parts.append('<text x="28" y="2354" fill="#92ADB7" font-family="monospace" font-size="12">Dry fixed-cell proposal: ID 0 cuts are explicit. No native Godot, liquid, clearance or physical-support proof.</text>')
    parts.append('</svg>')
    return '\n'.join(parts)+'\n'

def main():
    p=argparse.ArgumentParser();p.add_argument('--pack',type=Path,default=HERE/'pack.json');p.add_argument('--output',type=Path,default=HERE/'preview.svg');p.add_argument('--check',action='store_true');a=p.parse_args()
    pack=json.loads(a.pack.read_text(encoding='utf-8'));result=check(pack)
    if not result['ok']:raise SystemExit('Invalid pack: '+str(result['errors']))
    svg=generate(pack)
    if a.check:
        if not a.output.exists() or a.output.read_text(encoding='utf-8')!=svg: raise SystemExit('PREVIEW STALE')
        print('PREVIEW PASS: exact deterministic source-colour SVG')
    else:
        a.output.write_text(svg,encoding='utf-8');print('WROTE',a.output,len(svg),'characters')

if __name__=='__main__':main()
