"""Adversarial readback of an actual retained process trace (no timing mock)."""
import copy
import json
from pathlib import Path
import sys
from render_publication_campaign import reduce_trace

def main():
    original=json.loads(Path(sys.argv[1]).read_text())
    reduce_trace(original)
    controls=[]
    def rejects(name, mutation):
        altered=copy.deepcopy(original)
        mutation(altered)
        try: reduce_trace(altered)
        except (ValueError,KeyError): controls.append(name); return
        raise RuntimeError("reader accepted corrupt evidence: " + name)
    rejects("truncated",lambda d:d.update(dropped=1))
    rejects("engine-failed",lambda d:d.update(failures=1))
    rejects("counter-erased",lambda d:d["counts"].update(refresh=0))
    rejects("counter-kind-missing",lambda d:d["counts"].pop("refresh"))
    rejects("reset-full-missing",lambda d:next(e for e in d["events"] if e["event"]=="native_end").update(complete_full=False))
    rejects("generation-missing",lambda d:[e.update(generation=1) for e in d["events"] if e["event"]=="native_end"])
    rejects("operation-identity",lambda d:next(e for e in d["events"] if e["event"]=="patch_end").update(serial=-1))
    rejects("negative-native-duration",lambda d:next(e for e in d["events"] if e["event"]=="native_end").update(duration_usec=-1))
    rejects("native-call-three",lambda d:next(e for e in d["events"] if e["event"]=="native_end").update(call=3))
    rejects("native-call-unpaired",lambda d:next(e for e in d["events"] if e["event"]=="native_begin").update(refresh=-1))
    rejects("publication-missing",lambda d:next(e for e in d["events"] if e["event"]=="owner_end").update(refresh=-1))
    if "candidate" in original:
        rejects("CPU-native-parity",lambda d:d.update(final_cpu_native_equal=False))
        rejects("texture-CPU-parity",lambda d:d.update(final_texture_image_equal=False))
        rejects("wrong-owner",lambda d:d.update(owner_script="res://wrong.gd"))
        if original["candidate"]=="E": rejects("pending-bound",lambda d:d.update(pending_high_water=4194305))
    ack_kind="ack_issue" if original["arm"]=="N" else "ack_withheld"
    rejects("ack-before-upload",lambda d:next(e for e in d["events"] if e["event"]==ack_kind).update(usec=0))
    if any(e["event"]=="forced_retry" for e in original["events"]):
        rejects("overflow-cause-missing",lambda d:[e.update(byte_overflow=False) for e in d["events"] if e["event"]=="dirty_onto_full"])
    if original["arm"]=="N":
        rejects("ack-clear-without-cover",lambda d:next(e for e in d["events"] if e["event"]=="ack_clear").update(ack_serial=-1))
    print(json.dumps({"status":"passed","positive":"retained actual graphical trace","negative_controls":controls}))

if __name__=="__main__": main()
