"""Keyless HTTP fixtures plus the real native UI path. Never calls cloud services."""
import argparse, http.server, json, os, pathlib, subprocess, threading, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        # Assert the actual wire contract, including bearer header (not logged).
        if self.path.endswith("/responses"):
            assert data["max_output_tokens"] in (4096,8192,16384)
            assert "instructions" in data and "input" in data
            assert self.headers["Authorization"] == "Bearer dummy-key-123"
        else:
            assert data["max_tokens"] in (4096,8192,16384)
            assert data["messages"][0]["role"] == "system"
            assert data["messages"][-1]["role"] == "user"
        model = data["model"]
        if model == "slow": time.sleep(2)
        if model in ("rate","hard-quota"):
            code = "insufficient_quota" if model == "hard-quota" else "rate_limit_error"
            raw = json.dumps({"error":{"code":code,"message":"rate limit; dummy-key-123"}}).encode()
            self.send_response(429)
            self.send_header("Retry-After","2")
            self.send_header("Content-Length",str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
            return
        text = '[{"shape":"rectangle","x0":10,"y0":10,"x1":12,"y1":12,"material":58}]'
        if self.path.endswith("/responses"):
            packet = {"model":"deployment-alias","status":"completed","output":[{"content":[{"type":"output_text","text":text}]}],"usage":{"input_tokens":111,"output_tokens":32}}
        else: packet = {"model":"deployment-alias","choices":[{"message":{"content":text},"finish_reason":"stop"}],"usage":{"prompt_tokens":111,"completion_tokens":32}}
        raw = json.dumps(packet).encode()
        self.send_response(200)
        self.send_header("Content-Type","application/json")
        self.send_header("Content-Length",str(len(raw)))
        if model == "reset":
            self.send_header("x-ratelimit-remaining-requests","0")
            self.send_header("x-ratelimit-reset-requests","1m2.5s")
        self.end_headers()
        try: self.wfile.write(raw)
        except (BrokenPipeError,ConnectionResetError): pass

def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--godot",required=True); parser.add_argument("--output",type=pathlib.Path,required=True); parser.add_argument("--graphical",action="store_true"); args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    server=http.server.ThreadingHTTPServer(("127.0.0.1",0),Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True); thread.start()
    try:
        for provider in ("OpenAI","NVIDIA","LM Studio"):
            env=dict(os.environ,WB_ART_TEST_ENDPOINT=f"http://127.0.0.1:{server.server_port}/v1",WB_ART_TEST_MODEL="fixture",WB_ART_TEST_PROVIDER=provider,WB_ART_TEST_IMAGE="1" if args.graphical else "0",WB_ART_EVIDENCE_DIR=str(args.output.resolve()/provider.replace(" ","-")))
            with (args.output/(provider.replace(" ","-")+".log")).open("w",encoding="utf-8") as log:
                subprocess.run((["xvfb-run","-a",args.godot,"--audio-driver","Dummy","--rendering-method","gl_compatibility"] if args.graphical else [args.godot,"--headless"])+["--path",str(ROOT/"godot"),"--script","res://tests/run_art_provider_local.gd"],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
            print(provider,"real HTTP fixture + native UI: passed")
        env=dict(os.environ,WB_ART_TEST_ENDPOINT=f"http://127.0.0.1:{server.server_port}/v1")
        with (args.output/"failures.log").open("w",encoding="utf-8") as log:
            subprocess.run([args.godot,"--headless","--path",str(ROOT/"godot"),"--script","res://tests/run_art_provider_http.gd"],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=60)
        print("HTTP rate error, cancellation and timeout: passed")
    finally: server.shutdown(); server.server_close()
if __name__ == "__main__": main()
