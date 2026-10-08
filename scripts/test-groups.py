#!/usr/bin/env python3
"""Validate CI groups, emit selectors, and require complete xcresult case coverage."""

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlparse
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
UNIT_TARGET = "EstimateMyMortgageTests"
UI_TARGET = "EstimateMyMortgageUITests"


def unique_object(pairs):
    """Reject duplicate JSON keys rather than silently replacing a group."""
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate manifest key: {key}")
        result[key] = value
    return result


def source_cases(directory):
    """Read class/method IDs from the repository's one-XCTestCase-per-file sources."""
    cases = []
    for path in sorted(directory.rglob("*.swift")):
        source = path.read_text()
        methods = re.findall(r"^\s*func\s+(test\w+)\s*\(", source, re.MULTILINE)
        if not methods:
            continue
        classes = re.findall(r"\bclass\s+(\w+)\s*:\s*XCTestCase\b", source)
        if len(classes) != 1:
            raise ValueError(f"{path.name}: expected one XCTestCase class for test methods")
        cases.extend(f"{classes[0]}/{method}" for method in methods)
    if not cases or len(cases) != len(set(cases)):
        raise ValueError(f"{directory.name}: expected nonempty, unique class/method test IDs")
    return cases


def validate_groups(groups, ui_cases):
    """Require one whole unit target and three exhaustive, disjoint UI groups."""
    if not isinstance(groups, dict) or len(groups) != 4:
        raise ValueError("Manifest must contain exactly four test groups")
    unit_groups = 0
    ui_groups = 0
    assigned = []
    for name, group in groups.items():
        if name == "all" or not re.fullmatch(r"[a-z][a-z0-9-]*", name):
            raise ValueError(f"Invalid group name: {name!r}")
        if not isinstance(group, dict):
            raise ValueError(f"Group {name} must be an object")
        if group.get("target") == UNIT_TARGET:
            if set(group) != {"target"}:
                raise ValueError(f"Group {name} must select the whole unit target")
            unit_groups += 1
        elif group.get("target") == UI_TARGET:
            tests = group.get("tests")
            if set(group) != {"target", "tests"} or not isinstance(tests, list) or not tests:
                raise ValueError(f"Group {name} must contain a nonempty UI test list")
            if any(not isinstance(test, str) or not re.fullmatch(r"\w+/test\w+", test) for test in tests):
                raise ValueError(f"Group {name} contains an invalid class/method test ID")
            ui_groups += 1
            assigned.extend(tests)
        else:
            raise ValueError(f"Group {name} has an unknown test target")
    if unit_groups != 1 or ui_groups != 3:
        raise ValueError("Manifest must select the unit target once and have three UI groups")
    duplicates = sorted(test for test, count in Counter(assigned).items() if count > 1)
    missing = sorted(set(ui_cases) - set(assigned))
    unknown = sorted(set(assigned) - set(ui_cases))
    if duplicates or missing or unknown:
        raise ValueError(f"Invalid UI partition: duplicates={duplicates}, missing={missing}, unknown={unknown}")


def load_contract():
    """Validate the manifest against current source classes and enabled scheme targets."""
    groups = json.loads((ROOT / "scripts/test-groups.json").read_text(), object_pairs_hook=unique_object)
    scheme = ET.parse(ROOT / "EstimateMyMortgage.xcodeproj/xcshareddata/xcschemes/EstimateMyMortgage.xcscheme")
    testables = scheme.findall("./TestAction/Testables/TestableReference")
    targets = []
    for testable in testables:
        if testable.get("skipped") == "NO":
            reference = testable.find("BuildableReference")
            if reference is None:
                raise ValueError("An enabled scheme test target has no BuildableReference")
            targets.append(reference.get("BlueprintName"))
    if Counter(targets) != Counter([UNIT_TARGET, UI_TARGET]):
        raise ValueError("The shared scheme must enable each declared test target exactly once")
    sources = {UNIT_TARGET: source_cases(ROOT / "Tests"), UI_TARGET: source_cases(ROOT / "UITests")}
    validate_groups(groups, sources[UI_TARGET])
    return groups, sources


def selectors(groups, name):
    """Return xcodebuild arguments; all keeps the scheme's default full suite."""
    if name == "all":
        return []
    if name not in groups:
        raise ValueError(f"Unknown test group {name!r}; choose all or {', '.join(groups)}")
    group = groups[name]
    target = group["target"]
    if target == UNIT_TARGET:
        return [f"-only-testing:{target}"]
    return [f"-only-testing:{target}/{test}" for test in group["tests"]]


def expected_cases(groups, sources, name):
    """Return full target/class/method IDs for the selected group or entire scheme."""
    selectors(groups, name)
    if name == "all":
        return {f"{target}/{case}" for target, cases in sources.items() for case in cases}
    group = groups[name]
    target = group["target"]
    cases = sources[target] if target == UNIT_TARGET else group["tests"]
    return {f"{target}/{case}" for case in cases}


def validate_result(expected, report):
    """Require exact terminal-case coverage and reject reported test failures."""
    actual = set()
    failed = []

    def visit(nodes):
        for node in nodes:
            if node.get("nodeType") == "Test Case":
                url = urlparse(node.get("nodeIdentifierURL", ""))
                parts = url.path.strip("/").split("/")
                if url.scheme != "test" or url.netloc != "com.apple.xcode" or len(parts) != 4:
                    raise ValueError("xcresult contains an invalid target/class/method identifier URL")
                _, target, test_class, method = parts
                if node.get("nodeIdentifier") != f"{test_class}/{method}()":
                    raise ValueError("xcresult case identifier disagrees with its class/method URL")
                if node.get("result") not in {"Passed", "Failed", "Skipped"}:
                    raise ValueError(f"xcresult case {target}/{test_class}/{method} was not completed")
                identifier = f"{target}/{test_class}/{method}"
                if identifier in actual:
                    raise ValueError(f"xcresult contains a duplicate case: {identifier}")
                # Failed attempts count toward coverage, but cannot make a run green.
                actual.add(identifier)
                if node["result"] == "Failed":
                    failed.append(identifier)
            visit(node.get("children", []))

    visit(report.get("testNodes", []))
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    if missing or unexpected:
        raise ValueError(f"Incomplete selected run: missing={missing}, unexpected={unexpected}")
    if failed:
        raise ValueError(f"xcresult reports failed cases: {sorted(failed)}")
    return len(actual)


def check_result(expected, path):
    """Read the native test report; missing/unreadable result bundles fail validation."""
    result = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(path), "--compact"],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        raise ValueError(f"Cannot read xcresult (exit {result.returncode}): {result.stderr.strip()}")
    return validate_result(expected, json.loads(result.stdout))


def main():
    """Validate before emitting selectors, matrix names, or a result coverage check."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("group", nargs="?", default="all")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--list-groups", action="store_true")
    mode.add_argument("--validate", action="store_true")
    mode.add_argument("--check-result", type=Path)
    args = parser.parse_args()
    try:
        groups, sources = load_contract()
        selected = selectors(groups, args.group)
        if args.list_groups:
            print(json.dumps(list(groups)))
        elif args.validate:
            print(f"Validated {len(groups)} groups: {len(sources[UNIT_TARGET])} unit tests and {len(sources[UI_TARGET])} UI tests assigned exactly once")
        elif args.check_result:
            count = check_result(expected_cases(groups, sources, args.group), args.check_result)
            print(f"Verified {count} attempted cases for group {args.group}")
        else:
            for selector in selected:
                print(selector)
    except (OSError, ValueError, ET.ParseError) as error:
        print(f"Test group validation failed: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
