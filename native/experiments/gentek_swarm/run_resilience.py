#!/usr/bin/env python3
"""Qualify the reconstructed SWARM-003 and its preregistered capacity continuation.

This runner was reconstructed on 19 November 2026. It is not represented as
the lost ffb9e85 runner. The original evidence ZIP is opened read-only, and
historical comparisons retain every difference under the new source identity.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import platform
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
import zipfile

from run_admission import normalized_negotiated
from run_negotiated import (DONORS, HARNESS, HERE, ROOT, canonical, fingerprint,
                            first_mismatch, git, now, source_inputs, stop_command_group)

PARENT = "5bf7b4b90616130577744e39c9fbc9c0376c52b2"
HISTORICAL_SOURCE = "ffb9e85cc3baabda367adb0424f78e01eebb910d"
HISTORICAL_ARCHIVE_SHA256 = "dc4136e02c7787e54a37232e2db560d5d58b10f40b1ded5232f3e745951f3e81"
CAPACITY_POLICIES = ("native_receiver_single", "native_receiver_six", "native_receiver_eight")
LANE_SEEDS = {"primary": [605, 1701], "regression": [2718, 4099], "validation": [8191, 12289]}
SUITES = ("test_mosaic_admission", "test_resilience_solver", "test_gentek_resilience")


class RunnerCancelled(Exception):
    """Cancellation retained after the active command tree has been reaped."""


class CommandRunner:
    """Own each launched process group and retain a receipt on every exit path."""

    def __init__(self, out, manifest, save, cwd=ROOT, grace_seconds=8):
        self.out, self.manifest, self.save = Path(out), manifest, save
        self.cwd, self.grace_seconds = Path(cwd), grace_seconds

    def execute(self, label, command, timeout, cwd=None):
        if not label or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" for c in label):
            raise ValueError("Command labels must be plain unique file stems")
        if any(r["label"] == label for r in self.manifest.setdefault("commands", [])):
            raise ValueError("Duplicate command label would overwrite evidence")
        argv = list(map(str, command))
        workdir = Path(cwd) if cwd is not None else self.cwd
        log = self.out / (label + ".log")
        if log.exists():
            raise ValueError("Refusing to overwrite a retained command log")
        receipt = {"label": label, "argv": argv, "cwd": str(workdir), "log": log.name,
                   "timeout_seconds": timeout, "started_utc": now(), "outcome": "RUNNING"}
        start = time.monotonic()
        process = None
        waiting = False
        cancelled = None
        previous = {sig: signal.getsignal(sig) for sig in (signal.SIGTERM, signal.SIGINT)}

        def cancel(signum, _frame):
            nonlocal cancelled
            cancelled = signal.Signals(signum).name
            # Popen must finish assigning its child identity before cancellation
            # can unwind. A signal received during launch is handled immediately
            # after Popen returns; no unidentified child is left behind.
            if waiting:
                raise RunnerCancelled(cancelled)

        for sig in previous:
            signal.signal(sig, cancel)
        env = os.environ.copy()
        env["ASAN_OPTIONS"] = "detect_leaks=0:halt_on_error=1"
        env["UBSAN_OPTIONS"] = "halt_on_error=1"
        print(f"[{label}] {' '.join(argv)}", flush=True)
        try:
            with log.open("x") as stream:
                if cancelled:
                    raise RunnerCancelled(cancelled)
                process = subprocess.Popen(argv, cwd=workdir, stdout=stream, stderr=subprocess.STDOUT,
                                           env=env, start_new_session=True)
                receipt["pid"] = process.pid
                waiting = True
                if cancelled:
                    raise RunnerCancelled(cancelled)
                process.wait(timeout=timeout)
                waiting = False
                receipt["outcome"] = "PASS" if process.returncode == 0 else "FAIL"
        except RunnerCancelled:
            waiting = False
            receipt["outcome"] = "CANCELLED"
        except subprocess.TimeoutExpired:
            waiting = False
            receipt["outcome"] = "TIMEOUT"
        except BaseException as error:
            waiting = False
            receipt.update(outcome="ERROR", error=f"{type(error).__name__}: {error}")
        finally:
            waiting = False
            if process is not None:
                # Also remove same-group descendants when their leader has
                # already exited. Nested supervisors receive time to close their
                # separately launched groups and retain their own receipts.
                try:
                    stop_command_group(process, self.grace_seconds if receipt["outcome"] != "PASS" else 0)
                except BaseException as error:
                    receipt.update(outcome="ERROR", cleanup_error=f"{type(error).__name__}: {error}")
                receipt["exit_code"] = process.returncode
            else:
                receipt["exit_code"] = None
            if cancelled:
                receipt.update(outcome="CANCELLED", cancellation_signal=cancelled)
            for sig, handler in previous.items():
                signal.signal(sig, handler)
            receipt.update(termination_grace_seconds=self.grace_seconds,
                           elapsed_seconds=round(time.monotonic() - start, 3), finished_utc=now(),
                           log_sha256=fingerprint(log) if log.is_file() else None)
            self.manifest["commands"].append(receipt)
            self.save()
        print(f"[{label}] {receipt['outcome']} seconds={receipt['elapsed_seconds']}", flush=True)
        if receipt["outcome"] == "CANCELLED":
            raise RunnerCancelled(f"{label}: {cancelled}")
        if receipt["outcome"] != "PASS":
            raise RuntimeError(f"{label}: {receipt['outcome']}; retained {log}")
        return receipt


def retained_source_inputs():
    """Hash every harness file, including the registration and selection files."""
    paths = [p for p in HERE.iterdir() if p.is_file()]
    paths.extend(ROOT / p for p in DONORS)
    return {p.relative_to(ROOT).as_posix(): fingerprint(p) for p in sorted(paths)}


def verify_committed_inputs(inputs):
    """Check actual input bytes against HEAD, including files hidden by index flags."""
    output = subprocess.check_output(["git", "-C", str(ROOT), "ls-tree", "-rz", "HEAD", "--", str(HARNESS), *map(str, DONORS)], timeout=30)
    tracked = {}
    for entry in output.split(b"\0"):
        if not entry:
            continue
        header, path = entry.split(b"\t", 1)
        _mode, kind, object_id = header.split()
        if kind == b"blob":
            tracked[path.decode()] = object_id.decode()
    if set(tracked) != set(inputs):
        missing = sorted(set(tracked) - set(inputs))
        unexpected = sorted(set(inputs) - set(tracked))
        raise ValueError(f"Source inventory differs from committed HEAD; missing={missing}, unexpected={unexpected}")
    algorithm = git("rev-parse", "--show-object-format")
    for name in inputs:
        data = (ROOT / name).read_bytes()
        blob = hashlib.new(algorithm, b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        if tracked.get(name) != blob:
            raise ValueError(f"Source input differs from committed HEAD: {name}")


def read_selection(path, policy, clean, root=ROOT, git_command=git):
    if not clean:
        raise ValueError("Fresh validation requires clean, frozen source")
    if policy not in CAPACITY_POLICIES:
        raise ValueError("Fresh validation requires one registered frozen capacity policy")
    path = Path(path).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError("Selection must be a committed file inside this source repository")
    relative = path.relative_to(root.resolve()).as_posix()
    git_command("ls-files", "--error-unmatch", "--", relative)
    if git_command("hash-object", "--", relative) != git_command("rev-parse", "HEAD:" + relative):
        raise ValueError("Selection file differs from HEAD")
    value = json.loads(path.read_text())
    if value.get("selected_policy") != policy or value.get("fresh_validation_seeds") != LANE_SEEDS["validation"]:
        raise ValueError("Selection does not freeze the requested policy and exact new seed pair")
    return {"path": relative, "sha256": fingerprint(path),
            "selection_commit": git_command("log", "-1", "--format=%H", "HEAD", "--", relative),
            "selected_policy": policy, "fresh_validation_seeds": LANE_SEEDS["validation"], "document": value}


def normalized_historical(document, identity):
    """Normalize only declared source identity and the explicit default capacity.

    Trace prose, ordering, work, masks, paths, failure outcomes and all native
    arrays remain exact. The new default-four field makes an implicit historical
    default explicit; it is not an outcome normalization.
    """
    if document.get("schema") == 2:
        return normalized_negotiated(document, identity)
    if document.get("schema") not in (3, 4):
        raise ValueError("Unexpected historical raw schema")
    value = dict(document)
    value["digest"] = "<source-dependent>"
    value["candidate"] = normalized_negotiated(document["candidate"], identity)
    if document["schema"] == 4:
        value["options"] = {"optional_capacity": 4, **document["options"]}
    return value



# Reviewed against all 756 matched original known records. These exact value
# pairs govern evidence comparison only; no native generator reads this table.
HISTORICAL_EQUIVALENCE_VERSION = 1
_HISTORICAL_CHANGES_1 = [{'after': 8272, 'before': 5024, 'kind': 'value'}, {'after': 8240, 'before': 5024, 'kind': 'value'},
 {'after': 9888, 'before': 6785, 'kind': 'value'}, {'after': 9936, 'before': 6785, 'kind': 'value'},
 {'after': 456, 'before': 448, 'kind': 'value'}, {'after': 392, 'before': 448, 'kind': 'value'},
 {'after': 424, 'before': 448, 'kind': 'value'}, {'after': 8888, 'before': 5560, 'kind': 'value'},
 {'after': 1696, 'before': 1600, 'kind': 'value'}, {'after': 944, 'before': 832, 'kind': 'value'},
 {'after': 472, 'before': 448, 'kind': 'value'}, {'after': 408, 'before': 448, 'kind': 'value'}]

_HISTORICAL_CHANGES_2 = [{'after': 3712, 'before': 3840, 'kind': 'value'}, {'after': 3520, 'before': 3840, 'kind': 'value'},
 {'after': 3584, 'before': 3840, 'kind': 'value'}, {'after': 3776, 'before': 3840, 'kind': 'value'},
 {'after': 3456, 'before': 3840, 'kind': 'value'}, {'after': 3648, 'before': 3840, 'kind': 'value'},
 {'after': 3904, 'before': 3840, 'kind': 'value'}, {'after': 3968, 'before': 3840, 'kind': 'value'}]

_HISTORICAL_CHANGES_3 = [{'after': 2, 'before': 4, 'kind': 'length'}]

_HISTORICAL_CHANGES_4 = [{'after': 'No partial categorical assignment is rasterised; failed donor work is unavailable, not '
           'fabricated.',
  'before': 'No partial assignment is rasterised; failed-attempt work remains unavailable and exhaustion is '
            'not UNSAT.',
  'kind': 'value'},
 {'after': 'GEN-003 performs bounded propagation/backtracking; its public API exposes total work, not '
           'backtrack count.',
  'before': 'Resilience uses at most two predeclared attempts; their allocations sum to the original '
            'categorical ceiling.',
  'kind': 'value'},
 {'after': 'Motif doorway compatibility is local; this is not a global support or post-simulation stability '
           'certificate.',
  'before': 'Fallback after exhaustion is a preference-policy decision, not a proof that preferred '
            'constraints were UNSAT.',
  'kind': 'value'},
 {'after_present': False,
  'before': 'GEN-003 performs bounded propagation/backtracking; its public API exposes total work, not '
            'backtrack count.',
  'kind': 'removed'},
 {'after_present': False,
  'before': 'Motif doorway compatibility is local; this is not a global support or post-simulation stability '
            'certificate.',
  'kind': 'removed'}]

_HISTORICAL_CHANGES_5 = [{'after': 'all attempted predeclared domain sets proved UNSAT',
  'before': 'region adjacency/domain constraints are unsatisfiable within the declared finite tile',
  'kind': 'value'},
 {'after': 'configured domain sets remain unknown after bounded exhaustion; a later nonmonotone fallback '
           'does not prove the preferred problem UNSAT',
  'before': 'region solver exhausted declared preparation work; increase max_work or simplify constraints',
  'kind': 'value'}]

_HISTORICAL_CHANGES_6 = [{'after': 52179, 'before': 52307, 'kind': 'value'}, {'after': 54201, 'before': 54329, 'kind': 'value'},
 {'after': 62473, 'before': 59353, 'kind': 'value'}, {'after': 61573, 'before': 58645, 'kind': 'value'},
 {'after': 37573, 'before': 37829, 'kind': 'value'}, {'after': 38791, 'before': 39047, 'kind': 'value'},
 {'after': 47031, 'before': 44071, 'kind': 'value'}, {'after': 46731, 'before': 43835, 'kind': 'value'},
 {'after': 30270, 'before': 30590, 'kind': 'value'}, {'after': 31086, 'before': 31406, 'kind': 'value'},
 {'after': 360462, 'before': 357679, 'kind': 'value'}, {'after': 378970, 'before': 379034, 'kind': 'value'},
 {'after': 381480, 'before': 381608, 'kind': 'value'}, {'after': 381544, 'before': 381672, 'kind': 'value'},
 {'after': 380344, 'before': 380728, 'kind': 'value'}, {'after': 56386, 'before': 56514, 'kind': 'value'},
 {'after': 58641, 'before': 58833, 'kind': 'value'}, {'after': 388340, 'before': 385317, 'kind': 'value'},
 {'after': 386932, 'before': 384101, 'kind': 'value'}, {'after': 388485, 'before': 388677, 'kind': 'value'},
 {'after': 68997, 'before': 69189, 'kind': 'value'}, {'after': 390245, 'before': 390501, 'kind': 'value'},
 {'after': 390309, 'before': 390565, 'kind': 'value'}, {'after': 389709, 'before': 390093, 'kind': 'value'},
 {'after': 58280, 'before': 58344, 'kind': 'value'}, {'after': 61040, 'before': 61104, 'kind': 'value'},
 {'after': 61496, 'before': 61552, 'kind': 'value'}, {'after': 59832, 'before': 60144, 'kind': 'value'},
 {'after': 74561, 'before': 74625, 'kind': 'value'}, {'after': 440641, 'before': 440705, 'kind': 'value'},
 {'after': 77551, 'before': 77679, 'kind': 'value'}, {'after': 443631, 'before': 443759, 'kind': 'value'},
 {'after': 443695, 'before': 443823, 'kind': 'value'}, {'after': 442051, 'before': 442435, 'kind': 'value'},
 {'after': 427392, 'before': 427456, 'kind': 'value'}, {'after': 430068, 'before': 430196, 'kind': 'value'},
 {'after': 430132, 'before': 430260, 'kind': 'value'}, {'after': 428784, 'before': 429168, 'kind': 'value'},
 {'after': 63716, 'before': 63780, 'kind': 'value'}, {'after': 429796, 'before': 429860, 'kind': 'value'},
 {'after': 66392, 'before': 66520, 'kind': 'value'}, {'after': 432472, 'before': 432600, 'kind': 'value'},
 {'after': 432536, 'before': 432664, 'kind': 'value'}, {'after': 431188, 'before': 431572, 'kind': 'value'},
 {'after': 323408, 'before': 323728, 'kind': 'value'}, {'after': 324224, 'before': 324544, 'kind': 'value'},
 {'after': 324616, 'before': 324992, 'kind': 'value'}, {'after': 323400, 'before': 323720, 'kind': 'value'},
 {'after': 324216, 'before': 324536, 'kind': 'value'}, {'after': 324608, 'before': 324984, 'kind': 'value'},
 {'after': 335538, 'before': 335794, 'kind': 'value'}, {'after': 336710, 'before': 336966, 'kind': 'value'},
 {'after': 337134, 'before': 337414, 'kind': 'value'}, {'after': 336866, 'before': 337210, 'kind': 'value'},
 {'after': 347748, 'before': 347876, 'kind': 'value'}, {'after': 349872, 'before': 350000, 'kind': 'value'},
 {'after': 350328, 'before': 350448, 'kind': 'value'}, {'after': 349312, 'before': 349624, 'kind': 'value'},
 {'after': 58216, 'before': 58344, 'kind': 'value'}, {'after': 60084, 'before': 60212, 'kind': 'value'},
 {'after': 60540, 'before': 60660, 'kind': 'value'}, {'after': 59684, 'before': 59996, 'kind': 'value'},
 {'after': 420108, 'before': 420172, 'kind': 'value'}, {'after': 422868, 'before': 422932, 'kind': 'value'},
 {'after': 423324, 'before': 423380, 'kind': 'value'}, {'after': 421660, 'before': 421972, 'kind': 'value'},
 {'after': 415236, 'before': 415364, 'kind': 'value'}, {'after': 417810, 'before': 417938, 'kind': 'value'},
 {'after': 417874, 'before': 418002, 'kind': 'value'}, {'after': 416526, 'before': 416910, 'kind': 'value'},
 {'after': 423140, 'before': 423204, 'kind': 'value'}, {'after': 425816, 'before': 425944, 'kind': 'value'},
 {'after': 425880, 'before': 426008, 'kind': 'value'}, {'after': 424532, 'before': 424916, 'kind': 'value'},
 {'after': 69280, 'before': 69216, 'kind': 'value'}, {'after': 80710, 'before': 77382, 'kind': 'value'},
 {'after': 79510, 'before': 76438, 'kind': 'value'}, {'after': 532764, 'before': 532668, 'kind': 'value'},
 {'after': 532164, 'before': 532196, 'kind': 'value'}, {'after': 547612, 'before': 547484, 'kind': 'value'},
 {'after': 551200, 'before': 551088, 'kind': 'value'}, {'after': 550000, 'before': 550144, 'kind': 'value'},
 {'after': 74780, 'before': 74652, 'kind': 'value'}, {'after': 59736, 'before': 60120, 'kind': 'value'},
 {'after': 60608, 'before': 60992, 'kind': 'value'}, {'after': 60672, 'before': 61056, 'kind': 'value'},
 {'after': 423328, 'before': 423456, 'kind': 'value'}, {'after': 426104, 'before': 426232, 'kind': 'value'},
 {'after': 426168, 'before': 426296, 'kind': 'value'}, {'after': 424672, 'before': 425056, 'kind': 'value'},
 {'after': 402830, 'before': 403022, 'kind': 'value'}, {'after': 404926, 'before': 405118, 'kind': 'value'},
 {'after': 404990, 'before': 405182, 'kind': 'value'}, {'after': 404090, 'before': 404474, 'kind': 'value'},
 {'after': 415424, 'before': 415616, 'kind': 'value'}, {'after': 417502, 'before': 417694, 'kind': 'value'},
 {'after': 417566, 'before': 417758, 'kind': 'value'}, {'after': 416666, 'before': 417050, 'kind': 'value'},
 {'after': 385256, 'before': 385512, 'kind': 'value'}, {'after': 386528, 'before': 386784, 'kind': 'value'},
 {'after': 386984, 'before': 387232, 'kind': 'value'}, {'after': 386684, 'before': 386996, 'kind': 'value'},
 {'after': 362271, 'before': 362527, 'kind': 'value'}, {'after': 361703, 'before': 362087, 'kind': 'value'},
 {'after': 346324, 'before': 346708, 'kind': 'value'}, {'after': 372425, 'before': 372617, 'kind': 'value'},
 {'after': 371589, 'before': 371973, 'kind': 'value'}, {'after': 356433, 'before': 356753, 'kind': 'value'},
 {'after': 356133, 'before': 356517, 'kind': 'value'}, {'after': 85020, 'before': 85148, 'kind': 'value'},
 {'after': 83376, 'before': 83760, 'kind': 'value'}, {'after': 50552, 'before': 50744, 'kind': 'value'},
 {'after': 49652, 'before': 50036, 'kind': 'value'}, {'after': 427387, 'before': 427515, 'kind': 'value'},
 {'after': 426187, 'before': 426571, 'kind': 'value'}, {'after': 435302, 'before': 435342, 'kind': 'value'},
 {'after': 433786, 'before': 434082, 'kind': 'value'}, {'after': 442148, 'before': 442036, 'kind': 'value'},
 {'after': 440568, 'before': 440712, 'kind': 'value'}, {'after': 331436, 'before': 331796, 'kind': 'value'},
 {'after': 339538, 'before': 339818, 'kind': 'value'}, {'after': 339270, 'before': 339614, 'kind': 'value'},
 {'after': 337290, 'before': 337570, 'kind': 'value'}, {'after': 337022, 'before': 337366, 'kind': 'value'},
 {'after': 339694, 'before': 339974, 'kind': 'value'}, {'after': 339426, 'before': 339770, 'kind': 'value'},
 {'after': 84576, 'before': 84704, 'kind': 'value'}, {'after': 83228, 'before': 83612, 'kind': 'value'},
 {'after': 438254, 'before': 438382, 'kind': 'value'}, {'after': 436906, 'before': 437290, 'kind': 'value'},
 {'after': 428286, 'before': 428326, 'kind': 'value'}, {'after': 427130, 'before': 427426, 'kind': 'value'},
 {'after': 435280, 'before': 435168, 'kind': 'value'}, {'after': 433912, 'before': 434056, 'kind': 'value'},
 {'after': 67776, 'before': 68096, 'kind': 'value'}, {'after': 67476, 'before': 67860, 'kind': 'value'},
 {'after': 388889, 'before': 389209, 'kind': 'value'}, {'after': 388589, 'before': 388973, 'kind': 'value'},
 {'after': 414759, 'before': 415015, 'kind': 'value'}, {'after': 414159, 'before': 414543, 'kind': 'value'},
 {'after': 392988, 'before': 393244, 'kind': 'value'}, {'after': 392388, 'before': 392772, 'kind': 'value'},
 {'after': 411754, 'before': 412010, 'kind': 'value'}, {'after': 411154, 'before': 411538, 'kind': 'value'}]

_HISTORICAL_CHANGES_7 = [{'after': 115869, 'before': 115997, 'kind': 'value'}, {'after': 117891, 'before': 118019, 'kind': 'value'},
 {'after': 126163, 'before': 123043, 'kind': 'value'}, {'after': 125263, 'before': 122335, 'kind': 'value'},
 {'after': 100633, 'before': 100889, 'kind': 'value'}, {'after': 101851, 'before': 102107, 'kind': 'value'},
 {'after': 110091, 'before': 107131, 'kind': 'value'}, {'after': 109791, 'before': 106895, 'kind': 'value'},
 {'after': 136069, 'before': 136389, 'kind': 'value'}, {'after': 136885, 'before': 137205, 'kind': 'value'},
 {'after': 466273, 'before': 463490, 'kind': 'value'}, {'after': 449459, 'before': 449523, 'kind': 'value'},
 {'after': 449300, 'before': 449364, 'kind': 'value'}, {'after': 451965, 'before': 452093, 'kind': 'value'},
 {'after': 451919, 'before': 452047, 'kind': 'value'}, {'after': 452029, 'before': 452157, 'kind': 'value'},
 {'after': 450670, 'before': 451054, 'kind': 'value'}, {'after': 174968, 'before': 175096, 'kind': 'value'},
 {'after': 177223, 'before': 177415, 'kind': 'value'}, {'after': 506958, 'before': 503935, 'kind': 'value'},
 {'after': 505526, 'before': 502695, 'kind': 'value'}, {'after': 470039, 'before': 470231, 'kind': 'value'},
 {'after': 150549, 'before': 150741, 'kind': 'value'}, {'after': 471812, 'before': 472068, 'kind': 'value'},
 {'after': 471876, 'before': 472132, 'kind': 'value'}, {'after': 471261, 'before': 471645, 'kind': 'value'},
 {'after': 124380, 'before': 124444, 'kind': 'value'}, {'after': 127140, 'before': 127204, 'kind': 'value'},
 {'after': 127596, 'before': 127652, 'kind': 'value'}, {'after': 125932, 'before': 126244, 'kind': 'value'},
 {'after': 126260, 'before': 126324, 'kind': 'value'}, {'after': 129020, 'before': 129084, 'kind': 'value'},
 {'after': 129476, 'before': 129532, 'kind': 'value'}, {'after': 127812, 'before': 128124, 'kind': 'value'},
 {'after': 152747, 'before': 152811, 'kind': 'value'}, {'after': 518858, 'before': 518922, 'kind': 'value'},
 {'after': 518855, 'before': 518919, 'kind': 'value'}, {'after': 155737, 'before': 155865, 'kind': 'value'},
 {'after': 521844, 'before': 521972, 'kind': 'value'}, {'after': 521908, 'before': 522036, 'kind': 'value'},
 {'after': 520237, 'before': 520621, 'kind': 'value'}, {'after': 520517, 'before': 520581, 'kind': 'value'},
 {'after': 520528, 'before': 520592, 'kind': 'value'}, {'after': 523189, 'before': 523317, 'kind': 'value'},
 {'after': 523178, 'before': 523306, 'kind': 'value'}, {'after': 523253, 'before': 523381, 'kind': 'value'},
 {'after': 521870, 'before': 522254, 'kind': 'value'}, {'after': 167543, 'before': 167607, 'kind': 'value'},
 {'after': 533663, 'before': 533727, 'kind': 'value'}, {'after': 533660, 'before': 533724, 'kind': 'value'},
 {'after': 170533, 'before': 170661, 'kind': 'value'}, {'after': 536640, 'before': 536768, 'kind': 'value'},
 {'after': 536704, 'before': 536832, 'kind': 'value'}, {'after': 535033, 'before': 535417, 'kind': 'value'},
 {'after': 157226, 'before': 157290, 'kind': 'value'}, {'after': 523356, 'before': 523420, 'kind': 'value'},
 {'after': 523345, 'before': 523409, 'kind': 'value'}, {'after': 159902, 'before': 160030, 'kind': 'value'},
 {'after': 526017, 'before': 526145, 'kind': 'value'}, {'after': 526006, 'before': 526134, 'kind': 'value'},
 {'after': 526081, 'before': 526209, 'kind': 'value'}, {'after': 524698, 'before': 525082, 'kind': 'value'},
 {'after': 361338, 'before': 361658, 'kind': 'value'}, {'after': 362154, 'before': 362474, 'kind': 'value'},
 {'after': 362546, 'before': 362922, 'kind': 'value'}, {'after': 362445, 'before': 362765, 'kind': 'value'},
 {'after': 363261, 'before': 363581, 'kind': 'value'}, {'after': 363653, 'before': 364029, 'kind': 'value'},
 {'after': 394196, 'before': 394452, 'kind': 'value'}, {'after': 394194, 'before': 394450, 'kind': 'value'},
 {'after': 395368, 'before': 395624, 'kind': 'value'}, {'after': 395792, 'before': 396072, 'kind': 'value'},
 {'after': 395522, 'before': 395866, 'kind': 'value'}, {'after': 362613, 'before': 362933, 'kind': 'value'},
 {'after': 363429, 'before': 363749, 'kind': 'value'}, {'after': 363821, 'before': 364197, 'kind': 'value'},
 {'after': 448860, 'before': 448988, 'kind': 'value'}, {'after': 448858, 'before': 448986, 'kind': 'value'},
 {'after': 450984, 'before': 451112, 'kind': 'value'}, {'after': 450982, 'before': 451110, 'kind': 'value'},
 {'after': 451440, 'before': 451560, 'kind': 'value'}, {'after': 450407, 'before': 450719, 'kind': 'value'},
 {'after': 126057, 'before': 126185, 'kind': 'value'}, {'after': 127925, 'before': 128053, 'kind': 'value'},
 {'after': 128381, 'before': 128501, 'kind': 'value'}, {'after': 127525, 'before': 127837, 'kind': 'value'},
 {'after': 531886, 'before': 531950, 'kind': 'value'}, {'after': 531870, 'before': 531934, 'kind': 'value'},
 {'after': 534646, 'before': 534710, 'kind': 'value'}, {'after': 535102, 'before': 535158, 'kind': 'value'},
 {'after': 533409, 'before': 533721, 'kind': 'value'}, {'after': 508089, 'before': 508217, 'kind': 'value'},
 {'after': 510663, 'before': 510791, 'kind': 'value'}, {'after': 510727, 'before': 510855, 'kind': 'value'},
 {'after': 509340, 'before': 509724, 'kind': 'value'}, {'after': 510273, 'before': 510337, 'kind': 'value'},
 {'after': 510257, 'before': 510321, 'kind': 'value'}, {'after': 513033, 'before': 513097, 'kind': 'value'},
 {'after': 513489, 'before': 513545, 'kind': 'value'}, {'after': 511796, 'before': 512108, 'kind': 'value'},
 {'after': 516678, 'before': 516742, 'kind': 'value'}, {'after': 516666, 'before': 516730, 'kind': 'value'},
 {'after': 519342, 'before': 519470, 'kind': 'value'}, {'after': 519406, 'before': 519534, 'kind': 'value'},
 {'after': 518019, 'before': 518403, 'kind': 'value'}, {'after': 127092, 'before': 127028, 'kind': 'value'},
 {'after': 138522, 'before': 135194, 'kind': 'value'}, {'after': 137322, 'before': 134250, 'kind': 'value'},
 {'after': 575407, 'before': 575311, 'kind': 'value'}, {'after': 574803, 'before': 574835, 'kind': 'value'},
 {'after': 650645, 'before': 650517, 'kind': 'value'}, {'after': 650643, 'before': 650515, 'kind': 'value'},
 {'after': 654227, 'before': 654115, 'kind': 'value'}, {'after': 653017, 'before': 653161, 'kind': 'value'},
 {'after': 575573, 'before': 575477, 'kind': 'value'}, {'after': 574969, 'before': 575001, 'kind': 'value'},
 {'after': 639992, 'before': 639864, 'kind': 'value'}, {'after': 167142, 'before': 167014, 'kind': 'value'},
 {'after': 643579, 'before': 643467, 'kind': 'value'}, {'after': 642368, 'before': 642512, 'kind': 'value'},
 {'after': 123714, 'before': 124098, 'kind': 'value'}, {'after': 124586, 'before': 124970, 'kind': 'value'},
 {'after': 124650, 'before': 125034, 'kind': 'value'}, {'after': 123666, 'before': 124050, 'kind': 'value'},
 {'after': 124538, 'before': 124922, 'kind': 'value'}, {'after': 124602, 'before': 124986, 'kind': 'value'},
 {'after': 509455, 'before': 509583, 'kind': 'value'}, {'after': 509453, 'before': 509581, 'kind': 'value'},
 {'after': 512231, 'before': 512359, 'kind': 'value'}, {'after': 512295, 'before': 512423, 'kind': 'value'},
 {'after': 510771, 'before': 511155, 'kind': 'value'}, {'after': 493087, 'before': 493279, 'kind': 'value'},
 {'after': 493074, 'before': 493266, 'kind': 'value'}, {'after': 495183, 'before': 495375, 'kind': 'value'},
 {'after': 495247, 'before': 495439, 'kind': 'value'}, {'after': 494306, 'before': 494690, 'kind': 'value'},
 {'after': 503757, 'before': 503949, 'kind': 'value'}, {'after': 503755, 'before': 503947, 'kind': 'value'},
 {'after': 505835, 'before': 506027, 'kind': 'value'}, {'after': 505899, 'before': 506091, 'kind': 'value'},
 {'after': 504983, 'before': 505367, 'kind': 'value'}, {'after': 480182, 'before': 480438, 'kind': 'value'},
 {'after': 481454, 'before': 481710, 'kind': 'value'}, {'after': 481910, 'before': 482158, 'kind': 'value'},
 {'after': 481596, 'before': 481908, 'kind': 'value'}, {'after': 109846, 'before': 106886, 'kind': 'value'},
 {'after': 109546, 'before': 106650, 'kind': 'value'}, {'after': 108970, 'before': 106010, 'kind': 'value'},
 {'after': 108670, 'before': 105774, 'kind': 'value'}, {'after': 461112, 'before': 461368, 'kind': 'value'},
 {'after': 460518, 'before': 460902, 'kind': 'value'}, {'after': 426530, 'before': 426914, 'kind': 'value'},
 {'after': 486729, 'before': 486921, 'kind': 'value'}, {'after': 485864, 'before': 486248, 'kind': 'value'},
 {'after': 433772, 'before': 434092, 'kind': 'value'}, {'after': 433459, 'before': 433843, 'kind': 'value'},
 {'after': 154194, 'before': 154322, 'kind': 'value'}, {'after': 152550, 'before': 152934, 'kind': 'value'},
 {'after': 113599, 'before': 113791, 'kind': 'value'}, {'after': 112699, 'before': 113083, 'kind': 'value'},
 {'after': 481728, 'before': 481856, 'kind': 'value'}, {'after': 480501, 'before': 480885, 'kind': 'value'},
 {'after': 530979, 'before': 531019, 'kind': 'value'}, {'after': 529441, 'before': 529737, 'kind': 'value'},
 {'after': 535591, 'before': 535719, 'kind': 'value'}, {'after': 534364, 'before': 534748, 'kind': 'value'},
 {'after': 537996, 'before': 537884, 'kind': 'value'}, {'after': 536401, 'before': 536545, 'kind': 'value'},
 {'after': 388074, 'before': 388434, 'kind': 'value'}, {'after': 362501, 'before': 362877, 'kind': 'value'},
 {'after': 401068, 'before': 401348, 'kind': 'value'}, {'after': 400798, 'before': 401142, 'kind': 'value'},
 {'after': 422021, 'before': 422301, 'kind': 'value'}, {'after': 421739, 'before': 422083, 'kind': 'value'},
 {'after': 399550, 'before': 399830, 'kind': 'value'}, {'after': 399280, 'before': 399624, 'kind': 'value'},
 {'after': 424046, 'before': 424326, 'kind': 'value'}, {'after': 423764, 'before': 424108, 'kind': 'value'},
 {'after': 153631, 'before': 153759, 'kind': 'value'}, {'after': 152283, 'before': 152667, 'kind': 'value'},
 {'after': 538008, 'before': 538136, 'kind': 'value'}, {'after': 536621, 'before': 537005, 'kind': 'value'},
 {'after': 523963, 'before': 524003, 'kind': 'value'}, {'after': 522785, 'before': 523081, 'kind': 'value'},
 {'after': 541662, 'before': 541790, 'kind': 'value'}, {'after': 540275, 'before': 540659, 'kind': 'value'},
 {'after': 531209, 'before': 531097, 'kind': 'value'}, {'after': 529820, 'before': 529964, 'kind': 'value'},
 {'after': 138378, 'before': 135050, 'kind': 'value'}, {'after': 137178, 'before': 134106, 'kind': 'value'},
 {'after': 676589, 'before': 676477, 'kind': 'value'}, {'after': 675379, 'before': 675523, 'kind': 'value'},
 {'after': 585274, 'before': 585178, 'kind': 'value'}, {'after': 584670, 'before': 584702, 'kind': 'value'},
 {'after': 673082, 'before': 672970, 'kind': 'value'}, {'after': 671872, 'before': 672016, 'kind': 'value'},
 {'after': 585452, 'before': 585356, 'kind': 'value'}, {'after': 584848, 'before': 584880, 'kind': 'value'},
 {'after': 133177, 'before': 133497, 'kind': 'value'}, {'after': 132877, 'before': 133261, 'kind': 'value'},
 {'after': 133253, 'before': 133573, 'kind': 'value'}, {'after': 132953, 'before': 133337, 'kind': 'value'},
 {'after': 468117, 'before': 468437, 'kind': 'value'}, {'after': 467815, 'before': 468199, 'kind': 'value'},
 {'after': 512541, 'before': 512797, 'kind': 'value'}, {'after': 511937, 'before': 512321, 'kind': 'value'},
 {'after': 488190, 'before': 488446, 'kind': 'value'}, {'after': 487574, 'before': 487958, 'kind': 'value'},
 {'after': 509814, 'before': 510070, 'kind': 'value'}, {'after': 509210, 'before': 509594, 'kind': 'value'}]

_HISTORICAL_CHANGES_8 = [{'after': 'physically qualified original-native receiver selected by support count, distance, coordinates '
           'and tile before solving',
  'before': 'required native receiving face selected before solve from original native motifs plus closed '
            'receivers; exact material/thickness retained',
  'kind': 'value'}]

_HISTORICAL_CHANGES_9 = [{'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: optional-admitted; native receiving opportunity passed finite local screening '
            'and changes the selected tile domain',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: optional-redundant-admitted; same native domain already admitted; explicit '
            'join authority retained and one optional capacity position consumed',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: required-admitted; hard mechanical obligation retained in every attempted '
            'domain set',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
           'optional offer withheld by pre-solve native admission',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: optional-not-selected-within-capacity; matched required-receiver hard-only '
            'diagnostic withholds every optional preference and its join authority',
  'kind': 'value'},
 {'after': 'physically qualified original-native receiver selected by support count, distance, coordinates '
           'and tile before solving',
  'before': 'required native receiving face selected before solve from original native motifs plus closed '
            'receivers; exact material/thickness retained; native admission: required-admitted; hard '
            'mechanical obligation retained in every attempted domain set',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
           'optional offer withheld by pre-solve native admission',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: optional-not-selected-within-capacity; four higher-ranked optional offers '
            'already admitted; no solve-dependent refill',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
           'selected assignment did not satisfy this preference or damage revoked its contact',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: optional-admitted; native receiving opportunity passed finite local screening '
            'and changes the selected tile domain; selected assignment did not satisfy this preference or '
            'damage revoked its contact',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
           'selected assignment did not satisfy this preference or damage revoked its contact',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: optional-redundant-admitted; same native domain already admitted; explicit '
            'join authority retained and one optional capacity position consumed; selected assignment did '
            'not satisfy this preference or damage revoked its contact',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
           'optional offer withheld by pre-solve native admission',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: optional-competing; receiving domain conflicts locally with an earlier native '
            'or required opportunity',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'unresolved because the bounded solve or native generation exhausted',
  'kind': 'value'},
 {'after': 'no admitted receiving face in finite slot envelope; optional offer withheld by pre-solve native '
           'admission',
  'before': 'no admitted receiving face in finite slot envelope; native admission: '
            'optional-locally-incompatible; no native material face with the required thickness/contact '
            'geometry',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
           'optional offer withheld by pre-solve native admission',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: optional-locally-incompatible; no receiving category has cardinal support '
            'even in the optimistic native neighborhood',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: optional-redundant-admitted; same native domain already admitted; explicit '
            'join authority retained and one optional capacity position consumed; unresolved because the '
            'bounded solve or native generation exhausted',
  'kind': 'value'},
 {'after': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness',
  'before': 'MOSAIC closed termination/receiving buttress has exposed material and inward bearing thickness; '
            'native admission: optional-admitted; native receiving opportunity passed finite local screening '
            'and changes the selected tile domain; unresolved because the bounded solve or native generation '
            'exhausted',
  'kind': 'value'}]

_HISTORICAL_CHANGES_10 = [{'after': 'zero optional capacity diagnostic; all required obligations retained',
  'before': 'matched required-receiver hard-only diagnostic withholds every optional preference and its join '
            'authority',
  'kind': 'value'}]

_HISTORICAL_CHANGES_11 = [{'after': 'full original offer universe retained; no native optional admission screen',
  'before': 'Original full admission: every reservation is forwarded without local screening',
  'kind': 'value'},
 {'after': 'native flexibility/support/distance/ID order; optional capacity 0, fixed fallback capacity 0; '
           'one-hop screening is not a global satisfiability proof',
  'before': 'matched required-receiver hard-only diagnostic; all mandatory conditions retained and optional '
            'capacity zero',
  'kind': 'value'}]

_HISTORICAL_CHANGES_12 = [{'after': 'no original-native receiving face has reciprocal local support; original hard condition retained',
  'before': 'no locally supported existing-native face in the original envelope; original required failure '
            'retained',
  'kind': 'value'},
 {'after': 'physically qualified original-native receiver selected by support count, distance, coordinates '
           'and tile before solving',
  'before': 'original closed face had no local support; selected most-supported original-native material '
            'face, then distance and stable coordinates; raw mask retained',
  'kind': 'value'}]

_HISTORICAL_CHANGES_13 = [{'after': 8208, 'before': 4960, 'kind': 'value'}, {'after': 8176, 'before': 4960, 'kind': 'value'},
 {'after': 9824, 'before': 6721, 'kind': 'value'}, {'after': 9872, 'before': 6721, 'kind': 'value'},
 {'after': 392, 'before': 384, 'kind': 'value'}, {'after': 328, 'before': 384, 'kind': 'value'},
 {'after': 360, 'before': 384, 'kind': 'value'}, {'after': 424, 'before': 384, 'kind': 'value'},
 {'after': 8400, 'before': 5112, 'kind': 'value'}, {'after': 408, 'before': 384, 'kind': 'value'},
 {'after': 440, 'before': 384, 'kind': 'value'}, {'after': 344, 'before': 384, 'kind': 'value'}]

HISTORICAL_EQUIVALENCE_RULES = {
    '$/candidate/final_mosaic/metrics/resilience_required_receiver_work': ('accounting_or_telemetry', _HISTORICAL_CHANGES_1),
    '$/candidate/final_mosaic/metrics/resilience_solver_receipt_work': ('accounting_or_telemetry', _HISTORICAL_CHANGES_2),
    '$/candidate/final_mosaic/notes/$length': ('prose_or_termination_label', _HISTORICAL_CHANGES_3),
    '$/candidate/final_mosaic/notes/*': ('prose_or_termination_label', _HISTORICAL_CHANGES_4),
    '$/candidate/final_mosaic/termination': ('prose_or_termination_label', _HISTORICAL_CHANGES_5),
    '$/candidate/final_mosaic/work': ('accounting_or_telemetry', _HISTORICAL_CHANGES_6),
    '$/candidate/metrics/candidate_generator_work': ('accounting_or_telemetry', _HISTORICAL_CHANGES_7),
    '$/candidate/mosaic/domains/*/influences/*/reason': ('prose_or_termination_label', _HISTORICAL_CHANGES_8),
    '$/candidate/mosaic/responses/*/reason': ('prose_or_termination_label', _HISTORICAL_CHANGES_9),
    '$/candidate/mosaic/result/metrics/resilience_required_receiver_work': ('accounting_or_telemetry', _HISTORICAL_CHANGES_1),
    '$/candidate/mosaic/result/metrics/resilience_solver_receipt_work': ('accounting_or_telemetry', _HISTORICAL_CHANGES_2),
    '$/candidate/mosaic/result/notes/$length': ('prose_or_termination_label', _HISTORICAL_CHANGES_3),
    '$/candidate/mosaic/result/notes/*': ('prose_or_termination_label', _HISTORICAL_CHANGES_4),
    '$/candidate/mosaic/result/termination': ('prose_or_termination_label', _HISTORICAL_CHANGES_5),
    '$/candidate/mosaic/result/work': ('accounting_or_telemetry', _HISTORICAL_CHANGES_6),
    '$/trace/admission/decisions/*/reason': ('prose_or_termination_label', _HISTORICAL_CHANGES_10),
    '$/trace/admission/reason': ('prose_or_termination_label', _HISTORICAL_CHANGES_11),
    '$/trace/receivers/*/reason': ('prose_or_termination_label', _HISTORICAL_CHANGES_12),
    '$/trace/receivers/*/work': ('accounting_or_telemetry', _HISTORICAL_CHANGES_13),
    '$/trace/solver/preparation_work': ('accounting_or_telemetry', _HISTORICAL_CHANGES_2),
}

def changes(before, after, path="$", parts=()):
    # Python container equality conflates nested 0/False and 13/13.0. Only
    # identity or exact-typed scalar equality may bypass recursive inspection.
    if before is after:
        return
    if type(before) is not type(after):
        yield {"path": path, "pattern": path_pattern(parts), "kind": "type", "before": before, "after": after}
    elif isinstance(before, dict):
        for key in sorted(set(before) | set(after)):
            child = path + "/" + key.replace("~", "~0").replace("/", "~1")
            nested = parts + (key,)
            if key not in before:
                yield {"path": child, "pattern": path_pattern(nested), "kind": "added", "before_present": False, "after": after[key]}
            elif key not in after:
                yield {"path": child, "pattern": path_pattern(nested), "kind": "removed", "before": before[key], "after_present": False}
            else:
                yield from changes(before[key], after[key], child, nested)
    elif isinstance(before, list):
        scalar_types = (str, int, float, bool, type(None))
        if len(before) == len(after) and all(left is right or
                (type(left) is type(right) and type(left) in scalar_types and left == right)
                for left, right in zip(before, after)):
            return
        if len(before) != len(after):
            yield {"path": path + "/$length", "pattern": path_pattern(parts) + "/$length", "kind": "length", "before": len(before), "after": len(after)}
        for index in range(max(len(before), len(after))):
            child = path + "/" + str(index)
            nested = parts + (index,)
            if index >= len(before):
                yield {"path": child, "pattern": path_pattern(nested), "kind": "added", "before_present": False, "after": after[index]}
            elif index >= len(after):
                yield {"path": child, "pattern": path_pattern(nested), "kind": "removed", "before": before[index], "after_present": False}
            else:
                yield from changes(before[index], after[index], child, nested)
    elif before != after:
        yield {"path": path, "pattern": path_pattern(parts), "kind": "value", "before": before, "after": after}


def path_pattern(parts):
    return "$" + "".join("/" + ("*" if isinstance(part, int) else part.replace("~", "~0").replace("/", "~1")) for part in parts)


def signature(change):
    return json.dumps({key: value for key, value in change.items() if key not in ("path", "pattern")}, sort_keys=True, separators=(",", ":"))


class HistoricalEquivalence:
    def __init__(self):
        self.rules = {pattern: (category, {signature(value) for value in values})
                      for pattern, (category, values) in HISTORICAL_EQUIVALENCE_RULES.items()}

    def compare(self, before, after):
        differences, unexpected = [], []
        for difference in changes(before, after):
            rule = self.rules.get(difference["pattern"])
            allowed = bool(rule and signature(difference) in rule[1] and before.get("schema") == after.get("schema") == 4)
            item = {**difference, "reviewed_equivalent": allowed, "category": rule[0] if rule else "strict-field"}
            differences.append(item)
            if not allowed:
                unexpected.append(item)
        accounting_errors = accounting_invariants(before, after) if before.get("schema") == after.get("schema") == 4 else []
        return {"equivalent": not unexpected and not accounting_errors, "differences": differences,
                "unexpected_differences": unexpected, "accounting_errors": accounting_errors}


def accounting_invariants(before, after):
    """Keep each permitted work delta reconciled and under the same hard bound.

    The reconstructed solver reserve is independently recomputed from its
    bounded input sizes. The historical formula is deliberately not inferred.
    Receiver counters must sum to their phase total, and all generator delta
    must be explained by the two explicitly reconstructed preparation phases.
    These are operation reserves, not measured CPU time or donor solver work.
    """
    errors = []

    def require(condition, message):
        if not condition:
            errors.append(message)

    def integer(value):
        return type(value) is int and value >= 0

    try:
        old, new = before["candidate"], after["candidate"]
        old_trace, trace = before["trace"]["solver"], after["trace"]["solver"]
        count = len(new["mosaic"]["domains"])
        require(count == trace["width"] * trace["height"], "Solver receipt dimensions differ from domain count")
        influence_count = sum(len(domain["influences"]) for domain in new["mosaic"]["domains"])
        require(influence_count <= 8 and len(new["mosaic"]["responses"]) <= 8, "Unbounded reconstructed receipt input")
        expected_preparation = 256 + count * 32 + influence_count * 64 + len(trace["category_ids"]) * 32
        require(trace["preparation_work"] == expected_preparation, "Reconstructed solver preparation formula differs")
        require(integer(old_trace["preparation_work"]) and integer(trace["preparation_work"]), "Invalid preparation counter type/value")
        receiver_work = []
        for label, document in (("historical", before), ("current", after)):
            candidate = document["candidate"]
            result = candidate["mosaic"]["result"]
            final = candidate["final_mosaic"]
            solver = document["trace"]["solver"]
            receipts = document["trace"]["receivers"]
            limits = candidate["mosaic_request"]["limits"]
            require(limits["work"] == 2_000_000 and limits["solver_work"] == 4_000_000 and
                    candidate["metrics"]["candidate_charged_work_upper_bound"] == 10_000_000,
                    label + ": original generator/categorical/structural ceiling changed")
            require(solver["aggregate_limit"] == solver["allocated_limit"] == 4_000_000,
                    label + ": categorical allocation differs from fixed ceiling")
            value = result["metrics"].get("resilience_required_receiver_work", 0)
            require(integer(value) and all(integer(row["work"]) for row in receipts), label + ": invalid receiver work")
            expected_receiver = 64 + sum(row["work"] for row in receipts) if document["options"]["receivers"] == "required-original-native" else 0
            require(value == expected_receiver, label + ": receiver phase counter does not reconcile")
            require(final["metrics"].get("resilience_required_receiver_work", 0) == value, label + ": final receiver work differs")
            require(result["metrics"].get("resilience_solver_receipt_work") == solver["preparation_work"], label + ": solver receipt work metric missing or inconsistent")
            require(final["metrics"].get("resilience_solver_receipt_work") == solver["preparation_work"], label + ": final solver receipt work differs")
            require(integer(result["work"]) and result["work"] <= candidate["mosaic_request"]["limits"]["work"], label + ": MOSAIC work exceeds unchanged ceiling")
            require(all(integer(counter) for counter in (final["work"], candidate["metrics"]["candidate_generator_work"],
                    document["trace"]["admission"]["work"], result["metrics"].get("resilience_domain_preparation_work", 0))),
                    label + ": accounting counter is negative, Boolean or noninteger")
            preparation = solver["preparation_work"] + value + document["trace"]["admission"]["work"] + result["metrics"].get("resilience_domain_preparation_work", 0)
            require(preparation <= result["work"], label + ": preparation was not charged")
            receiver_work.append(value)
        expected_delta = trace["preparation_work"] - old_trace["preparation_work"] + receiver_work[1] - receiver_work[0]
        require(new["mosaic"]["result"]["work"] - old["mosaic"]["result"]["work"] == expected_delta, "MOSAIC work delta is not explained by reconstructed phases")
        require(new["final_mosaic"]["work"] - old["final_mosaic"]["work"] == expected_delta, "Final MOSAIC work delta differs")
        require(new["metrics"]["candidate_generator_work"] - old["metrics"]["candidate_generator_work"] == expected_delta, "Aggregate generator work delta differs")
    except (KeyError, TypeError, ValueError) as error:
        errors.append("Malformed accounting receipt: " + str(error))
    return errors


def compare_historical(archive, campaign_dir, old_lane, destination):
    """Compare all native outcomes and retain every reviewed receipt difference."""
    archive, campaign_dir, destination = Path(archive), Path(campaign_dir), Path(destination)
    archive_hash = fingerprint(archive)
    if archive_hash != HISTORICAL_ARCHIVE_SHA256:
        raise ValueError("Historical archive does not match its recorded immutable SHA-256")
    current = json.loads((campaign_dir / "campaign.json").read_text())
    if current["result"] != "PASS":
        raise ValueError("Cannot compare an incomplete current campaign")
    report = {"check": "Reconstructed-source comparison with the original SWARM-003 corpus",
              "historical_source": HISTORICAL_SOURCE, "current_source": current["source"],
              "historical_archive_sha256": archive_hash, "historical_lane": old_lane,
              "current_lane": current["lane"], "normalization": normalized_historical.__doc__.strip(),
              "equivalence_review": {"version": HISTORICAL_EQUIVALENCE_VERSION,
                  "claim": "Exact matched native outcomes, with finite reviewed prose and reconstructed operation-accounting differences. This is not original source or full-receipt identity.",
                  "rules_sha256": hashlib.sha256(canonical(HISTORICAL_EQUIVALENCE_RULES)).hexdigest(),
                  "permitted_path_patterns": sorted(HISTORICAL_EQUIVALENCE_RULES),
                  "unknown_differences": "reject; native state, domains, statuses, requests, limits and donor work remain strict"},
              "started_utc": now(), "cases": [], "errors": []}
    current_records = {(r["case"], r["policy"]): r for r in current["records"]}
    equivalence = HistoricalEquivalence()
    differences_path = destination.with_suffix(".differences.jsonl")
    difference_counts = {}
    with zipfile.ZipFile(archive) as saved, differences_path.open("w") as differences_file:
        prefix = "qualification/" + old_lane + "/"
        historical = json.loads(saved.read(prefix + "campaign.json"))
        if historical["source"] != HISTORICAL_SOURCE or historical["result"] != "PASS":
            raise ValueError("Unexpected historical campaign custody")
        if historical["seeds"] != current["seeds"]:
            raise ValueError("Historical comparison changed the matched seeds")
        for old in historical["records"]:
            pair = (old["case"], old["policy"])
            if pair not in current_records:
                report["errors"].append({"case": old["case"], "policy": old["policy"], "error": "Missing matched current record"})
                continue
            new = current_records[pair]
            raw_before = saved.read(prefix + old["file"])
            raw_after = (campaign_dir / new["file"]).read_bytes()
            before = normalized_historical(json.loads(raw_before), HISTORICAL_SOURCE)
            after = normalized_historical(json.loads(raw_after), current["source"])
            reviewed = equivalence.compare(before, after)
            before_candidate, after_candidate = before.get("candidate", before), after.get("candidate", after)
            candidate_differences = [difference for difference in reviewed["differences"]
                                     if "candidate" not in before or difference["path"] == "$/candidate" or difference["path"].startswith("$/candidate/")]
            record = {"case": old["case"], "policy": old["policy"], "historical_file": prefix + old["file"],
                      "current_file": new["file"], "historical_raw_sha256": hashlib.sha256(raw_before).hexdigest(),
                      "current_raw_sha256": hashlib.sha256(raw_after).hexdigest(),
                      "candidate_behavior_equal": not candidate_differences,
                      "full_receipt_equal": not reviewed["differences"],
                      "native_outcome_equivalent": reviewed["equivalent"],
                      "reviewed_difference_count": len(reviewed["differences"]) - len(reviewed["unexpected_differences"]),
                      "unexpected_difference_count": len(reviewed["unexpected_differences"]),
                      "accounting_errors": reviewed["accounting_errors"],
                      "historical_behavior_sha256": hashlib.sha256(canonical(before)).hexdigest(),
                      "current_behavior_sha256": hashlib.sha256(canonical(after)).hexdigest()}
            if reviewed["differences"]:
                record["first_receipt_difference"] = reviewed["differences"][0]["path"]
            if candidate_differences:
                record["first_candidate_difference"] = candidate_differences[0]["path"]
            for difference in reviewed["differences"]:
                differences_file.write(json.dumps({"case": old["case"], "policy": old["policy"], **difference}, separators=(",", ":")) + "\n")
                key = difference["pattern"]
                difference_counts[key] = difference_counts.get(key, 0) + 1
            if not reviewed["equivalent"]:
                report["errors"].append({"case": old["case"], "policy": old["policy"],
                    "unexpected_difference_count": len(reviewed["unexpected_differences"]),
                    "first_unexpected_difference": next(iter(reviewed["unexpected_differences"]), None),
                    "accounting_errors": reviewed["accounting_errors"]})
            report["cases"].append(record)
    report.update(cases_compared=len(report["cases"]), expected_cases=len(historical["records"]),
                  candidate_behavior_matches=sum(r["candidate_behavior_equal"] for r in report["cases"]),
                  full_receipt_matches=sum(r["full_receipt_equal"] for r in report["cases"]),
                  native_outcome_equivalence_matches=sum(r["native_outcome_equivalent"] for r in report["cases"]),
                  reviewed_difference_count=sum(r["reviewed_difference_count"] for r in report["cases"]),
                  unexpected_difference_count=sum(r["unexpected_difference_count"] for r in report["cases"]),
                  difference_path_counts=dict(sorted(difference_counts.items())),
                  all_differences={"path": differences_path.name, "sha256": fingerprint(differences_path)},
                  result="FAIL" if report["errors"] else "PASS", finished_utc=now())
    destination.write_text(json.dumps(report, indent=2) + "\n")
    return {k: report[k] for k in ("result", "cases_compared", "expected_cases", "candidate_behavior_matches", "full_receipt_matches",
                                  "native_outcome_equivalence_matches", "reviewed_difference_count", "unexpected_difference_count")}


def write_index(out, manifest):
    links = [(name + "/index.html", name.title() + " native gallery") for name in LANE_SEEDS if (out / name / "index.html").is_file()]
    if (out / "frozen-controls/index.html").is_file():
        links.append(("frozen-controls/index.html", "Independent frozen B/C qualification"))
    links.extend((name, name) for name in ("manifest.json", "sha256sums.txt", "source-snapshot.tar", "source-inventory.json") if name == "sha256sums.txt" or (out / name).is_file())
    page = "<!doctype html><html lang='en'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>SWARM-003 continuation evidence</title>"
    page += "<style>body{max-width:1050px;margin:40px auto;padding:0 24px;background:#111822;color:#e2eaf3;font:17px system-ui;line-height:1.55}a{color:#68dec6}code{overflow-wrap:anywhere}li{margin:12px 0}</style>"
    page += "<h1>SWARM-003 continuation: native evidence</h1><p>Draft / HOLD · " + html.escape(manifest["result"]) + "</p>"
    page += "<p>New source <code>" + html.escape(manifest["execution_identity"]) + "</code>. This reconstruction has its own source identity; the original saved qualification remains unchanged.</p>"
    page += "<p>Primary seeds 605/1701 and former validation seeds 2718/4099 are known regression sets. Fresh seeds 8191/12289 are executed only for a committed selected policy on clean source.</p><ul>"
    page += "".join("<li><a href='" + html.escape(path, quote=True) + "'>" + html.escape(title) + "</a></li>" for path, title in links) + "</ul>"
    page += "<p>Whole-frame required connectors, native material contributions, late joining cells, capacity admission and categorical scheduling are reported separately. Failed solver work is unavailable; no physical stability or aesthetic score is claimed.</p></html>"
    (out / "index.html").write_text(page)


def inventory(out):
    excluded = {out / "manifest.json", out / "sha256sums.txt"}
    entries = {p.relative_to(out).as_posix(): fingerprint(p) for p in sorted(out.rglob("*")) if p.is_file() and p not in excluded}
    path = out / "sha256sums.txt"
    path.write_text("".join(f"{value}  {name}\n" for name, value in entries.items()))
    return {"path": path.name, "sha256": fingerprint(path), "files": len(entries)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--build", type=Path, default=Path("/tmp/gentek-resilience-build"))
    parser.add_argument("--lane", choices=("known", "primary", "regression", "validation", "all"), default="known")
    parser.add_argument("--qualification", action="store_true")
    parser.add_argument("--sanitize", action="store_true")
    parser.add_argument("--allow-dirty", action="store_true")
    parser.add_argument("--selected-policy", choices=CAPACITY_POLICIES)
    parser.add_argument("--selection", type=Path, default=HERE / "SELECTION-CONTINUATION.json")
    parser.add_argument("--historical-evidence", type=Path)
    args = parser.parse_args()
    lanes = ["primary", "regression"] if args.lane == "known" else list(LANE_SEEDS) if args.lane == "all" else [args.lane]
    out, build_parent = args.out.resolve(), args.build.resolve()
    if out.is_relative_to(ROOT) or build_parent.is_relative_to(ROOT):
        parser.error("Generated evidence and build outputs must be outside the source repository")
    if out.is_relative_to(build_parent) or build_parent.is_relative_to(out):
        parser.error("Evidence and build outputs must be separate directory trees")
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        parser.error("Use a fresh empty evidence directory")
    if args.qualification and (args.allow_dirty or not args.sanitize or args.lane != "all" or not args.historical_evidence):
        parser.error("Final qualification requires --lane all --sanitize --historical-evidence and clean source")
    source, tree, dirty = git("rev-parse", "HEAD"), git("rev-parse", "HEAD^{tree}"), git("status", "--porcelain")
    if dirty and not args.allow_dirty:
        parser.error("Source is dirty; use --allow-dirty only for a labelled known-seed development run")
    selection = None
    if "validation" in lanes:
        try:
            selection = read_selection(args.selection, args.selected_policy, not bool(dirty))
        except (ValueError, OSError, subprocess.SubprocessError, json.JSONDecodeError) as error:
            parser.error(str(error))
    code_inputs, all_inputs = source_inputs(), retained_source_inputs()
    if not dirty:
        try:
            verify_committed_inputs(all_inputs)
        except (ValueError, OSError, subprocess.SubprocessError) as error:
            parser.error(str(error))
    source_hash = hashlib.sha256(canonical(code_inputs)).hexdigest()
    identity = source + ("+dirty-" + source_hash[:12] if dirty else "")
    out.mkdir(parents=True, exist_ok=True)
    build_parent.mkdir(parents=True, exist_ok=True)
    build = Path(tempfile.mkdtemp(prefix=source_hash[:16] + "-", dir=build_parent))
    manifest = {"programme": "GENTEK-SWARM-003-CONTINUATION", "phase": "qualification" if args.qualification else "development",
                "source_commit": source, "source_tree": tree, "execution_identity": identity,
                "parent_commit": PARENT, "branch": git("branch", "--show-current"), "clean_source": not bool(dirty),
                "dirty_status": dirty, "source_inputs": code_inputs, "source_input_fingerprint": source_hash,
                "complete_harness_and_donor_inputs": all_inputs, "lanes": lanes, "lane_seeds": LANE_SEEDS,
                "selected_policy": args.selected_policy, "selection": selection, "fresh_build_directory": str(build),
                "sanitizers_requested": args.sanitize, "leak_check": "disabled under host instrumentation; no leak pass claimed",
                "platform": platform.platform(), "python": sys.version, "started_utc": now(), "result": "RUNNING", "commands": []}

    def save():
        (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    runner = CommandRunner(out, manifest, save)
    save()
    prior = {sig: signal.getsignal(sig) for sig in (signal.SIGTERM, signal.SIGINT)}

    def cancel(signum, _frame):
        raise RunnerCancelled(signal.Signals(signum).name)

    for sig in prior:
        signal.signal(sig, cancel)
    try:
        (out / "source-inventory.json").write_text(json.dumps(all_inputs, indent=2) + "\n")
        with tarfile.open(out / "source-snapshot.tar", "w") as snapshot:
            for name in all_inputs:
                snapshot.add(ROOT / name, arcname=name, recursive=False)
        manifest["source_archive"] = {"path": "source-snapshot.tar", "sha256": fingerprint(out / "source-snapshot.tar"), "files": len(all_inputs)}
        runner.execute("parent-ancestry", ["git", "merge-base", "--is-ancestor", PARENT, source], 30)
        runner.execute("compiler", [os.environ.get("CXX", "g++"), "--version"], 30)
        manifest["compiler"] = (out / "compiler.log").read_text().splitlines()[0]
        runner.execute("runner-lifecycle-tests", [sys.executable, HERE / "test_resilience_runner.py"], 90)
        if args.qualification:
            controls = out / "frozen-controls"
            runner.execute("independent-frozen-controls", [sys.executable, HERE / "run_admission.py", "--out", controls, "--sanitize"], 3600)
            frozen = json.loads((controls / "manifest.json").read_text())
            if frozen["result"] != "PASS" or frozen["execution_identity"] != identity or not frozen.get("source_custody_revalidated"):
                raise RuntimeError("Frozen qualification outcome/source custody mismatch")
            manifest["frozen_controls"] = {"manifest": "frozen-controls/manifest.json", "sha256": fingerprint(controls / "manifest.json"),
                                          "swarm001": frozen["control_qualification"]["swarm001_regression"], "swarm002": frozen["frozen_c_regression"]}
        runner.execute("resilience-build", ["make", "-C", HERE, f"BUILD={build}", "resilience"], 900)
        for suite in SUITES:
            runner.execute(suite.replace("_", "-"), [build / suite], 900)
        if args.sanitize:
            runner.execute("resilience-sanitizer-build", ["make", "-C", HERE, f"BUILD={build}", *[build / (suite + "_sanitized") for suite in SUITES]], 1200)
            for suite in SUITES:
                runner.execute(suite.replace("_", "-") + "-sanitized", [build / (suite + "_sanitized")], 1200)
        for lane in lanes:
            if lane == "validation":
                if read_selection(args.selection, args.selected_policy, not bool(git("status", "--porcelain"))) != selection:
                    raise RuntimeError("Selection changed before fresh validation")
                if source_inputs() != code_inputs or retained_source_inputs() != all_inputs or git("rev-parse", "HEAD") != source:
                    raise RuntimeError("Source changed before fresh validation")
                verify_committed_inputs(all_inputs)
            command = [build / "gentek_resilience", out / lane, identity, lane]
            if lane == "validation":
                command.append(args.selected_policy)
            runner.execute(lane + "-native-campaign", command, 1800)
            command = [sys.executable, HERE / "resilience_gallery.py", out / lane]
            if args.selected_policy:
                command.extend(["--selected-policy", args.selected_policy])
            runner.execute(lane + "-gallery", command, 1200)
            manifest[lane] = json.loads((out / lane / "resilience_summary.json").read_text())
            if manifest[lane]["matched_cases"] != 36 or manifest[lane]["audit"]["result"] != "PASS":
                raise RuntimeError("Incomplete or unaudited native campaign")
            if args.historical_evidence and lane != "validation":
                old_lane = "primary" if lane == "primary" else "validation"
                destination = out / (lane + "-historical-comparison.json")
                result = compare_historical(args.historical_evidence, out / lane, old_lane, destination)
                manifest.setdefault("historical_comparisons", {})[lane] = result
                save()
                if result["result"] != "PASS":
                    raise RuntimeError(f"Historical candidate behavior differs; inspect retained {destination}")
        if git("rev-parse", "HEAD") != source or git("rev-parse", "HEAD^{tree}") != tree or source_inputs() != code_inputs or retained_source_inputs() != all_inputs:
            raise RuntimeError("Source changed during execution")
        if not dirty and git("status", "--porcelain"):
            raise RuntimeError("Clean source became dirty during execution")
        if not dirty:
            verify_committed_inputs(all_inputs)
        manifest.update(source_custody_revalidated=True, result="PASS")
    except RunnerCancelled as error:
        manifest.update(result="CANCELLED", error=str(error))
        raise
    except BaseException as error:
        manifest.update(result="FAIL", error=f"{type(error).__name__}: {error}")
        raise
    finally:
        for sig, handler in prior.items():
            signal.signal(sig, handler)
        manifest["finished_utc"] = now()
        names = ("gentek_resilience", *SUITES, *[suite + "_sanitized" for suite in SUITES])
        manifest["binaries"] = {name: fingerprint(build / name) for name in names if (build / name).is_file()}
        save()
        write_index(out, manifest)
        manifest["artifact_inventory"] = inventory(out)
        save()
    print(f"Retained evidence: {out / 'index.html'}", flush=True)


if __name__ == "__main__":
    main()
