"""Independent audit of actual maintained navigation parent/quit-child evidence."""
import hashlib
import json
from pathlib import PurePosixPath
import re


EXPECTED = ["active_pending_repeated", "naturally_sleeping", "opening", "reset_superseded", "held_interval",
            "stop_delivery_faults", "already_closed_prior_policy", "window_close_upgrade"]


def audit(read, source):
    report = {"failures": []}
    def expect(condition, label):
        if not condition:
            report["failures"].append(label)
    parent = json.loads(read("worker-navigation.json"))
    expect(parent.get("schema") == "objectshard-worker-navigation-test-v1" and parent.get("source_revision") == source,
           "Navigation parent exact schema/source")
    expect(type(parent.get("checks")) is int and parent["checks"] >= 100 and type(parent.get("failures")) is int and parent["failures"] == 0,
           "Navigation parent successful complete assertion count")
    expect(parent.get("cases") == EXPECTED, "Navigation exact ordered eight-case inventory")
    assertions = [row for row in parent.get("observations", []) if "check" in row]
    expect(len(assertions) == parent["checks"] and all(row.get("passed") is True for row in assertions), "Every retained parent assertion actually passed")
    cases = [row for row in parent.get("observations", []) if "after" in row]
    expect([row.get("case") for row in cases] == EXPECTED[:-1], "Seven parent lifecycle completion observations")
    for row in cases:
        after = row["after"]
        expect(after.get("state") == "Closed" and after.get("body_count") == 0 and after.get("terrain_count") == 0
               and after.get("space_valid") is False and after.get("thread_started") is False
               and after.get("worker", {}).get("stopped") is True
               and after.get("worker", {}).get("terminal", {}).get("outcome") == "Stopped",
               "Navigation actual native/RID/thread disposition: " + row["case"])
    children = [row for row in parent.get("observations", []) if row.get("case") == "window_close_upgrade"]
    expect(len(children) == 1, "Exactly one actual window-close child")
    childrow = children[0]
    child = json.loads(read("worker-navigation-quit-child.json"))
    expect(child == childrow.get("child_report"), "Child standalone report equals parent-observed report")
    expect(child.get("schema") == "objectshard-worker-navigation-quit-child-v1" and child.get("source_revision") == source,
           "Navigation child exact schema/source")
    expect(type(child.get("checks")) is int and child["checks"] >= 18 and type(child.get("failures")) is int and child["failures"] == 0,
           "Navigation child complete successful assertions")
    childassertions = [row for row in child.get("observations", []) if "check" in row]
    expect(len(childassertions) == child["checks"] and all(row.get("passed") is True for row in childassertions), "Every retained child assertion actually passed")
    expect(type(childrow.get("child_exit_code")) is int and childrow["child_exit_code"] == 0, "Actual child exited successfully")
    logname = PurePosixPath(childrow["child_output_log"].replace("\\", "/")).name
    expect(logname == "worker-navigation-quit-child.json.log", "Expected source-bound child log member")
    log = read(logname)
    expect(hashlib.sha256(log).hexdigest() == childrow.get("child_output_sha256"), "Child actual output log hash")
    receipts = []
    for line in log.decode("utf-8", errors="replace").splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and value.get("schema") == child["schema"]:
            receipts.append(value)
    expect(receipts == [{"schema": child["schema"], "checks": child["checks"], "failures": child["failures"]}], "Child footer exact successful receipt")
    expect(re.search(rb"(?:SCRIPT ERROR|ERROR):", log) is None, "No error in actual quit child output")
    report.update(status="passed" if not report["failures"] else "failed", cases=EXPECTED, parent_checks=parent["checks"],
                  child_checks=child["checks"], child_exit_code=childrow["child_exit_code"], child_log_sha256=hashlib.sha256(log).hexdigest(),
                  scope="Eight actual autoload/F2/launcher lifecycle cases; real quit child; injected stop-status delivery is expressly distinguished from native disposal failure")
    return report
