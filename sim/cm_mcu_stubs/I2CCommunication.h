#ifndef TEST_I2C_COMMUNICATION_H
#define TEST_I2C_COMMUNICATION_H

#include <stdint.h>

int apollo_i2c_ctl_w(uint8_t device, uint8_t address, uint8_t nbytes,
                     unsigned int value);
int apollo_i2c_ctl_reg_r(uint8_t device, uint8_t address,
                         uint8_t nbytes_addr, uint16_t register_address,
                         uint8_t nbytes, uint32_t *data);
int apollo_i2c_ctl_reg_w(uint8_t device, uint8_t address,
                         uint8_t nbytes_addr, uint16_t register_address,
                         uint8_t nbytes, uint32_t data);

#endif
