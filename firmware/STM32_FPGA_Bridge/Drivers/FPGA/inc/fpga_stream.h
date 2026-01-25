/**
* @file     fpga_stream.h
* @brief    FPGA Data Plane Driver (SPI + DMA)
* @details  Handles high-speed SPI streaming, CS control, and DMA management
*/

#ifndef FPGA_STREAM_H
#define FPGA_STREAM_H

#include "stm32h7xx_hal.h"
#include <stdbool.h>
#include <stdint.h>

/* Status Definitions */
typedef enum {
    STREAM_OK = 0,
    STREAM_ERROR,
    STREAM_BUSY
} stream_status_t;

/* public API */

stream_status_t fpga_stream_init(SPI_HandleTypeDef *hspi);
stream_status_t fpga_stream_start(uint8_t *tx_buf, uint8_t *rx_buf, uint16_t len);
stream_status_t fpga_stream_stop(void);
bool fpga_stream_check_complete(void);
void fpga_stream_clear_complete(void);

#endif
