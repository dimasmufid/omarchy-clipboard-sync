from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "scripts" / "clipboard-sync-adapter"
FAKE_CLI = ROOT / "tests" / "fixtures" / "fake-kdeconnect-cli"
FAKE_PASTE = ROOT / "tests" / "fixtures" / "fake-wl-paste"
DEVICE_ID = "a" * 32


class AdapterTests(unittest.TestCase):
    def invoke(self, *args: str, scenario: str = "online", clipboard: str = "text", extra_env=None):
        env = os.environ.copy()
        env.update(
            {
                "CLIPBOARD_SYNC_KDECONNECT_CLI": str(FAKE_CLI),
                "CLIPBOARD_SYNC_WL_PASTE": str(FAKE_PASTE),
                "CLIPBOARD_SYNC_TEST_SCENARIO": scenario,
                "CLIPBOARD_SYNC_TEST_CLIPBOARD": clipboard,
                "CLIPBOARD_SYNC_TEST_DEVICE_ID": DEVICE_ID,
                "CLIPBOARD_SYNC_TIMEOUT": "0.2",
                "CLIPBOARD_SYNC_PAIR_TIMEOUT": "0.3",
            }
        )
        if extra_env:
            env.update(extra_env)
        completed = subprocess.run(
            [str(ADAPTER), *args],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
            timeout=5,
            check=False,
        )
        self.assertEqual(completed.stderr, "")
        return completed, json.loads(completed.stdout)

    def test_doctor(self):
        completed, payload = self.invoke("doctor")
        self.assertEqual(completed.returncode, 0)
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["data"]["state"], "ready")
        self.assertIn("24.12.0", payload["data"]["kdeconnectVersion"])

    def test_missing_dependency_is_structured(self):
        completed, payload = self.invoke(
            "doctor",
            extra_env={"CLIPBOARD_SYNC_KDECONNECT_CLI": "/definitely/missing"},
        )
        self.assertEqual(completed.returncode, 3)
        self.assertEqual(payload["error"]["code"], "DEPENDENCY_MISSING")

    def test_lists_device_states(self):
        completed, payload = self.invoke("devices", scenario="duplicate-names")
        self.assertEqual(completed.returncode, 0)
        devices = payload["data"]["devices"]
        self.assertEqual(len(devices), 2)
        self.assertTrue(devices[0]["paired"])
        self.assertTrue(devices[0]["reachable"])
        self.assertFalse(devices[1]["reachable"])
        self.assertNotEqual(devices[0]["id"], devices[1]["id"])

    def test_available_set_overrides_human_readable_detail(self):
        completed, payload = self.invoke("devices", scenario="available-overrides-detail")
        self.assertEqual(completed.returncode, 0)
        device = payload["data"]["devices"][0]
        self.assertTrue(device["paired"])
        self.assertTrue(device["reachable"])

    def test_unicode_and_metacharacters_are_data(self):
        name = "Phone $(touch nope) ' 👋"
        completed, payload = self.invoke(
            "devices",
            extra_env={"CLIPBOARD_SYNC_TEST_DEVICE_NAME": name},
        )
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(payload["data"]["devices"][0]["name"], name)

    def test_malformed_device_output_is_rejected(self):
        completed, payload = self.invoke("devices", scenario="malformed")
        self.assertEqual(completed.returncode, 3)
        self.assertEqual(payload["error"]["code"], "UNSUPPORTED_VERSION")

    def test_daemon_error_is_classified(self):
        completed, payload = self.invoke("devices", scenario="daemon-error")
        self.assertEqual(completed.returncode, 3)
        self.assertEqual(payload["error"]["code"], "DAEMON_UNAVAILABLE")
        self.assertTrue(payload["error"]["retryable"])

    def test_invalid_device_id_never_reaches_cli(self):
        completed, payload = self.invoke("send", "--device-id", "$(touch nope)")
        self.assertEqual(completed.returncode, 2)
        self.assertEqual(payload["error"]["code"], "INVALID_ARGUMENT")

    def test_send_text(self):
        completed, payload = self.invoke("send", "--device-id", DEVICE_ID)
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(payload["data"]["state"], "sent-to-kde-connect")
        self.assertEqual(payload["data"]["sizeBytes"], len("hello from omarchy"))
        self.assertNotIn("hello from omarchy", completed.stdout)

    def test_send_unicode_counts_utf8_bytes(self):
        completed, payload = self.invoke("send", "--device-id", DEVICE_ID, clipboard="unicode")
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(payload["data"]["sizeBytes"], len("Halo 👋 世界".encode()))

    def test_empty_clipboard(self):
        completed, payload = self.invoke("send", "--device-id", DEVICE_ID, clipboard="empty")
        self.assertEqual(completed.returncode, 5)
        self.assertEqual(payload["error"]["code"], "CLIPBOARD_EMPTY")

    def test_non_text_clipboard(self):
        completed, payload = self.invoke("send", "--device-id", DEVICE_ID, clipboard="image")
        self.assertEqual(completed.returncode, 5)
        self.assertEqual(payload["error"]["code"], "CLIPBOARD_NOT_TEXT")

    def test_mixed_clipboard_uses_plain_text(self):
        completed, payload = self.invoke("send", "--device-id", DEVICE_ID, clipboard="mixed")
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(payload["data"]["state"], "sent-to-kde-connect")

    def test_exact_size_limit_is_accepted(self):
        completed, payload = self.invoke("send", "--device-id", DEVICE_ID, clipboard="exact-limit")
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(payload["data"]["sizeBytes"], 65536)

    def test_oversized_clipboard(self):
        completed, payload = self.invoke("send", "--device-id", DEVICE_ID, clipboard="oversized")
        self.assertEqual(completed.returncode, 5)
        self.assertEqual(payload["error"]["code"], "CLIPBOARD_TOO_LARGE")

    def test_invalid_utf8_clipboard(self):
        completed, payload = self.invoke("send", "--device-id", DEVICE_ID, clipboard="invalid")
        self.assertEqual(completed.returncode, 5)
        self.assertEqual(payload["error"]["code"], "CLIPBOARD_NOT_TEXT")

    def test_unpaired_and_offline_are_distinct(self):
        unpaired_completed, unpaired_payload = self.invoke(
            "send", "--device-id", DEVICE_ID, scenario="unpaired"
        )
        offline_completed, offline_payload = self.invoke(
            "send", "--device-id", DEVICE_ID, scenario="offline"
        )
        self.assertEqual(unpaired_completed.returncode, 4)
        self.assertEqual(unpaired_payload["error"]["code"], "DEVICE_UNPAIRED")
        self.assertEqual(offline_completed.returncode, 4)
        self.assertEqual(offline_payload["error"]["code"], "DEVICE_OFFLINE")

    def test_pair_acceptance(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = str(Path(temporary) / "paired")
            completed, payload = self.invoke(
                "pair",
                "--device-id",
                DEVICE_ID,
                scenario="pairable",
                extra_env={"CLIPBOARD_SYNC_TEST_STATE_FILE": state},
            )
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(payload["data"]["state"], "paired")

    def test_pair_rejection(self):
        completed, payload = self.invoke(
            "pair", "--device-id", DEVICE_ID, scenario="pair-rejected"
        )
        self.assertEqual(completed.returncode, 4)
        self.assertEqual(payload["error"]["code"], "PAIR_REJECTED")

    def test_pair_timeout(self):
        completed, payload = self.invoke(
            "pair", "--device-id", DEVICE_ID, scenario="pair-timeout"
        )
        self.assertEqual(completed.returncode, 6)
        self.assertEqual(payload["error"]["code"], "PAIR_TIMEOUT")

    def test_unpair(self):
        completed, payload = self.invoke("unpair", "--device-id", DEVICE_ID)
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(payload["data"]["state"], "unpaired")

    def test_timeout_is_structured(self):
        completed, payload = self.invoke("devices", scenario="timeout")
        self.assertEqual(completed.returncode, 6)
        self.assertEqual(payload["error"]["code"], "OPERATION_TIMEOUT")

    def test_no_devices_is_success(self):
        completed, payload = self.invoke("devices", scenario="no-devices")
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(payload["data"]["devices"], [])

    def test_refresh_returns_devices(self):
        completed, payload = self.invoke("refresh")
        self.assertEqual(completed.returncode, 0)
        self.assertEqual(len(payload["data"]["devices"]), 1)

    def test_unknown_device(self):
        completed, payload = self.invoke(
            "send", "--device-id", "b" * 32, scenario="offline"
        )
        self.assertEqual(completed.returncode, 4)
        self.assertEqual(payload["error"]["code"], "DEVICE_NOT_FOUND")


if __name__ == "__main__":
    unittest.main()
