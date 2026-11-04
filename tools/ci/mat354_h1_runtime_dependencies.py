#!/usr/bin/env python3
"""H1-only custody of full inputs emitted during the unchanged runtime build.

The Linux-hosted GCC and LLVM-MinGW drivers compile fourteen sources in one
invocation. A normal -MF file is overwritten by each compiler child. Capturing
/dev/stdout through an actual PIPE preserves every child rule without changing
the original driver arguments, their order, the build directory or code flags.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import shlex
import shutil
import subprocess
import sys

SCHEMA = "mat354-h1-runtime-compiled-inputs-v1"
RECEIPT = "runtime-compiled-inputs.json"
DIRECTORY = "compiler-inputs"
MARKER = "H1_COMPILED_INPUTS_SHA256="
TARGET = "mat354-h1-runtime.o"
FLAGS = ("-MD", "-MF", "/dev/stdout", "-MT", TARGET)
PREFLIGHT_FLAGS = ("-M", "-MF", "/dev/stdout", "-MT", TARGET)
MAX_INPUTS = 4096
MAX_STREAM_BYTES = 16 * 1024 * 1024
MAX_HEADER_BYTES = 16 * 1024 * 1024
MAX_HEADERS_TOTAL = 256 * 1024 * 1024
MAX_ARCHIVE_BYTES = 512 * 1024 * 1024
# Independent inventory; do not derive completeness from the compiler's output.
SOURCES = (
    "godot/native_extension/cyber_native_cell_world.cpp",
    "godot/native_extension/cyber_world_generator.cpp",
    "godot/native_extension/register_types.cpp",
    "native/src/world.cpp", "native/src/world_generation.cpp",
    "native/src/generation_fields.cpp", "native/src/generation_typed_fields.cpp",
    "native/src/generation_spatial.cpp", "native/src/generation_grammar.cpp",
    "native/src/generation_planes.cpp", "native/src/render_snapshot.cpp",
    "native/src/settled_world_discovery.cpp", "native/src/material_rules.cpp",
    "native/src/scheduler_geometry.cpp",
)
ENVIRONMENT = (
    "LC_ALL", "TZ", "SOURCE_DATE_EPOCH", "PATH", "CPATH", "CPLUS_INCLUDE_PATH",
    "C_INCLUDE_PATH", "COMPILER_PATH", "LIBRARY_PATH", "GCC_EXEC_PREFIX",
    "LD_LIBRARY_PATH", "DEPENDENCIES_OUTPUT", "SUNPRO_DEPENDENCIES",
    "LINUX_CXX", "WINDOWS_CXX", "GODOT_CPP_ROOT", "GODOT_CPP_LIBRARY",
)
FORBIDDEN_ENVIRONMENT = ("CPATH", "CPLUS_INCLUDE_PATH", "C_INCLUDE_PATH", "COMPILER_PATH",
                         "LIBRARY_PATH", "GCC_EXEC_PREFIX", "LD_LIBRARY_PATH",
                         "DEPENDENCIES_OUTPUT", "SUNPRO_DEPENDENCIES")
INVOCATION_FIELDS = {"original_argv", "actual_argv", "preflight_argv", "cwd", "environment",
                     "compiler_before", "source", "roots", "platform", "archive_path", "output_path"}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def unique_object(pairs):
    value = {}
    for key, item in pairs:
        require(key not in value, "Duplicate receipt field: " + key)
        value[key] = item
    return value


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object)


def write_json(path, value):
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")


def file_fact(path):
    path = Path(path)
    require(path.is_file(), "Missing regular input: " + str(path))
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": digest(data)}


def normalized(path):
    require(isinstance(path, str) and path.startswith("/") and "\x00" not in path,
            "Dependency path must be an absolute build-host path")
    return posixpath.normpath(path)


def beneath(path, root):
    return path == root or path.startswith(root.rstrip("/") + "/")


def classify(path, roots):
    path = normalized(path)
    for label in ("project", "sdk", "toolchain"):
        root = roots.get(label)
        if root and beneath(path, root):
            return label
    if any(beneath(path, root) for root in roots["system"]):
        return "system"
    raise RuntimeError("Unexpected compiler input path: " + path)


def parse_stream(raw, root):
    """Consume every byte of fourteen make rules, including continuations."""
    require(len(raw) <= MAX_STREAM_BYTES, "Dependency stream exceeds custody bound")
    text = raw.decode("utf-8")
    require(text.endswith("\n") and "\r" not in text, "Truncated dependency stream")
    starts = [match.start() for match in re.finditer(r"(?m)^" + re.escape(TARGET) + r":", text)]
    require(len(starts) == len(SOURCES) and starts[0] == 0, "Missing or duplicate translation unit")
    rules = []
    expected = [root + "/" + source for source in SOURCES]
    for index, start in enumerate(starts):
        chunk = text[start:starts[index + 1] if index + 1 < len(starts) else len(text)]
        logical = chunk.replace("\\\n", " ")
        require(logical.endswith("\n") and "\n" not in logical[:-1], "Unparsed dependency content")
        require(not chunk.endswith("\\\n"), "Truncated continued dependency rule")
        tokens = shlex.split(logical[len(TARGET) + 1:].strip(), comments=False)
        paths = [normalized(token) for token in tokens]
        require(paths and paths[0] == expected[index], "Wrong or reordered primary translation unit")
        require(len(paths) == len(set(paths)), "Duplicate dependency input")
        require(set(paths).intersection(expected) == {expected[index]}, "Spliced translation units")
        rules.append({"source": SOURCES[index], "paths": paths, "raw": chunk.encode("utf-8")})
    return rules


def original_arguments(platform, root, sdk, archive, output):
    """Exact current source-owned recipes; any recipe change requires review."""
    if platform == "linux":
        flags = ["-std=c++20", "-O3", "-DNDEBUG", "-fPIC", "-shared", "-pthread", "-fno-math-errno"]
        link = ["-Wl,--build-id=sha1"]
    else:
        flags = ["-std=c++20", "-O3", "-DNDEBUG", "-DWINDOWS_ENABLED", "-shared", "-pthread", "-Wno-c++11-narrowing"]
        link = ["-Wl,--no-undefined", "-static"]
    return [*flags, "-ffile-prefix-map=" + root + "=.", "-ffile-prefix-map=" + sdk + "=godot-cpp",
            "-I" + root + "/native/include", "-I" + sdk + "/include",
            "-I" + sdk + "/gen/include", "-I" + sdk + "/gdextension",
            *(root + "/" + source for source in SOURCES), archive, *link, "-o", output]


def preflight_arguments(original):
    require(original.count("-o") == 1, "Preflight requires a single original output")
    index = original.index("-o")
    require(index + 1 < len(original), "Missing original output path")
    # Clang refuses a multi-source -M query with -o. This separate observation
    # emits dependencies only; the actual compilation retains the original -o.
    return [*original[:index], *original[index + 2:], *PREFLIGHT_FLAGS]


def verify_environment(environment, platform, roots, compiler, archive):
    require(set(environment) == set(ENVIRONMENT) and
            all(value is None or isinstance(value, str) for value in environment.values()),
            "Incomplete or malformed compiler environment")
    require(all(not environment[name] for name in FORBIDDEN_ENVIRONMENT),
            "Unadmitted compiler search or dependency environment")
    require({key: environment[key] for key in ("LC_ALL", "TZ", "SOURCE_DATE_EPOCH")} ==
            {"LC_ALL": "C", "TZ": "UTC", "SOURCE_DATE_EPOCH": "0"}, "Build determinism environment changed")
    require(environment["GODOT_CPP_ROOT"] == roots["sdk"] and
            environment["GODOT_CPP_LIBRARY"] in (None, "", archive), "Compiler SDK environment differs")
    selector = "LINUX_CXX" if platform == "linux" else "WINDOWS_CXX"
    require(environment[selector] == compiler, "Compiler selector environment differs")


def executable_fact(path):
    selected = shutil.which(str(path))
    require(selected is not None, "Missing compiler executable")
    actual = Path(selected).resolve()
    return {"selected": str(Path(selected).absolute()), "resolved": str(actual), **file_fact(actual)}


def compiler_facts(compiler, platform):
    if platform == "linux":
        cc1 = subprocess.check_output([compiler, "-print-prog-name=cc1plus"], text=True).strip()
        linker = subprocess.check_output([compiler, "-print-prog-name=ld"], text=True).strip()
        paths = {"compiler-driver": compiler, "compiler-cc1plus": cc1, "linker": linker}
    else:
        parent = Path(compiler).parent
        paths = {"compiler-driver-wrapper": compiler, "compiler-clang-payload": parent / "clang",
                 "linker-lld-payload": parent / "ld.lld"}
    return {label: executable_fact(path) for label, path in paths.items()}


def retain(path, roots, objects, limit=MAX_HEADER_BYTES):
    key = normalized(str(path))
    scope = classify(key, roots)
    actual = Path(key).resolve()
    require(actual.is_file() and actual.stat().st_size <= limit, "Non-regular or oversized compiler input")
    require(classify(str(actual), roots) == scope, "Compiler input symlink escapes its source domain")
    if scope != "system":
        require(beneath(str(actual), roots[scope]), "Compiler input symlink escapes its root")
    data = actual.read_bytes()
    sha = digest(data)
    target = objects / sha
    if target.exists():
        require(not target.is_symlink() and target.read_bytes() == data, "Content-addressed input collision")
    else:
        with target.open("xb") as handle:
            handle.write(data)
    return {"scope": scope, "resolved": str(actual), "bytes": len(data),
            "sha256_before": sha, "sha256_after": None, "object": sha}


def unchanged(path, fact):
    require(str(Path(path).resolve()) == fact["resolved"], "Input resolution changed during build")
    current = file_fact(path)
    require(current == {"bytes": fact["bytes"], "sha256": fact["sha256_before"]},
            "Compiler input bytes changed during build: " + str(path))
    fact["sha256_after"] = current["sha256"]


def compiler_call(config_path, arguments):
    config = read_json(config_path)
    compiler = config["compiler"]
    environment = dict(os.environ)
    key = "LINUX_CXX" if config["platform"] == "linux" else "WINDOWS_CXX"
    if config["original_selector"] is None:
        environment.pop(key, None)
    else:
        environment[key] = config["original_selector"]
    if arguments == ["--version"]:
        return subprocess.call([compiler, *arguments], env=environment)
    directory = Path(config["directory"])
    require(not (directory / "invocation.json").exists(), "Duplicate runtime compiler invocation")
    require(arguments.count("-o") == 1, "Missing single output argument")
    output = arguments[arguments.index("-o") + 1]
    expected = original_arguments(config["platform"], config["roots"]["project"], config["roots"]["sdk"], config["archive"], output)
    require(arguments == expected, "Unexpected original compiler arguments or dependency mode")
    require(Path.cwd() == Path(config["cwd"]), "Runtime compiler working directory changed")
    recorded_environment = {key: environment.get(key) for key in ENVIRONMENT}
    verify_environment(recorded_environment, config["platform"], config["roots"], compiler, config["archive"])
    before = compiler_facts(compiler, config["platform"])
    original = [compiler, *arguments]
    invocation = {"original_argv": original, "actual_argv": [*original, *FLAGS],
                  "preflight_argv": preflight_arguments(original), "cwd": str(Path.cwd()),
                  "environment": recorded_environment,
                  "compiler_before": before, "source": config["source"], "roots": config["roots"],
                  "platform": config["platform"], "archive_path": config["archive"], "output_path": output}
    write_json(directory / "invocation.json", invocation)
    preflight = subprocess.run(invocation["preflight_argv"], env=environment,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    (directory / "preflight.stdout").write_bytes(preflight.stdout)
    (directory / "preflight.stderr").write_bytes(preflight.stderr)
    require(preflight.returncode == 0, "Full dependency preflight failed")
    pre_rules = parse_stream(preflight.stdout, config["roots"]["project"])
    objects = directory / "objects"
    objects.mkdir()
    paths = sorted({path for rule in pre_rules for path in rule["paths"]})
    require(len(paths) <= MAX_INPUTS and sum(Path(path).stat().st_size for path in paths) <= MAX_HEADERS_TOTAL,
            "Compiler input closure exceeds custody bound")
    inputs = {path: retain(path, config["roots"], objects) for path in paths}
    archive = retain(config["archive"], config["roots"], objects, MAX_ARCHIVE_BYTES)
    # stdout MUST be a PIPE. Reopening /dev/stdout over a regular file truncates
    # earlier compiler-child output and would silently lose thirteen sources.
    actual = subprocess.run(invocation["actual_argv"], env=environment,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    (directory / "actual.stdout").write_bytes(actual.stdout)
    (directory / "actual.stderr").write_bytes(actual.stderr)
    sys.stderr.buffer.write(actual.stderr)
    require(actual.returncode == 0, "Actual runtime compilation failed")
    actual_rules = parse_stream(actual.stdout, config["roots"]["project"])
    units = []
    for index, (pre, post) in enumerate(zip(pre_rules, actual_rules)):
        require(pre["source"] == post["source"] and set(pre["paths"]) == set(post["paths"]),
                "Preflight and actual compiler input closure differ")
        row = {"source": pre["source"], "paths": post["paths"]}
        for label, rule in (("preflight", pre), ("actual", post)):
            name = label + "-" + str(index).zfill(2) + ".d"
            (directory / name).write_bytes(rule["raw"])
            row[label] = {"path": name, **file_fact(directory / name)}
        units.append(row)
    for path, item in inputs.items():
        unchanged(path, item)
    unchanged(config["archive"], archive)
    after = compiler_facts(compiler, config["platform"])
    require(before == after, "Compiler payload changed during build")
    require(any(item["scope"] == "sdk" and "/gen/include/" in path for path, item in inputs.items()),
            "Generated SDK headers are absent from emitted closure")
    require(any(item["scope"] in ("system", "toolchain") for item in inputs.values()), "System headers absent")
    receipt = invocation | {"schema": SCHEMA, "compiler_after": after, "translation_units": units,
        "inputs": inputs, "archive": archive, "runtime": file_fact(output),
        "preflight_returncode": preflight.returncode, "actual_returncode": actual.returncode,
        "files": {name: file_fact(directory / name) for name in
                  ("invocation.json", "preflight.stdout", "preflight.stderr", "actual.stdout", "actual.stderr")}}
    write_json(directory.parent / RECEIPT, receipt)
    return 0


def verify(directory, manifest, source, root):
    """Authenticate retained bytes on either OS; never resolve build-host paths."""
    directory = Path(directory)
    receipt_path = directory / RECEIPT
    require(receipt_path.is_file() and not receipt_path.is_symlink(), "Missing compiled-input receipt")
    receipt = read_json(receipt_path)
    require(receipt["schema"] == SCHEMA and receipt["platform"] == manifest["platform"], "Wrong compiled-input receipt identity")
    require(receipt["source"] == {"commit": source, "tree": manifest["source_tree"]}, "Stale compiled-input source")
    markers = re.findall(r"(?m)^" + MARKER + r"([0-9a-f]{64})$", manifest["toolchain"])
    require(markers == [digest(receipt_path.read_bytes())], "Compiled-input receipt is not bound to provenance")
    require(receipt["runtime"] == {"sha256": manifest["sha256"], "bytes": manifest["size"]}, "Compiled runtime differs")
    require(receipt["preflight_returncode"] == receipt["actual_returncode"] == 0, "Non-passing compiler invocation")
    roots = receipt["roots"]
    require(all(normalized(roots[name]) == roots[name] for name in ("project", "sdk")), "Invalid build roots")
    compiler = receipt["original_argv"][0]
    require(roots["system"] == (["/usr/include", "/usr/lib/gcc"] if receipt["platform"] == "linux" else []),
            "Unadmitted system-header roots")
    expected_toolchain = str(PurePosixPath(compiler).parent.parent) if receipt["platform"] == "windows" else None
    require(roots["toolchain"] == expected_toolchain, "Wrong compiler header root")
    require(receipt["cwd"] == roots["project"] and not beneath(roots["sdk"], roots["project"])
            and not beneath(roots["project"], roots["sdk"]), "Overlapping or incorrect build roots")
    verify_environment(receipt["environment"], receipt["platform"], roots, compiler, receipt["archive_path"])
    expected = [compiler, *original_arguments(receipt["platform"], roots["project"], roots["sdk"], receipt["archive_path"], receipt["output_path"])]
    require(receipt["original_argv"] == expected and receipt["actual_argv"] == [*expected, *FLAGS]
            and receipt["preflight_argv"] == preflight_arguments(expected), "Incorrect or stale compiler argv")
    require(receipt["compiler_before"] == receipt["compiler_after"], "Unstable compiler payload")
    records = re.findall(r"(?m)^executable\[([^]]+)\] selected=(\S+) resolved=(\S+) size=(\d+) sha256=([0-9a-f]{64})$", manifest["toolchain"])
    toolchain = {label: {"selected": selected, "resolved": resolved, "bytes": int(size), "sha256": sha}
                 for label, selected, resolved, size, sha in records}
    labels = ({"compiler-driver", "compiler-cc1plus", "linker"} if receipt["platform"] == "linux" else
              {"compiler-driver-wrapper", "compiler-clang-payload", "linker-lld-payload"})
    require(len(records) == 3 and set(toolchain) == labels and receipt["compiler_before"] == toolchain,
            "Incorrect compiler payload identity")
    driver = toolchain["compiler-driver" if receipt["platform"] == "linux" else "compiler-driver-wrapper"]
    require(driver["selected"] == compiler, "Driver argv and compiler identity differ")
    capture = directory / DIRECTORY
    require(capture.is_dir() and not capture.is_symlink(), "Missing compiled-input payload directory")
    def retained(name, expected_fact):
        require(re.fullmatch(r"(?:invocation\.json|(?:preflight|actual)\.(?:stdout|stderr)|(?:preflight|actual)-\d{2}\.d)", name) is not None,
                "Unsafe dependency evidence path")
        path = capture / name
        require(path.is_file() and not path.is_symlink() and file_fact(path) == expected_fact, "Dependency evidence hash mismatch")
        return path.read_bytes()
    require(set(receipt["files"]) == {"invocation.json", "preflight.stdout", "preflight.stderr", "actual.stdout", "actual.stderr"}, "Incomplete raw compiler evidence")
    raws = {name: retained(name, value) for name, value in receipt["files"].items()}
    invocation = json.loads(raws["invocation.json"], object_pairs_hook=unique_object)
    require(set(invocation) == INVOCATION_FIELDS and
            all(receipt[key] == invocation[key] for key in INVOCATION_FIELDS),
            "Incomplete or spliced compiler invocation")
    pre = parse_stream(raws["preflight.stdout"], roots["project"])
    actual = parse_stream(raws["actual.stdout"], roots["project"])
    require([unit["source"] for unit in receipt["translation_units"]] == list(SOURCES), "Missing or duplicate recorded translation unit")
    union = set()
    for index, (unit, before, after) in enumerate(zip(receipt["translation_units"], pre, actual)):
        require(unit["paths"] == after["paths"] and set(before["paths"]) == set(after["paths"]), "Omitted or changed compiler input")
        for label, rule in (("preflight", before), ("actual", after)):
            entry = unit[label]
            require(entry["path"] == label + "-" + str(index).zfill(2) + ".d", "Duplicate or spliced dependency file")
            require(retained(entry["path"], {key: entry[key] for key in ("bytes", "sha256")}) == rule["raw"], "Dependency rule differs from original stream")
        union.update(after["paths"])
    require(set(receipt["inputs"]) == union, "Missing or unexpected input hash")
    require(len(union) <= MAX_INPUTS and sum(item["bytes"] for item in receipt["inputs"].values()) <= MAX_HEADERS_TOTAL,
            "Compiler input closure exceeds custody bound")
    require(all(type(item["bytes"]) is int and 0 <= item["bytes"] <= MAX_HEADER_BYTES for item in receipt["inputs"].values())
            and type(receipt["archive"]["bytes"]) is int and 0 < receipt["archive"]["bytes"] <= MAX_ARCHIVE_BYTES,
            "Input size exceeds custody bound")
    objects = capture / "objects"
    require(objects.is_dir() and not objects.is_symlink(), "Missing retained compiler inputs")
    all_facts = list(receipt["inputs"].items()) + [(receipt["archive_path"], receipt["archive"])]
    expected_objects = set()
    for path, item in all_facts:
        require(item["scope"] == classify(path, roots), "Wrong input scope")
        require(classify(item["resolved"], roots) == item["scope"], "Input symlink escapes source domain")
        if item["scope"] != "system":
            require(beneath(item["resolved"], roots[item["scope"]]), "Input symlink escapes source root")
        sha = item["sha256_before"]
        require(re.fullmatch(r"[0-9a-f]{64}", sha) is not None and sha == item["sha256_after"] == item["object"], "Changed or malformed input hash")
        payload = objects / sha
        require(payload.is_file() and not payload.is_symlink() and file_fact(payload) == {"sha256": sha, "bytes": item["bytes"]}, "Retained input bytes differ")
        expected_objects.add(sha)
        if item["scope"] == "project":
            relative = str(PurePosixPath(path).relative_to(roots["project"]))
            require(manifest["source_inputs"].get(relative) == sha, "Project compiler input is not the frozen source")
    require({path.name for path in objects.iterdir()} == expected_objects, "Unexpected retained input object")
    archive_lines = re.findall(r"(?m)^([0-9a-f]{64})\s+" + re.escape(receipt["archive_path"]) + r"$", manifest["toolchain"])
    require(archive_lines == [receipt["archive"]["sha256_before"]], "Linked SDK archive identity differs")
    require(receipt["archive_path"] == roots["sdk"] + "/bin/libgodot-cpp." + receipt["platform"] + ".template_debug.x86_64.a", "Unexpected SDK archive")
    require(any(item["scope"] == "sdk" and "/gen/include/" in path for path, item in receipt["inputs"].items()), "Missing generated SDK closure")
    require(any(item["scope"] in ("system", "toolchain") for item in receipt["inputs"].values()), "Missing system-header closure")
    return receipt


def build(args):
    root = Path(__file__).resolve().parents[2]
    source = {"commit": subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip(),
              "tree": subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD^{tree}"], text=True).strip()}
    require(source["commit"] == args.source_sha, "Build source is not HEAD")
    require(not subprocess.check_output(["git", "-C", str(root), "status", "--porcelain=v1"]).strip(), "Build source is dirty")
    sdk = args.sdk_root.resolve()
    compiler = str(Path(shutil.which(args.compiler) or args.compiler).absolute())
    archive = sdk / "bin" / ("libgodot-cpp." + args.platform + ".template_debug.x86_64.a")
    require(os.environ.get("GODOT_CPP_ROOT") == str(sdk), "SDK environment differs")
    require(not os.environ.get("GODOT_CPP_LIBRARY") or os.environ["GODOT_CPP_LIBRARY"] == str(archive), "Unexpected SDK archive override")
    require(os.environ.get("CYBERSAND_NATIVE_OUTPUT") == str(args.runtime.absolute()), "Runtime output environment differs")
    directory = args.bundle.absolute() / DIRECTORY
    directory.mkdir(parents=True, exist_ok=False)
    roots = {"project": str(root), "sdk": str(sdk),
             "toolchain": str(Path(compiler).parent.parent) if args.platform == "windows" else None,
             "system": ["/usr/include", "/usr/lib/gcc"] if args.platform == "linux" else []}
    selector = "LINUX_CXX" if args.platform == "linux" else "WINDOWS_CXX"
    require(os.environ.get(selector) == compiler, "Requested compiler differs from source-owned selector")
    config = {"source": source, "platform": args.platform, "compiler": compiler,
              "archive": str(archive), "roots": roots, "directory": str(directory),
              "cwd": str(root), "original_selector": os.environ.get(selector)}
    config_path = directory / "wrapper-config.json"
    write_json(config_path, config)
    wrapper = directory / "compiler-wrapper"
    wrapper.write_text("#!" + sys.executable + "\nimport os,sys\nos.execv(" + repr(sys.executable) + ", [" +
                       repr(sys.executable) + ", '-B', " + repr(str(Path(__file__).resolve())) +
                       ", 'compiler', " + repr(str(config_path)) + ", *sys.argv[1:]])\n", encoding="utf-8")
    wrapper.chmod(0o755)
    environment = dict(os.environ, **{selector: str(wrapper)})
    script = "tools/build_native_extension" + ("_windows" if args.platform == "windows" else "") + ".sh"
    result = subprocess.run(["bash", script], cwd=root, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    (directory / "build.stdout").write_bytes(result.stdout)
    (directory / "build.stderr").write_bytes(result.stderr)
    sys.stdout.buffer.write(result.stdout); sys.stderr.buffer.write(result.stderr)
    require(result.returncode == 0, "Source-owned runtime builder failed")
    receipt = read_json(args.bundle / RECEIPT)
    require(file_fact(args.runtime) == receipt["runtime"], "Built runtime changed after compilation")
    for path, item in receipt["inputs"].items():
        unchanged(path, item)
    unchanged(receipt["archive_path"], receipt["archive"])
    require(compiler_facts(compiler, args.platform) == receipt["compiler_after"], "Compiler changed after builder")
    require(not subprocess.check_output(["git", "-C", str(root), "status", "--porcelain=v1"]).strip(), "Builder modified source checkout")
    print(MARKER + digest((args.bundle / RECEIPT).read_bytes()))


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "compiler":
        return compiler_call(Path(sys.argv[2]), sys.argv[3:])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["build"])
    parser.add_argument("--platform", required=True, choices=["linux", "windows"])
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--sdk-root", required=True, type=Path)
    parser.add_argument("--runtime", required=True, type=Path)
    parser.add_argument("--bundle", required=True, type=Path)
    build(parser.parse_args())
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, ValueError, KeyError, OSError) as error:
        print("H1 compiled-input custody failed: " + str(error), file=sys.stderr)
        raise SystemExit(1)
