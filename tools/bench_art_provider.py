"""Repeat local art prompts through actual UI/native/rendering. Optional WSL->Windows loopback relay is test-only."""
import argparse, http.server, json, os, pathlib, subprocess, sys, threading, urllib.request, urllib.error
ROOT=pathlib.Path(__file__).resolve().parents[1]
PROMPT="draw a detailed gundam mech style cyberpunk statue"
def forward():
    body=sys.stdin.buffer.read()
    try:
        with urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:1234/v1/chat/completions",body,{"Content-Type":"application/json"}),timeout=180) as response:
            result={"code":response.status,"body":response.read().decode()}
    except urllib.error.HTTPError as exc: result={"code":exc.code,"body":exc.read().decode()}
    except Exception as exc: result={"code":502,"body":json.dumps({"error":str(exc)})}
    print(json.dumps(result,ensure_ascii=True))
class Relay(http.server.BaseHTTPRequestHandler):
    python=None
    def log_message(self,*args): pass
    def do_POST(self):
        body=self.rfile.read(int(self.headers["Content-Length"]))
        result=subprocess.run([self.python,"tools/bench_art_provider.py","--forward"],input=body,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=190,check=True)
        response=json.loads(result.stdout); raw=response["body"].encode()
        self.send_response(response["code"]);self.send_header("Content-Type","application/json");self.send_header("Content-Length",str(len(raw)));self.end_headers()
        try:self.wfile.write(raw)
        except (BrokenPipeError,ConnectionResetError):pass

def main():
    parser=argparse.ArgumentParser();parser.add_argument("--forward",action="store_true");parser.add_argument("--godot");parser.add_argument("--output",type=pathlib.Path);parser.add_argument("--windows-python");args=parser.parse_args()
    if args.forward:forward();return
    assert args.godot and args.output
    args.output.mkdir(parents=True,exist_ok=True)
    server=None
    endpoint="http://127.0.0.1:1234/v1"
    if args.windows_python:
        Relay.python=args.windows_python;server=http.server.ThreadingHTTPServer(("127.0.0.1",0),Relay);threading.Thread(target=server.serve_forever,daemon=True).start();endpoint=f"http://127.0.0.1:{server.server_port}/v1"
    try:
        for model in ["wb-art-instruct","wb-art-local","wb-art-vision"]:
            for repeat in range(1,4):
                folder=args.output.resolve()/model/str(repeat);folder.mkdir(parents=True,exist_ok=True)
                env=dict(os.environ,WB_ART_TEST_ENDPOINT=endpoint,WB_ART_TEST_MODEL=model,WB_ART_EVIDENCE_DIR=str(folder),WB_ART_BENCH_PROMPT=PROMPT)
                command=["xvfb-run","-a",args.godot,"--audio-driver","Dummy","--rendering-method","gl_compatibility","--path",str(ROOT/"godot"),"--script","res://tests/run_art_provider_benchmark.gd"]
                with (folder/"native.log").open("w",encoding="utf-8") as log: subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300,check=True)
                print(model,repeat,"completed",flush=True)
    finally:
        if server:server.shutdown();server.server_close()
if __name__=="__main__":main()
