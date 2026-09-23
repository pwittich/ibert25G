"""Offline tests for the fixed v275 soak launcher; never connect to hardware."""
import sys
import unittest
from unittest.mock import patch

import board_v275_soak


class BoardV275SoakTests(unittest.TestCase):
    def test_only_fixed_operations_are_accepted(self):
        with patch.object(sys, "argv", ["board_v275_soak", "deploy"]):
            with patch.object(board_v275_soak, "deploy") as action:
                board_v275_soak.main()
                action.assert_called_once_with()
        for operation in ("start", "status", "results"):
            with patch.object(sys, "argv", ["board_v275_soak", operation]):
                with patch.object(board_v275_soak, "run_stage") as action:
                    board_v275_soak.main()
                    action.assert_called_once_with(operation)

    def test_extra_arguments_are_rejected_without_action(self):
        with patch.object(sys, "argv", ["board_v275_soak", "start",
                                        "--duration-ms", "1"]):
            with patch.object(board_v275_soak, "run_stage") as action:
                with self.assertRaises(SystemExit):
                    board_v275_soak.main()
                action.assert_not_called()

    def test_evidence_collision_prevents_remote_command(self):
        with patch.object(board_v275_soak.Path, "exists", return_value=True):
            with patch.object(board_v275_soak.subprocess, "Popen") as popen:
                with self.assertRaises(RuntimeError):
                    board_v275_soak.run_stage("start")
                popen.assert_not_called()


if __name__ == "__main__":
    unittest.main()
