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
#define FPGA_I2C_ADDR_READ		(FPGA_I2C_ADDR << 1)
/*Private Functions ====================================================== */

/*
* Check if handle is valid and initialized
*/
static inline bool fpga_is_valid(fpga_handle_t *hfpga) {
    return (hfpga != NULL && hfpga->hi2c != NULL);
}

/*
 *  Helper to get string name from device ID
 */
static const char* get_device_name(uint8_t device_id) {
    switch(device_id) {
        case 0xA7: return "Artix-7 FPGA";
        case 0xA0: return "Generic FPGA";
        case 0x50: return "EEPROM";
        default:   return "Unknown Device";
    }
}


/* Core Functions Implementation ======================================== */

fpga_status_t fpga_init(fpga_handle_t *hfpga, I2C_HandleTypeDef *hi2c) {
    fpga_status_t status;
    HAL_StatusTypeDef hal_status;

    FPGA_DEBUG("=== FPGA INIT START ===");
    FPGA_DEBUG("hfpga=%p, hi2c=%p", (void*)hfpga, (void*)hi2c);

    /* Validate Params */
    if (hfpga == NULL || hi2c == NULL) {
        FPGA_DEBUG("ERROR: NULL parameters");
        return FPGA_ERR_PARAM;
    }

    /* Initialize handle */
    memset(hfpga, 0, sizeof(fpga_handle_t));
    hfpga->hi2c = hi2c;

    /* CRITICAL FIX: Set true NOW so read_reg doesn't block us */
    hfpga->initialized = true;
    FPGA_DEBUG("Handle initialized (Tentative)");

    /* 1. Check device presence on I2C Bus */
    FPGA_DEBUG_STEP(1, "Ping Device");
    FPGA_DEBUG("Checking device at address 0x%02X (write)", FPGA_I2C_ADDR_WRITE);

    hal_status = HAL_I2C_IsDeviceReady(hi2c, FPGA_I2C_ADDR_WRITE, 3, FPGA_I2C_TIMEOUT_MS);

    if (hal_status != HAL_OK) {
        FPGA_DEBUG("ERROR: Device not ready. HAL Status: %s (0x%02X)",
                   hal_i2c_error_str(hal_status), hal_status);
        FPGA_DEBUG("Check: 1) Physical connections 2) Pull-up resistors 3) Power");

        // Diagnostic: Try with read address just in case
        hal_status = HAL_I2C_IsDeviceReady(hi2c, FPGA_I2C_ADDR_READ, 1, 10);
        FPGA_DEBUG("Test with read address 0x%02X: %s",
                   FPGA_I2C_ADDR_READ, hal_i2c_error_str(hal_status));

        hfpga->initialized = false; // Revoke init status
        return FPGA_ERR_I2C;
    }
    FPGA_DEBUG("SUCCESS: Device responded to address ping");

    /* 2. Read & verify DEVICE_ID */
    FPGA_DEBUG_STEP(2, "Verify ID");
    FPGA_DEBUG("Reading DEVICE_ID from register 0x%02X", FPGA_REG_DEVICE_ID);

    status = fpga_read_reg(hfpga, FPGA_REG_DEVICE_ID, &hfpga->info.device_id);

    if (status != FPGA_OK) {
        FPGA_DEBUG("ERROR: Failed to read DEVICE_ID. FPGA Status: %s (%d)",
                   fpga_status_str(status), status);
        hfpga->initialized = false; // Revoke init status
        return status;
    }

    FPGA_DEBUG_HEX("DEVICE_ID read", hfpga->info.device_id);

    if (hfpga->info.device_id != FPGA_DEVICE_ID_EXPECTED) {
        FPGA_DEBUG("ERROR: Device ID mismatch");
        FPGA_DEBUG("Expected: 0x%02X (%s)", FPGA_DEVICE_ID_EXPECTED,
                   get_device_name(FPGA_DEVICE_ID_EXPECTED));
        FPGA_DEBUG("Received: 0x%02X (%s)", hfpga->info.device_id,
                   get_device_name(hfpga->info.device_id));

        hfpga->initialized = false; // Revoke init status
        return FPGA_ERR_DEVICE_ID;
    }
    FPGA_DEBUG("SUCCESS: Device ID verified");

    /* 3. Read Version information */
    FPGA_DEBUG_STEP(3, "Read Versions");

    // Read major version
    status = fpga_read_reg(hfpga, FPGA_REG_VERSION_MAJ, &hfpga->info.version_maj);
    if (status != FPGA_OK) {
        FPGA_DEBUG("ERROR: Failed to read VERSION_MAJ");
        hfpga->initialized = false;
        return status;
    }
    
    // Read minor version
    status = fpga_read_reg(hfpga, FPGA_REG_VERSION_MIN, &hfpga->info.version_min);
    if (status != FPGA_OK) {
        FPGA_DEBUG("ERROR: Failed to read VERSION_MIN");
        hfpga->initialized = false;
        return status;
    }
    FPGA_DEBUG("Version: v%d.%d", hfpga->info.version_maj, hfpga->info.version_min);

    /* 4. Read link capabilities */
    FPGA_DEBUG_STEP(4, "Read Capabilities");
    status = fpga_read_reg(hfpga, FPGA_REG_LINK_CAPS, &hfpga->info.link_caps);
    if (status != FPGA_OK) {
        hfpga->initialized = false;
        return status;
    }

    // Parse capabilities for debug log
    uint8_t bus_width = (hfpga->info.link_caps >> 6) & 0x03;
    uint8_t max_clk = (hfpga->info.link_caps >> 4) & 0x03;
    uint8_t fmi_avail = (hfpga->info.link_caps >> 3) & 0x01;
    uint8_t dma_support = (hfpga->info.link_caps >> 2) & 0x01;
    uint8_t crc_avail = (hfpga->info.link_caps >> 1) & 0x01;
    uint8_t irq_avail = hfpga->info.link_caps & 0x01;
    
    FPGA_DEBUG("Capabilities: BusWidth=%d, MaxClk=%dMHz, FMI=%d, DMA=%d, CRC=%d, IRQ=%d",
               (1 << bus_width), (max_clk == 0 ? 10 : max_clk == 1 ? 25 : max_clk == 2 ? 50 : 100),
               fmi_avail, dma_support, crc_avail, irq_avail);

    /* Success - Keep initialized as true */
    FPGA_DEBUG("=== FPGA INIT COMPLETE ===");
    FPGA_DEBUG("Device: 0x%02X, Version: v%d.%d, Capabilities: 0x%02X",
               hfpga->info.device_id, hfpga->info.version_maj,
               hfpga->info.version_min, hfpga->info.link_caps);
    
    return FPGA_OK;
}

fpga_status_t fpga_read_reg(fpga_handle_t *hfpga, uint8_t reg_addr, uint8_t *value) {
    HAL_StatusTypeDef hal_status;

    if (hfpga == NULL || value == NULL) {
        FPGA_DEBUG("[fpga_read_reg] ERROR: NULL parameters");
        return FPGA_ERR_PARAM;
    }

    if (!hfpga->initialized) {
        FPGA_DEBUG("[fpga_read_reg] ERROR: FPGA not initialized");
        return FPGA_ERR_UNINIT;
    }

    FPGA_DEBUG("[fpga_read_reg] Reading reg 0x%02X", reg_addr);

    // Step 1: Write register address
    hal_status = HAL_I2C_Master_Transmit(hfpga->hi2c, FPGA_I2C_ADDR_WRITE, &reg_addr, 1, FPGA_I2C_TIMEOUT_MS);

    if (hal_status != HAL_OK) {
        FPGA_DEBUG("[fpga_read_reg] ERROR: Address write failed. HAL Status: %s",
                   hal_i2c_error_str(hal_status));
        FPGA_DEBUG("  Addr: 0x%02X, Reg: 0x%02X", FPGA_I2C_ADDR_WRITE, reg_addr);
        return FPGA_ERR_I2C;
    }
    FPGA_DEBUG("[fpga_read_reg] Address write successful");

    // Step 2: Read register value
    hal_status = HAL_I2C_Master_Receive(hfpga->hi2c, FPGA_I2C_ADDR_READ, value, 1, FPGA_I2C_TIMEOUT_MS);

    if (hal_status != HAL_OK) {
        FPGA_DEBUG("[fpga_read_reg] ERROR: Data read failed. HAL Status: %s",
                   hal_i2c_error_str(hal_status));
        FPGA_DEBUG("  Addr: 0x%02X", FPGA_I2C_ADDR_READ);
        return FPGA_ERR_I2C;
    }
    
    FPGA_DEBUG("[fpga_read_reg] SUCCESS: Reg 0x%02X = 0x%02X", reg_addr, *value);
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

    FPGA_DEBUG("[fpga_write_reg] SUCCESS: Wrote 0x%02X to Reg 0x%02X", data, reg);
    
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

// Enhanced I2C diagnostic function
void fpga_i2c_diagnostic(I2C_HandleTypeDef *hi2c) {
    FPGA_DEBUG("=== I2C DIAGNOSTIC ===");

    // Test write address (0xA0)
    HAL_StatusTypeDef status_w = HAL_I2C_IsDeviceReady(hi2c, FPGA_I2C_ADDR_WRITE, 1, 10);
    FPGA_DEBUG("Write address 0x%02X: %s", FPGA_I2C_ADDR_WRITE, hal_i2c_error_str(status_w));

    // Test read address (0xA1)
    HAL_StatusTypeDef status_r = HAL_I2C_IsDeviceReady(hi2c, FPGA_I2C_ADDR_READ, 1, 10);
    FPGA_DEBUG("Read address 0x%02X: %s", FPGA_I2C_ADDR_READ, hal_i2c_error_str(status_r));

    // Test other possible addresses
    for(uint8_t addr = 0x10; addr < 0x80; addr += 0x10) {
        HAL_StatusTypeDef status = HAL_I2C_IsDeviceReady(hi2c, addr << 1, 1, 1);
        if(status == HAL_OK) {
            FPGA_DEBUG("Found device at address 0x%02X", addr);
        }
    }

    FPGA_DEBUG("=== END DIAGNOSTIC ===");
}

// Retry wrapper for fpga_init with diagnostic
fpga_status_t fpga_init_with_retry(fpga_handle_t *hfpga, I2C_HandleTypeDef *hi2c,
                                   uint8_t max_retries, uint32_t retry_delay_ms) {
    fpga_status_t status;
    uint8_t attempt = 0;

    FPGA_DEBUG("=== FPGA INIT WITH RETRY (%d attempts) ===", max_retries);

    for(attempt = 1; attempt <= max_retries; attempt++) {
        FPGA_DEBUG("Attempt %d/%d", attempt, max_retries);

        // Run diagnostic on first failure
        if(attempt == 2) {
            fpga_i2c_diagnostic(hi2c);
        }

        status = fpga_init(hfpga, hi2c);

        if(status == FPGA_OK) {
            FPGA_DEBUG("SUCCESS on attempt %d", attempt);
            return FPGA_OK;
        }

        FPGA_DEBUG("FAILED on attempt %d: %s", attempt, fpga_status_str(status));

        if(attempt < max_retries) {
            FPGA_DEBUG("Retrying in %ld ms...", retry_delay_ms);
            HAL_Delay(retry_delay_ms);
        }
    }

    FPGA_DEBUG("All %d attempts failed", max_retries);
    return status;
}

/**
 * @brief	I2C error code to string
 */
const char* hal_i2c_error_str(HAL_StatusTypeDef status) {
    switch(status) {
        case HAL_OK: return "HAL_OK";
        case HAL_ERROR: return "HAL_ERROR";
        case HAL_BUSY: return "HAL_BUSY";
        case HAL_TIMEOUT: return "HAL_TIMEOUT";
        default: return "UNKNOWN";
    }
}


