"""Read-only audit of the frozen M6/M7 qualification-history delivery.

The eight original Actions archive identities below were retained before this
history ZIP was made. No nested archive is rewritten or unpacked into a profile.
"""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import io
import json
import stat
import zipfile

EXPECTED_SOURCE = {
    45506178712: "fc8194c00294d54a0e148aa933ccfb57ce194c6e",
    45512988153: "d948deab5d280adfe1e890bddf85725b2efd59bc",
    45520561849: "17c6b5b35049b7b2541c2deeea23c02fd1e2fc5d",
}
EXPECTED = [
    (45506178712,14974993415,"linux",26206036,"a42ce8cf66e85d8b440d6ae6281e2635ba58a8f3a1c63eb966f20f611b7a39f3"),
    (45506178712,14974697855,"windows",22544923,"4ad0e55840c858dbc738cdeca003d4cfc0dff2d0df08ae1838d5bc14a5a58a68"),
    (45512988153,14977921869,"linux",26224529,"8e315e6d34b7b9fc9404f088c7d5aeb342eb90dc1d48694c62caca700e925d82"),
    (45512988153,14979431856,"windows",24721624,"41d3c5882a363a93a77f4d120482d6f43231486dcb786d4cdfc84e1b4b07da64"),
    (45520561849,14981408538,"linux",26226147,"2d2c94c44629d9a87a322d3834ad5dd327d91467aacfdb696dcf32b92b658146"),
    (45520561849,14983835743,"windows",48540546,"6117b1cce68461c267b0df1f11c98d9efa4e557abac2acafa505fab1dd043ea0"),
    (45520561849,14978269731,"windows-runtime",2106710,"ad2ca41bfb8111a17fe20e21d6dd133fa43a81da02957b1ac9de03e412d6d3ad"),
    (45520561849,14980481166,"windows-build",8230,"b4375848209601366a66670d2f613f9e0c58b799eee51b7f03095eb4deec4c4a"),
]
REVIEWS = {
    "owner-evaluator-custody-a.json":"dee0c05bc91edea3e65f16c642a6f0e831aa0ae9806f8f01695aea5c7edfab42",
    "source-platform-text-review-a.json":"5b848e3c3fc3dcf7d6fcd60d045f0f8b3373db37f129ba9c4a8c265bfc7caa2d",
    "source-extracted-owner-pairing-a.json":"d80c36f10747ba31cc41a001cf9ef3fcbe3efb76c014c536adf6f5ab92c85fea",
    "windows-runtime-custody-a.json":"170d95f6d956a7eb245e96b4bc5c30e7f81e67257eff42c7749f1e2a027d13da",
    "linux-catalogue-review-a.json":"1ab6814879e15d538a6f7beef15ac7ce19b06a7043273cad281bed84eceded3c",
    "windows-catalogue-review-a.json":"86831e972d7c697e692a008296277e673743469eb8b1381a51be51f2daaec812",
    "linux-hierarchy-review-a.json":"20ea74f6e5c4b400dbe37ff14c3f3c424f2ba3232fb4a66b5098c1c72ed62ec0",
    "windows-hierarchy-review-a.json":"f8d36992c653f1f6d3b628a3dc3cbcb30ed6d9d660704b214c23bac1064fb512",
    "windows-extracted-hierarchy-review-a.json":"96c7051c147de00862c157156f33ef795f3c583a6535ef72ebcdaf493cdc9bb6",
    "catalogue-visual-binding-review-a.json":"db619a1cf45f7fdfaef6e858447c849841e61eec53a96355f8c9a87f52d4b1b0",
    "final-artifact-handoff-a.json":"9926b4ce64b5d39a06ea7a4598431bac70f853c00315c36a527bdbdc8b98baa7",
    "windows-outcomes-review-c.json":"5477d5c9d85d97445add0007ed5a03f2c3b501166a41529ad1809da71af40c9a",
}
DLL = "dd2b1a9e0c2bc58a8bd31b7e7e25d67bf93c04b8c57ea6553a358874af76b36d"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def verify(path):
    with path.open("rb") as stream:
        archive_sha = hashlib.file_digest(stream, "sha256").hexdigest()
    assert path.stat().st_size == 177055307
    assert archive_sha == "0b83d4e29fe3c952233362923cdaaab321272d74306fa6014664b0b7f656cbaf"
    observations = []
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        assert len(names) == len(set(names)) == len({n.casefold() for n in names})
        for entry in archive.infolist():
            assert not entry.is_dir() and not stat.S_ISLNK(entry.external_attr >> 16)
            assert not entry.filename.startswith("/") and "\\" not in entry.filename and ":" not in entry.filename
            assert ".." not in PurePosixPath(entry.filename).parts
        manifest_raw = archive.read("MANIFEST.json")
        manifest_sha = sha(manifest_raw)
        assert manifest_sha == "f04872b24c75cfc834ec487439dfd2287e354fdaaeeecb196fb29366ac008546"
        manifest = json.loads(manifest_raw)
        assert manifest["final_application"] == EXPECTED_SOURCE[45520561849]
        assert manifest["file_count"] == len(manifest["files"]) == 67
        assert manifest["original_artifact_count"] == len(manifest["original_artifacts"]) == 8
        rows = {row["path"]:row for row in manifest["files"]}
        assert len(rows) == 67 and set(rows) | {"MANIFEST.json"} == set(names)
        # Reading every complete member also validates its ZIP CRC.
        for name,row in rows.items():
            assert archive.getinfo(name).file_size == row["bytes"]
            with archive.open(name) as stream:
                assert hashlib.file_digest(stream,"sha256").hexdigest() == row["sha256"], name
        originals = {row["path"]:row for row in manifest["original_artifacts"]}
        expected_names = {f"original-actions/{run}/{artifact}-{platform}.zip" for run,artifact,platform,_,_ in EXPECTED}
        assert set(originals) == expected_names
        assert {n for n in names if n.startswith("original-actions/")} == expected_names
        for run,artifact,platform,size,digest in EXPECTED:
            name = f"original-actions/{run}/{artifact}-{platform}.zip"
            row = originals[name]
            assert row["run"] == run and row["artifact"] == artifact and row["platform"] == platform
            assert row["bytes"] == size and row["sha256"] == digest
            assert row["application_source"] == EXPECTED_SOURCE[run]
            assert rows[name]["kind"] == "original-github-actions-zip"
            assert all(rows[name][key] == row[key] for key in row)
            data = archive.read(name)
            assert len(data) == size and sha(data) == digest
            with zipfile.ZipFile(io.BytesIO(data)) as nested:
                if platform in ("linux","windows"):
                    report = json.loads(nested.read("application/qualification.json"))
                    assert report["source_commit"] == EXPECTED_SOURCE[run]
                    expected_status = "failed" if run == 45506178712 and platform == "windows" else "passed"
                    assert report["status"] == expected_status
                    if expected_status == "passed":
                        assert len(report["results"]) == 89 and all(r["status"] == "passed" for r in report["results"])
                    observed = {"path":name,"source_commit":report["source_commit"],"source_status":report["status"],"source_process_groups":len(report["results"])}
                    if platform == "windows" and run in (45512988153,45520561849):
                        extracted=json.loads(nested.read("extracted-evaluator/qualification.json"))
                        assert extracted["source_commit"] == EXPECTED_SOURCE[run]
                        expected_extracted="failed" if run==45512988153 else "passed"
                        assert extracted["status"]==expected_extracted
                        assert len(extracted["results"])==(1 if expected_extracted=="failed" else 72)
                        observed.update(extracted_status=extracted["status"],extracted_process_groups=len(extracted["results"]))
                    observations.append(observed)
                elif platform == "windows-runtime":
                    provenance=json.loads(nested.read("candidate-provenance.json"))
                    assert provenance["source_commit"]==provenance["build_commit"]==EXPECTED_SOURCE[run]
                    assert provenance["source_tree"]=="ea59a4a95d647c58820c943d37dd14e3d760b2f8"
                    assert len(provenance["source_inputs"])==105 and provenance["sha256"]==DLL
                    dll=nested.read("cybersand_native.windows.x86_64.dll")
                    assert dll[:2]==b"MZ" and len(dll)==5820416 and sha(dll)==DLL
                    observations.append({"path":name,"source_commit":provenance["source_commit"],"native_sha256":DLL,"native_inputs":105})
                else:
                    build=json.loads(nested.read("build-native.log"))
                    assert build["source_commit"]==EXPECTED_SOURCE[run] and build["returncode"]==0
                    assert build["runtime_sha256"]==DLL
                    observations.append({"path":name,**build})
        for name,digest in REVIEWS.items():
            member="independent-reviews/45520561849/"+name
            assert member in rows and rows[member]["sha256"]==digest
        for name in ("final-hosted-science-review-b.json","final-hosted-science-review-b.md","final-windows-review-c.json","final-windows-review-c.md","final-campaign-api-status.json","windows-job-138893152369.log"):
            assert "independent-reviews/45520561849/"+name in rows
        nonoriginal = set(rows)-expected_names
        forbidden_components={"fresh-userdata","profiles","profile","user-data","userdata",".godot",".git"}
        for name in nonoriginal:
            p=PurePosixPath(name)
            assert name.startswith(("independent-reviews/","supplementary/"))
            assert p.suffix in {".json",".md",".log"}
            assert not forbidden_components.intersection(p.parts)
        return {"schema":"cybersand-independent-qualification-history-review-a-v1","status":"PASS",
            "archive":str(path),"archive_bytes":path.stat().st_size,"archive_sha256":archive_sha,
            "manifest_sha256":manifest_sha,"manifested_payload_files":67,"total_regular_members":68,
            "original_actions_archives":8,"original_actions_bytes":sum(row[3] for row in EXPECTED),
            "original_source_outcomes":observations,"independently_pinned_review_files":len(REVIEWS),
            "all_payload_sha256_and_crc_verified":True,"safe_unique_casefold_paths":True,
            "extra_unlisted_payload":False,"user_profiles_outside_original_actions":False,
            "code_checkpoint_bundles_outside_original_actions":False,"portable_evaluator_repacked_here":False,
            "scope":"Read-only manifest, retained original API digest/size and source-report audit. Original eight Actions ZIPs are byte-identical; both earlier failures and final pass remain distinct. Raw profiles within the original immutable Actions outputs are neither extracted nor rewritten. Source code, checkpoint bundle, development archive and owner evaluator remain separate deliverables. No application execution or physical owner acceptance."}


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive",type=Path)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args();report=verify(args.archive)
    args.output.write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps({"status":report["status"],"report":str(args.output),"report_sha256":sha(args.output.read_bytes()),"original_archives":8,"payload_files":67},indent=2))
