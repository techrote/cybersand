#!/usr/bin/env python3
"""CyberSand Atlas credit-aware Responses API agent runner (MAP-AUTO-02 / #499).

See docs/tools/atlas-agent-runner.md. Subcommands: run, credit-check, verify-receipt, publish.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from atlas_agent.cli import main  # noqa: E402

if __name__ == "__main__":
    sys.exit(main())
