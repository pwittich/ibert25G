"""Offline checks: do not connect to hardware."""
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
import board_diagnostics as diagnostics


class DiagnosticsTests(unittest.TestCase):
    def test_fixed_operations(self):
        for action in ('clocks', 'modules', 'mcu_temperatures', 'results', 'temperatures'):
            command, source = diagnostics.invocation(action)
            self.assertTrue(command)
            if source:
                self.assertTrue(source.is_file())
        with self.assertRaises(ValueError):
            diagnostics.invocation('program')

    def test_dry_run_never_connects(self):
        for action in ('clocks', 'modules', 'mcu_temperatures', 'results', 'temperatures'):
            with patch.object(sys, 'argv', ['diagnostics', action, '--dry-run']):
                with patch.object(diagnostics.subprocess, 'run') as run:
                    self.assertEqual(diagnostics.main(), 0)
                    run.assert_not_called()

    def test_payload_and_exit_status(self):
        with patch.object(sys, 'argv', ['diagnostics', 'modules']):
            with patch.object(diagnostics.subprocess, 'run') as run:
                run.return_value.returncode = 7
                self.assertEqual(diagnostics.main(), 7)
                self.assertIsInstance(run.call_args.kwargs['input'], bytes)
                self.assertNotIn('shell', run.call_args.kwargs)

    def test_extra_arguments_rejected_before_connecting(self):
        with patch.object(sys, 'argv', ['diagnostics', 'clocks', '--command', 'anything']):
            with patch.object(diagnostics.subprocess, 'run') as run:
                with self.assertRaises(SystemExit) as error:
                    diagnostics.main()
                self.assertEqual(error.exception.code, 2)
                run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
