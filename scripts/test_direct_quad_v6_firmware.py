"""Compile the actual session branch on the host with mocked register access."""
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class FirmwareSessionMasks(unittest.TestCase):
    def check_profile(self, version, masks):
        source = (ROOT / 'firmware/gt_test_milestone2.c').read_text()
        branch = source.split('#ifdef GTTE_ENABLE_TX_SESSION\n', 1)[1].split('#endif', 1)[0]
        # The branch normally continues the firmware polling loop.
        branch = branch.replace('continue;', 'return response;')
        definitions = '\n'.join('#define GTTE_MANAGED_MASK{} {}u'.format(i, m)
                                for i, m in enumerate(masks))
        program = r'''
#include <stdint.h>
#include <assert.h>
#include "gt_test_engine_regs.h"
#define GTTE_BASE 0x44a00000u
DEFINITIONS
static uint32_t state_value, session_value, response, writes;
static uint32_t mmio_read(uint32_t base, uint32_t off) {
  (void)base; return off == 0x010u ? state_value : session_value;
}
static void mmio_write(uint32_t base, uint32_t off, uint32_t val) {
  (void)base;
  if (off == 0x100u) { session_value = val == 1u ? 0x11u : 0u; ++writes; }
  if (off == GTTE_MAILBOX_RESPONSE_CODE) response = val;
}
static uint32_t check(uint32_t command, uint32_t duration, uint32_t timeout,
                      uint32_t mask0, uint32_t mask1, uint32_t mask2, uint32_t mask3) {
  uint32_t sequence = 7, handled_sequence = 0;
  BRANCH
  return 99;
}
static uint32_t request(uint32_t command, uint32_t duration, uint32_t timeout,
                        const uint32_t *m) {
  return check(command, duration, timeout, m[0], m[1], m[2], m[3]);
}
int main(void) {
  uint32_t good[4] = {GTTE_MANAGED_MASK0, GTTE_MANAGED_MASK1,
                       GTTE_MANAGED_MASK2, GTTE_MANAGED_MASK3};
  assert(request(2, 180000, 0, good) == 0 && writes == 1 && session_value == 0x11);
  assert(request(2, 180000, 0, good) == 1 && writes == 1);
  assert(request(3, 0, 0, good) == 0 && writes == 2 && session_value == 0);
  for (unsigned lane = 0; lane < 128; ++lane) {
    uint32_t bad[4] = {good[0],good[1],good[2],good[3]};
    bad[lane/32] ^= 1u << (lane%32);
    assert(request(2, 180000, 0, bad) == 1 && writes == 2);
    assert(request(3, 0, 0, bad) == 1 && writes == 2);
  }
  assert(request(2, 0, 0, good) == 1);
  assert(request(2, 86400001, 0, good) == 1);
  assert(request(2, 1000, 1, good) == 1);
  assert(request(3, 1, 0, good) == 1);
  state_value = 1;
  assert(request(2, 1000, 0, good) == 1);
  state_value = 0x10000;
  assert(request(2, 1000, 0, good) == 1);
  assert(writes == 2);
  return 0;
}
'''.replace('DEFINITIONS', definitions).replace('BRANCH', branch)
        with tempfile.TemporaryDirectory(prefix='v6-firmware-test-') as directory:
            path = pathlib.Path(directory)
            (path / 'test.c').write_text(program)
            subprocess.run(['gcc', '-std=c99', '-I' + str(ROOT / 'firmware'),
                            str(path / 'test.c'), '-o', str(path / 'test')], check=True)
            subprocess.run([str(path / 'test')], check=True)
        if version == 0x20304:
            historical = program.replace(
                'mask0 == GTTE_MANAGED_MASK0 &&\n'
                '                       mask1 == GTTE_MANAGED_MASK1 &&\n'
                '                       mask2 == GTTE_MANAGED_MASK2 &&\n'
                '                       mask3 == GTTE_MANAGED_MASK3',
                'mask0 == 0xfffu && mask1 == 0u && mask2 == 0u && mask3 == 0u\n\n\n')
            self.assertNotEqual(program, historical)
            # Same host assembly for the old and new v5 command branch.
            command = ['gcc', '-Os', '-S', '-x', 'c', '-', '-o', '-',
                       '-I' + str(ROOT / 'firmware')]
            current_asm = subprocess.run(command, input=program.encode(),
                                         stdout=subprocess.PIPE, check=True).stdout
            previous_asm = subprocess.run(command, input=historical.encode(),
                                          stdout=subprocess.PIPE, check=True).stdout
            self.assertEqual(current_asm, previous_asm)

    def test_v5_unchanged(self):
        self.check_profile(0x20304, [0xfff, 0, 0, 0])

    def test_f1_v6(self):
        self.check_profile(0x20400, [0, 0xf0000000, 0, 0])

    def test_f2_v6(self):
        self.check_profile(0x20403, [0, 0, 0, 0xf00])


if __name__ == '__main__':
    unittest.main()
