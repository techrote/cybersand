"""Keyless HTTP fixtures plus the real native UI path. Never calls cloud services."""
import argparse, http.server, json, os, pathlib, re, subprocess, sys, threading, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT_ERRORS = re.compile(r"SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:")
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

def godot_command(godot, project, script, graphical):
    command = [str(pathlib.Path(godot).resolve()), "--audio-driver", "Dummy"]
    if graphical:
        command += ["--rendering-method", "gl_compatibility"]
        if sys.platform == "win32":
            command += ["--rendering-driver", "opengl3_angle"]
        elif sys.platform.startswith("linux"):
            command += ["--display-driver", "x11"]
            if not os.environ.get("DISPLAY"):
                command = ["xvfb-run", "--auto-servernum", "--server-args=-screen 0 1920x1080x24 -nolisten tcp"] + command
    else:
        command += ["--headless"]
    return command + ["--path", str(project), "--script", "res://tests/"+script+".gd"]


def run_fixture(command, log_path, env, marker, graphical=False):
    with log_path.open("w",encoding="utf-8") as log:
        result = subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600)
    text = log_path.read_text(encoding="utf-8",errors="replace")
    if result.returncode or SCRIPT_ERRORS.search(text):
        raise RuntimeError(f"Mocked provider fixture failed: {log_path}\n{text[-12000:]}")
    lines = [line[len(marker):].strip() for line in text.splitlines() if line.startswith(marker+" ")]
    if not lines:
        raise RuntimeError("Mocked provider fixture omitted its completion receipt: "+str(log_path))
    if marker == "ART_PROVIDER_RESULT":
        receipt = json.loads(lines[-1])
        if receipt.get("checks",0) < 1 or receipt.get("failures") != 0:
            raise RuntimeError("Mocked provider fixture contains failing or unexecuted checks: "+str(log_path))
        if graphical:
            screenshot = pathlib.Path(env["WB_ART_EVIDENCE_DIR"]) / "provider-ui.png"
            if not screenshot.is_file() or not screenshot.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"):
                raise RuntimeError("Graphical provider fixture produced no native framebuffer: "+str(log_path))
            traffic = pathlib.Path(env["WB_ART_EVIDENCE_DIR"]) / "provider-native-traffic.jsonl"
            if not traffic.is_file() or "data:image/png;base64," not in traffic.read_text(encoding="utf-8"):
                raise RuntimeError("Graphical provider fixture did not transmit its real image observation: "+str(log_path))
    elif not re.fullmatch(r"failures=0",lines[-1]):
        raise RuntimeError("Mocked provider control fixture failed: "+str(log_path))


def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--godot",required=True); parser.add_argument("--output",type=pathlib.Path,required=True); parser.add_argument("--graphical",action="store_true"); parser.add_argument("--project",type=pathlib.Path,default=ROOT/"godot"); args=parser.parse_args()
    args.project = args.project.resolve()
    args.output.mkdir(parents=True,exist_ok=True)
    server=http.server.ThreadingHTTPServer(("127.0.0.1",0),Handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True); thread.start()
    try:
        for provider in ("OpenAI","NVIDIA","LM Studio"):
            env=dict(os.environ,WB_ART_TEST_ENDPOINT=f"http://127.0.0.1:{server.server_port}/v1",WB_ART_TEST_MODEL="fixture",WB_ART_TEST_PROVIDER=provider,WB_ART_TEST_IMAGE="1" if args.graphical else "0",WB_ART_EVIDENCE_DIR=str(args.output.resolve()/provider.replace(" ","-")))
            run_fixture(godot_command(args.godot,args.project,"run_art_provider_local",args.graphical),
                        args.output/(provider.replace(" ","-")+".log"),env,"ART_PROVIDER_RESULT",args.graphical)
            print(provider,"mocked loopback HTTP + actual native UI: passed",flush=True)
        env=dict(os.environ,WB_ART_TEST_ENDPOINT=f"http://127.0.0.1:{server.server_port}/v1")
        run_fixture(godot_command(args.godot,args.project,"run_art_provider_http",False),
                    args.output/"failures.log",env,"ART_PROVIDER_HTTP")
        print("HTTP rate error, cancellation and timeout: passed")
    finally: server.shutdown(); server.server_close()
if __name__ == "__main__": main()
