"""Offline checks: unavailable data and absent restart evidence must not pass."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from recovery_diagnostics import decode, require_completed_delta


class RecoveryDiagnosticsTest(unittest.TestCase):
    def page(self, count=0, status=0, cause=0):
        return decode([0x52430001, 1, count, count,
                       (0xF << 16) | (status << 8) | cause, count, 0, 0])

    def test_unavailable_integrity(self):
        self.assertIsNone(self.page()["integrity_count"])
        self.assertIsNone(self.page()["integrity_state"])
        self.assertIsNone(self.page()["integrity"])

    def test_integrity_state(self):
        state = ((1 << 15) | (0xF << 11) | (1 << 10) |
                 (0x4 << 6) | (1 << 5) | (0x2 << 1) | 1)
        page = decode([0x52430001, 3, 0, 0, 0, 0, 7, state])
        self.assertEqual(page["integrity_count"], 7)
        self.assertEqual(page["integrity"], {
            "fault": True, "error_fault_lanes": 2,
            "clock_fault": True, "retained_error_lanes": 4,
            "retained_clock_fault": True, "selected_lanes": 15,
            "monitor_enabled": True,
        })

    def test_heartbeat_test_capability(self):
        page = decode([0x52430001, 7, 0, 0, 0, 0, 0, 0])
        self.assertTrue(page["heartbeat_test_hook"])

    def test_exact_evidence(self):
        require_completed_delta(self.page(), self.page(1, 3, 2), 1, 2)

    def test_reject_weak_or_ambiguous_evidence(self):
        for after in (self.page(), self.page(2, 3, 2), self.page(1, 2, 2),
                      self.page(1, 3, 3), self.page(0xFFFFFFFF, 3, 2)):
            with self.assertRaises(RuntimeError):
                require_completed_delta(self.page(), after, 1, 2)
        with self.assertRaises(RuntimeError):
            require_completed_delta(self.page(2), self.page(1, 3, 2), 1, 2)

    def test_missing_completion(self):
        after = self.page(1, 3, 2)
        after["completed"] = 0
        with self.assertRaises(RuntimeError):
            require_completed_delta(self.page(), after, 1, 2)

    def test_unknown_schema(self):
        with self.assertRaises(ValueError):
            decode([0] * 8)


if __name__ == "__main__":
    unittest.main()
