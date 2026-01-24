/**
* @file    fpga_link.h
* @brief   FPGA Communication Driver - I2C Control Plane
* @author  Trey Parker
* @date    2026-01-19
* @version 1.0
*
* @details Driver for STM32H7 to Artix-7 FPGA communication via I2C control plane.
*          Implements register access per Adaptive Link Architecture Spec v0.2.
*
* @note    Requires: STM32 HAL I2C driver
* 
*/

#ifndef FPGA_LINK_H
#define FPGA_LINK_H

/* Includes ========================================================================== */
#include "stm32h7xx_hal.h"
#include <stdint.h>
#include <stdbool.h>

/* Include app_config for centralized configuration */
#if __has_include("app_config.h")
#include "app_config.h"
#endif

/* Debug ===================================================================*/
#define FPGA_DEBUG_ENABLE 1

#if FPGA_DEBUG_ENABLE
    #define FPGA_DEBUG(fmt, ...)        printf("[FPGA_DBG] " fmt "\r\n", ##__VA_ARGS__)
    // Fixed: Takes a step number AND a description
    #define FPGA_DEBUG_STEP(num, desc)  printf("[FPGA_DBG] Step %d: %s\r\n", num, desc)
    #define FPGA_DEBUG_HEX(name, val)   printf("[FPGA_DBG] %s = 0x%02X\r\n", name, val)
    #define FPGA_DEBUG_BIN(name, val)   printf("[FPGA_DBG] %s = 0b%d%d%d%d%d%d%d%d\r\n", name, \
                                        (val>>7)&1, (val>>6)&1, (val>>5)&1, (val>>4)&1, \
                                        (val>>3)&1, (val>>2)&1, (val>>1)&1, (val>>0)&1)
#else
    #define FPGA_DEBUG(fmt, ...)
    #define FPGA_DEBUG_STEP(num, desc)
    #define FPGA_DEBUG_HEX(name, val)
    #define FPGA_DEBUG_BIN(name, val)
#endif

// Configuration can be overwridden by app_config.h
#ifndef FPGA_I2C_ADDR
#define FPGA_I2C_ADDR           0x55
#endif

#ifndef FPGA_I2C_TIMEOUT_MS
#define FPGA_I2C_TIMEOUT_MS     100     /** I2C operation timeout */
#endif

/* Register Addresses - System Block (0x00-0x0F) ==================================== */
#define FPGA_REG_DEVICE_ID      0x00    /**< Device identifier (R) = 0xA7 */
#define FPGA_REG_VERSION_MAJ    0x01    /**< Firmware major version (R) */
#define FPGA_REG_VERSION_MIN    0x02    /**< Firmware minor version (R) */
#define FPGA_REG_SYS_STATUS     0x03    /**< System status flags (R) */
#define FPGA_REG_SYS_CTRL       0x04    /**< System control (R/W) */
#define FPGA_REG_SCRATCH0       0x05    /**< Test register 0 (R/W) */
#define FPGA_REG_SCRATCH1       0x06    /**< Test register 1 (R/W) */

/* Register Addresses - Link Control Block (0x10-0x1F) ============================== */
#define FPGA_REG_LINK_CAPS      0x10    /**< Data plane capabilities (R) */
#define FPGA_REG_DATA_MODE      0x11    /**< Active data plane mode (R/W) */
#define FPGA_REG_DATA_CLK_DIV   0x12    /**< Data plane clock divisor (R/W) */
#define FPGA_REG_DATA_STATUS    0x13    /**< Data plane health (R) */
#define FPGA_REG_DATA_ERR_CNT   0x14    /**< Error counter, clears on read (R) */
#define FPGA_REG_DATA_TEST      0x15    /**< Test pattern trigger (R/W) */

/* Register Addresses - GPIO Block (0x20-0x2F) ====================================== */
#define FPGA_REG_LED_OUT        0x20    /**< LED[7:0] output (R/W) */
#define FPGA_REG_LED_OUT_H      0x21    /**< LED[15:8] output (R/W) */
#define FPGA_REG_SW_IN          0x22    /**< Switch[7:0] input (R) */
#define FPGA_REG_SW_IN_H        0x23    /**< Switch[15:8] input (R) */
#define FPGA_REG_SEG_DATA       0x24    /**< 7-segment display data (R/W) */
#define FPGA_REG_SEG_CTRL       0x25    /**< 7-segment control (R/W) */

/* Register Addresses - Data Engine Block (0x30-0x3F) =============================== */
#define FPGA_REG_FIFO_STATUS    0x30    /**< TX/RX FIFO status (R) */
#define FPGA_REG_FIFO_TX_LVL    0x31    /**< TX FIFO fill level (R) */
#define FPGA_REG_FIFO_RX_LVL    0x32    /**< RX FIFO fill level (R) */
#define FPGA_REG_FIFO_CTRL      0x33    /**< FIFO control (R/W) */

/* Expected Values ================================================================== */
#define FPGA_DEVICE_ID_EXPECTED 0xA7    /**< Expected DEVICE_ID value */
#define FPGA_LINK_CAPS_DEFAULT  0x15    /**< Default LINK_CAPS value */

/* LINK_CAPS Bit Definitions ======================================================== */
#define LINK_CAPS_IRQ_AVAIL     (1 << 0)    /**< IRQ output available */
#define LINK_CAPS_CRC_AVAIL     (1 << 1)    /**< Hardware CRC available */
#define LINK_CAPS_DMA_AVAIL     (1 << 2)    /**< DMA streaming supported */
#define LINK_CAPS_FMC_AVAIL     (1 << 3)    /**< FMC interface available */
#define LINK_CAPS_CLK_MASK      (3 << 4)    /**< Max clock tier mask */
#define LINK_CAPS_WIDTH_MASK    (3 << 6)    /**< Max bus width mask */

/* DATA_MODE Bit Definitions ======================================================== */
#define DATA_MODE_ENABLE        (1 << 7)    /**< Enable data plane */
#define DATA_MODE_LOOPBACK      (1 << 6)    /**< Loopback mode for testing */
#define DATA_MODE_WIDTH_MASK    (3 << 2)    /**< Bus width field */
#define DATA_MODE_MODE_MASK     (3 << 0)    /**< Mode select field */

/* Data plane enum modes =========================================================== */
typedef enum 
{
    FPGA_MODE_SPI       = 0x00,     /**< Mode 0: SPI 1-10MHz */
    FPGA_MODE_SPI_HI    = 0x01,     /**< Mode 1: SPI 10-25MHz */
    FPGA_MODE_QSPI      = 0x02,     /**< Mode 2: QSPI 25-50MHz */
    FPGA_MODE_FMC       = 0x03      /**< Mode 3: FMC 50-100MHz */ 
} fpga_data_mode_t;

/* Status codes =================================================================== */
typedef enum {
    FPGA_OK             = 0,        /**< Operation successful */
    FPGA_ERR_I2C        = -1,       /**< I2C communication error */
    FPGA_ERR_DEVICE_ID  = -2,       /**< Wrong device ID */
    FPGA_ERR_TIMEOUT    = -3,       /**< Operation timeout */
    FPGA_ERR_VERIFY     = -4,       /**< Verification failed */
    FPGA_ERR_PARAM      = -5,       /**< Invalid parameter */
	FPGA_ERR_UNINIT		= -6		/**< Init unsuccessful */
} fpga_status_t;

/* Device info Structure ===================================================== */
typedef struct {
    uint8_t device_id;              /**< Device identifier (should be 0xA7) */
    uint8_t version_maj;            /**< Firmware major version */
    uint8_t version_min;            /**< Firmware minor version */
    uint8_t link_caps;              /**< Link capabilities */
    uint8_t sys_status;             /**< System status (if implemented) */
} fpga_info_t;

/* Driver Handle Structure ================================================= */
typedef struct {
    I2C_HandleTypeDef *hi2c;        /**< HAL I2C handle */
    fpga_info_t info;               /**< Cached device info */
    bool initialized;               /**< Init flag */
} fpga_handle_t;

/* Core Functions ========================================================== */

fpga_status_t fpga_init(fpga_handle_t *hfpga, I2C_HandleTypeDef *hi2c);
fpga_status_t fpga_init_with_retry(fpga_handle_t *hfpga, I2C_HandleTypeDef *hi2c, uint8_t max_retries, uint32_t retry_delay_ms);
void fpga_i2c_diagnostic(I2C_HandleTypeDef *hi2c);

fpga_status_t fpga_read_reg(fpga_handle_t *hfpga, uint8_t reg, uint8_t *data);
fpga_status_t fpga_write_reg(fpga_handle_t *hfpga, uint8_t reg, uint8_t data);
fpga_status_t fpga_set_leds(fpga_handle_t *hfpga, uint8_t pattern);
fpga_status_t fpga_test_scratch(fpga_handle_t *hfpga);
fpga_status_t fpga_test_link(fpga_handle_t *hfpga);

const char* fpga_status_str(fpga_status_t status);
const char* hal_i2c_error_str(HAL_StatusTypeDef status);


#endif
