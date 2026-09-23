"""Offline tests for the fixed v274 launcher; never connect to hardware."""
import sys
import unittest
from unittest.mock import patch

import board_v274


class BoardV274Tests(unittest.TestCase):
    def test_only_fixed_operations_are_accepted(self):
        for operation in ("deploy", "clean1", "heartbeat2"):
            with patch.object(sys, "argv", ["board_v274", operation]):
                with patch.object(board_v274, operation if operation != "heartbeat2" else "heartbeat2") as action:
                    board_v274.main()
                    action.assert_called_once_with()

    def test_extra_arguments_are_rejected_without_action(self):
        with patch.object(sys, "argv", ["board_v274", "heartbeat2", "--sequence", "3"]):
            with patch.object(board_v274, "heartbeat2") as action:
                with self.assertRaises(SystemExit):
                    board_v274.main()
                action.assert_not_called()

    def test_evidence_collision_prevents_watcher_start(self):
        with patch.object(board_v274.Path, "exists", return_value=True):
            with patch.object(board_v274.subprocess, "Popen") as popen:
                with self.assertRaises(RuntimeError):
                    board_v274.heartbeat2()
                popen.assert_not_called()


if __name__ == "__main__":
    unittest.main()
