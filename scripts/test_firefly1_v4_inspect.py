import contextlib
import io
import runpy
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch


class InspectionTests(unittest.TestCase):
    def inspect(self, broken=False):
        class FPGA:
            def __init__(self, site):
                self.site = site
            def read_reg(self, address, size):
                ident = 1 if self.site == 'F1' else 0
                summary = 0xc0c01 if ident else 0
                values = {0x9c: 0x434da501, 0xc0: 0x20303, 0xc4: 0x20303,
                          0xc8: 0, 0xa0: ident, 0xf0: ident, 0xf8: ident,
                          0xf4: summary, 0xfc: summary,
                          36: 100000, 40: 325000, 92: 322260}
                value = values.get(address, 322260)
                if broken and self.site == 'F2' and address == 92:
                    value = 0
                return value.to_bytes(4, 'little')
            def write_reg(self, *args, **kwargs):
                raise AssertionError('inspection must not write')
        module = types.ModuleType('cm_interface.registry')
        module.Registry = lambda **kwargs: types.SimpleNamespace(
            fpgas={site: FPGA(site) for site in ('F1', 'F2')})
        with patch.dict(sys.modules, {'cm_interface.registry': module}), patch.object(
                sys, 'argv', ['inspect', 'verify']), contextlib.redirect_stdout(io.StringIO()):
            runpy.run_path(str(Path(__file__).with_name('firefly1_v4_inspect_remote.py')))

    def test_healthy_read_only(self):
        self.inspect()

    def test_missing_f2_reference_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'required clock'):
            self.inspect(broken=True)


if __name__ == '__main__':
    unittest.main()
