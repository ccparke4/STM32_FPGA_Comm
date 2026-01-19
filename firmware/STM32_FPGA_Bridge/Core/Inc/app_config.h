/**
* @file    app_config.h
* @brief   Application Configuration and Test Mode Selection
* @author  Trey Parker
* @date    2026-01-18
*
* @details Central configuration for enabling/disabling subsystems
*          and selecting test modes. Modify these defines to control
*          what runs at startup.
*/

#ifndef APP_CONFIG_H
#define APP_CONFIG_H

/* Test Mode Selection ===================================================== */
/*
* @brief Test mode enumeration
* @note Set APP_TEST_MODE to one of these values
*/

typedef enum {
    TEST_MODE_NORMAL = 0,       // All systems active
    TEST_MODE_I2C_ONLY,         // Control Plane - I2C testing
    TEST_MODE_SPI_ONLY,         // Data Plane - SPI testing
    TEST_MODE_I2C_SPI_STRESS,   // Concurrent stress test
    TEST_MODE_LOOPBACK          // Internal Loopback testing
} app_test_mode_t;

/* active test mode - this is the mode switch (TBD: automate via python)*/
#define APP_TEST_MODE       TSET_MODE_I2C_ONLY

/* Subsystem Enable/Disable ============================================= */

/* automatically set based on testmode, or overrride */
#if (APP_TEST_MODE == TEST_MODE_I2C_ONLY)
    #define ENABLE_I2C_SUBSYSTEM    1
    #define ENABLE_SPI_SUBSYSTEM    0
#elif(APP_TEST_MODE == TEST_MODE_SPI_ONLY)
    #define ENABLE_I2C_SUBSYSTEM    0
    #define ENABLE_SPI_SUBSYSTEM    1
#elif(APP_TEST_MODE == TEST_MODE_I2C_SPI_STRESS)
    #define ENABLE_I2C_SUBSYSTEM    1
    #define ENABLE_SPI_SUBSYSTEM    1
#else // TESTT_MODE_NORMAL or TEST_MODE_LOOPBACK
    #define ENABLE_I2C_SUBSYSTEM    1
    #define ENABLE_SPI_SUBSYSTEM    1
#endif

/* I2C configuration ==================================================== */

#define FPGA_I2C_HANDLE     hi2c1   // HAL handle
#define FPGA_I2C_ADDR       0x50    // FPGA slave adddr (7'b)
#define FPGA_I2C_TIMEOUT_MS 100     // i2c operation timeout

/* SPI confiuration ===================================================== */

#define FPGA_SPI_HANDLE     hspi4   // HAL handle
#define SPI_DMA_BUFFER_SIZE 64      // DMA buffer size in bytes 

/* Task configuration ================================================== */
#define TASK_PERIOD_DEBUG       1000    // debug task print interval
#define TASK_PERIOD_I2C_POLL    100     // I2C polling interval (eventually repl w/ DMA)
#define TASK_PERIOD_SPI_BURST   10      // SPI burst interval

/* Task stack sizes (words) */
#define STACK_SIZE_DEFAULT      (128*4)
#define STACK_SIZE_I2C          (512*4)
#define STACK_SIZE_SPI          (512*4)
#define STACK_SIZE_DEBUG        (512*4)

/* Debug/logging Configuration ========================================= */

#define ENABLE_DEBUG_PRINTS     1   

/* conditional dbg macros */
#if ENABLE_DEBUG_PRINTS
    #define DBG_PRINT(...)      printf(__VA_ARGS__)
#else
    #define DBG_PRINT(...)      ((void)0)
#endif

#if ENABLE_VERBOSE_LOGS
    #define VERBOSE_PRINT(...)  printf(__VA_ARGS__)
#else
    #define VERBOSE_PRINT(...)  ((void)0)
#endif

/* HW verification checks =============================================== */

/* expected values */
#define FPGA_DEVICE_ID_EXPECTED     0xA7
#define FPGA_VERSION_MAG_EXPECTED   0x01

#endif