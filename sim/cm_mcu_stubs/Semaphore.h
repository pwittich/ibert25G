#ifndef TEST_SEMAPHORE_H
#define TEST_SEMAPHORE_H

#include "semphr.h"

extern SemaphoreHandle_t i2c5_sem;
SemaphoreHandle_t getSemaphore(int number);
int acquireI2CSemaphoreTime(SemaphoreHandle_t semaphore,
                            TickType_t ticks_to_wait);

#endif
