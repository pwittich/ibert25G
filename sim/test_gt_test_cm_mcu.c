#include <assert.h>
#include <stdint.h>
#include <string.h>

#include "GTTestEngine.h"
#include "I2CCommunication.h"
#include "Semaphore.h"

SemaphoreHandle_t i2c5_sem = (SemaphoreHandle_t)(uintptr_t)5u;

static uint32_t registers[64];
static uint32_t lane_record[112][8];
static unsigned int selected_lane;
static unsigned int descriptor_readback_mask;
static unsigned int run_id_reads;
static int change_run_id;
static int lock_depth;
static int mux_value;
static int mux_selected_value;
static int sequence_committed;
static int fail_register = -1;

static int descriptor_index(uint16_t address)
{
  static const uint8_t descriptor_address[7] = {
    0xa4u, 0xa8u, 0xacu, 0xb0u, 0xb4u, 0xb8u, 0xbcu
  };
  unsigned int index;

  for (index = 0; index < 7u; ++index)
    if (descriptor_address[index] == address)
      return (int)index;
  return -1;
}

SemaphoreHandle_t getSemaphore(int number)
{
  assert(number == 5);
  return i2c5_sem;
}

BaseType_t xSemaphoreGive(SemaphoreHandle_t semaphore)
{
  assert(semaphore == i2c5_sem);
  assert(lock_depth == 1);
  --lock_depth;
  return pdTRUE;
}

int acquireI2CSemaphoreTime(SemaphoreHandle_t semaphore,
                            TickType_t ticks_to_wait)
{
  assert(semaphore == i2c5_sem);
  assert(ticks_to_wait == 250u);
  assert(lock_depth == 0);
  ++lock_depth;
  return pdTRUE;
}

int apollo_i2c_ctl_w(uint8_t device, uint8_t address, uint8_t nbytes,
                     unsigned int value)
{
  assert(lock_depth == 1);
  assert(device == 5u);
  assert(address == 0x70u);
  assert(nbytes == 1u);
  assert(value == 0u || value == 1u || value == 4u);
  mux_value = (int)value;
  if (value != 0u)
    mux_selected_value = (int)value;
  return 0;
}

int apollo_i2c_ctl_reg_w(uint8_t device, uint8_t address,
                         uint8_t nbytes_addr, uint16_t register_address,
                         uint8_t nbytes, uint32_t data)
{
  assert(lock_depth == 1);
  assert(mux_value == 1 || mux_value == 4);
  assert(device == 5u && address == 0x2bu && nbytes_addr == 1u);
  assert(nbytes == 1u || nbytes == 4u);
  if ((int)register_address == fail_register)
    return 7;
  if (register_address == 0xccu) {
    selected_lane = data;
  }
  else {
    registers[register_address >> 2] = data;
  }
  if (register_address == 0xa0u) {
    assert(descriptor_readback_mask == 0x7fu);
    sequence_committed = 1;
  }
  return 0;
}

int apollo_i2c_ctl_reg_r(uint8_t device, uint8_t address,
                         uint8_t nbytes_addr, uint16_t register_address,
                         uint8_t nbytes, uint32_t *data)
{
  int index;

  assert(lock_depth == 1);
  assert(mux_value == 1 || mux_value == 4);
  assert(device == 5u && address == 0x2bu && nbytes_addr == 1u);
  assert(nbytes == 4u);
  if ((int)register_address == fail_register)
    return 7;
  if (register_address >= 0xd0u && register_address <= 0xecu) {
    *data = lane_record[selected_lane][(register_address - 0xd0u) >> 2];
  }
  else {
    if (register_address == 0xf8u && change_run_id && run_id_reads++ == 1u)
      ++registers[register_address >> 2];
    *data = registers[register_address >> 2];
  }
  index = descriptor_index(register_address);
  if (index >= 0)
    descriptor_readback_mask |= 1u << (unsigned int)index;
  return 0;
}

static void reset_mock(void)
{
  memset(registers, 0, sizeof(registers));
  memset(lane_record, 0, sizeof(lane_record));
  selected_lane = 0u;
  descriptor_readback_mask = 0u;
  run_id_reads = 0u;
  change_run_id = 0;
  lock_depth = 0;
  mux_value = 0;
  mux_selected_value = 0;
  sequence_committed = 0;
  fail_register = -1;
}

static void populate_result(void)
{
  unsigned int lane;

  registers[0xc0u >> 2] = 0x00020000u;
  registers[0xc4u >> 2] = 0x00020000u;
  registers[0xc8u >> 2] = 0u;
  registers[0xf0u >> 2] = 7u;
  registers[0xf4u >> 2] = 0x00040401u;
  registers[0xf8u >> 2] = 9u;
  registers[0xfcu >> 2] = 0x00040401u;
  for (lane = 12u; lane <= 15u; ++lane) {
    lane_record[lane][0] = lane | GTTE_LANE_SELECTED | GTTE_LANE_LOCKED;
    lane_record[lane][3] = 0x89abcdefu + lane;
    lane_record[lane][4] = 0x01234567u;
    lane_record[lane][6] = lane;
    lane_record[lane][7] = 1u;
  }
}

int main(void)
{
  gtte_request_t request = {
    .sequence = 7u,
    .command = 0x00010501u,
    .duration = 1000u,
    .timeout = 2000u,
    .lane_mask = {0x0000f000u, 0u, 0u, 0u}
  };
  gtte_cm_result_set_t results;
  unsigned int lane;

  reset_mock();
  assert(gtte_cm_submit(GTTE_CM_FPGA_F1, &request) == GTTE_CM_OK);
  assert(sequence_committed);
  assert(registers[0xa0u >> 2] == 7u);
  assert(mux_selected_value == 4 && mux_value == 0 && lock_depth == 0);

  reset_mock();
  populate_result();
  assert(gtte_cm_read_managed_results(GTTE_CM_FPGA_F2, 9u, &results) ==
         GTTE_CM_OK);
  assert(mux_selected_value == 1 && mux_value == 0 && lock_depth == 0);
  assert(results.completion.run_id == 9u);
  assert(results.completion.summary.stop_reason == GTTE_STOP_NORMAL);
  for (lane = 0u; lane < 4u; ++lane) {
    assert(results.lane[lane].lane_id == lane + 12u);
    assert(gtte_lane_acceptance_passed(&results.lane[lane]));
  }

  reset_mock();
  populate_result();
  change_run_id = 1;
  assert(gtte_cm_read_managed_results(GTTE_CM_FPGA_F1, 9u, &results) ==
         GTTE_CM_ERROR_RESULT_CHANGED);
  assert(mux_value == 0 && lock_depth == 0);

  reset_mock();
  populate_result();
  fail_register = 0xd0;
  assert(gtte_cm_read_managed_results(GTTE_CM_FPGA_F1, 9u, &results) == 7);
  assert(mux_value == 0 && lock_depth == 0);

  return 0;
}
