#!/usr/bin/env python3
"""Reproduce status-versus-diff EOL drift with exact committed Rapier descriptors."""
from pathlib import Path
import hashlib,json,subprocess,tempfile
APP="2743f89a0df6f6afcf7484e859c10790d521e74b"
FILES=["godot/addons/godot-rapier2d/Radial2D.svg.import","godot/addons/godot-rapier2d/icons/Fluid2D.svg.import","godot/addons/godot-rapier2d/icons/StateManager2D.svg.import","godot/addons/godot-rapier2d/logo_square_2d.png.import"]
def command(*args,cwd):
    return subprocess.run(list(args),cwd=cwd,check=True,capture_output=True).stdout
def git(*args,cwd):return command("git",*args,cwd=cwd).decode()
root=Path.cwd(); source={name:command("git","show",APP+":"+name,cwd=root) for name in FILES}
temp=Path(tempfile.mkdtemp(prefix="art-import-eol-exact-",dir="/tmp"))
def g(*args):return git(*args,cwd=temp)
g("init","-q");g("config","user.name","Fixture");g("config","user.email","fixture@example.invalid");g("config","core.autocrlf","true")
(temp/".gitattributes").write_bytes(b"* text=auto\n")
for name,data in source.items():
    target=temp/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
g("add",".");g("commit","-qm","exact committed import descriptors")
def checkout():
    for name in FILES:(temp/name).unlink()
    g("checkout","--",*FILES)
def rewrite():
    for name,data in source.items():(temp/name).write_bytes(data.replace(b"\r\n",b"\n"))
def snapshot(label):
    return {"label":label,"porcelain":g("status","--porcelain=v1","--untracked-files=no"),"diff_names":g("diff","--name-only"),
            "files":{name:{"crlf":(temp/name).read_bytes().count(b"\r\n"),"lf":(temp/name).read_bytes().count(b"\n"),
                          "sha256":hashlib.sha256((temp/name).read_bytes()).hexdigest()} for name in FILES}}
checkout();rows=[snapshot("autocrlf_true_fresh_checkout")];rewrite();rows.append(snapshot("Godot_style_LF_rewrite"))
(temp/".gitattributes").write_bytes(b"* text=auto\n*.import text eol=lf\n");g("add",".gitattributes");g("commit","-qm","explicit LF descriptor contract")
checkout();rows.append(snapshot("explicit_LF_fresh_checkout"));rewrite();rows.append(snapshot("explicit_LF_Godot_style_rewrite"))
assert rows[0]["porcelain"]=="" and rows[0]["diff_names"]==""
assert len(rows[1]["porcelain"].splitlines())==4 and rows[1]["diff_names"]==""
assert rows[2]["porcelain"]==rows[3]["porcelain"]==rows[2]["diff_names"]==rows[3]["diff_names"]==""
print(json.dumps({"format":"cybersand-art-import-eol-mechanism-v1","application_source":APP,"git_version":git("--version",cwd=root).strip(),
                  "source_sha256":{n:hashlib.sha256(b).hexdigest() for n,b in source.items()},"rows":rows,
                  "scope":"Disposable Linux Git repository with core.autocrlf=true; Windows failure had no retained porcelain, so actual-path attribution remains inference."},indent=2,sort_keys=True))
