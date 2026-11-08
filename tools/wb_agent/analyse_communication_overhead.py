"""Aggregate local diagnostic overhead without copying private messages/IDs."""
from __future__ import annotations
import argparse,hashlib,json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from workbench_api_agent.controller import Runner

def analyse(path:Path)->dict:
    raw=path.read_bytes()
    if len(raw)>64*1024*1024:raise ValueError('input exceeds64MiB')
    records=[json.loads(x) for x in raw.decode('utf-8-sig').splitlines() if x.strip()]
    projection=object.__new__(Runner)
    projection.limit={'max_tool_result_bytes':24000}
    projection.desktop=True
    rows=[]
    for record in records:
        if record.get('kind')!='http.request':continue
        body=record.get('payload',{}).get('body',{})
        if not isinstance(body,dict):continue
        items=body.get('input',[])
        if not isinstance(items,list):continue
        results=[]
        for item in items:
            if not isinstance(item,dict) or item.get('type')!='function_call_output':continue
            text=item.get('output','')
            if not isinstance(text,str):continue
            try:native=json.loads(text)
            except ValueError:continue
            if not isinstance(native,dict):continue
            status=native.get('status','unknown')
            tool={'proposed':'prepare_edit','applied':'apply_edit','observed':'observe','stepped':'step'}.get(status,'other')
            summary,_=projection._native_summary({'receipt':{'result':native,'tool':tool,'status':status,'completed_native_ticks_total':0}})
            selected=projection._project(summary)
            results.append({'tool':tool,'legacy_text_bytes':len(text.encode()),'runner_selected_text_bytes':len(selected.encode())})
        rows.append({'request_ordinal':len(rows)+1,'recorded_compact_body_bytes':len(json.dumps(body,separators=(',',':'),ensure_ascii=False).encode()),'results':results})
    return {'source_bytes':len(raw),'source_sha256':hashlib.sha256(raw).hexdigest(),'method':'recorded bodies reserialized compactUTF8; image descriptors exclude originalbase64; no exactwire/token claim','projection':'existing Runner selected-native-fields; not a new model run','requests':rows}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('log',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    result=analyse(a.log);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result,indent=2))
