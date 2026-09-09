"""Loopback-only Web fixture host and bounded, write-once result collector."""
import argparse
import functools
import http.server
import json
from pathlib import Path

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy","same-origin")
        self.send_header("Cross-Origin-Embedder-Policy","require-corp")
        self.send_header("Cache-Control","no-store")
        super().end_headers()

    def do_POST(self):
        if self.path!="/physics-results":self.send_error(404);return
        try:
            length=int(self.headers.get("Content-Length","0"))
            if length<1 or length>8*1024*1024:self.send_error(413);return
            data=self.rfile.read(length)
            decoded=json.loads(data)
            if not isinstance(decoded.get("result",{}).get("results"),list):raise ValueError("missing result array")
            with self.server.result_file.open("xb") as output:output.write(data)
            self.send_response(201);self.end_headers();self.wfile.write(b"saved")
        except FileExistsError:self.send_error(409,"Evidence already saved; choose a new output directory")
        except (ValueError,OSError):self.send_error(400)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--port",type=int,required=True)
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    server=http.server.ThreadingHTTPServer(("127.0.0.1",args.port),functools.partial(Handler,directory=str(args.directory.resolve())))
    server.result_file=args.output.resolve()/"browser-result.json"
    server.serve_forever()

if __name__=="__main__":main()
