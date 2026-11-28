"""Original requested renderer contract with an explicit registered driver.

The only change is an explicit driver argument for Linux development execution;
Windows still requires ANGLE. Every source/workload/physical policy predicate is
unchanged. Original renderer and V3 readers remain intact.
"""
from results import need

def validate_requested_renderer(data: dict, case: dict, campaign: dict, source: str,
                                nonce: str, engine_sha256: str, thread: str, *, expected_driver: str):
    """Original requested-capture contract with one explicit registered owner."""
    need(thread in ("safe", "separate"), "Unregistered render owner")
    need(data["source_identity"]["source_sha"] == source and data["case_nonce"] == nonce
         and data["source_identity"]["engine_sha256"] == engine_sha256,
         "Captured application/executable/nonce differs")
    expected = {"renderer": expected_driver, "render_thread": {"requested": thread, "runtime": thread},
                "camera": case["camera"], "workers": case["workers"], "water_law": case["water_law"],
                "water_profile": case.get("water_profile", campaign["measurement"]["water_profile"]),
                "water_variant": case.get("water_variant", "reference"), "input_mode": case.get("input_mode", "tape"),
                "command_mode": "repeated_callback", "observer_mode": "full"}
    need(data["fixture"]["name"] == case["fixture"], "Requested renderer fixture differs")
    for key, value in expected.items():
        need(data[key] == value, "Requested renderer capture differs: " + key)
    for phase in ("selectors_before", "selectors_after"):
        status = data[phase]
        need(status["physics"] == "early" and status["presentation"] == "coherent"
             and status["cadence"] == "repaired" and status["rendezvous"]["mode"] == "off"
             and status["rendezvous"]["separate_render_thread"] is (thread == "separate"),
             "Renderer isolation changed physical policy or actual rendezvous render owner")
