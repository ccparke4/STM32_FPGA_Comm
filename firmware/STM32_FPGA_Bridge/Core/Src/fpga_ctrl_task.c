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
#include "fpga_link.h"
#include "app_config.h"
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
static void run_i2c_only_test(void);
static void run_stress_test(void);
static void run_normal_operation(void);

/* Public Functions =========================================================== */

fpga_handle_t* fpga_ctrl_get_handle(void) {
    return &fpga;
}

fpga_ctrl_stats_t* fpga_ctrl_get_stats(void) {
    return &stats;
}

bool fpga_ctrl_is_ready(void) {
    return (fpga.initialized && task_running);
}

/* Task Implementation ======================================================== */

void StartFpgaCtrlTask(void *argument) {
    (void)argument;

    DBG_PRINT("\n========================================\n");
    DBG_PRINT("  FPGA Control Plane Task Started\n");
    DBG_PRINT("  Test Mode: %d\n", APP_TEST_MODE);
    DBG_PRINT("========================================\n\n");

    /* Clear stats */
    memset(&stats, 0, sizeof(stats));

    /* initialize FPGA comm. */
    run_init_sequence();

    /* if init failed, suspend */
    if (fpga.initialized) {
        DBG_PRINT("[FPGA_CTRL] Init failed, task suspended\n");
        vTaskSuspend(NULL);
    }

    task_running = true;

    /* main loop - behavior is depndednt on test mode */
    for (;;) {
        switch (APP_TEST_MODE) {
            case TEST_MODE_I2C_ONLY:
                run_i2c_only_test();
                break;
            
            case TEST_MODE_I2C_SPI_STRESS:
                run_stress_test();
                break;

            case TEST_MODE_NORMAL:
            default:
                run_normal_operation();
                break;
        }
    }

}