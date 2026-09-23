import contextlib
import io
import unittest
from unittest.mock import Mock, patch
import firefly1_v5_loss_remote as gate
from test_firefly1_v5_oneway import FakeBox


class Tx:
    part_id = 'test-only'
    def __init__(self):
        self.mask = b'\xa0\x00'
        self.writes = []
        self.ambiguous = False
    def read_reg(self, address, size=1):
        return b'\x00' if address == 127 else self.mask
    def write_reg(self, address, value):
        self.writes.append((address,value))
        self.mask = self.mask[:1]+value
        if self.ambiguous and len(self.writes) == 1:
            raise IOError('lost ACK')


class Tests(unittest.TestCase):
    def setUp(self):
        self.now = 0
        self.tx = Tx()
        self.before = [1000.0]*12
        self.down = list(self.before)
        self.down[2] = 50
        self.values = {i:dict(id_status=0x1800+i,errors=0,lock_losses=0,
                       valid_cycles=322265625*60,tested_bits=322265625*60*80) for i in range(12)}
        self.values[9].update(id_status=0x5809,errors=0xffffffff)
        self.quiet = contextlib.redirect_stdout(io.StringIO())
        self.quiet.__enter__()
        self.addCleanup(self.quiet.__exit__,None,None,None)
    def sleep(self, duration): self.now += duration
    def pulse(self, reader):
        return gate.pulse(self.tx, reader, b'\xa0\x00',self.sleep,lambda:self.now)
    def test_pulse_preserves_reserved_bits(self):
        self.pulse(lambda:self.down)
        self.assertEqual(self.tx.writes,[(53,b'\x04'),(53,b'\x00')])
        self.assertEqual(self.tx.mask,b'\xa0\x00')
        self.assertEqual(self.now,10)
    def test_ambiguous_write_restores(self):
        self.tx.ambiguous = True
        with self.assertRaisesRegex(IOError,'lost ACK'): self.pulse(lambda:self.down)
        self.assertEqual(self.tx.writes[-1],(53,b'\x00'))
    def test_rssi_error_restores(self):
        with self.assertRaises(IOError): self.pulse(Mock(side_effect=IOError('RSSI')))
        self.assertEqual(self.tx.mask,b'\xa0\x00')
    def test_deadline_exception_restores(self):
        with self.assertRaises(TimeoutError): self.pulse(Mock(side_effect=TimeoutError()))
        self.assertEqual(self.tx.mask,b'\xa0\x00')
    def test_mask_change_no_write(self):
        self.tx.mask=b'\x00\x01'
        with self.assertRaises(RuntimeError): self.pulse(lambda:self.down)
        self.assertEqual(self.tx.writes,[])
    def test_mapping_and_recovery(self):
        self.assertEqual(gate.classify(self.before,[self.before,self.down,self.down],self.before),9)
    def test_unexpected_destination_is_observation(self):
        down=list(self.before); down[7]=0
        self.assertEqual(gate.classify(self.before,[down]*3,self.before),4)
    def test_inconclusive_mapping(self):
        with self.assertRaises(RuntimeError): gate.classify(self.before,[self.before]*3,self.before)
    def test_neighbor_drop_fails(self):
        self.down[3]=100
        with self.assertRaises(RuntimeError): gate.classify(self.before,[self.down]*3,self.before)
    def test_saturated_target_accepted(self): gate.validate((5,0x010b0c01,self.values),9)
    def test_neighbor_error_fails(self):
        self.values[1]['errors']=1
        with self.assertRaisesRegex(RuntimeError,'neighbor'): gate.validate((5,0x010b0c01,self.values),9)
    def test_synthetic_records_refused(self):
        with self.assertRaisesRegex(RuntimeError,'synthetic'): gate.validate((5,0x0c000c04,self.values),9)
    def test_no_effect_refused(self):
        self.values[9]['errors']=0
        with self.assertRaisesRegex(RuntimeError,'interruption'): gate.validate((5,0x000c0c01,self.values),9)
    def endpoints(self):
        a,b=FakeBox(),FakeBox()
        a.reg.update({0xa0:11,0xf0:11})
        b.reg.update({0xa0:15,0xf0:15,0xf8:4})
        s=gate.Diagnostic(a,self.sleep,lambda:self.now,site='F1')
        r=gate.Diagnostic(b,self.sleep,lambda:self.now,site='F2')
        s.evidence=r.evidence=Mock()
        return s,r
    def test_wrong_predecessor_no_writes(self):
        s,r=self.endpoints();r.box.reg[0xf0]=14
        with self.assertRaises(RuntimeError): gate.run(s,r,self.tx,lambda:self.before,self.sleep,lambda:self.now)
        self.assertEqual(s.box.requests+r.box.requests+self.tx.writes,[])
    def test_no_run_no_stimulus_source_stopped(self):
        s,r=self.endpoints()
        with patch.object(gate,'soak_records'),patch.object(gate,'compact'):
            with self.assertRaisesRegex(RuntimeError,'no RUN'):
                gate.run(s,r,self.tx,lambda:self.before,self.sleep,lambda:self.now)
        self.assertEqual(self.tx.writes,[])
        self.assertEqual(s.box.requests[-1],(13,3,0,0xfff))


if __name__ == '__main__': unittest.main()
