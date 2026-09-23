import contextlib
import io
import unittest
from unittest.mock import Mock,patch
from test_firefly1_v5_all12 import Box
from firefly1_v5_oneway_remote import Diagnostic
import firefly1_v5_soak1h_remote as gate


class SoakBox(Box):
    def __init__(self,clock):
        super().__init__()
        self.clock=clock
        self.finish=None

    def write_u32(self,address,value):
        super().write_u32(address,value)
        if address==0xa0 and self.reg[0xa4]==0x10501 and not self.fail_rx:
            self.finish=self.clock()+3600
            self.reg.update({0xf0:13,0xf8:3,0xc8:gate.CAP|gate.ACTIVE|2})

    def read_u32(self,address):
        if self.finish is not None and self.clock()>=self.finish:
            self.reg.update({0xf0:14,0xf8:4,0xfc:gate.SUMMARY,0xf4:gate.SUMMARY,0xc8:gate.CAP|gate.ACTIVE})
            self.finish=None
        return super().read_u32(address)


class Tests(unittest.TestCase):
    def setUp(self):
        self.now=0
        self.a,self.b=Box(),SoakBox(lambda:self.now)
        self.a.reg.update({0xa0:9,0xf0:9})
        self.b.reg.update({0xa0:12,0xf0:12,0xf8:3})
        self.source=Diagnostic(self.a,self.sleep,lambda:self.now,site='F1')
        self.rx=Diagnostic(self.b,self.sleep,lambda:self.now,site='F2')
        for endpoint in (self.source,self.rx): endpoint.evidence=Mock()
        self.rows={i:dict(id_status=0x1800+i,errors=0,lock_losses=0,valid_cycles=gate.CYCLES,tested_bits=gate.CYCLES*80) for i in range(12)}

    def sleep(self,delay): self.now+=delay

    def run_gate(self):
        with contextlib.redirect_stdout(io.StringIO()),patch.object(gate,'compact'),patch.object(gate,'prior_records'),patch.object(gate,'read_lane',side_effect=lambda b,l:self.rows[l]):
            gate.run(self.source,self.rx,lambda:[0]*12,self.sleep,lambda:self.now)

    def test_fixed_hour_and_cleanup(self):
        self.run_gate()
        self.assertEqual(self.a.requests,[(10,2,3900000,0xfff),(11,3,0,0xfff)])
        self.assertEqual(self.b.requests,[(13,2,3900000,0xfff),(14,0x10501,3600000,0xfff),(15,3,0,0xfff)])
        self.assertGreaterEqual(self.now,3632)
        self.assertLess(self.now,3700)
        self.assertEqual(self.b.reg[0xf8],4)

    def test_acquisition_failure_no_retry(self):
        self.b.fail_rx=True
        with self.assertRaisesRegex(RuntimeError,'response/run'): self.run_gate()
        self.assertEqual([r[0] for r in self.b.requests],[13,14])
        self.assertEqual(self.a.requests[-1],(11,3,0,0xfff))

    def test_bad_predecessor_no_writes(self):
        self.a.reg[0xf0]=8
        with self.assertRaises(RuntimeError): self.run_gate()
        self.assertEqual(self.a.requests+self.b.requests,[])

    def test_counter_error_fails_after_stops(self):
        self.rows[9]['errors']=1
        with self.assertRaisesRegex(RuntimeError,'lane9'): self.run_gate()
        self.assertEqual(self.b.requests[-1],(15,3,0,0xfff))


if __name__=='__main__': unittest.main()
