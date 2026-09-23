"""Offline tests for the fixed v275 launcher; never connect to hardware."""
import sys
import unittest
from unittest.mock import patch

import board_v275


class BoardV275Tests(unittest.TestCase):
    def test_only_fixed_operations_are_accepted(self):
        with patch.object(sys, "argv", ["board_v275", "deploy"]):
            with patch.object(board_v275, "deploy") as action:
                board_v275.main()
                action.assert_called_once_with()
        for operation in ("clean1", "clean2"):
            with patch.object(sys, "argv", ["board_v275", operation]):
                with patch.object(board_v275, "run_clean") as action:
                    board_v275.main()
                    action.assert_called_once_with(operation)

    def test_extra_arguments_are_rejected_without_action(self):
        with patch.object(sys, "argv", ["board_v275", "clean1", "--sequence", "3"]):
            with patch.object(board_v275, "run_clean") as action:
                with self.assertRaises(SystemExit):
                    board_v275.main()
                action.assert_not_called()

    def test_evidence_collision_prevents_remote_run(self):
        with patch.object(board_v275.Path, "exists", return_value=True):
            with patch.object(board_v275.subprocess, "run") as run:
                with self.assertRaises(RuntimeError):
                    board_v275.run_clean("clean1")
                run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
