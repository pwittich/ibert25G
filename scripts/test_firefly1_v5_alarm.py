import contextlib
import io
import unittest
from unittest.mock import Mock, patch
import firefly1_v5_alarm_remote as gate
from test_firefly1_v5_oneway import FakeBox
from test_firefly1_v5_loss import Tx


class Tests(unittest.TestCase):
    def setUp(self):
        self.values={i:dict(id_status=0x1800+i,errors=0,lock_losses=0,
                           valid_cycles=322265625*10,tested_bits=322265625*10*80) for i in range(12)}
        self.now=0
        self.quiet=contextlib.redirect_stdout(io.StringIO());self.quiet.__enter__()
        self.addCleanup(self.quiet.__exit__,None,None,None)
    def sleep(self,d): self.now+=d
    def test_raw_alarm_byte_order(self):
        rx=Mock();rx.read_reg.side_effect=[b'\x00\x04',b'\x08\x04']
        self.assertEqual(gate.alarm_sample(rx,'test'),(4,0x804))
    def test_zero_is_observation_not_failure(self):
        rx=Mock();rx.read_reg.return_value=b'\x00\x00'
        self.assertEqual(gate.alarm_sample(rx,'test'),(0,0))
    def test_error_sentinel_refused(self):
        rx=Mock();rx.read_reg.return_value=b'\xff\xff'
        with self.assertRaises(RuntimeError): gate.alarm_sample(rx,'test')
    def test_clean_baseline(self): gate.check_records((6,0x000c0c01,self.values),6,10,True)
    def test_dirty_baseline_refused(self):
        self.values[9]['errors']=1
        with self.assertRaises(RuntimeError): gate.check_records((6,0x000c0c01,self.values),6,10,True)
    def test_saturated_target_valid_observation(self):
        for v in self.values.values(): v['valid_cycles']*=6;v['tested_bits']*=6
        self.values[9].update(id_status=0x5809,errors=0xffffffff)
        gate.check_records((7,0x010b0c01,self.values),7,60,False)
    def test_stop_exact_predecessors(self):
        for seq,run in ((19,5),(20,6),(21,7)):
            b=FakeBox();b.reg.update({0xa0:seq,0xf0:seq,0xf8:run,0xc8:gate.CAP|gate.ACTIVE})
            gate.safe_stop(gate.Diagnostic(b))
            self.assertEqual(b.requests,[(22,3,0,0xfff)])
    def test_no_stop_ambiguous_or_fault(self):
        b=FakeBox();b.reg.update({0xa0:21,0xf0:20,0xf8:6,0xc8:gate.CAP|gate.ACTIVE|2})
        gate.safe_stop(gate.Diagnostic(b));self.assertEqual(b.requests,[])
    def test_bypassed_cdr_no_requests_or_stimulus(self):
        a,b=FakeBox(),FakeBox()
        a.reg.update({0xa0:13,0xf0:13});b.reg.update({0xa0:18,0xf0:18,0xf8:5})
        s=gate.Diagnostic(a,site='F1');r=gate.Diagnostic(b,site='F2')
        s.evidence=r.evidence=Mock()
        tx=Tx();rx=Mock();rx.read_reg.side_effect=lambda a,size=1:b'\x00' if a==127 else b'\x00\x00'
        with self.assertRaisesRegex(RuntimeError,'bypassed'): gate.run(s,r,tx,rx)
        self.assertEqual(a.requests+b.requests+tx.writes,[])
    def test_failed_baseline_no_pulse_and_source_cleanup(self):
        a,b=FakeBox(),FakeBox()
        a.reg.update({0xa0:13,0xf0:13});b.reg.update({0xa0:18,0xf0:18,0xf8:5})
        b.fail_rx=True
        s=gate.Diagnostic(a,self.sleep,lambda:self.now,site='F1')
        r=gate.Diagnostic(b,self.sleep,lambda:self.now,site='F2')
        s.evidence=r.evidence=Mock()
        tx=Tx();rx=Mock();rx.read_reg.side_effect=lambda a,size=1: b'\x00' if a==127 else b'\x0f\xff' if a==74 else b'\x00\x00'
        with patch.object(gate,'rssi'),patch.object(gate,'compact'),patch.object(gate,'pulse') as pulse:
            with self.assertRaisesRegex(RuntimeError,'response/run'): gate.run(s,r,tx,rx,self.sleep,lambda:self.now)
            pulse.assert_not_called()
        self.assertEqual(tx.writes,[])
        self.assertEqual(a.requests[-1],(15,3,0,0xfff))


if __name__=='__main__': unittest.main()
