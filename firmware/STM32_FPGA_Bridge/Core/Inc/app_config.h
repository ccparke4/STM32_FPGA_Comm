/**
* @file    app_config.h
* @brief   Application Configuration and Test Mode Selection
* @author  Trey Parker
* @date    2026-01-18
* @updated 2026-02-05 - Added TEST_MODE_LINK_CHAR
*
* @details Central configuration for enabling/disabling subsystems
*          and selecting test modes. Modify these defines to control
*          what runs at startup.
*/

#ifndef APP_CONFIG_H
#define APP_CONFIG_H

/* Test Mode Selection ===================================================== */
/**
* @brief Test mode enumeration
* @note Set APP_TEST_MODE to one of these values
*/

#define TEST_MODE_NORMAL            0   // Normal operation (I2C + SPI tasks)
#define TEST_MODE_I2C_ONLY          1   // I2C control plane only
#define TEST_MODE_SPI_ONLY          2   // SPI data plane only
#define TEST_MODE_I2C_SPI_STRESS    3   // Stress test both planes
#define TEST_MODE_LOOPBACK          4   // Loopback verification
#define TEST_MODE_LINK_CHAR         5   // Link characterization suite
#define TEST_MODE_LINK_CHAR_QUICK   6   // Quick characterization (~10 sec)

/* =========================================================================
 * ACTIVE TEST MODE - CHANGE THIS TO SELECT MODE
 * ========================================================================= */
#define APP_TEST_MODE       TEST_MODE_LINK_CHAR_QUICK

/* Subsystem Enable/Disable ============================================= */

/* Automatically set based on test mode, or override */
#if (APP_TEST_MODE == TEST_MODE_I2C_ONLY)
    #define ENABLE_I2C_SUBSYSTEM    1
    #define ENABLE_SPI_SUBSYSTEM    0
    #define ENABLE_LINK_CHAR        0
#elif (APP_TEST_MODE == TEST_MODE_SPI_ONLY)
    #define ENABLE_I2C_SUBSYSTEM    0
    #define ENABLE_SPI_SUBSYSTEM    1
    #define ENABLE_LINK_CHAR        0
#elif (APP_TEST_MODE == TEST_MODE_I2C_SPI_STRESS)
    #define ENABLE_I2C_SUBSYSTEM    1
    #define ENABLE_SPI_SUBSYSTEM    1
    #define ENABLE_LINK_CHAR        0
#elif (APP_TEST_MODE == TEST_MODE_LINK_CHAR)
    #define ENABLE_I2C_SUBSYSTEM    1
    #define ENABLE_SPI_SUBSYSTEM    1
    #define ENABLE_LINK_CHAR        1
    #define LINK_CHAR_FULL_SUITE    1   // Run full suite
#elif (APP_TEST_MODE == TEST_MODE_LINK_CHAR_QUICK)
    #define ENABLE_I2C_SUBSYSTEM    1
    #define ENABLE_SPI_SUBSYSTEM    1
    #define ENABLE_LINK_CHAR        1
    #define LINK_CHAR_FULL_SUITE    0   // Run quick suite only
#else /* TEST_MODE_NORMAL or TEST_MODE_LOOPBACK */
    #define ENABLE_I2C_SUBSYSTEM    1
    #define ENABLE_SPI_SUBSYSTEM    1
    #define ENABLE_LINK_CHAR        0
#endif

/* I2C Configuration ==================================================== */

#define FPGA_I2C_HANDLE     hi2c1   // HAL handle
#define FPGA_I2C_ADDR       0x55    // FPGA slave addr (7-bit)
#define FPGA_I2C_TIMEOUT_MS 100     // I2C operation timeout

/* SPI Configuration ===================================================== */

#define FPGA_SPI_HANDLE     hspi4   // HAL handle
#define SPI_DMA_BUFFER_SIZE 64      // DMA buffer size in bytes 

/* Link Characterization Configuration =================================== */

#define LINK_CHAR_I2C_ITERATIONS        1000        // I2C test iterations
#define LINK_CHAR_SPI_BURST_SIZE        64          // SPI burst size
#define LINK_CHAR_SPI_BER_BYTES         1000000     // Bytes for BER test (1MB)
#define LINK_CHAR_CONCURRENT_SEC        30          // Concurrent test duration
#define LINK_CHAR_STRESS_SEC            300         // Stress test duration (5 min)

/* Quick mode overrides */
#if !LINK_CHAR_FULL_SUITE
    #undef LINK_CHAR_I2C_ITERATIONS
    #undef LINK_CHAR_SPI_BER_BYTES
    #undef LINK_CHAR_CONCURRENT_SEC
    #define LINK_CHAR_I2C_ITERATIONS    100         // Quick: 100 iterations */
    #define LINK_CHAR_SPI_BER_BYTES     10000       // Quick: 10KB
    #define LINK_CHAR_CONCURRENT_SEC    5           // Quick: 5 seconds
#endif

/* Task Configuration ==================================================== */

#define TASK_PERIOD_DEBUG       1000    // Debug task print interval (ms)
#define TASK_PERIOD_I2C_POLL    100     // I2C polling interval (ms)
#define TASK_PERIOD_SPI_BURST   10      // SPI burst interval (ms)

/* Task stack sizes (words, multiply by 4 for bytes) */
#define STACK_SIZE_DEFAULT      (128*4)
#define STACK_SIZE_I2C          (512*4)
#define STACK_SIZE_SPI          (512*4)
#define STACK_SIZE_DEBUG        (512*4)
#define STACK_SIZE_LINK_CHAR    (1024*4)    // Larger for printf buffers

/* Debug/Logging Configuration =========================================== */

#define ENABLE_DEBUG_PRINTS     1
#define ENABLE_VERBOSE_LOGS     0

/* Conditional debug macros */
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

/* HW Verification Checks ================================================ */

#define FPGA_DEVICE_ID_EXPECTED     0xA7
#define FPGA_VERSION_MAJ_EXPECTED   0x01

/* GPIO Trigger Pin (for oscilloscope/logic analyzer) ==================== */
/**
 * @note Trigger pin pulses high at start of each test
 *       Connect to scope trigger or logic analyzer
 *       Default: PE0 (adjust in link_char.c if needed)
 */
#define LINK_CHAR_TRIGGER_ENABLE    1

#endif /* APP_CONFIG_H */
