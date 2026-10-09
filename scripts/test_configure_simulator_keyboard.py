"""Exercise fixture preservation and fail-closed boundaries with private files and fake commands."""

from contextlib import redirect_stdout
import copy
from datetime import datetime
import importlib.util
import io
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location("keyboard_fixture", Path(__file__).with_name("configure-simulator-keyboard.py"))
fixture = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fixture)
SELECTED = "11111111-1111-4111-8111-111111111111"
OTHER = "22222222-2222-4222-8222-222222222222"


class KeyboardFixtureTests(unittest.TestCase):
    """No native commands or owner preferences are accessed by these tests."""

    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="emm-keyboard-test-")
        self.addCleanup(self.scratch.cleanup)
        self.home = Path(self.scratch.name)
        self.legacy = self.home / "Library/Preferences/com.apple.iphonesimulator.plist"
        self.hub = self.home / "Library/Containers/com.apple.dt.Devices/Data/Library/Preferences/com.apple.dt.Devices.plist"
        self.calls = []
        self.frontends = {"DeviceHub": 1, "Simulator": 1}
        self.state = "Shutdown"
        self.available = True
        self.command_fault = None
        self.export_override = None
        self.boot_on_second_check = False
        self.checks = 0
        self.devices_payload = None
        self.output = io.StringIO()
        self.addCleanup(patch.stopall)
        patch.object(fixture.subprocess, "run", side_effect=self.native).start()

    def native(self, arguments, *, input, capture_output, timeout, check):
        """Keep fake command behavior at the native boundary, including import/export bytes."""
        self.calls.append(arguments)
        self.assertTrue(capture_output)
        self.assertEqual(timeout, 30)
        self.assertFalse(check)
        code, stdout, stderr = 0, b"", b""
        if self.command_fault and self.command_fault(arguments):
            return subprocess.CompletedProcess(arguments, 2, b"", b"injected native failure")
        if arguments[0] == "pgrep":
            self.assertEqual(arguments[1], "-x")
            code = self.frontends[arguments[2]]
            stdout = b"1234\n" if code == 0 else b""
        elif arguments[0] == "xcrun":
            self.assertEqual(arguments[1:], ["simctl", "list", "devices", "available", "--json"])
            self.checks += 1
            state = "Booted" if self.boot_on_second_check and self.checks > 1 else self.state
            stdout = json.dumps({"devices": {"iOS-27-0": [{"udid": SELECTED, "state": state,
                                                         "isAvailable": self.available}]}}).encode()
            if self.devices_payload is not None:
                stdout = self.devices_payload
        else:
            self.assertEqual(arguments[0], "defaults")
            self.assertEqual(arguments[-1], "-")
            path = Path(arguments[2])
            self.assertIn(path, (self.legacy, self.hub))
            if arguments[1] == "import":
                path.write_bytes(input)
            else:
                self.assertEqual(arguments[1], "export")
                stdout = path.read_bytes()
                if self.export_override:
                    stdout = self.export_override(path, stdout)
        return subprocess.CompletedProcess(arguments, code, stdout, stderr)

    def seed(self, path, preferences):
        """Create only task-private initial plist data."""
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(plistlib.dumps(preferences))

    def configure(self, selected=SELECTED.lower()):
        with redirect_stdout(self.output):
            fixture.configure(selected, self.home)

    def assert_no_imports(self):
        self.assertFalse(any(command[:2] == ["defaults", "import"] for command in self.calls))

    def test_preserves_common_selected_other_device_types_and_is_idempotent(self):
        legacy = {"ConnectHardwareKeyboard": True, "Unrelated": [b"bytes", datetime(2026, 1, 1), 0, False],
                  "DevicePreferences": {SELECTED: {"ConnectHardwareKeyboard": True, "Scale": 0.75},
                                        OTHER: {"ConnectHardwareKeyboard": True, "Other": "keep"}}}
        hub = {"alwaysSimulateHardwareKeyboard": True, "Shared": "keep",
               "DevicePreferences": {SELECTED: {"pasteboardSyncEnabled": False}, OTHER: {"keep": 1}}}
        self.seed(self.legacy, legacy)
        self.seed(self.hub, hub)
        expected_legacy, expected_hub = copy.deepcopy(legacy), copy.deepcopy(hub)
        expected_legacy["ConnectHardwareKeyboard"] = False
        expected_legacy["DevicePreferences"][SELECTED]["ConnectHardwareKeyboard"] = False
        expected_hub["alwaysSimulateHardwareKeyboard"] = False
        self.configure()
        self.assertEqual(self.legacy.read_bytes(), fixture.encoded(expected_legacy))
        self.assertEqual(self.hub.read_bytes(), fixture.encoded(expected_hub))
        first = (self.legacy.read_bytes(), self.hub.read_bytes())
        self.configure()
        self.assertEqual(first, (self.legacy.read_bytes(), self.hub.read_bytes()))

    def test_cold_paths_create_only_three_boolean_values(self):
        self.configure()
        self.assertEqual(plistlib.loads(self.legacy.read_bytes()),
                         {"ConnectHardwareKeyboard": False, "DevicePreferences": {SELECTED: {"ConnectHardwareKeyboard": False}}})
        self.assertIs(plistlib.loads(self.hub.read_bytes())["alwaysSimulateHardwareKeyboard"], False)

    def test_invalid_uuid_frontend_running_or_process_error_never_initializes_paths(self):
        for invalid in ("not-a-uuid", SELECTED.replace("-", "")):
            with self.subTest(invalid=invalid), self.assertRaises(fixture.FixtureError):
                self.configure(invalid)
        self.assertEqual(self.calls, [])
        for frontend in self.frontends:
            for code in (0, 2):
                with self.subTest(frontend=frontend, code=code):
                    self.frontends[frontend] = code
                    with self.assertRaises(fixture.FixtureError):
                        self.configure()
                    self.frontends[frontend] = 1
        self.assertFalse((self.home / "Library").exists())
        self.assert_no_imports()

    def test_booted_unavailable_or_reboot_during_preflight_refuses_cold_writes(self):
        self.state = "Booted"
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.state, self.available = "Shutdown", False
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.available, self.checks, self.boot_on_second_check = True, 0, True
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.assertFalse((self.home / "Library").exists())
        self.assert_no_imports()

    def test_malformed_second_domain_prevents_all_imports(self):
        self.seed(self.legacy, {"keep": "unchanged"})
        before = self.legacy.read_bytes()
        self.hub.parent.mkdir(parents=True)
        self.hub.write_bytes(b"<?xml version='1.0'?><plist><dict>")
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.assertEqual(self.legacy.read_bytes(), before)
        self.assert_no_imports()

    def test_invalid_dictionary_shapes_fail_before_import(self):
        for path in (self.legacy, self.hub):
            for invalid in ([], {"DevicePreferences": []}, {"DevicePreferences": {SELECTED: "wrong"}}):
                with self.subTest(path=path.name, shape=invalid):
                    self.seed(path, invalid)
                    with self.assertRaises(fixture.FixtureError): self.configure()
                    self.assert_no_imports()
                    path.unlink()

    def test_symlink_directory_and_unreadable_existing_file_are_rejected(self):
        self.hub.parent.mkdir(parents=True)
        self.hub.mkdir()
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.hub.rmdir()
        target = self.home / "unrelated.plist"
        self.seed(target, {"keep": "safe"})
        self.hub.symlink_to(target)
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.hub.unlink()
        self.seed(self.hub, {})
        with patch.object(fixture.os, "access", return_value=False), self.assertRaises(fixture.FixtureError):
            self.configure()
        self.assert_no_imports()
        self.assertEqual(plistlib.loads(target.read_bytes()), {"keep": "safe"})

    def test_native_export_disagreement_or_failure_prevents_writes(self):
        self.seed(self.legacy, {"keep": "safe"})
        self.export_override = lambda path, data: plistlib.dumps({"keep": "concurrent value"})
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.export_override = None
        self.command_fault = lambda args: args[:2] == ["defaults", "export"]
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.assert_no_imports()
        self.assertEqual(plistlib.loads(self.legacy.read_bytes()), {"keep": "safe"})

    def test_import_error_and_unparseable_export_stop_fixture(self):
        self.command_fault = lambda args: args[:2] == ["defaults", "import"]
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.command_fault = None
        self.export_override = lambda path, data: b"<?xml version='1.0'?><plist><dict>"
        with self.assertRaises(fixture.FixtureError): self.configure()

    def test_integer_zero_readback_cannot_pass_boolean_false_check(self):
        def substitute(path, data):
            values = plistlib.loads(data)
            values["ConnectHardwareKeyboard"] = 0
            return plistlib.dumps(values)
        self.export_override = substitute
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.assertFalse(self.hub.exists())

    def test_readback_loss_of_unrelated_setting_aborts_before_second_import(self):
        self.seed(self.legacy, {"Keep": "unchanged"})
        def drop_after_import(path, data):
            if any(args[:2] == ["defaults", "import"] for args in self.calls):
                preferences = plistlib.loads(data)
                del preferences["Keep"]
                return plistlib.dumps(preferences)
            return data
        self.export_override = drop_after_import
        with self.assertRaises(fixture.FixtureError): self.configure()
        self.assertFalse(self.hub.exists())

    def test_second_domain_import_failure_is_not_reported_as_success(self):
        self.seed(self.legacy, {"Keep": "unchanged"})
        self.command_fault = lambda args: args[:3] == ["defaults", "import", str(self.hub)]
        with self.assertRaises(fixture.FixtureError): self.configure()
        actual = plistlib.loads(self.legacy.read_bytes())
        self.assertIs(actual["ConnectHardwareKeyboard"], False)
        self.assertEqual(actual["Keep"], "unchanged")
        self.assertFalse(self.hub.exists())
        self.assertNotIn("Verified three", self.output.getvalue())

    def test_command_timeout_and_invalid_simulator_json_are_actionable(self):
        with patch.object(fixture.subprocess, "run", side_effect=subprocess.TimeoutExpired("pgrep", 30)):
            with self.assertRaises(fixture.FixtureError): self.configure()
        for payload in (b"invalid json", b'{}', b'{"devices": []}', b'{"devices": {"iOS-27-0": []}}'):
            with self.subTest(payload=payload):
                self.devices_payload = payload
                with self.assertRaises(fixture.FixtureError): self.configure()
        self.assert_no_imports()

    def test_cli_refuses_non_ci_without_commands(self):
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}), patch.object(fixture.sys, "argv", ["fixture", SELECTED]), \
                redirect_stdout(self.output), patch.object(fixture.sys, "stderr", self.output):
            self.assertEqual(fixture.main(), 1)
        self.assertEqual(self.calls, [])


if __name__ == "__main__":
    unittest.main()
