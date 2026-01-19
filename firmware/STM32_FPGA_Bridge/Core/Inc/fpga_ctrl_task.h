/** 
* @file     fpga_ctrl_task.h
* @brief    FPGA I2C Control Plane Task Header
* @author   Trey Parker
* @date     2026-01-19
*/

#ifndef FPGA_CTRL_TASK_H
#define FPGA_CTRL_TASK_H

#include "fpga_link.h"
#include <stdint.h>
#include <stdbool.h>

/* Statistics Structure ======================================== */

typedef struct {
    uint32_t read_count;            // Succesful reads
    uint32_t read_errors;           // Failed reads
    uint32_t write_count;           // Successful writes
    uint32_t write_errors;          // Failed writes
    uint32_t verify_pass;           // W/R verification passes
    uint32_t verify_fail;           // W/R verification failures
    uint32_t scratch_tests_passed;  // Scratch test passes
    uint32_t scratch_tests_failed;  // Scratch test failures
} fpga_ctrl_stats_t;

/* Task function =============================================== */
/** 
* @brief FPGA Control Plane Task entry Point
* @param argument: not used
* @note  Create this via osThreadNew()
*/
void StartFpgaCtrlTask(void *argument);

/* API ======================================================== */
/** 
* @brief  Get FPGA handle for use in other modules
* @retval Pointer to FPGA handle
*/
fpga_handle_t* fpga_ctrl_get_handle(void);

/** 
* @brief  Get current stats
* @retval Pointer to stats structure
*/
fpga_ctrl_stats_t* fpga_ctrl_get_stats(void);

/** 
* @brief Check if FPGA control plane is ready
* @retval true if initialized and running
*/
bool fpga_ctrl_is_ready(void);

/**
* @brief Bump all FPGA regs to debug output
*/
void fpga_ctrl_dump_registers(void);

#endif
