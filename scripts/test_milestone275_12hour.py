"""Offline tests for the fixed v275 soak operator."""
import sys
import unittest
from unittest.mock import Mock, patch

import milestone275_12hour as operator


class Milestone275SoakTests(unittest.TestCase):
    def test_start_is_fully_fixed(self):
        mailbox = Mock()
        mailbox.read_u32.return_value = operator.PREVIOUS_RUN_ID
        overview = {
            "firmware version": operator.VERSION,
            "hardware version": operator.VERSION,
            "engine state": 0,
            "request sequence": operator.PREVIOUS_SEQUENCE,
            "response sequence": operator.PREVIOUS_SEQUENCE,
            "response code": operator.soak.SUMMARY_NORMAL_FOUR_LANES,
            "hardware run ID": operator.PREVIOUS_RUN_ID,
            "hardware summary": operator.soak.SUMMARY_NORMAL_FOUR_LANES,
        }
        with patch.object(sys, "argv", ["milestone275_12hour", "start"]):
            with patch.object(operator, "fixed_mailbox", return_value=mailbox):
                with patch.object(operator.soak, "read_overview", return_value=overview):
                    with patch.object(operator.soak, "expect"):
                        with patch.object(operator.soak, "start_soak") as start:
                            self.assertEqual(operator.main(), 0)
        start.assert_called_once_with(
            mailbox, 3, 2, 43200000,
            "v275 sequence-3 12-hour external qualification soak",
            0x0000F000)

    def test_extra_argument_is_rejected_before_board_access(self):
        with patch.object(sys, "argv", ["milestone275_12hour", "start",
                                        "--sequence", "4"]):
            with patch.object(operator, "fixed_mailbox") as mailbox:
                with self.assertRaises(SystemExit):
                    operator.main()
                mailbox.assert_not_called()

    def test_running_status_keeps_previous_published_run_id(self):
        mailbox = Mock()
        overview = {
            "firmware version": operator.VERSION,
            "hardware version": operator.VERSION,
            "engine state": operator.soak.STATE_RUN,
            "request sequence": operator.SEQUENCE,
            "response sequence": operator.PREVIOUS_SEQUENCE,
            "hardware run ID": operator.PREVIOUS_RUN_ID,
        }
        with patch.object(operator.soak, "read_overview", return_value=overview):
            with patch.object(operator.soak, "expect") as expect:
                operator.exact_status(mailbox)
        expect.assert_any_call("hardware run ID", operator.PREVIOUS_RUN_ID,
                               operator.PREVIOUS_RUN_ID)

    def test_completed_status_requires_new_published_run_id(self):
        mailbox = Mock()
        overview = {
            "firmware version": operator.VERSION,
            "hardware version": operator.VERSION,
            "engine state": 0,
            "request sequence": operator.SEQUENCE,
            "response sequence": operator.SEQUENCE,
            "hardware run ID": operator.EXPECTED_RUN_ID,
        }
        with patch.object(operator.soak, "read_overview", return_value=overview):
            with patch.object(operator.soak, "expect") as expect:
                operator.exact_status(mailbox)
        expect.assert_any_call("hardware run ID", operator.EXPECTED_RUN_ID,
                               operator.EXPECTED_RUN_ID)

    def test_fault_status_preserves_diagnostics_and_fails(self):
        mailbox = Mock()
        overview = {
            "firmware version": operator.VERSION,
            "hardware version": operator.VERSION,
            "engine state": operator.soak.PLATFORM_FAULT_BIT,
            "request sequence": operator.SEQUENCE,
            "response sequence": operator.SEQUENCE,
            "hardware run ID": operator.EXPECTED_RUN_ID,
        }
        with patch.object(operator.soak, "read_overview", return_value=overview):
            with patch.object(operator.soak, "expect"):
                with patch.object(operator.soak, "print_platform_diagnostics") as diagnostics:
                    with self.assertRaises(RuntimeError):
                        operator.exact_status(mailbox)
                    diagnostics.assert_called_once_with(mailbox)


if __name__ == "__main__":
    unittest.main()
