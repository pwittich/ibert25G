import contextlib
import io
import unittest
from unittest.mock import Mock,patch
from test_firefly1_v5_all12 import Box
from firefly1_v5_oneway_remote import Diagnostic
import firefly1_v5_all12_remote as all12
import firefly1_v5_closeout_remote as gate


class Tests(unittest.TestCase):
    def setUp(self):
        self.a,self.b=Box(),Box()
        self.a.reg.update({0xa0:15,0xf0:15})
        self.b.reg.update({0xa0:22,0xf0:22,0xf8:7})
        self.now=0
        self.source=Diagnostic(self.a,self.sleep,lambda:self.now,site='F1')
        self.rx=Diagnostic(self.b,self.sleep,lambda:self.now,site='F2')
        self.source.evidence=self.rx.evidence=Mock()
        self.data={i:dict(id_status=0x1800+i,errors=0,lock_losses=0,
            tested_bits=257812500000,valid_cycles=3222656250) for i in range(12)}
    def sleep(self,d): self.now+=d
    def run_gate(self):
        with contextlib.redirect_stdout(io.StringIO()),patch.object(gate,'compact'),patch.object(all12,'read_lane',side_effect=lambda b,l:self.data[l]):
            gate.run(self.source,self.rx,self.sleep,lambda:self.now)
    def test_fixed_success(self):
        self.run_gate()
        self.assertEqual(self.a.requests,[(16,2,180000,0xfff),(17,3,0,0xfff)])
        self.assertEqual(self.b.requests,[(23,2,180000,0xfff),(24,0x10501,10000,0xfff),(25,3,0,0xfff)])
        self.assertEqual(self.b.reg[0xf8],8)
    def test_wrong_predecessor(self):
        self.b.reg[0xf0]=21
        with self.assertRaises(RuntimeError):self.run_gate()
        self.assertEqual(self.a.requests+self.b.requests,[])
    def test_acquisition_fault_no_retry(self):
        self.b.fail_rx=True
        with self.assertRaisesRegex(RuntimeError,'response/run'):self.run_gate()
        self.assertEqual([r[0] for r in self.b.requests],[23,24])
        self.assertEqual(self.a.requests[-1],(17,3,0,0xfff))
    def test_lane9_error_stops(self):
        self.data[9]['errors']=1
        with self.assertRaisesRegex(RuntimeError,'lane9'):self.run_gate()
        self.assertEqual(self.b.requests[-1],(25,3,0,0xfff))
    def test_controls_no_writes(self):
        tx,rx=Mock(),Mock();tx.read_reg.return_value=rx.read_reg.return_value=b'\x00\x00'
        with contextlib.redirect_stdout(io.StringIO()):gate.controls(tx,rx)
        tx.write_reg.assert_not_called();rx.write_reg.assert_not_called()
        rx.read_reg.return_value=b'\x00\x04'
        with contextlib.redirect_stdout(io.StringIO()),self.assertRaises(RuntimeError):gate.controls(tx,rx)


if __name__=='__main__':unittest.main()
