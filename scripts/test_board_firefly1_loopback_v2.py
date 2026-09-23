"""Offline checks for the fixed FireFly-1 v2 hardware launcher."""
import sys
import unittest
from unittest.mock import patch

import board_firefly1_loopback_v2


class FireFlyV2LauncherTests(unittest.TestCase):
    def test_only_fixed_stages_are_accepted(self):
        for stage in ("deploy", "start", "status", "results", "diagnostics"):
            with patch.object(sys, "argv", ["firefly1_v2", stage]):
                with patch.object(board_firefly1_loopback_v2, "deploy") as deploy:
                    with patch.object(board_firefly1_loopback_v2, "run") as run:
                        board_firefly1_loopback_v2.main()
                        if stage == "deploy":
                            deploy.assert_called_once_with()
                            run.assert_not_called()
                        else:
                            run.assert_called_once_with(stage)

    def test_extra_arguments_are_rejected_without_action(self):
        with patch.object(sys, "argv", ["firefly1_v2", "start", "--duration", "1"]):
            with patch.object(board_firefly1_loopback_v2, "run") as run:
                with self.assertRaises(SystemExit):
                    board_firefly1_loopback_v2.main()
                run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
