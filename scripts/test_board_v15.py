"""Offline tests for the fixed v15 hardware launcher."""
import sys
import unittest
from unittest.mock import patch

import board_v15


class BoardV15Tests(unittest.TestCase):
    def test_only_fixed_operations_are_accepted(self):
        for operation in ("start", "status", "results", "start2", "status2", "results2"):
            with patch.object(sys, "argv", ["board_v15", operation]):
                with patch.object(board_v15, "run_stage") as action:
                    board_v15.main()
                    action.assert_called_once_with(operation)

    def test_extra_arguments_are_rejected_without_action(self):
        with patch.object(sys, "argv", ["board_v15", "start2", "--sequence", "3"]):
            with patch.object(board_v15, "run_stage") as action:
                with self.assertRaises(SystemExit):
                    board_v15.main()
                action.assert_not_called()

    def test_second_run_has_fixed_sequence_history(self):
        self.assertEqual(board_v15.RUNS["start2"], ("start", 2, 1))
        self.assertEqual(board_v15.RUNS["results2"], ("results", 2, 1))


if __name__ == "__main__":
    unittest.main()
