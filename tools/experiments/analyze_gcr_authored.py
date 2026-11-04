"""Authenticate and reduce the registered authored-compound C/E/S captures.

Incomplete acquisitions remain incomplete. Observed-prefix checks and physical
carry/spill outcomes are reported separately from source/current-head custody.
No whole-body energy/passivity claim is inferred from the passive solver ledger.
"""
import argparse
import hashlib
import io
import json
import math
import statistics
import subprocess
import tarfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
REG = "GCR-AUTHORED-001"
PROTOCOL = "docs/audits/gcr-authored-2026-11-04/protocol.json"
DEFINITION = "godot/authoring/flyers/scooper.json"
FROZEN_DEFINITION_SOURCE = "6015cd3753bcb7929e3fa576e42d39304fcbe0c3"
# Actual Godot4.7 JSON.stringify(raw,"",true,true) content identity for the
# frozen definition. Its complete file is authenticated against Git below;
# Python's ordinary float serializer is deliberately not substituted for Godot.
DEFINITION_HASH = "cf1857b65f5421e64bcf914c8dd7e6440d4c0bab5ed8aa0c917c113f9748d6ae"
RESPONSES = ("LA", "LA-EVENT-OFF", "LA-SELECTIVE")
PLATFORMS = ("windows", "linux")
CODE = {".gd", ".tscn", ".tres", ".gdshader", ".gdextension", ".json"}
NATIVE = {".h", ".hpp", ".c", ".cpp", ".inc"}
ARCHIVES = {}


class EvidenceError(RuntimeError):
    pass


def require(value, reason):
    if not value:
        raise EvidenceError(reason)


def digest(value):
    return hashlib.sha256(value).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"),
                      parse_constant=lambda value: (_ for _ in ()).throw(EvidenceError("Nonfinite JSON: " + value)))


def finite(value):
    if isinstance(value, float):
        require(math.isfinite(value), "Nonfinite observation")
    elif isinstance(value, dict):
        for item in value.values():
            finite(item)
    elif isinstance(value, list):
        for item in value:
            finite(item)


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def integer(value):
    return number(value) and int(value) == value


def same(actual, expected, tolerance=1e-12):
    if type(expected) is bool:
        return type(actual) is bool and actual == expected
    if number(expected):
        return number(actual) and abs(actual - expected) <= tolerance
    if isinstance(expected, dict):
        return isinstance(actual, dict) and actual.keys() == expected.keys() and all(same(actual[k], v, tolerance) for k, v in expected.items())
    if isinstance(expected, list):
        return isinstance(actual, list) and len(actual) == len(expected) and all(same(a, b, tolerance) for a, b in zip(actual, expected))
    return type(actual) is type(expected) and actual == expected


def norm(value):
    require(isinstance(value, list) and len(value) == 2 and all(number(x) for x in value), "Missing two-component vector")
    return math.hypot(*value)


def percentile(values, p):
    if not values:
        return None
    values = sorted(values)
    position = (len(values) - 1) * p
    low = math.floor(position)
    high = math.ceil(position)
    return values[low] + (values[high] - values[low]) * (position - low)


def distribution(values):
    return {"p50": percentile(values, .5), "p95": percentile(values, .95),
            "p99": percentile(values, .99), "max": max(values) if values else None}


def archived(source):
    if source not in ARCHIVES:
        require(isinstance(source, str) and len(source) == 40 and all(c in "0123456789abcdef" for c in source), "Invalid source SHA")
        paths = ["godot", "native/src", "native/include"]
        if subprocess.run(["git", "-C", str(ROOT), "cat-file", "-e", source+":"+PROTOCOL], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60).returncode == 0:
            paths.append(PROTOCOL)
        command = ["git", "-C", str(ROOT), "archive", "--format=tar", source, "--", *paths]
        try:
            payload = subprocess.check_output(command, timeout=60)
        except subprocess.SubprocessError as exc:
            raise EvidenceError("Cannot authenticate retained Git source " + source) from exc
        hashes, retained = {}, {}
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:") as archive:
            for member in archive:
                if not member.isfile():
                    continue
                path = PurePosixPath(member.name)
                relevant = (str(path).startswith("godot/") and (path.suffix in CODE or path.name == "project.godot")) or path.suffix in NATIVE or str(path) == PROTOCOL
                if relevant:
                    data = archive.extractfile(member).read().replace(b"\r\n", b"\n")
                    hashes[str(path)] = digest(data)
                    if str(path) in (DEFINITION, PROTOCOL):
                        retained[str(path)] = data
        ARCHIVES[source] = {"hashes": hashes, "retained": retained}
    return ARCHIVES[source]


def bundle_path(root, path):
    name = PurePosixPath(path)
    require(not name.is_absolute() and ".." not in name.parts and "\\" not in path, "Unsafe evidence path")
    return root.joinpath(*name.parts)


def verify_source_map(actual, expected, label):
    require(isinstance(actual,dict) and actual.keys()==expected.keys(),label+" input key-set mismatch")
    require(actual==expected,label+" input hash mismatch")


def source_scope(archive, native=False):
    prefixes=("native/src/","native/include/","godot/native_extension/")
    return {name:value for name,value in archive["hashes"].items()
            if (name.startswith(prefixes) and PurePosixPath(name).suffix in NATIVE if native else
                name.startswith("godot/") and ".godot" not in PurePosixPath(name).parts and
                (PurePosixPath(name).suffix in CODE or PurePosixPath(name).name=="project.godot"))}


def material_quantity(census):
    require(isinstance(census, dict) and isinstance(census.get("counts"), list) and isinstance(census.get("sum_y"), list), "Missing native census")
    require(len(census["counts"]) == len(census["sum_y"]) and all(integer(v) and v >= 0 for v in census["counts"]), "Malformed native census")
    require(integer(census.get("water_mass")) and census["water_mass"] >= 0, "Malformed Water quantity")
    return census["counts"], census["water_mass"]


def conserved(before, after, material, inserted):
    a, water_a = material_quantity(before)
    b, water_b = material_quantity(after)
    require(len(a) == len(b) and 0 <= material < len(a) and integer(inserted) and inserted >= 0, "Census/addition schema mismatch")
    expected = list(a)
    expected[material] += inserted
    return water_a == water_b and all(expected[i] == b[i] for i in range(len(a)) if i not in (0, 3))


def centroid(census, material):
    material_quantity(census)
    count = census["counts"][material]
    return census["sum_y"][material] / count if count else None


def state_metrics(rows, initial):
    if not rows:
        return None
    states = [r["state"] for r in rows]
    tail = states[-120:]
    xs = [s["position"][0] for s in states]
    ys = [s["position"][1] for s in states]
    angles = [states[0]["rotation"]]
    for previous, current in zip(states, states[1:]):
        delta = current["rotation"] - previous["rotation"]
        angles.append(angles[-1] + math.atan2(math.sin(delta), math.cos(delta)))
    return {"final": states[-1], "net_translation": [states[-1]["position"][i] - initial["position"][i] for i in (0, 1)],
            "position_span": [max(xs) - min(xs), max(ys) - min(ys)],
            "angle_unwrapped_span": max(angles) - min(angles),
            "peak_upward_speed": max(0, -min(s["velocity"][1] for s in states)),
            "peak_downward_speed": max(0, max(s["velocity"][1] for s in states)),
            "tail_observed_rows": len(tail),
            "tail_abs_vertical_velocity": distribution([abs(s["velocity"][1]) for s in tail]),
            "tail_abs_omega": distribution([abs(s["omega"]) for s in tail]),
            "tail_centre_span": [max(s["position"][i] for s in tail) - min(s["position"][i] for s in tail) for i in (0, 1)]}


def carry_gate(raw, gate):
    rows = raw.get("rows", [])
    samples = [r for r in rows if "cavity_count" in r]
    initial_count = raw["before"]["counts"][int(raw["case"]["material"])]
    initial_y = raw["initial"]["position"][1]
    initial_primary = samples[0]["cavity_count"] if samples else None
    zeros = [r["tick"] for r in samples if r["cavity_count"] == 0]
    lift = [r for r in samples if r["tick"] < gate["tip_start"] and r["cavity_count"] >= gate["min_retained"] and initial_y - r["state"]["position"][1] >= gate["rise_cells"]]
    before_tip = [r for r in samples if r["tick"] < gate["tip_start"]]
    start = next((r for r in samples if r["tick"] == gate["tip_start"]), None)
    released = [] if start is None or start["cavity_count"] <= 0 else [r for r in samples if gate["tip_start"] <= r["tick"] <= gate["tip_deadline"] and r["cavity_count"] <= start["cavity_count"] * (1 - gate["release_fraction"])]
    complete_tip = bool(rows and rows[-1]["tick"] >= gate["tip_deadline"])
    lift_ok = initial_count == gate["initial_grains"] and bool(lift)
    spill_ok = bool(start and start["cavity_count"] > 0 and released and complete_tip)
    return {"initial_native_material_count": initial_count, "initial_primary_cavity_count": initial_primary,
            "primary_zero_ticks": zeros, "primary_zero_before_tip": [tick for tick in zeros if tick < gate["tip_start"]],
            "observed_uninterrupted_primary_load_before_tip": bool(before_tip) and all(r["cavity_count"] >= gate["min_retained"] for r in before_tip),
            "minimum_primary_before_tip": min((r["cavity_count"] for r in before_tip), default=None),
            "first_lift_tick": lift[0]["tick"] if lift else None,
            "maximum_rise_with_at_least_minimum_load": max((initial_y - r["state"]["position"][1] for r in before_tip if r["cavity_count"] >= gate["min_retained"]), default=None),
            "tip_start_primary_load": start["cavity_count"] if start else None,
            "first_half_release_tick": released[0]["tick"] if released else None,
            "observed_tip_window_complete": complete_tip, "lift_gate_pass": lift_ok,
            "spill_gate_pass": spill_ok, "registered_demonstration_pass": lift_ok and spill_ok,
            "interpretation": "Primary counts use post-step material and current body pose; sample-pose counts are auxiliary only. Zero load is not a vacuous spill pass."}


def reduce_capture(raw, spec, response, context, receipt):
    finite(raw)
    require(raw.get("registration") == REG and same(raw.get("case"), spec) and raw.get("response") == response, "Fixture/response mismatch")
    require(raw.get("platform") == ("Windows" if context["platform"] == "windows" else "Linux"), "Platform mismatch")
    identity = raw.get("identity", {})
    for key, value in {"source": context["source"], "inputs": context["inputs_hash"], "protocol_sha256": context["protocol_sha256"], "native_sha256": context["native_sha256"], "definition_hash": DEFINITION_HASH, "physics_backend": "Rapier2D"}.items():
        require(identity.get(key) == value, "Capture identity mismatch: " + key)
    require(str(identity.get("engine_version", "")).startswith("4.7"), "Unexpected captured engine")
    expected_options = {"response": response, "budget": 20., "mass_multiplier": 1., "inertia_multiplier": 1., "thrust_multiplier": 1., "torque_multiplier": 1., "boost_multiplier": 2.}
    require(same(raw.get("options"), expected_options), "Registered physical/actuator options differ")
    require(number(raw.get("mass")) and abs(raw["mass"] - .18) <= 1e-6 and number(raw.get("inertia")) and abs(raw["inertia"] - 22.099868512110724) <= 1e-5, "Registered actual mass/inertia differ")
    rows = raw.get("rows", [])
    require(isinstance(rows, list) and [r.get("tick") for r in rows] == list(range(len(rows))) and len(rows) <= spec["ticks"], "Noncontiguous/oversized observation prefix")
    violations = []
    def check(ok, reason, tick=None):
        if not ok and len(violations) < 32:
            violations.append({"tick": tick, "reason": reason})
    seen = set()
    for row in rows:
        tick, g, app = row["tick"], row["gcr"], row["application"]
        bodies = app.get("bodies", [])
        check(g.get("proxy_count") == 6 and g.get("physical_body_id") == 1, "One body/six proxies", tick)
        check(row.get("observed_steps") == [1, 1], "Native/Rapier step count", tick)
        check(row.get("observed_response_counts") in ([1, 0], [1, 1]) and row.get("physical_wrench_applications") in (0, 1), "One response/at most one nonzero wrench", tick)
        check(app.get("accepted") is True and len(bodies) == 1, "Accepted one-body application", tick)
        if len(bodies) == 1:
            body = bodies[0]
            key = (body.get("session"), body.get("index"), body.get("sample"))
            check(integer(body.get("session")) and body["session"]>=1 and body.get("index")==0 and integer(body.get("sample")) and 0<=body["sample"]<1_000_000 and integer(g.get("session_id")) and g["session_id"]==body["session"], "Typed physical sample/session identity", tick)
            check(body.get("age") == 0 and key not in seen and body.get("sample") == g.get("sample_serial"), "Fresh unique sample", tick)
            seen.add(key)
            check(body.get("physical_wrench_applications") == row.get("physical_wrench_applications"), "Wrench counter closure", tick)
        check(number(g.get("normal_accepted")) and number(g.get("event_budget_cost")) and number(g.get("global_capacity")) and g["normal_accepted"] >= -1e-8 and g["event_budget_cost"] >= -1e-8 and g["normal_accepted"] + g["event_budget_cost"] <= g["global_capacity"] + 1e-8, "Shared normal/event budget", tick)
        check(number(g.get("energy_before")) and number(g.get("energy_after")) and g["energy_after"] <= g["energy_before"] + 1e-8 * max(1, g["energy_before"]), "Passive solver energy", tick)
        check(integer(g.get("nodes")) and 0 <= g["nodes"] <= 96 and integer(g.get("updates")) and 0 <= g["updates"] <= 768, "Six-shape bounded solve work", tick)
        check(abs(g.get("mass", -1) - raw["mass"]) <= 1e-12 and abs(g.get("inertia", -1) - raw["inertia"]) <= 1e-12, "One actual mass/inertia", tick)
        if spec["id"] in ("water", "hard"):
            check(abs(g.get("normal_accepted", math.inf)) <= 1e-12, "Negative control zero granular bearing", tick)
        if response=="LA-EVENT-OFF":
            check(norm(g.get("event_accepted"))<=1e-12 and abs(g.get("event_torque",math.inf))<=1e-12 and abs(g.get("event_budget_cost",math.inf))<=1e-12,"Events-off admitted event channel is zero",tick)
        if response=="LA-SELECTIVE" and g.get("arrival_count")==0:
            check(norm(g.get("event_accepted"))<=1e-12 and abs(g.get("event_torque",math.inf))<=1e-12 and abs(g.get("event_budget_cost",math.inf))<=1e-12,"Selective event wrench requires an arrival witness",tick)
        if "granular_events" in g:
            check(g["granular_events"]=={"LA":"control","LA-EVENT-OFF":"off","LA-SELECTIVE":"selective"}[response],"Observed event selector",tick)
        if "admission_kind" in g:check(g["admission_kind"]=="authored","Observed admission kind",tick)
    material = int(spec["material"])
    censuses = raw.get("censuses", [])
    expected_census_ticks = [r["tick"] for r in rows if r["tick"] % 60 == 0 or r["tick"] == spec["ticks"] - 1]
    check([c.get("tick") for c in censuses] == expected_census_ticks, "Native census observation coverage")
    for census in censuses:
        check(census.get("conserved") is True and conserved(raw["before"], census["observed"], material, census["source_inserted"]), "Closed native quantity plus actual source additions", census.get("tick"))
    source = raw.get("source", {})
    inserted = source.get("inserted", 0)
    check(conserved(raw["before"], raw["after"], material, inserted), "Final closed native quantity plus actual source additions")
    complete = raw.get("ok") is True and raw.get("errors") == [] and len(rows) == spec["ticks"] and receipt.get("ok") is True and receipt.get("exit") == 0 and receipt.get("timed_out") is False and receipt.get("identity_ok") is True
    values = lambda field: [r["gcr"].get(field, 0) for r in rows]
    result = {"capture_complete": complete, "status": "complete" if complete else "failed_or_incomplete", "observed_rows": len(rows), "expected_rows": spec["ticks"],
              "errors": raw.get("errors", []), "reported_failure": raw.get("failure"), "mechanical_observed_prefix_ok": not violations,
              "mechanical_complete_pass": complete and not violations, "violations": violations,
              "motion": state_metrics(rows, raw["initial"]), "source_inserted": inserted,
              "source_attempted": source.get("attempted",0), "source_blocked": source.get("blocked",0),
              "material_cell_centroid_grid_y_before": centroid(raw["before"], material), "material_cell_centroid_grid_y_after": centroid(raw["after"], material),
              "material_count_before": raw["before"]["counts"][material], "material_count_after": raw["after"]["counts"][material],
              "water_quantity_before": raw["before"]["water_mass"], "water_quantity_after": raw["after"]["water_mass"],
              "peak_pre_ejection_overlap": max(values("cellular_overlap_pre"), default=None), "peak_post_ejection_overlap": max(values("cellular_overlap_post"), default=None),
              "maximum_budget_overrun": max((r["gcr"]["normal_accepted"] + r["gcr"]["event_budget_cost"] - r["gcr"]["global_capacity"] for r in rows), default=None),
              "peak_native_wrench_force": max((norm(r["gcr"]["impulse"]) / context["dt"] for r in rows), default=None),
              "peak_native_wrench_torque_rate": max((abs(r["gcr"]["torque"]) / context["dt"] for r in rows), default=None),
              "nonzero_event_boundaries": sum(norm(r["gcr"]["event_accepted"]) > 1e-12 or abs(r["gcr"]["event_torque"]) > 1e-12 for r in rows),
              "arrival_count_sum": sum(values("arrival_count")), "arrival_missing_sum": sum(values("arrival_missing")), "arrival_misaligned_sum": sum(values("arrival_misaligned")),
              "event_budget_cost_sum": sum(values("event_budget_cost")), "step_time_us": distribution([r["step_us"] for r in rows]),
              "maximum_nodes": max(values("nodes"), default=None), "maximum_scalar_updates": max(values("updates"), default=None),
              "scanned_work": distribution([r["work"][0] for r in rows]), "move_work": distribution([r["work"][1] for r in rows]), "active_block_work": distribution([r["work"][2] for r in rows])}
    if spec["id"] == "carry-spill":
        result["carry_gate"] = carry_gate(raw, context["carry_gate"])
        result["carry_gate"]["registered_demonstration_pass"] &= complete and not violations
    selected = []
    for row in rows:
        choose = spec["id"] == "carry-spill" and "cavity_count" in row
        choose |= spec["id"] == "stream" and row["tick"] in {0, 60, 120, 180, 240, 258, 259, 300, 450, 599, 600, 750, 899, len(rows)-1}
        if choose:
            selected.append({"tick": row["tick"], "source_sample": row["gcr"].get("sample_serial"), "current_pose": {k: row["state"][k] for k in ("position", "rotation")},
                             "velocity": row["state"]["velocity"], "omega": row["state"]["omega"], "primary_cavity_count": row.get("cavity_count"),
                             "sample_pose": row.get("sample_pose"), "sample_pose_cavity_count_auxiliary": row.get("sample_pose_cavity_count"),
                             "native_impulse": row["gcr"].get("impulse"), "native_torque": row["gcr"].get("torque")})
    return result, {"samples": selected, "reported_failure": raw.get("failure"), "errors": raw.get("errors", []), "first_unobserved_tick_if_partial": len(rows) if not complete else None}, rows


def analyze(output, summary_dir):
    output, summary_dir = Path(output).resolve(), Path(summary_dir).resolve()
    require(not summary_dir.exists(), "Use a fresh summary directory")
    manifest, watched, global_errors, summaries, selected, traces = [], {}, [], [], [], {}
    def watch(path, kind):
        path = Path(path)
        if not path.exists():
            manifest.append({"path": path.relative_to(output).as_posix(), "kind": kind, "present": False})
            return None
        data = path.read_bytes()
        value = digest(data)
        watched[path] = value
        manifest.append({"path": path.relative_to(output).as_posix(), "kind": kind, "present": True, "bytes": len(data), "sha256": value})
        return value
    watch(output / "identity.json", "source_identity")
    identity = read(output / "identity.json")
    source = identity["source"]
    archive = archived(source)
    require(digest(json.dumps(identity["inputs"], sort_keys=True).encode()) == identity["inputs_hash"], "Source input-map digest mismatch")
    verify_source_map(identity["inputs"],source_scope(archive),"Godot source")
    for path, expected in identity["inputs"].items():
        require(archive["hashes"].get(path) == expected, "Input map differs from retained source: " + path)
    completion = None
    if watch(output / "completion.json", "runner_completion"):
        completion = read(output / "completion.json")
        require(completion.get("source") == source, "Runner completion source mismatch")
    frozen_definition = archived(FROZEN_DEFINITION_SOURCE)["retained"][DEFINITION]
    require(archive["retained"][DEFINITION] == frozen_definition, "Scooper definition changed from registered source profile")
    protocol = None
    for platform in PLATFORMS:
        folder = output / platform
        try:
            ph = watch(folder / PROTOCOL, "registered_protocol")
            require(ph == identity["protocol_sha256"], "Protocol byte hash mismatch")
            platform_protocol = read(folder / PROTOCOL)
            require(same(platform_protocol, json.loads(archive["retained"][PROTOCOL])), "Protocol differs from retained source")
            if protocol is None:
                protocol = platform_protocol
            else:
                require(same(platform_protocol, protocol), "Cross-platform protocol differs")
            require(protocol.get("registration") == REG and protocol.get("responses") == list(RESPONSES) and len(protocol.get("cases", [])) == 8 and protocol.get("workers") == 1 and abs(protocol.get("dt", 0) - 1/60) < 1e-15, "Foreign protocol population")
            require(len({c["id"] for c in protocol["cases"]}) == 8 and all(0 < c["ticks"] <= 900 for c in protocol["cases"]), "Scenario capacity")
            watch(folder / "runtime.json", "runtime_identity")
            runtime = read(folder / "runtime.json")
            watch(folder / "gates.json", "gate_receipts")
            gates = read(folder / "gates.json")
            require(any(g.get("test") == "import" and g.get("ok") is True for g in gates), "Fresh import receipt missing")
            require(runtime.get("engine_version") == "4.7.stable.official.5b4e0cb0f", "Unpinned engine identity")
            project = folder / "godot"
            for path, expected in identity["inputs"].items():
                require(path.startswith("godot/"), "Foreign project input path")
                file = bundle_path(project, path[len("godot/"):])
                require(digest(file.read_bytes().replace(b"\r\n", b"\n")) == expected, "Copied source input mismatch: " + path)
            copied_definition = bundle_path(project, DEFINITION[len("godot/"):]).read_bytes().replace(b"\r\n", b"\n")
            require(copied_definition == frozen_definition, "Copied registered definition differs")
            suffix = "" if platform == "windows" else ".linux"
            native = read(project / ("addons/cybersand_native/runtime-provenance" + suffix + ".json"))
            require(native["source_commit"] == runtime["native_build_source"] and native["source_inputs"] == runtime["native_source_inputs"], "Native source provenance mismatch")
            verify_source_map(native["source_inputs"],source_scope(archive,native=True),"Capture native source")
            verify_source_map(native["source_inputs"],source_scope(archived(native["source_commit"]),native=True),"Compiled native source")
            require(all(archive["hashes"].get(path) == expected and archived(native["source_commit"])["hashes"].get(path) == expected for path, expected in native["source_inputs"].items()), "Native compiled/capture source inputs differ")
            native_file = bundle_path(project, native["artifact"].removeprefix("godot/"))
            require(digest(native_file.read_bytes()) == native["sha256"] == runtime["native_sha256"], "Native runtime bytes differ")
            rapier = read(project / ("addons/godot-rapier2d/runtime-provenance." + platform + ".json"))
            require(digest(bundle_path(project, rapier["artifact"].removeprefix("godot/")).read_bytes()) == rapier["sha256"] == runtime["rapier_sha256"], "Rapier bytes differ")
            watch(folder / "campaign.json", "capture_receipts")
            campaign = read(folder / "campaign.json")
            receipts = {(r["case"], r["response"]): r for r in campaign}
            require(len(receipts) == len(campaign) and all(k[0] in {c["id"] for c in protocol["cases"]} and k[1] in RESPONSES for k in receipts), "Duplicate/foreign campaign member")
            context = {"platform": platform, "source": source, "inputs_hash": identity["inputs_hash"], "protocol_sha256": ph, "native_sha256": runtime["native_sha256"], "dt": protocol["dt"], "carry_gate": protocol["carry_gate"]}
            for spec in protocol["cases"]:
                for response in RESPONSES:
                    name = spec["id"] + "-" + response
                    raw_path, log_path = folder / (name + ".json"), folder / (name + ".log")
                    receipt = receipts.get((spec["id"], response))
                    row = {"platform": platform, "case": spec["id"], "response": response, "material": spec["material"]}
                    raw_hash, log_hash = watch(raw_path, "raw_capture"), watch(log_path, "capture_log")
                    if receipt is None or raw_hash is None:
                        row.update(status="missing", capture_complete=False, mechanical_complete_pass=False, identity_errors=["Missing original capture/receipt"])
                    else:
                        try:
                            require(receipt.get("raw_sha256") == raw_hash and receipt.get("log_sha256") == log_hash, "Original raw/log receipt hash mismatch")
                            raw = read(raw_path)
                            require(receipt.get("rows") == len(raw.get("rows", [])), "Receipt row count mismatch")
                            reduced, trace, raw_rows = reduce_capture(raw, spec, response, context, receipt)
                            row.update(reduced)
                            traces[(platform, spec["id"], response)] = raw_rows
                            if trace["samples"] or trace["reported_failure"] or trace["errors"]:
                                selected.append(dict(platform=platform, case=spec["id"], response=response, **trace))
                        except (EvidenceError, KeyError, TypeError, ValueError) as exc:
                            row.update(status="invalid", capture_complete=False, mechanical_complete_pass=False, identity_errors=[str(exc)])
                    summaries.append(row)
        except (EvidenceError, KeyError, TypeError, ValueError, OSError) as exc:
            global_errors.append({"platform": platform, "reason": str(exc)})
    if protocol:
        existing = {(r["platform"], r["case"], r["response"]) for r in summaries}
        for platform in PLATFORMS:
            for spec in protocol["cases"]:
                for response in RESPONSES:
                    if (platform, spec["id"], response) not in existing:
                        summaries.append({"platform": platform, "case": spec["id"], "response": response, "material": spec["material"], "status": "unverified_bundle", "capture_complete": False, "mechanical_complete_pass": False})
    negative = []
    complete_by_key = {(r["platform"],r["case"],r["response"]):r.get("capture_complete",False) for r in summaries}
    for platform in PLATFORMS:
        for case in ("water", "hard"):
            arms = [traces.get((platform, case, response)) for response in RESPONSES]
            maximum = 0.0
            available = all(arms) and len({len(a) for a in arms}) == 1
            complete_arms = available and all(complete_by_key.get((platform,case,response),False) for response in RESPONSES)
            if available:
                for left, right in ((arms[0], arms[1]), (arms[0], arms[2])):
                    for a, b in zip(left, right):
                        av = a["state"]["position"] + a["state"]["velocity"] + [a["state"]["rotation"], a["state"]["omega"]]
                        bv = b["state"]["position"] + b["state"]["velocity"] + [b["state"]["rotation"], b["state"]["omega"]]
                        maximum = max(maximum, *(abs(x-y) for x, y in zip(av, bv)))
            negative.append({"platform": platform, "case": case, "available_equal_observation_lengths": available, "maximum_absolute_pose_velocity_difference": maximum if available else None,
                             "complete_three_response_population":complete_arms,
                             "within_1e_minus_4": complete_arms and maximum <= 1e-4, "scope": "Same-platform C/E/S state traces only; not cross-platform determinism or exact coupled replay."})
    for path, before in watched.items():
        if not path.exists() or digest(path.read_bytes()) != before:
            global_errors.append({"reason": "Original evidence changed during analysis", "path": path.relative_to(output).as_posix()})
    full = len(summaries) == 48 and all(row.get("capture_complete") for row in summaries)
    mechanical = full and not global_errors and all(row.get("mechanical_complete_pass") for row in summaries)
    runner_custody = completion is not None and completion.get("ok") is True and completion.get("inputs_unchanged") is True
    result = {"schema": 1, "registration": REG, "source": source, "tree": identity.get("tree"), "protocol_sha256": identity["protocol_sha256"],
              "definition_identity": {"frozen_source": FROZEN_DEFINITION_SOURCE, "path": DEFINITION, "source_file_sha256_lf": digest(frozen_definition), "godot_canonical_hash": DEFINITION_HASH},
              "capture_population_complete": full, "mechanical_population_pass": mechanical, "runner_current_head_custody_pass": runner_custody,
              "runner_completion": completion, "integrity_errors": global_errors, "mechanisms": summaries, "negative_controls": negative,
              "scope": ["Passive energy excludes motors, event impulses, correction/zeroing, gravity and hard contact.", "Centroids use stored cell grid-y coordinates without adding0.5; Water cell centroid is not mass-weighted.", "Repeated events/boundaries are diagnostic counts, not independent efficacy populations.", "Primary current-pose cavity counts are never replaced by auxiliary sample-pose counts.", "Owner gameplay acceptance and production/default promotion remain outside this analyzer."]}
    result["scope"].append("step_time_us measures the complete runtime.step owner boundary; source authoring and census/cavity observations are outside that timer. It is not coupling-only timing.")
    result["scope"].append("Selector/admission strings are asserted by the authenticated capture producer before every appended row; the retained reduced gcr metrics omit these strings. Events-off zero event J/L/cost and selective arrival-witness closure are independently checked from recorded metrics.")
    summary_dir.mkdir(parents=True)
    for name, value in (("machine-summary.json", result), ("raw-manifest.json", {"source": source, "files": manifest}), ("selected-traces.json", {"source": source, "traces": selected})):
        (summary_dir / name).write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8", newline="\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="Original run_gcr_authored output directory")
    parser.add_argument("--summary-dir", type=Path, required=True, help="Fresh compact summary directory")
    args = parser.parse_args()
    try:
        result = analyze(args.output, args.summary_dir)
    except (EvidenceError, OSError, KeyError, TypeError, ValueError) as exc:
        print(json.dumps({"ok": False, "evidence_error": str(exc)}))
        return 2
    carry = [r["carry_gate"]["registered_demonstration_pass"] for r in result["mechanisms"] if "carry_gate" in r]
    ok = result["mechanical_population_pass"] and result["runner_current_head_custody_pass"] and len(carry) == 6 and all(carry) and all(r["within_1e_minus_4"] for r in result["negative_controls"])
    print(json.dumps({"source": result["source"], "captures_complete": result["capture_population_complete"], "mechanical_pass": result["mechanical_population_pass"], "runner_custody_pass": result["runner_current_head_custody_pass"], "carry_passes": sum(carry), "carry_population": len(carry), "ok": ok}))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
