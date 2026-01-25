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
#include "fpga_ctrl_task.h" // To check system readiness
#include "fpga_stream.h"    // The New Driver
#include "app_config.h"
#include "cmsis_os.h"
#include "main.h"
#include <stdio.h>

/* DMA Buffers ======================================================= */

// out of stack, put in SRAM (global); align for cache
__attribute__((section(".RAM_D2"))) __attribute__((aligned(32))) uint8_t tx_buffer[64];
__attribute__((section(".RAM_D2"))) __attribute__((aligned(32))) uint8_t rx_buffer[64];


extern SPI_HandleTypeDef FPGA_SPI_HANDLE;

static fpga_spi_stats_t stats = {0};
static volatile bool spi_ready = false;

/* GPIO Definitions ================================================== */

/* Redundant but for reference */
#ifndef SPI_CS_GPIO_Port
#define SPI_CS_GPIO_Port    GPIOE
#endif
#ifndef SPI_CS_Pin
#define SPI_CS_Pin          GPIO_PIN_4
#endif

bool fpga_spi_is_ready(void) {
    return spi_ready;
}

fpga_spi_stats_t* fpga_spi_get_stats(void) {
    return &stats;
}

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
    DBG_PRINT("  Bit  Errors:   %lu\n", stats.bit_errors);
    DBG_PRINT("  DMA  Errors:   %lu\n", stats.dma_errors);
    DBG_PRINT("  Error Rate:    %.4f%%\n", error_rate);
    DBG_PRINT("===========================\n");
}

void StartFpgaSpiTask(void *argument) {
    (void)argument;
    spi_ready = false;

    // 1. Wait for Control Plane (Link Training)
    printf("[SPI] Waiting for Control Plane...\n");

    while (!fpga_ctrl_is_ready()) {
        osDelay(100);
    }
    printf("[SPI] Control Plane Ready. Initializing Stream.\n");

    // 2. Initialize the Stream Driver
    if (fpga_stream_init(&FPGA_SPI_HANDLE) != STREAM_OK) {
        printf("[SPI] Driver Init Failed!\n");
        // Kill task if driver fails, preventing crash
        vTaskDelete(NULL);
    }

    // 3. Fill Buffer with Pattern (0, 1, 2... 63)
    for(int i=0; i<64; i++) tx_buffer[i] = i;

    // 4. Start Continuous Stream
    if (fpga_stream_start(tx_buffer, rx_buffer, 64) == STREAM_OK) {
        printf("[SPI] Stream Started.\n");
        spi_ready = true;
    } else {
        printf("[SPI] Stream Start Failed!\n");
    }

    for(;;) {
        // 5. Process Data
        // The driver handles DMA in background. We check for completion flag.
        if (fpga_stream_check_complete()) {
            fpga_stream_clear_complete();

            stats.transfer_count++;
            stats.bytes_transferred += 64;

            // Simple Integrity Check
            // We expect rx_buffer[1] to match tx_buffer[1] (Echo)
            if (rx_buffer[1] != tx_buffer[1]) {
                 stats.byte_errors++;
            }
        }

        // Periodic Debug Print (Every 100 transfers)
        if (stats.transfer_count > 0 && (stats.transfer_count % 100 == 0)) {
            // Uncomment to spam console, or rely on DebugTask to call print_stats
            fpga_spi_print_stats();
            osDelay(10);
        } else {
            osDelay(1); // Yield
        }
    }
}
