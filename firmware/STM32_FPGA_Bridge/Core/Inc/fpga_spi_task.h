/**
* @file   fpga_spi_task.h
* @brief  FPGA SPI Data Plane Task header
* @author Trey Parker
* @date   2026-01-19
*/
#ifndef FPGA_SPI_TASK_H
#define FPGA_SPI_TASK_H

#include <stdint.h>
#include <stdbool.h>

/* Stats Structure ================================================= */

typedef struct {
    uint32_t transfer_count;        // Number of DMA transfers
    uint32_t bytes_transferred;     // Total bytes transferred
    uint32_t byte_errors;           // Byte mismatch errors
    uint32_t bit_errors;            // bit shift errors (mode mismatch)
    uint32_t dma_errors;            // DMA/HAL errors
} fpga_spi_stats_t;

/**
* @brief FPGA SPI Data Plane Task entry point
* @param argument: Not used
* @note  Create this task with osThreadNew()
*/
void StartFpgaSpiTask(void *argument);

/* Public API ====================================================== */

/**
* @brief  Get current SPI statistics
* @retval Pointer to stats structure
*/
fpga_spi_stats_t* fpga_spi_get_stats(void);

/**
* @brief  Check if SPI data plane is ready
* @retval true if task is running 
*/
bool fpga_spi_is_ready(void);

/**
* @brief print stats to dbg output
*/
void fpga_spi_print_stats(void);

#endif