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
#include "fpga_diagnostics.h"
#include "cmsis_os.h"
#include <stdio.h>

extern I2C_HandleTypeDef FPGA_I2C_HANDLE;

static fpga_handle_t fpga;
static fpga_ctrl_stats_t stats;
static volatile bool task_running = false;
static volatile bool system_ready = false;




/* api implementation */
bool fpga_ctrl_is_ready(void) {
    return system_ready;
}

fpga_handle_t* fpga_ctrl_get_handle(void) {
    return &fpga;
}

fpga_ctrl_stats_t* fpga_ctrl_get_stats(void) {
    return &stats;
}

// RESTORED: This was missing previously
void fpga_ctrl_dump_registers(void) {
    uint8_t val;
    printf("\n=== FPGA Register Dump ===\n");

    // System Regs
    fpga_read_reg(&fpga, 0x00, &val); printf("  [0x00] DEVICE_ID:   0x%02X\n", val);
    fpga_read_reg(&fpga, 0x01, &val); printf("  [0x01] VER_MAJ:     0x%02X\n", val);
    fpga_read_reg(&fpga, 0x03, &val); printf("  [0x03] SYS_STATUS:  0x%02X\n", val);

    // Link Regs
    fpga_read_reg(&fpga, 0x10, &val); printf("  [0x10] LINK_CAPS:   0x%02X\n", val);
    fpga_read_reg(&fpga, 0x11, &val); printf("  [0x11] DATA_MODE:   0x%02X\n", val);

    printf("==========================\n");
}


void StartFpgaCtrlTask(void *argument) {
    fpga_status_t status;
    uint8_t dev_id = 0;
    uint8_t status_val = 0;

    printf("\n[CTRL] FPGA Control Plane Started\n");

    /* initialize driver */
    status = fpga_init_with_retry(&fpga, &FPGA_I2C_HANDLE, 3, 100);

    if (status != FPGA_OK) {
        printf("[CTRL] CRITICAL: Link Init Failed!\n");
        // We stay in loop but don't set ready flag
    }

    /* Link verification/config */
    status = fpga_read_reg(&fpga, 0x00, &dev_id); // Read DEVICE_ID

    if (status == FPGA_OK && dev_id == 0xA7) {
        printf("[CTRL] Link Verified. Device ID: 0x%02X\n", dev_id);
        printf("[CTRL] Enabling Data Plane...\n");
        fpga_diagnostics_print_system_info(&fpga);
        system_ready = true; // <--- SIGNAL THE SPI TASK
    } else {
        printf("[CTRL] ID Mismatch or Read Fail. ID: 0x%02X\n", dev_id);
    }

    /* health check */
    for (;;) {
        // blink LED register
        if (system_ready) {
            fpga_read_reg(&fpga, 0x03, &status_val);
        }
        osDelay(500);
    }


}
