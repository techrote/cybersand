"""Fail-closed controls for a real local diagnostic runtime manifest."""
from pathlib import Path
import argparse
import copy
import json
from render_publication_campaign import source_identity

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--engine",required=True,type=Path)
    parser.add_argument("--manifest",required=True,type=Path)
    parser.add_argument("--output",required=True,type=Path)
    args=parser.parse_args()
    args.output.mkdir(exist_ok=False)
    original=json.loads(args.manifest.read_text())
    source_identity(args.engine,args.manifest)
    controls=[]
    def reject(name,mutation):
        altered=copy.deepcopy(original)
        mutation(altered)
        path=args.output/(name+".json")
        path.write_text(json.dumps(altered,indent=2))
        try: source_identity(args.engine,path)
        except ValueError: controls.append(name); return
        raise RuntimeError("accepted invalid runtime identity: " + name)
    reject("wrong-platform-library",lambda d:d.update(artifact="godot/addons/cybersand_native/bin/wrong.dll"))
    reject("missing-native-input",lambda d:d["source_inputs"].pop(next(iter(d["source_inputs"]))))
    reject("extra-native-input",lambda d:d["source_inputs"].update({"unregistered.cpp":"0"*64}))
    reject("mismatched-native-input",lambda d:d["source_inputs"].update({next(iter(d["source_inputs"])):"0"*64}))
    reject("wrong-runtime-bytes",lambda d:d.update(sha256="0"*64))
    result={"status":"passed","positive":"actual installed runtime and all native source inputs","negative_controls":controls}
    (args.output/"result.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result))

if __name__=="__main__": main()
