#include <assert.h>
#include <stddef.h>
#include <stdint.h>

#include "gt_test_mcu_protocol.h"

int main(void)
{
  gtte_request_t request = {
    .sequence = 7u,
    .command = gtte_make_command(GTTE_OPCODE_PARALLEL_BER, GTTE_PRBS31,
                                 0u, 1u),
    .duration = 1000u,
    .timeout = 2000u,
    .lane_mask = {0x0000f000u, 0u, 0u, 0u}
  };
  gtte_request_wire_t request_wire;
  gtte_status_wire_t status_wire = {0};
  gtte_status_t status;
  double ber = -1.0;

  assert(request.command == 0x00010501u);
  gtte_encode_request(&request_wire, &request);
  assert(gtte_le32_get(&request_wire.sequence) == 7u);
  assert(gtte_le32_get(&request_wire.lane_mask[0]) == 0x0000f000u);

  gtte_le32_put(&status_wire.firmware_version, 0x00020000u);
  gtte_le32_put(&status_wire.hardware_version, 0x00020000u);
  gtte_le32_put(&status_wire.engine_state,
                GTTE_STATE_INTERRUPT_PENDING | GTTE_STATE_IDLE);
  gtte_le32_put(&status_wire.result_lane, 12u);
  gtte_le32_put(&status_wire.lane.id_status,
                12u | GTTE_LANE_SELECTED | GTTE_LANE_LOCKED);
  gtte_le32_put(&status_wire.lane.tested_bits_low, 0x89abcdefu);
  gtte_le32_put(&status_wire.lane.tested_bits_high, 0x01234567u);
  gtte_le32_put(&status_wire.lane.valid_cycles_low, 0x11111111u);
  gtte_le32_put(&status_wire.lane.valid_cycles_high, 0x22222222u);
  gtte_le32_put(&status_wire.response_sequence, 7u);
  gtte_le32_put(&status_wire.response_code, 0x00040401u);
  gtte_le32_put(&status_wire.run_id, 9u);
  gtte_le32_put(&status_wire.summary, 0x00040401u);

  gtte_decode_status(&status, &status_wire);
  assert(status.firmware_version == 0x00020000u);
  assert(status.engine.interrupt_pending);
  assert(status.result_lane == 12u);
  assert(status.lane.lane_id == 12u);
  assert(status.lane.selected && status.lane.locked);
  assert(status.lane.tested_bits == UINT64_C(0x0123456789abcdef));
  assert(status.lane.valid_cycles == UINT64_C(0x2222222211111111));
  assert(gtte_lane_hardware_passed(&status.lane));
  assert(gtte_lane_acceptance_passed(&status.lane));
  assert(gtte_lane_ber(&status.lane, &ber));
  assert(ber == 0.0);
  assert(status.summary.stop_reason == GTTE_STOP_NORMAL);
  assert(status.summary.selected_count == 4u);
  assert(status.summary.passed_count == 4u);
  assert(status.summary.failed_count == 0u);

  return 0;
}
