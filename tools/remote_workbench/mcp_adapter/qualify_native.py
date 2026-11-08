#!/usr/bin/env python3
"""EXTERNAL native/MCP acceptance driver. NOT a chat-model tool invocation.

Requires a freshly authorized, disposable #547 Godot/native World plus a
separately running MCP adapter. Retains original MCP PNGs and native receipts.
This driver never launches a World and never obtains/changes host authority.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import time
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import ProxyHandler, Request, build_opener

OPENER = build_opener(ProxyHandler({}))

class MCPCaller:
    def __init__(self, url: str, token: str, output: Path):
        p = urlsplit(url)
        if not (p.scheme == 'http' and p.hostname in ('127.0.0.1', 'localhost')
                and p.port and p.path == '/mcp' and not p.username
                and not p.password and not p.query and not p.fragment):
            raise ValueError('only_private_loopback_mcp_url_allowed')
        self.url, self.token, self.output = url, token, output
        self.sequence = 0
        self.transcript = []

    def wire(self, method, params=None, *, token=None):
        self.sequence += 1
        payload = {'jsonrpc':'2.0','id':self.sequence,'method':method,'params':params or {}}
        request = Request(self.url, data=json.dumps(payload).encode('utf-8'),
                          headers={'Authorization':'Bearer '+(self.token if token is None else token),
                                   'Content-Type':'application/json',
                                   'Accept':'application/json, text/event-stream'}, method='POST')
        try:
            with OPENER.open(request, timeout=102) as response:
                return response.status, json.loads(response.read(9*1024*1024))
        except HTTPError as error:
            return error.code, json.loads(error.read(8192))

    def call(self, name, args=None, *, label=None):
        code, doc = self.wire('tools/call', {'name':name,'arguments':args or {}})
        if code != 200 or 'result' not in doc:
            raise AssertionError(f'{name}: MCP HTTP {code} / {str(doc)[:500]}')
        result = doc['result']; structured = result['structuredContent']
        images = [b for b in result['content'] if b.get('type') == 'image']
        frame = None
        if images:
            assert len(images)==1 and images[0]['mimeType']=='image/png'
            raw = base64.b64decode(images[0]['data'], validate=True)
            sha = hashlib.sha256(raw).hexdigest()
            assert sha == structured['original_png_sha256'] and raw.startswith(b'\x89PNG\r\n\x1a\n')
            namepng = f'{len(self.transcript)+1:03d}-{label or name}.png'
            frame = self.output/'frames'/namepng
            frame.write_bytes(raw)
            orig = structured['envelope']['receipt']['frame']
            assert orig['sha256'] == sha and orig['status']=='original_post_draw'
        self.transcript.append({'label':label or name,'tool':name,'arguments':args or {},
                 'structuredContent':structured,
                 'image':{'path':str(frame.relative_to(self.output)),
                          'sha256':sha,'bytes':len(raw)} if frame else None})
        return result

    def result(self, value):
        return value['structuredContent']


def require(value, why):
    if not value: raise AssertionError(why)


def result_native(block):
    data = block['structuredContent']
    return data.get('envelope', {}).get('receipt', {}).get('result', {})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mcp-url', default='http://127.0.0.1:8766/mcp')
    parser.add_argument('--mcp-token-file', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args=parser.parse_args()
    directory=args.output.resolve()
    require(not directory.exists() or not any(directory.iterdir()),'evidence directory not empty')
    directory.mkdir(parents=True, exist_ok=True)
    (directory/'frames').mkdir()
    # Reuse upstream client's owner-only mode-0600 token verifier for MCP token.
    import sys
    sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
    from client import read_token
    token = read_token(args.mcp_token_file)
    caller = MCPCaller(args.mcp_url,token,directory)
    evidence={'schema_version':1,'result':'failed', 'scope':'scripted_external_MCP_native_not_Cloud_Sol_chat',
              'started_at_unix_seconds':round(time.time(),3)}
    try:
        code,_=caller.wire('tools/list', token='')
        require(code==401,'missing MCP bearer unexpectedly permitted')
        code,_=caller.wire('tools/list', token=secrets.token_urlsafe(48))
        require(code==401,'wrong MCP bearer unexpectedly permitted')
        code,initialized=caller.wire('initialize', {'protocolVersion':'2025-11-25',
            'capabilities':{},'clientInfo':{'name':'cybersand-qualification','version':'1.0'}})
        require(code==200 and initialized['result']['serverInfo']['name']=='cybersand-workbench',
                'MCP initialise failed')
        code,listed=caller.wire('tools/list')
        require(code==200,'MCP tools/list failed')
        require({tool['name'] for tool in listed['result']['tools']} == {
                'session_status','observe','prepare_edit','apply_edit','step','stop'},'MCP tool surface changed')
        deadline=time.monotonic()+150
        while True:
            status=caller.call('session_status')
            snapshot=caller.result(status).get('session',{})
            if snapshot.get('phase')=='ready':break
            require(time.monotonic()<deadline,'native World not ready')
            time.sleep(0.3)
        sid=snapshot['session_id']; gen=snapshot['generation_id']
        require(snapshot.get('native_generation') is not None,'missing native generation')
        first=caller.call('observe',{'region':{'x':28,'y':28,'width':8,'height':8},'detail':'cells'})
        require(not first['isError'],'native first observation failed')
        obs1=result_native(first)['observation_id']
        stale=caller.call('prepare_edit',{'observation_id':obs1,
                'operations':[{'shape':'rectangle','x0':30,'y0':30,'x1':32,'y1':32,'material':58}]})
        require(not stale['isError'],'first prepare failed')
        staleid=result_native(stale)['proposal_id']
        stepped_before=caller.call('step',{'ticks':1})
        require(not stepped_before['isError'],'pre-stale step failed')
        stale_result=caller.call('apply_edit',{'proposal_id':staleid},label='stale-proposal-refused')
        require(stale_result['isError'] and caller.result(stale_result).get('error')=='native_refused_or_unconfirmed',
                'stale pre-step proposal was accepted')
        fresh=caller.call('observe',{'region':{'x':28,'y':28,'width':8,'height':8},'detail':'cells'})
        obs2=result_native(fresh)['observation_id']
        prep=caller.call('prepare_edit',{'observation_id':obs2,
                'operations':[{'shape':'rectangle','x0':30,'y0':30,'x1':32,'y1':32,'material':58}]})
        require(not prep['isError'],'first true edit prepare failed')
        proposal=result_native(prep)['proposal_id']
        request={'proposal_id':proposal,'request_id':'req-mcp-native-first-apply'}
        apply1=caller.call('apply_edit',request)
        require(not apply1['isError'],'first true native apply failed')
        before_duplicate=caller.result(caller.call('session_status'))['session']['commands_submitted']
        duplicate=caller.call('apply_edit',request,label='duplicate-idempotent-apply')
        after_duplicate=caller.result(caller.call('session_status'))['session']['commands_submitted']
        require(caller.result(apply1)['envelope']==caller.result(duplicate)['envelope']
                and before_duplicate==after_duplicate,'duplicate mutation was submitted')
        after=caller.call('observe',{'region':{'x':28,'y':28,'width':8,'height':8},'detail':'cells'})
        walls=result_native(after)['native_counts'].get('58')
        require(walls==9,'nine native Walls not confirmed')
        rev=caller.call('prepare_edit',{'observation_id':result_native(after)['observation_id'],
              'operations':[{'shape':'rectangle','x0':31,'y0':31,'x1':31,'y1':31,'material':0}]})
        require(not rev['isError'],'revision prepare failed')
        apply2=caller.call('apply_edit',{'proposal_id':result_native(rev)['proposal_id']})
        require(not apply2['isError'],'revision apply failed')
        after2=caller.call('observe',{'region':{'x':28,'y':28,'width':8,'height':8},'detail':'cells'})
        walls2=result_native(after2)['native_counts'].get('58')
        require(walls2==8,'readback-driven second edit not confirmed')
        stepped=caller.call('step',{'ticks':4})
        require(not stepped['isError'] and result_native(stepped)['completed']==4,
                'native four-tick Step failed')
        final=caller.call('session_status')
        last=caller.result(final)['session']
        require(last['session_id']==sid and last['generation_id']==gen and
                last['completed_native_ticks_total']==5,'native World/session continuity not proven')
        stopped=caller.call('stop',{'request_id':'req-mcp-native-stop'})
        require(not stopped['isError'] and result_native(stopped)['status']=='stopped',
                'native Stop not acknowledged')
        # The upstream service may retire promptly after native Stop; record either
        # explicit late native refusal or connection gone, never a late success.
        late=caller.call('apply_edit',{'proposal_id':proposal},label='late-command')
        require(late['isError'],'late mutation unexpectedly accepted')
        evidence.update(result='passed',generation_id=gen,native_generation=last['native_generation'],
                transport_session_id=sid,native_ticks=5,walls_first=walls,walls_after_revision=walls2,
                duplicate_mutation_prevented=True,stale_proposal_refused=True,
                unauthorized_missing_and_wrong_401=True,stop_acknowledged=True)
    except Exception as ex:
        evidence.update(result='failed',error_type=type(ex).__name__,error=str(ex)[:500])
        raise
    finally:
        # Failure/success evidence is durable; token content is never serialized.
        (directory/'sanitized-mcp-wire-transcript.json').write_text(
            json.dumps(caller.transcript,indent=2)+'\n',encoding='utf-8')
        evidence['artifacts']={str(p.relative_to(directory)):{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
                                  'bytes':p.stat().st_size} for p in sorted(directory.rglob('*.png'))}
        (directory/'qualification.json').write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({k:v for k,v in evidence.items() if k!='artifacts'},sort_keys=True))

if __name__=='__main__':
    main()
