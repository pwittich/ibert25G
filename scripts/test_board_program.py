import sys
import unittest
import tempfile
from pathlib import Path
from unittest.mock import patch
import board_program


class ProgrammingTests(unittest.TestCase):
    def test_v12_symmetric_fixed_choices_and_evidence(self):
        for image, site in (('direct_all_v12_f1', 'F1'),
                            ('direct_all_v12_f2', 'F2')):
            self.assertTrue(board_program.command(image)[-1].endswith(' ' + image))
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'build' / 'diagnostic_archive').mkdir(parents=True)
                result = board_program.subprocess.CompletedProcess(
                    [], 0, stdout='PROGRAM_%s_COMPLETE\n' % site)
                with patch.object(board_program, 'ROOT', root), patch.object(
                        sys, 'argv', ['program', image]), patch.object(
                        board_program.subprocess, 'run', return_value=result) as run:
                    self.assertEqual(board_program.main(), 0)
                    run.assert_called_once()
                self.assertEqual(len(list(
                    (root / 'build' / 'diagnostic_archive').glob(
                        'firefly1-v12-%s-program-*.log' % site))), 1)

    def test_v11_symmetric_fixed_choices_and_evidence(self):
        for image, site in (('direct_all_v11_f1', 'F1'),
                            ('direct_all_v11_f2', 'F2')):
            self.assertTrue(board_program.command(image)[-1].endswith(' ' + image))
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'build' / 'diagnostic_archive').mkdir(parents=True)
                result = board_program.subprocess.CompletedProcess(
                    [], 0, stdout='PROGRAM_%s_COMPLETE\n' % site)
                with patch.object(board_program, 'ROOT', root), patch.object(
                        sys, 'argv', ['program', image]), patch.object(
                        board_program.subprocess, 'run', return_value=result) as run:
                    self.assertEqual(board_program.main(), 0)
                    run.assert_called_once()
                self.assertEqual(len(list(
                    (root / 'build' / 'diagnostic_archive').glob(
                        'firefly1-v11-%s-program-*.log' % site))), 1)

    def test_v10_symmetric_fixed_choices_and_evidence(self):
        for image, site in (('direct_all_v10_f1', 'F1'),
                            ('direct_all_v10_f2', 'F2')):
            self.assertTrue(board_program.command(image)[-1].endswith(' ' + image))
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'build' / 'diagnostic_archive').mkdir(parents=True)
                result = board_program.subprocess.CompletedProcess(
                    [], 0, stdout='PROGRAM_%s_COMPLETE\n' % site)
                with patch.object(board_program, 'ROOT', root), patch.object(
                        sys, 'argv', ['program', image]), patch.object(
                        board_program.subprocess, 'run', return_value=result) as run:
                    self.assertEqual(board_program.main(), 0)
                    run.assert_called_once()
                self.assertEqual(len(list(
                    (root / 'build' / 'diagnostic_archive').glob(
                        'firefly1-v10-%s-program-*.log' % site))), 1)

    def test_v9_symmetric_fixed_choices_and_evidence(self):
        for image, site in (('direct_all_v9_f1', 'F1'),
                            ('direct_all_v9_f2', 'F2')):
            self.assertTrue(board_program.command(image)[-1].endswith(' ' + image))
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'build' / 'diagnostic_archive').mkdir(parents=True)
                result = board_program.subprocess.CompletedProcess(
                    [], 0, stdout='PROGRAM_%s_COMPLETE\n' % site)
                with patch.object(board_program, 'ROOT', root), patch.object(
                        sys, 'argv', ['program', image]), patch.object(
                        board_program.subprocess, 'run', return_value=result) as run:
                    self.assertEqual(board_program.main(), 0)
                    run.assert_called_once()
                self.assertEqual(len(list(
                    (root / 'build' / 'diagnostic_archive').glob(
                        'firefly1-v9-%s-program-*.log' % site))), 1)

    def test_v6_fixed_choices_and_evidence(self):
        for image, site in (('direct_quad_v6_f1', 'F1'), ('direct_quad_v6_f2', 'F2')):
            self.assertTrue(board_program.command(image)[-1].endswith(' ' + image))
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'build' / 'diagnostic_archive').mkdir(parents=True)
                result = board_program.subprocess.CompletedProcess([], 0, stdout='PROGRAM_%s_COMPLETE\n' % site)
                with patch.object(board_program, 'ROOT', root), patch.object(
                        sys, 'argv', ['program', image]), patch.object(
                        board_program.subprocess, 'run', return_value=result) as run:
                    self.assertEqual(board_program.main(), 0)
                    run.assert_called_once()
                self.assertEqual(len(list((root / 'build' / 'diagnostic_archive').glob(
                    'firefly1-v6-%s-program-*.log' % site))), 1)

    def test_v5_fixed_choices_and_evidence(self):
        for image, site in (('firefly1_loopback_v5', 'F1'), ('firefly1_loopback_v5_f2', 'F2')):
            self.assertTrue(board_program.command(image)[-1].endswith(' ' + image))
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'build' / 'diagnostic_archive').mkdir(parents=True)
                result = board_program.subprocess.CompletedProcess([], 0, stdout='PROGRAM_%s_COMPLETE\n' % site)
                with patch.object(board_program, 'ROOT', root), patch.object(
                        sys, 'argv', ['program', image]), patch.object(
                        board_program.subprocess, 'run', return_value=result) as run:
                    self.assertEqual(board_program.main(), 0)
                    run.assert_called_once()
                logs = list((root / 'build' / 'diagnostic_archive').glob('firefly1-v5-%s-program-*.log' % site))
                self.assertEqual(len(logs), 1)

    def test_fixed_f2_choice(self):
        self.assertTrue(board_program.command('firefly1_loopback_v4_f2')[-1].endswith(
            'board_program.tcl firefly1_loopback_v4_f2'))
        with self.assertRaises(ValueError):
            board_program.command('golden_f2')

    def test_f2_requires_own_completion_marker(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'build' / 'diagnostic_archive').mkdir(parents=True)
            with patch.object(board_program, 'ROOT', root), patch.object(
                    sys, 'argv', ['program', 'firefly1_loopback_v4_f2']):
                result = board_program.subprocess.CompletedProcess([], 0, stdout='PROGRAM_F1_COMPLETE\n')
                with patch.object(board_program.subprocess, 'run', return_value=result) as run:
                    self.assertEqual(board_program.main(), 2)
                    run.assert_called_once()

    def test_fixed_choices(self):
        for image in ('v270', 'v271', 'v272', 'v273', 'v274', 'v275', 'v13', 'v14', 'v15', 'firefly1_loopback_v2', 'firefly1_loopback_v3', 'firefly1_loopback_v4', 'golden'):
            self.assertTrue(board_program.command(image)[-1].endswith(' ' + image))
        with self.assertRaises(ValueError):
            board_program.command('v270; arbitrary-command')

    def test_dry_run(self):
        with patch.object(sys, 'argv', ['program', 'v270', '--dry-run']):
            with patch.object(board_program.subprocess, 'run') as run:
                self.assertEqual(board_program.main(), 0)
                run.assert_not_called()

    def test_no_extra_arguments(self):
        with patch.object(sys, 'argv', ['program', 'v270', '--fpga', 'F2']):
            with patch.object(board_program.subprocess, 'run') as run:
                with self.assertRaises(SystemExit):
                    board_program.main()
                run.assert_not_called()

    def test_v4_missing_completion_is_failure_without_retry(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'build' / 'diagnostic_archive').mkdir(parents=True)
            with patch.object(board_program, 'ROOT', root), patch.object(
                    sys, 'argv', ['program', 'firefly1_loopback_v4']):
                result = board_program.subprocess.CompletedProcess([], 0, stdout='PROGRAM_F1 image=firefly1_loopback_v4\n')
                with patch.object(board_program.subprocess, 'run', return_value=result) as run:
                    self.assertEqual(board_program.main(), 2)
                    run.assert_called_once()
                logs = list((root / 'build' / 'diagnostic_archive').glob('*.log'))
                self.assertEqual(len(logs), 1)
                self.assertEqual(logs[0].read_text(), result.stdout)


if __name__ == '__main__':
    unittest.main()
