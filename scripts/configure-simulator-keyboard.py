#!/usr/bin/env python3
"""Set keyboard fixture intent on an exclusive disposable CI runner, before boot.

No Simulator or DeviceHub frontend may be running, and the selected simulator
must be Shutdown. Full-domain imports require exclusive ownership of these
preferences; another writer could otherwise lose updates. Imports across the two
domains are not atomic: any failure aborts the fixture and must prevent testing.
This configures three Boolean values, not proof of effective keyboard behavior.
"""

import argparse
import copy
import json
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
from uuid import UUID
from xml.parsers.expat import ExpatError


class FixtureError(RuntimeError):
    """A failed fixture boundary that must stop CI before native tests."""


def execute(arguments, *, input_data=None, allowed=(0,)):
    """Run one bounded native command; preserve unexpected failures as errors."""
    try:
        result = subprocess.run(arguments, input=input_data, capture_output=True,
                                timeout=30, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise FixtureError(f"Cannot run {arguments[0]}: {error}") from error
    if result.returncode not in allowed:
        detail = result.stderr.decode(errors="replace").strip()[:1200]
        raise FixtureError(f"{' '.join(arguments)} failed ({result.returncode}): {detail}")
    return result


def require_shutdown_fixture(selected):
    """Refuse active frontends or a missing, unavailable, or booted selected device."""
    for frontend in ("DeviceHub", "Simulator"):
        result = execute(["pgrep", "-x", frontend], allowed=(0, 1))
        if result.returncode == 0:
            raise FixtureError(f"{frontend} is running; use a fresh exclusive disposable runner")
    result = execute(["xcrun", "simctl", "list", "devices", "available", "--json"])
    try:
        devices = json.loads(result.stdout)["devices"]
        if not isinstance(devices, dict) or any(not isinstance(rows, list) for rows in devices.values()):
            raise ValueError("invalid device-list shape")
        matches = [row for rows in devices.values() for row in rows
                   if isinstance(row, dict) and isinstance(row.get("udid"), str)
                   and row["udid"].upper() == selected]
    except (ValueError, KeyError, TypeError) as error:
        raise FixtureError(f"Cannot parse the simulator device list: {error}") from error
    if len(matches) != 1 or matches[0].get("isAvailable") is not True:
        raise FixtureError(f"Selected simulator {selected} must exist exactly once and be available")
    if matches[0].get("state") != "Shutdown":
        raise FixtureError(f"Selected simulator {selected} must be Shutdown before configuring preferences")


def encoded(preferences):
    """Canonical XML preserves plist types, including the distinction between 0 and false."""
    try:
        return plistlib.dumps(preferences, sort_keys=True)
    except (ValueError, TypeError, OverflowError) as error:
        raise FixtureError(f"Cannot encode preference values: {error}") from error


def validate_preferences(preferences, selected, label):
    """Reject incompatible dictionaries before any preference writes."""
    if not isinstance(preferences, dict):
        raise FixtureError(f"{label}: preferences must be a plist dictionary")
    if "DevicePreferences" in preferences:
        devices = preferences["DevicePreferences"]
        if not isinstance(devices, dict):
            raise FixtureError(f"{label}: DevicePreferences must be a dictionary")
        if selected in devices and not isinstance(devices[selected], dict):
            raise FixtureError(f"{label}: the selected DevicePreferences entry must be a dictionary")


def read_preferences(path, selected):
    """Preflight existing regular readable plists and require native export to agree with disk."""
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        return {}
    except OSError as error:
        raise FixtureError(f"Cannot inspect {path}: {error}") from error
    if not stat.S_ISREG(metadata.st_mode) or not os.access(path, os.R_OK):
        raise FixtureError(f"{path}: existing preferences must be a regular readable file")
    try:
        on_disk = plistlib.loads(path.read_bytes())
    except (OSError, ValueError, plistlib.InvalidFileException, ExpatError) as error:
        raise FixtureError(f"Cannot read a valid plist at {path}: {error}") from error
    validate_preferences(on_disk, selected, str(path))
    exported = export_preferences(path, selected)
    if encoded(exported) != encoded(on_disk):
        raise FixtureError(f"{path}: native export differs from disk; refusing to overwrite possibly concurrent updates")
    return exported


def export_preferences(path, selected):
    """Read the native domain as a typed dictionary; parse and access failures are fatal."""
    result = execute(["defaults", "export", str(path), "-"])
    try:
        preferences = plistlib.loads(result.stdout)
    except (ValueError, plistlib.InvalidFileException, ExpatError) as error:
        raise FixtureError(f"Cannot parse exported preferences from {path}: {error}") from error
    validate_preferences(preferences, selected, str(path))
    return preferences


def import_and_verify(path, preferences, selected):
    """Import a prepared full domain and reject any readback value or type difference."""
    execute(["defaults", "import", str(path), "-"], input_data=encoded(preferences))
    actual = export_preferences(path, selected)
    if encoded(actual) != encoded(preferences):
        raise FixtureError(f"{path}: imported readback differs in values or types; abort this disposable fixture")


def configure(selected, home):
    """Preserve both domains while setting only common, selected-device, and DeviceHub keyboard false."""
    try:
        parsed = UUID(selected)
        if str(parsed).lower() != selected.lower():
            raise ValueError("use the hyphenated simulator UUID")
    except (ValueError, AttributeError) as error:
        raise FixtureError(f"Invalid simulator UUID: {selected}") from error
    selected = str(parsed).upper()
    require_shutdown_fixture(selected)
    print(f"Selected simulator {selected}: Shutdown; DeviceHub and Simulator frontends: not running")
    legacy_path = home / "Library/Preferences/com.apple.iphonesimulator.plist"
    hub_path = home / "Library/Containers/com.apple.dt.Devices/Data/Library/Preferences/com.apple.dt.Devices.plist"
    # Current maintainer writes all three locations before choosing its boot lifecycle.
    # https://github.com/appium/appium-ios/blob/main/packages/simulator/lib/extensions/settings.ts
    legacy = copy.deepcopy(read_preferences(legacy_path, selected))
    hub = copy.deepcopy(read_preferences(hub_path, selected))
    legacy["ConnectHardwareKeyboard"] = False
    legacy.setdefault("DevicePreferences", {}).setdefault(selected, {})["ConnectHardwareKeyboard"] = False
    hub["alwaysSimulateHardwareKeyboard"] = False
    prepared = [(legacy_path, legacy), (hub_path, hub)]
    # Finish both preflights and recheck shutdown ownership before initializing cold paths.
    for path, preferences in prepared:
        require_shutdown_fixture(selected)
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
        except OSError as error:
            raise FixtureError(f"Cannot initialize {path.parent}: {error}") from error
        import_and_verify(path, preferences, selected)
    print("Verified three typed Boolean false values with all unrelated preferences preserved.")
    print("Configured intent verified before frontend startup; native tests must prove keyboard behavior.")


def main():
    """Restrict the owner-home mutation entrypoint to CI and fail actionably before boot."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("simulator_uuid")
    args = parser.parse_args()
    try:
        if os.environ.get("GITHUB_ACTIONS") != "true":
            raise FixtureError("This helper may only run on an exclusive disposable GitHub Actions runner")
        configure(args.simulator_uuid, Path.home())
    except (FixtureError, OSError) as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
