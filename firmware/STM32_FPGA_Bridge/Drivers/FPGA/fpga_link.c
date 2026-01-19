/**
* @file    fpga_link.c
* @brief   FPGA Communication Driver - I2C Control Plane Implementation
* @author  Trey Parker
* @date    2026-01-18
* @version 1.0
*/

#include "fpga_link.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

/* Private Macros ======================================================== */
#define FPGA_I2C_ADDR_WRITE     (FPGA_I2C_ADDR << 1)

/*Private Functions ====================================================== */
/**
* @brief    Check if handle is valid and initialized
*/
static inline bool fpga_is_valid(fpga_handle_t *hfpga) {
    return (hfpga != NULL && hfpga->hi2c != NULL);
}

/* Core Functions Implementation ======================================== */

fpga_status_t fpga_init(fpga_handle_t *hfpga, I2C_HandleTypeDef *hi2c) {
    fpga_status_t status;

    /* Validate Params */
    if (hfpga == NULL || hi2c == NULL) {
        return FPGA_ERR_PARAM;
    }

    /* Initialize handle */
    memset(hfpga, 0, sizeof(fpga_handle_t));
    hfpga->hi2c = hi2c;
    hfpga->initialized = false;

    /* 1. Check device presence on I2C Bus */
    if (HAL_I2C_IsDeviceReady(hi2c, FPGA_I2C_ADDR_WRITE, 3, FPGA_I2C_TIMEOUT_MS) != HAL_OK) {
        return FPGA_ERR_I2C;
    }

    /* 2. Read & verify DEVICE_ID */
    status = fpga_read_reg(hfpga, FPGA_REG_DEVICE_ID, &hfpga->info.device_id);
    if (status != FPGA_OK) {
        return status;
    }

    if (hfpga->info.device_id != FPGA_DEVICE_ID_EXPECTED) {
        return FPGA_ERR_DEVICE_ID;
    }

    /* 3. Read Version information */
    status = fpga_read_reg(hfpga, FPGA_REG_VERSION_MAJ, &hfpga->info.version_maj);
    if (status != FPGA_OK) return status;
    
    status = fpga_read_reg(hfpga, FPGA_REG_VERSION_MIN, &hfpga->info.version_min);
    if (status != FPGA_OK) return status;

    /* Phase 4: Read link capabilities */
    status = fpga_read_reg(hfpga, FPGA_REG_LINK_CAPS, &hfpga->info.link_caps);
    if (status != FPGA_OK) return status;
    
    /* Mark as initialized */
    hfpga->initialized = true;
    
    return FPGA_OK;
}

fpga_status_t fpga_read_reg(fpga_handle_t *hfpga, uint8_t reg, uint8_t *data) {
    if (!fpga_is_valid(hfpga) || data == NULL) {
        return FPGA_ERR_PARAM;
    }

    if (HAL_I2C_Mem_Read(hfpga->hi2c, FPGA_I2C_ADDR_WRITE, reg,
            I2C_MEMADD_SIZE_8BIT, data, 1, FPGA_I2C_TIMEOUT_MS) != HAL_OK) {
        return FPGA_ERR_I2C;
    }
    
    return FPGA_OK;
}

fpga_status_t fpga_write_reg(fpga_handle_t *hfpga, uint8_t reg, uint8_t data) {
    if (!fpga_is_valid(hfpga)) {
        return FPGA_ERR_PARAM;
    }
    
    if (HAL_I2C_Mem_Write(hfpga->hi2c, FPGA_I2C_ADDR_WRITE, reg,
            I2C_MEMADD_SIZE_8BIT, &data, 1, FPGA_I2C_TIMEOUT_MS) != HAL_OK) {
        return FPGA_ERR_I2C;
    }
    
    return FPGA_OK;
}

fpga_status_t fpga_read_burst(fpga_handle_t *hfpga, uint8_t reg, uint8_t *buf, uint16_t len) {
    if (!fpga_is_valid(hfpga) || buf == NULL || len == 0) {
        return FPGA_ERR_PARAM;
    }
    
    if (HAL_I2C_Mem_Read(hfpga->hi2c, FPGA_I2C_ADDR_WRITE, reg,
            I2C_MEMADD_SIZE_8BIT, buf, len, FPGA_I2C_TIMEOUT_MS) != HAL_OK) {
        return FPGA_ERR_I2C;
    }
    
    return FPGA_OK;
}

fpga_status_t fpga_write_burst(fpga_handle_t *hfpga, uint8_t reg, uint8_t *buf, uint16_t len) {
    if (!fpga_is_valid(hfpga) || buf == NULL || len == 0) {
        return FPGA_ERR_PARAM;
    }
    
    if (HAL_I2C_Mem_Write(hfpga->hi2c, FPGA_I2C_ADDR_WRITE, reg,
            I2C_MEMADD_SIZE_8BIT, buf, len, FPGA_I2C_TIMEOUT_MS) != HAL_OK) {
        return FPGA_ERR_I2C;
    }
    
    return FPGA_OK;
}

/* Convient Functions ========================================================================= */

fpga_status_t fpga_set_leds(fpga_handle_t *hfpga, uint8_t pattern) {
    return fpga_write_reg(hfpga, FPGA_REG_LED_OUT, pattern);
}

fpga_status_t fpga_set_leds_16(fpga_handle_t *hfpga, uint16_t pattern) {
    fpga_status_t status;
    
    status = fpga_write_reg(hfpga, FPGA_REG_LED_OUT, (uint8_t)(pattern & 0xFF));
    if (status != FPGA_OK) return status;
    
    status = fpga_write_reg(hfpga, FPGA_REG_LED_OUT_H, (uint8_t)(pattern >> 8));
    return status;
}

fpga_status_t fpga_get_switches(fpga_handle_t *hfpga, uint8_t *sw_state) {
    return fpga_read_reg(hfpga, FPGA_REG_SW_IN, sw_state);
}

fpga_status_t fpga_get_switches_16(fpga_handle_t *hfpga, uint16_t *sw_state) {
    uint8_t buf[2];
    fpga_status_t status;
        
    if (sw_state == NULL) {
        return FPGA_ERR_PARAM;
    }
    
    status = fpga_read_burst(hfpga, FPGA_REG_SW_IN, buf, 2);
    if (status != FPGA_OK) return status;
    
    *sw_state = (uint16_t)buf[0] | ((uint16_t)buf[1] << 8);
    return FPGA_OK;
}

/* Test functions ============================================================================ */

fpga_status_t fpga_test_scratch(fpga_handle_t *hfpga) {
    const uint8_t test_patterns[] = {0x55, 0xAA, 0x00, 0xFF, 0xA5, 0x5A};
    uint8_t readback;
    fpga_status_t status;

     if (!fpga_is_valid(hfpga)) {
        return FPGA_ERR_PARAM;
    }
    
    /* Test SCRATCH0 */
    for (size_t i = 0; i < sizeof(test_patterns); i++) {
        status = fpga_write_reg(hfpga, FPGA_REG_SCRATCH0, test_patterns[i]);
        if (status != FPGA_OK) return status;
        
        status = fpga_read_reg(hfpga, FPGA_REG_SCRATCH0, &readback);
        if (status != FPGA_OK) return status;
        
        if (readback != test_patterns[i]) {
            return FPGA_ERR_VERIFY;
        }
    }
    
    /* Test SCRATCH1 */
    for (size_t i = 0; i < sizeof(test_patterns); i++) {
        status = fpga_write_reg(hfpga, FPGA_REG_SCRATCH1, test_patterns[i]);
        if (status != FPGA_OK) return status;
        
        status = fpga_read_reg(hfpga, FPGA_REG_SCRATCH1, &readback);
        if (status != FPGA_OK) return status;
        
        if (readback != test_patterns[i]) {
            return FPGA_ERR_VERIFY;
        }
    }

    /* cleanup - reset scratch regs*/
    fpga_write_reg(hfpga, FPGA_REG_SCRATCH0, 0x00);
    fpga_write_reg(hfpga, FPGA_REG_SCRATCH1, 0x00);

    return FPGA_OK;
}

fpga_status_t fpga_test_link(fpga_handle_t *hfpga) {
    uint8_t device_id;
    fpga_status_t status;

    if (!fpga_is_valid(hfpga)) {
        return FPGA_ERR_PARAM;
    }

    /* check device ready */
    if (HAL_I2C_IsDeviceReady(hfpga->hi2c, FPGA_I2C_ADDR_WRITE, 1, FPGA_I2C_TIMEOUT_MS) != HAL_OK) {
        return FPGA_ERR_I2C;
    }

    /* Verify device ID */
    status = fpga_read_reg(hfpga, FPGA_REG_DEVICE_ID, &device_id);
    if (status != FPGA_OK) return status;
    
    if (device_id != FPGA_DEVICE_ID_EXPECTED) {
        return FPGA_ERR_DEVICE_ID;
    }

    return FPGA_OK;
}

/* Utility Functions =================================================================== */

const char* fpga_status_str(fpga_status_t status) {
    switch (status) {
        case FPGA_OK:           return "OK";
        case FPGA_ERR_I2C:      return "I2C Error";
        case FPGA_ERR_DEVICE_ID: return "Wrong Device ID";
        case FPGA_ERR_TIMEOUT:  return "Timeout";
        case FPGA_ERR_VERIFY:   return "Verification Failed";
        case FPGA_ERR_PARAM:    return "Invalid Parameter";
        default:                return "Unknown Error";
    }
}

void fpga_print_info(fpga_handle_t *hfpga) {
    if (!fpga_is_valid(hfpga) || !hfpga->initialized) {
        printf("FPGA: Not initialized\n");
        return;
    }
    
    printf("FPGA Device Info:\n");
    printf("  Device ID:  0x%02X %s\n", hfpga->info.device_id,
           (hfpga->info.device_id == FPGA_DEVICE_ID_EXPECTED) ? "(OK)" : "(MISMATCH)");
    printf("  Version:    %d.%d\n", hfpga->info.version_maj, hfpga->info.version_min);
    printf("  LINK_CAPS:  0x%02X\n", hfpga->info.link_caps);
    printf("    - IRQ:    %s\n", (hfpga->info.link_caps & LINK_CAPS_IRQ_AVAIL) ? "Yes" : "No");
    printf("    - CRC:    %s\n", (hfpga->info.link_caps & LINK_CAPS_CRC_AVAIL) ? "Yes" : "No");
    printf("    - DMA:    %s\n", (hfpga->info.link_caps & LINK_CAPS_DMA_AVAIL) ? "Yes" : "No");
    printf("    - FMC:    %s\n", (hfpga->info.link_caps & LINK_CAPS_FMC_AVAIL) ? "Yes" : "No");
}

/* Extended Fucntions =================================================================== */

/**
* @brief    Set data plane mode (TBD FPGA side)
* @param    hfpga: Pointer to initialized FPGA handle
* @param    mode: Data plane mode (FPGA_MODE_SPI,...)
* @param    enable: Enable data plane after mode set
* @retval   FPGA_OK on success, else error
*/
fpga_status_t fpga_set_data_mode(fpga_handle_t *hfpga, fpga_data_mode_t mode, bool enable) {
    uint8_t reg_val;
    
    if (!fpga_is_valid(hfpga)) {
        return FPGA_ERR_PARAM;
    }
    
    reg_val = (mode & DATA_MODE_MODE_MASK);
    if (enable) {
        reg_val |= DATA_MODE_ENABLE;
    }
    
    return fpga_write_reg(hfpga, FPGA_REG_DATA_MODE, reg_val);
}

/**
* @brief  Enable loopback mode for testing
* @param  hfpga: Pointer to initialized FPGA handle
* @param  enable: Enable or disable loopback
* @retval FPGA_OK on success, error code otherwise
*/
fpga_status_t fpga_set_loopback(fpga_handle_t *hfpga, bool enable) {
    uint8_t reg_val;
    fpga_status_t status;
    
    if (!fpga_is_valid(hfpga)) {
        return FPGA_ERR_PARAM;
    }
    
    /* Read current mode */
    status = fpga_read_reg(hfpga, FPGA_REG_DATA_MODE, &reg_val);
    if (status != FPGA_OK) return status;
    
    /* Set or clear loopback bit */
    if (enable) {
        reg_val |= DATA_MODE_LOOPBACK;
    } else {
        reg_val &= ~DATA_MODE_LOOPBACK;
    }
    
    return fpga_write_reg(hfpga, FPGA_REG_DATA_MODE, reg_val);
}

/**
* @brief  Read all system registers in one burst
* @param  hfpga: Pointer to initialized FPGA handle
* @param  buf: Buffer to store 7 bytes (0x00-0x06)
* @retval FPGA_OK on success, error code otherwise
*/
fpga_status_t fpga_read_sys_regs(fpga_handle_t *hfpga, uint8_t *buf) {
    return fpga_read_burst(hfpga, FPGA_REG_DEVICE_ID, buf, 7);
}