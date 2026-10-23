"""Static instruction accounting, never dynamic execution counts or timings."""
import argparse
import json
from pathlib import Path
import re


def functions(text):
    active=None; result={}
    for line in text.splitlines():
        match=re.match(r'\s*\.type\s+([^,]+),\s*[@%]function',line)
        if match:
            active=match[1]; result[active]=[]
        if line.lstrip().startswith('.size'): active=None
        if active and re.match(r'^\s+[a-z][a-z0-9]*(?:\s|$)',line) and not line.lstrip().startswith(('.','#')):
            result[active].append(line.strip())
    return result


if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__); ap.add_argument('root',type=Path)
    args=ap.parse_args(); result={}
    for folder in sorted((args.root/'assembly').iterdir()):
        wrappers=functions((folder/'access.s').read_text())
        world=functions((folder/'world.s').read_text())
        result[folder.name]={'wrappers':{k:{'static_instruction_count':len(v),'instructions':v} for k,v in wrappers.items()},
                             'world':{k:len(v) for k,v in world.items() if any(s in k for s in ['begin_tick','update_cell','scan_rect','tick_phased','move_cell','transfer_water'])}}
    print(json.dumps({'scope':'compiler-output diagnostic; no dynamic frequency, counters or speed ranking','arms':result},indent=2))
