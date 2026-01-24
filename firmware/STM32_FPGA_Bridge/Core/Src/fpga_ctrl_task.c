/**
* @file    fpga_ctrl_task.c
* @brief   FPGA I2C Control Plane Task
* @author  Trey Parker
* @date    2026-01-19
*
* @details FreeRTOS task for FPGA communication via I2C control plane.
*          Handles initialization, status polling, and register access.
*/

#include "fpga_ctrl_task.h"
#include "app_config.h"
#include "fpga_link.h"
#include "cmsis_os.h"
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
/* External Refs ============================================================== */

extern I2C_HandleTypeDef FPGA_I2C_HANDLE;

/* Private Variabled ========================================================== */

static fpga_handle_t fpga;
static fpga_ctrl_stats_t stats;
static volatile bool task_running = false;

/* Private Function Prototypes ================================================ */

static void run_init_sequence(void);
static void run_i2c_test(void);

/* Public Functions =========================================================== */

fpga_ctrl_stats_t* fpga_ctrl_get_stats(void) {
    return &stats;
}

bool fpga_ctrl_is_ready(void) {
    return (fpga.initialized && task_running);
}

/* Task Implementation ======================================================== */

void StartFpgaCtrlTask(void *argument) {
    (void)argument;

    printf("\n========================================\n");
    printf("  FPGA Control Plane Task Started\n");
    printf("========================================\n\n");

    memset(&stats, 0, sizeof(stats));

    /* Initialize FPGA communication */
    run_init_sequence();

    if (!fpga.initialized) {
        printf("[FPGA_CTRL] Init failed, task suspended\n");
        vTaskSuspend(NULL);
    }

    task_running = true;

    /* Main loop */
    for (;;) {
        run_i2c_test();
        osDelay(100);
    }
}

/* Private Functions ============================================================*/
static void run_init_sequence(void) {
    fpga_status_t status;

    printf("[FPGA_CTRL] Initializing...\n");

    /* Attempt initialization with retries */
    for (int attempt = 1; attempt <= 3; attempt++) {
        printf("[FPGA_CTRL] Init attempt %d/3\n", attempt);

        status = fpga_init(&fpga, &hi2c1);

        if (status == FPGA_OK) {
            break;
        }

        printf("[FPGA_CTRL] Init failed: %s\n", fpga_status_str(status));
        osDelay(100);
    }

    if (status != FPGA_OK) {
        printf("[FPGA_CTRL] FATAL: Could not initialize FPGA\n");
        return;
    }

    printf("\n[FPGA_CTRL] Device Found!\n");
    fpga_print_info(&fpga);

    /* Run scratch register test */
    printf("\n[FPGA_CTRL] Scratch Register Test: ");
    status = fpga_test_scratch(&fpga);
    if (status == FPGA_OK) {
        printf("PASS\n");
        stats.scratch_tests_passed++;
    } else {
        printf("FAIL (%s)\n", fpga_status_str(status));
        stats.scratch_tests_failed++;
    }

    /* LED walking pattern to confirm hardware */
    printf("[FPGA_CTRL] LED Test Pattern...\n");
    for (int i = 0; i < 8; i++) {
        fpga_set_leds(&fpga, 1 << i);
        osDelay(200);
    }
    for (int i = 6; i >= 0; i--) {
        fpga_set_leds(&fpga, 1 << i);
        osDelay(200);
    }
    fpga_set_leds(&fpga, 0x00);

    printf("[FPGA_CTRL] Init complete!\n\n");
}

static void run_i2c_test(void) {
    fpga_status_t status;
    uint8_t read_val;
    static uint32_t iteration = 0;
    static uint32_t last_report = 0;

    iteration++;

    /* Test 1: Read DEVICE_ID */
    status = fpga_read_reg(&fpga, FPGA_REG_DEVICE_ID, &read_val);
    if (status == FPGA_OK && read_val == FPGA_DEVICE_ID_EXPECTED) {
        stats.read_count++;
    } else {
        stats.read_errors++;
    }

    /* Test 2: Scratch register round-trip */
    uint8_t test_val = (uint8_t)(iteration & 0xFF);
    status = fpga_write_reg(&fpga, FPGA_REG_SCRATCH0, test_val);
    if (status == FPGA_OK) {
        stats.write_count++;
    } else {
        stats.write_errors++;
    }

    status = fpga_read_reg(&fpga, FPGA_REG_SCRATCH0, &read_val);
    if (status == FPGA_OK) {
        stats.read_count++;
        if (read_val == test_val) {
            stats.verify_pass++;
        } else {
            stats.verify_fail++;
        }
    } else {
        stats.read_errors++;
    }

	/* Test 3: Mirror switches to LEDs */
	uint8_t switches;
	uint8_t led_val = 0;

	if (fpga_get_switches(&fpga, &switches) == FPGA_OK) {
		// Mask out the top bit so we can use it for heartbeat
		led_val = switches & 0x7F;

		// Toggle Bit 7 every 5 iterations (approx 500ms since task delay is 100ms)
		if ((iteration % 10) < 5) {
			led_val |= 0x80;
		}

		fpga_set_leds(&fpga, led_val);
	}

    /* Periodic status report */
    uint32_t now = HAL_GetTick();
    if (now - last_report >= 5000) {
        last_report = now;
        printf("\n[FPGA_CTRL] === I2C Test Report ===\n");
        printf("  Iterations:    %lu\n", iteration);
        printf("  Reads:         %lu (err: %lu)\n", stats.read_count, stats.read_errors);
        printf("  Writes:        %lu (err: %lu)\n", stats.write_count, stats.write_errors);
        printf("  Verify:        %lu pass / %lu fail\n", stats.verify_pass, stats.verify_fail);

        float error_rate = 0;
        uint32_t total = stats.read_count + stats.write_count;
        uint32_t errors = stats.read_errors + stats.write_errors;
        if (total > 0) {
            error_rate = (float)errors * 100.0f / (float)total;
        }
        printf("  Error Rate:    %.4f%%\n", error_rate);
        printf("================================\n\n");
    }
}

void fpga_ctrl_dump_registers(void) {
    uint8_t val;

    printf("\n=== FPGA Register Dump ===\n");

    printf("System Registers:\n");
    fpga_read_reg(&fpga, FPGA_REG_DEVICE_ID, &val);
    printf("  [0x00] DEVICE_ID:   0x%02X\n", val);
    fpga_read_reg(&fpga, FPGA_REG_VERSION_MAJ, &val);
    printf("  [0x01] VERSION_MAJ: 0x%02X\n", val);
    fpga_read_reg(&fpga, FPGA_REG_VERSION_MIN, &val);
    printf("  [0x02] VERSION_MIN: 0x%02X\n", val);
    fpga_read_reg(&fpga, FPGA_REG_SCRATCH0, &val);
    printf("  [0x05] SCRATCH0:    0x%02X\n", val);
    fpga_read_reg(&fpga, FPGA_REG_SCRATCH1, &val);
    printf("  [0x06] SCRATCH1:    0x%02X\n", val);

    printf("Link Registers:\n");
    fpga_read_reg(&fpga, FPGA_REG_LINK_CAPS, &val);
    printf("  [0x10] LINK_CAPS:   0x%02X\n", val);

    printf("GPIO Registers:\n");
    fpga_read_reg(&fpga, FPGA_REG_LED_OUT, &val);
    printf("  [0x20] LED_OUT:     0x%02X\n", val);
    fpga_read_reg(&fpga, FPGA_REG_SW_IN, &val);
    printf("  [0x22] SW_IN:       0x%02X\n", val);

    printf("==========================\n\n");
}
