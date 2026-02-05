/*
 * link_char_task.c
 *
 *  Created on: Feb 5, 2026
 *      Author: treyparker
 */

#include "link_char_task.h"
#include "link_char.h"
#include "fpga_link.h"
#include "app_config.h"
#include "cmsis_os.h"
#include <stdio.h>

#if ENABLE_LINK_CHAR

extern I2C_HandleTypeDef FPGA_I2C_HANDLE;

static fpga_handle_t s_fpga;
static link_char_results_t s_results;
static volatile bool s_test_complete = false;
static volatile bool s_test_passed = false;

/*
 * API
 */

bool link_char_task_is_complete(void)
{
    return s_test_complete;
}

bool link_char_task_passed(void)
{
    return s_test_passed;
}

const link_char_results_t* link_char_task_get_results(void)
{
    return &s_results;
}

/*
 * Task Entry Point
 */
void StartLinkCharTask(void *argument)
{
    (void)argument;

    printf("\n");
    printf("==============================================================\n");
    printf("          LINK CHARACTERIZATION TASK STARTED                  \n");
    printf("==============================================================\n");
#if LINK_CHAR_FULL_SUITE
    printf("  Mode: FULL SUITE                                            \n");
    printf("  This will take several minutes...                           \n");
#else
    printf("  Mode: QUICK (~10 seconds)                                   \n");
#endif
    printf("==============================================================\n");
    printf("\n");

    // Small delay to let debug console catch up
    osDelay(500);

    // Initialize FPGA link
    printf("[CHAR_TASK] Initializing FPGA link...\n");
    fpga_status_t status = fpga_init_with_retry(&s_fpga, &FPGA_I2C_HANDLE, 3, 100);

    if (status != FPGA_OK) {
        printf("[CHAR_TASK] CRITICAL: FPGA init failed! status=%d\n", status);
        printf("[CHAR_TASK] Check:\n");
        printf("  1. I2C wiring (SDA, SCL)\n");
        printf("  2. FPGA is programmed\n");
        printf("  3. FPGA powered on\n");
        s_test_complete = true;
        s_test_passed = false;
        vTaskDelete(NULL);
        return;
    }

    // Initialize characterization module
    if (!link_char_init(&s_fpga)) {
        printf("[CHAR_TASK] CRITICAL: link_char_init failed!\n");
        s_test_complete = true;
        s_test_passed = false;
        vTaskDelete(NULL);
        return;
    }

    // Run characterization
    printf("[CHAR_TASK] Starting characterization...\n");
    printf("[CHAR_TASK] Connect logic analyzer/scope now if desired.\n");
    printf("[CHAR_TASK] Trigger pin: PE0 (pulses at test boundaries)\n");
    printf("\n");

    osDelay(1000);  // Give user time to connect probe

#if LINK_CHAR_FULL_SUITE
    // Full suite
    link_char_config_t cfg = {
        .i2c_iterations = LINK_CHAR_I2C_ITERATIONS,
        .spi_burst_size = LINK_CHAR_SPI_BURST_SIZE,
        .spi_ber_bytes = LINK_CHAR_SPI_BER_BYTES,
        .concurrent_duration_sec = LINK_CHAR_CONCURRENT_SEC,
        .stress_duration_sec = LINK_CHAR_STRESS_SEC,
        .verbose = true,
        .gpio_trigger = true
    };
    s_test_passed = link_char_run(CHAR_TEST_ALL, &cfg, &s_results);
#else
    // Quick suite
    s_test_passed = link_char_quick(&s_results);
#endif

    // Print final results
    link_char_print_results(&s_results);
    link_char_print_csv(&s_results);

    // Summary
    printf("\n");
    printf("==============================================================\n");
    if (s_test_passed) {
        printf("              ✓ ALL TESTS PASSED                         \n");
    } else {
        printf("              ✗ SOME TESTS FAILED                        \n");
    }
    printf("==============================================================\n");
    printf("  Duration: %-5lu ms                                          \n", s_results.test_duration_ms);
    printf("                                                              \n");
    printf("  Key Metrics:                                                \n");
    printf("    I2C Read Latency:  %4lu µs avg                            \n", s_results.i2c.read_avg_us);
    printf("    SPI Throughput:    %4lu KB/s (DMA)                        \n", s_results.spi.dma_throughput_kbps);
    printf("    Bit Error Rate:    %.2e                                	  \n", s_results.spi.ber);
    printf("==============================================================\n");

    s_test_complete = true;

    /* Keep task alive for queries, or delete */
    printf("\n[CHAR_TASK] Characterization complete. Task idle.\n");

    for (;;) {
        osDelay(10000);  /* Sleep forever */
    }
}

#endif /* ENABLE_LINK_CHAR */
