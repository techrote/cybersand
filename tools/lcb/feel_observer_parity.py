"""LCB-FEEL #360 observer parity: compare a fresh preflight packet with the committed one.

Usage: python -I tools/lcb/feel_observer_parity.py COMMITTED_PLATFORM_DIR FRESH_PACKET_DIR

Every physical observable must be identical case by case: inventory completeness,
area and counts; the stored-Water census (visible, PressureFlow overfill, quantity,
cells, hashes); physical-state hash; IN tuple census; pressure/gas ledgers; health;
and the per-tick hash/quantity/movement series. Only probe-v2 census metadata may
be added to the inventory. Timing, worker-claimant counts and identities may differ.
Exit status 0 only when nothing differs.
"""
import json
import sys
from pathlib import Path

ALLOWED_INVENTORY_EXTRA = {"schema", "catalogue", "counted_cells", "bound_water", "material_source",
                           "sources", "water_reconciliation"}
TICK_FIELDS = ("tick", "physical_state_hash", "water_quantity", "water_overfill", "moved_cells",
               "visited_cells", "failed")


def census_view(census: dict) -> dict:
    inventory = census["inventory"]
    return {"complete": inventory["complete"], "area": inventory["area"], "counts": inventory["counts"],
            "water": census["water"], "physical_state_hash": census["physical_state_hash"],
            "inertial": census["inertial"], "pressure": census["pressure"], "health": census["health"]}


def compare(committed: Path, fresh: Path) -> int:
    compared = mismatches = 0
    inventory_keys: set[str] = set()
    overfill_rows = []
    for path in sorted((committed / "cases").glob("*.json")):
        other = fresh / "cases" / path.name
        if not other.exists():
            print("MISSING", path.name)
            mismatches += 1
            continue
        a, b = json.loads(path.read_text(encoding="utf-8")), json.loads(other.read_text(encoding="utf-8"))
        compared += 1
        if "initial" not in a:
            if a.get("controls", a.get("outcome")) != b.get("controls", b.get("outcome")):
                mismatches += 1
                print("NEGATIVE DIFF", path.name)
            continue
        for name in ("initial", "final"):
            inventory_keys |= set(b[name]["inventory"]) - {"complete", "area", "counts"}
            if census_view(a[name]) != census_view(b[name]):
                mismatches += 1
                print("CENSUS DIFF", path.name, name)
        if [[t[k] for k in TICK_FIELDS] for t in a["ticks"]] != [[t[k] for k in TICK_FIELDS] for t in b["ticks"]]:
            mismatches += 1
            print("TICK DIFF", path.name)
        if b["final"].get("schema") != "lcb-feel-probe-v2" or \
                b["final"]["inventory"].get("schema") != "lcb-feel-material-census-v1":
            mismatches += 1
            print("SCHEMA", path.name, b["final"].get("schema"))
        water = b["final"]["water"]
        if water["overfill"] > 0:
            overfill_rows.append((path.name, water["visible"], water["overfill"], water["quantity"],
                                  b["final"]["inventory"]["counts"]))
    unexpected = sorted(inventory_keys - ALLOWED_INVENTORY_EXTRA)
    print(f"compared={compared} mismatches={mismatches} new_inventory_keys={sorted(inventory_keys)} "
          f"unexpected={unexpected}")
    for row in overfill_rows:
        print("PF-OVERFILL", *row)
    return 1 if mismatches or unexpected or compared == 0 else 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(compare(Path(sys.argv[1]), Path(sys.argv[2])))
