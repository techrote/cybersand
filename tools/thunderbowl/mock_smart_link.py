#!/usr/bin/env python3
"""Offline smart-link file adapter. This is a mock policy, not model inference."""

import argparse
import json
from pathlib import Path
import time

MAX_BYTES = 65536


def respond(request: dict) -> dict:
    observation = request["observation"]
    if observation.get("observation_mode") != "local":
        raise ValueError("the mock accepts local policy observations only")
    for key in ("run_id", "actor_id", "epoch", "observation_id"):
        if request[key] != observation[key]:
            raise ValueError(f"request/observation identity mismatch: {key}")
    if request["observed_tick"] != observation["tick"]:
        raise ValueError("request/observation tick mismatch")
    response = {key: request[key] for key in (
        "version", "request_id", "run_id", "actor_id", "epoch", "observation_id", "observed_tick"
    )}
    # Echo the issued identities verbatim. A real vision/decision model replaces
    # this intention selection, while the in-game adapter retains authority.
    response.update(valid_for_ticks=120, intent={
        "mode": "pursue_visible", "goal": [0.0, 0.0], "speed": 0.65, "engage": True,
    })
    return response


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--response", type=Path, required=True)
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--seconds", type=float, default=60.0)
    args = parser.parse_args()
    if not 0.0 < args.seconds <= 3600.0:
        parser.error("--seconds must be > 0 and <= 3600")
    if args.request.resolve() == args.response.resolve():
        parser.error("request and response must be different files")
    deadline = time.monotonic() + args.seconds
    previous = None
    count = 0
    while True:
        try:
            with args.request.open("rb") as stream:
                data = stream.read(MAX_BYTES + 1)
            if len(data) > MAX_BYTES:
                raise ValueError("request exceeds 64 KiB")
            request = json.loads(data)
            if request.get("request_id") != previous:
                response = respond(request)
                args.response.parent.mkdir(parents=True, exist_ok=True)
                temporary = args.response.with_name(args.response.name + ".tmp")
                temporary.write_text(json.dumps(response, indent=2) + "\n", encoding="utf-8")
                temporary.replace(args.response)
                previous = request["request_id"]
                count += 1
                print(f"Mock decision {count}: actor {request['actor_id']}, observed tick {request['observed_tick']}", flush=True)
        except (OSError, ValueError, KeyError, TypeError) as error:
            if not args.watch:
                parser.exit(1, f"Cannot produce mock decision: {error}\n")
        if not args.watch or time.monotonic() >= deadline:
            break
        time.sleep(0.05)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
