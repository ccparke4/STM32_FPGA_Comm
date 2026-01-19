/**
* @file     fpga_spi_task.c
* @brief    FPGA SPI Data Plane Task
* @author   Trey Parker
* @date     2026-01-19
*
* @details  FreeRTOS task for FPGA high-speed data splane via SPI. 
*           Handles DMA transfers and data integrity verification.
*/

#include "fpga_spi_task.h"
#include "app_config.h"
#include "cmsis_os.h"
#include "main.h"
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#ifndef SPI_CS_HIGH
#define SPI_CS_HIGH()   HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET)
#endif

#ifndef SPI_CS_LOW
#define SPI_CS_LOW()    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_RESET)
#endif

/* External References =============================================== */

extern SPI_HandleTypeDef FPGA_SPI_HANDLE;
extern volatile uint8_t spi_dma_complete;


/* DMA Buffers ======================================================= */

// out of stack, put in SRAM (global); align for cache
__attribute__((section(".RAM_D2"))) __attribute__((aligned(32))) uint8_t tx_buffer[64];
__attribute__((section(".RAM_D2"))) __attribute__((aligned(32))) uint8_t rx_buffer[64];

/* Private Variables ================================================= */

static fpga_spi_stats_t stats;
static volatile bool task_running = false;

/* Private Function Prototypes ======================================= */

static void run_dma_burst(void);
static void verify_transfer(void);

/* GPIO Definitions ================================================== */

/* Redundant but for reference */
#ifndef SPI_CS_GPIO_Port
#define SPI_CS_GPIO_Port    GPIOE
#endif
#ifndef SPI_CS_Pin
#define SPI_CS_Pin          GPIO_PIN_4
#endif

/* Public Functions ==================================================== */

fpga_spi_stats_t* fpga_spi_get_stats(void) {
    return &stats;
}

bool fpga_spi_is_ready(void) {
    return task_running;
}

/* Task Implementation ================================================== */

void StartFpgaSpiTask(void *argument) {
    (void)argument;

    DBG_PRINT("\n========================================\n");
    DBG_PRINT("  FPGA SPI Data Plane Task Started\n");
    DBG_PRINT("========================================\n\n");

    /* Clear statistics */
    memset(&stats, 0, sizeof(stats));

    /* Report buffer addresses for debug */
    DBG_PRINT("[FPGA_SPI] TX Buffer: %p\n", (void*)tx_buffer);
    DBG_PRINT("[FPGA_SPI] RX Buffer: %p\n", (void*)rx_buffer);

    /* initialize buffers */
    memset(rx_buffer, 0x00, SPI_DMA_BUFFER_SIZE);
    for (int i = 0; i < SPI_DMA_BUFFER_SIZE; i++) {
        tx_buffer[i] = (uint8_t)i;
    }

    /* Ensure CS starts high */
    SPI_CS_HIGH();

    DBG_PRINT("[FPGA_SPI] Starting DMA transfers...\n\n");

    task_running = true;

    /* Main loop */
    for (;;) {
        run_dma_burst();
        osDelay(TASK_PERIOD_SPI_BURST);
    }

}


/* Private Functions ================================================= */

/**
* @brief Execute single DMA burst transfer
*/
static void run_dma_burst(void) {
    HAL_StatusTypeDef hal_status;

    /* Reset DMA completion flag */
    spi_dma_complete = 0;

    /* Assert chip select */
    SPI_CS_LOW();

    /* start DMA transfer */
    hal_status = HAL_SPI_TransmitReceive_DMA(&FPGA_SPI_HANDLE, 
                                              tx_buffer, rx_buffer,
                                              SPI_DMA_BUFFER_SIZE);

    if (hal_status != HAL_OK) {
        SPI_CS_HIGH();
        stats.dma_errors++;
        DBG_PRINT("[FPGA_SPI] DMA Error: %d\n", hal_status);
        return;
    }

    /* Wait for completion with timeout */
    uint32_t timeout = HAL_GetTick() + 100;
    while (!spi_dma_complete) {
        if (HAL_GetTick() > timeout) {
            SPI_CS_HIGH();
            stats.dma_errors++;
            DBG_PRINT("[FPGA_SPI] DMA Timeout\n");
            return;
        }
        osDelay(1);
    }

    /* Deassert chip select */
    SPI_CS_HIGH();

    /* Update statistics and verify */
    stats.transfer_count++;
    verify_transfer();

    /* Update TX pattern for next transfer */
    for (int i = 0; i < SPI_DMA_BUFFER_SIZE; i++) {
        tx_buffer[i]++;
    }
}


/**
* @brief Verify transfer integrity
*/
static void verify_transfer(void) {
    uint32_t exact_match = 0;
    uint32_t left_shift = 0;

    /* Verify: rx_buffer[i] should equal tx_buffer[i-1] (pipeline delay) */
    for (int i = 1; i < SPI_DMA_BUFFER_SIZE; i++) {
        if (rx_buffer[i] == tx_buffer[i-1]) {
            exact_match++;
        }
        if (rx_buffer[i] == (uint8_t)(tx_buffer[i-1] << 1)) {
            left_shift++;
        }
    }

    /* check for bit shift error */ 
    if (left_shift > exact_match) {
        stats.bit_errors += (SPI_DMA_BUFFER_SIZE - 1);
        if ((stats.transfer_count % 100) == 0) {
            DBG_PRINT("[FPGA_SPI] WARNING: Bit shift detected! Check SPI Mode\n");
        }
    } else if (exact_match < (SPI_DMA_BUFFER_SIZE - 1)) {
        stats.byte_errors += ((SPI_DMA_BUFFER_SIZE - 1) - exact_match);
    }    
    
    stats.bytes_transferred += SPI_DMA_BUFFER_SIZE;
    
    /* Periodic report */
    if ((stats.transfer_count % 100) == 0) {
        DBG_PRINT("[FPGA_SPI] Xfer: %lu | Match: %lu/%d | Bytes: %lu | Errors: B=%lu S=%lu D=%lu\n",
        stats.transfer_count,
        exact_match, SPI_DMA_BUFFER_SIZE - 1,
        stats.bytes_transferred,
        stats.byte_errors, stats.bit_errors, stats.dma_errors);
    }
}

/* Utility functions ===================================================== */
void fpga_spi_print_stats(void) {
    uint32_t total_errors = stats.byte_errors + stats.bit_errors + stats.dma_errors;
    float error_rate = 0;

    if (stats.bytes_transferred > 0) {
        error_rate = (float)total_errors * 100.0f / (float)stats.bytes_transferred;
    }

    DBG_PRINT("\n=== FPGA SPI Statistics ===\n");
    DBG_PRINT("  Transfers:     %lu\n", stats.transfer_count);
    DBG_PRINT("  Bytes:         %lu\n", stats.bytes_transferred);
    DBG_PRINT("  Byte Errors:   %lu\n", stats.byte_errors);
    DBG_PRINT("  Bit Errors:    %lu\n", stats.bit_errors);
    DBG_PRINT("  DMA Errors:    %lu\n", stats.dma_errors);
    DBG_PRINT("  Error Rate:    %.6f%%\n", error_rate);
    DBG_PRINT("===========================\n\n");
}
