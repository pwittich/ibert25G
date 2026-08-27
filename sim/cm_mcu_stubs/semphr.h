#ifndef TEST_SEMPHR_H
#define TEST_SEMPHR_H

#include "FreeRTOS.h"

typedef void *SemaphoreHandle_t;

BaseType_t xSemaphoreGive(SemaphoreHandle_t semaphore);

#endif
