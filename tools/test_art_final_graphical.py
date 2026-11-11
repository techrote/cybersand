import argparse,pathlib,subprocess,threading,http.server,json,os,hashlib,time
p=argparse.ArgumentParser();p.add_argument('--root',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1]);p.add_argument('--godot',required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
requests=[]
def identity(path):
 path=pathlib.Path(path)
 return {'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
def git(*args):
 return subprocess.check_output(['git',*args],cwd=a.root,text=True).strip()
provenance={'head':git('rev-parse','HEAD'),'tree':git('rev-parse','HEAD^{tree}'),'delta':git('status','--short'),'godot':identity(a.godot),'driver':identity(a.root/'godot/tests/run_art_final_graphical.gd'),'fixture':identity(__file__)}
native=a.root/('godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll' if os.name=='nt' else 'godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so')
provenance['native']=identity(native)
(a.output/'provenance.json').write_text(json.dumps(provenance,indent=2))
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_POST(self):
  body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  requests.append({'path':self.path,'body':body})
  user=str((body.get('input') or body.get('messages'))[-1]['content'])
  if 'SMOKE_INITIAL' in user:
   ops=[{'shape':'polygon','points':[[8,8],[1010,8],[1010,1010],[8,1010]],'material':58},{'shape':'airbrush','x':512,'y':512,'radius':490,'density':.6,'hardness':.3,'seed':17,'material':0}]
  elif 'SMOKE_LOCAL' in user:
   ops=[{'shape':'polygon','points':[[8,8],[220,8],[220,350],[8,350]],'material':58},{'shape':'airbrush','x':355,'y':355,'radius':130,'density':.7,'seed':21,'material':58}]
  elif 'SMOKE_WORLD' in user:
   ops=[{'shape':'polygon','points':[[1208,758],[1410,758],[1410,990],[1208,990]],'material':58},{'shape':'airbrush','x':1600,'y':875,'radius':100,'density':.65,'seed':42,'material':58}]
  else: ops=[{'shape':'rectangle','x0':1000,'y0':1000,'x1':1001,'y1':1001,'material':58}]
  text=json.dumps(ops)
  if self.path.endswith('/responses'):
   packet={'model':'fixture-world','status':'completed','output':[{'content':[{'type':'output_text','text':text}]}],'usage':{'input_tokens':400,'output_tokens':200}}
  else:packet={'model':'fixture-local','choices':[{'finish_reason':'stop','message':{'content':text}}],'usage':{'prompt_tokens':400,'completion_tokens':200}}
  raw=json.dumps(packet).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
s=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=s.serve_forever,daemon=True).start()
env=dict(os.environ,APPDATA=str(a.output.resolve()/'isolated-appdata'),XDG_DATA_HOME=str(a.output.resolve()/'isolated-appdata'),WB_ART_TEST_ENDPOINT=f'http://127.0.0.1:{s.server_port}/v1',WB_ART_EVIDENCE_DIR=str(a.output.resolve()))
render_args=['--rendering-driver','opengl3_angle'] if os.name=='nt' else ['--display-driver','x11']
try:
 with (a.output/'godot.log').open('w',encoding='utf8') as log:
  run=subprocess.run([a.godot,'--path',str(a.root/'godot'),'--rendering-method','gl_compatibility']+render_args+['--position','0,0','--script','res://tests/run_art_final_graphical.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240)
finally:s.shutdown();s.server_close()
(a.output/'fixture-requests.json').write_text(json.dumps(requests,indent=2))
assert len(requests)==4,('request count',len(requests))
for i in (1,2):
 b=requests[i]['body']; text=json.dumps(b);assert 'SMOKE_INITIAL' in text and 'Canvas result' in text and '"role": "assistant"' in text,('history',i)
 if i==1:assert 'Coordinates are LOCAL' in text and '512,512' in text, 'local area'
 else:assert 'Work area XYWH=[1200,750,512,256]' in text,'world area'
(a.output/'hashes.json').write_text(json.dumps({str(f.relative_to(a.output)):hashlib.sha256(f.read_bytes()).hexdigest() for f in a.output.iterdir() if f.is_file()},indent=2))
print('GRAPHICAL_SMOKE',run.returncode,'requests',len(requests))
raise SystemExit(run.returncode)
