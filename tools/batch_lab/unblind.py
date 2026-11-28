#!/usr/bin/env python3
"""Join complete, committed blind judgements with their separately kept key."""
import argparse
import json
from pathlib import Path
from evaluate import reveal_votes

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("votes", type=Path)
parser.add_argument("key", type=Path)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
result = reveal_votes(json.loads(args.votes.read_text()), json.loads(args.key.read_text()))
with args.output.open("x", encoding="utf-8") as stream:
    json.dump(result, stream, indent=2)
    stream.write("\n")
print(f"Revealed {len(result['attempts'])} previously committed judgements.")
