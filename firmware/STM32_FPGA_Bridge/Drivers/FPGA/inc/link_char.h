/**
 * link_char.h
 *
 *  Created on: Feb 5, 2026
 *      Author: treyparker
 *
 * @details: Measures and reports comm metrics between stm32 and fpga.
 * 			 Integrates w/ app_config.h
 *
 *	Usage:
 *		1. Set APP_TEST_MODE in app_config.h to TEST_MODE_LINK_CHAR
 *		2. build/flash
 *		3. connect UART/SWV
 */

#ifndef FPGA_INC_LINK_CHAR_H_
#define FPGA_INC_LINK_CHAR_H_

#include <stdint.h>
#include <stdbool.h>
#include "fpga_link.h"

/*
 * Test selection
 */
#define CHAR_TEST_CONNECTIVITY		(1 << 0)	// simple i2c/spi ping
#define CHAR_TEST_I2C_LATENCY		(1 << 1)	// I2C timing measurement
#define CHAR_TEST_SPI_THROUGHPUT	(1 << 2)	// spi sped measurement
#define CHAR_TEST_SPI_BER			(1 << 3)	// BER
#define CHAR_TEST_CONCURRENT		(1 << 4)    // I2C + SPI simultaneous
#define CHAR_STRESS_TEST			(1 << 5)	// Long duration stress test

#define CHAR_TEST_ALL				(0xFF)		// run all
#define CHAR_TEST_QUICK				(CHAR_TEST_CONNECTIVITY | CHAR_TEST_I2C_LATENCY | CHAR_TEST_SPI_THROUGHPUT)

/*
 *  results structs
 */

/* i2c timing measurements */
typedef struct {
	uint32_t wr_min_us;
	uint32_t wr_max_us;
	uint32_t wr_avg_us;
	uint32_t rd_min_us;
	uint32_t rd_max_us;
	uint32_t rd_avg_us;
	uint32_t total_transactions;
	uint32_t errors;
	float    success_rate_pct;
} link_char_i2c_t;

/* spi perf measurements */
typedef struct {
	uint32_t single_byte_rtt_us;
	uint32_t burst_throughput_kbps;
	uint32_t dma_throughput_kbps;
	uint64_t total_bytes;
	uint64_t error_bytes;
	uint64_t error_bits;
	double	 ber;
	uint32_t max_stable_clock_khz;
} link_char_spi_t;

/* results */
typedef struct {
	link_char_i2c_t i2c;
	link_char_spi_t spi;
	uint32_t 		test_duration_ms;
	bool 			connectivity_pass;
	bool			concurrent_pass;
	bool 			stress_pass;
	uint8_t 		tests_run;
} link_char_results_t;

/*
 * Configuration
 */

/* test config params */
typedef struct {
	uint32_t i2c_iterations;			// # of i2c R/W cycles
	uint32_t spi_burst_size;			// Bytes/burst
	uint32_t spi_ber_bytes;				// bytes for BER test
	uint32_t concurrent_duration_sec;	// duration of concurrent test
	uint32_t stress_duration_sec;		// duration of stress test
	bool	 verbose;					// print progress during tests
	bool 	 gpio_trigger;				// toggle gpio for scope trigger
} link_char_config_t;

/* default config */
#define LINK_CHAR_CONFIG_DEFAULT {  	\
		.i2c_iterations = 1000, 		\
		.spi_burst_size = 64,       	\
		.spi_ber_bytes = 1000000,		\
		.concurrent_duration_sec = 30,	\
		.stress_duration_sec = 300,		\
		.verbose = true,				\
		.gpio_trigger = true			\
}

/*
 * API
 */
bool link_char_init(fpga_handle_t *hfpga);
bool link_char_run(uint8_t tests, const link_char_config_t *config, link_char_results_t *results);
bool link_char_quick(link_char_results_t *results);
bool link_char_full(link_char_results_t *results);

bool link_char_test_connectivity(void);
void link_char_test_i2c_latency(uint32_t iterations, link_char_i2c_t *results);
void link_char_test_spi_throughput(uint32_t burst_size, link_char_spi_t *results);
void link_char_test_spi_ber(uint32_t num_bytes, link_char_spi_t *results);
bool link_char_test_concurrent(uint32_t duration_sec);

void link_char_print_results(const link_char_results_t *results);
void link_char_print_csv(const link_char_results_t *results);

/*
 * Timing utilities
 */
void link_char_timer_init(void);
void link_char_timer_start(void);
uint32_t link_char_timer_elapsed_us(void);

/*
 * gpio triggers
 */
void link_char_trigger_init(void);
void link_char_trigger_pulse(void);
void link_char_trigger_set(bool high);


#endif /* FPGA_INC_LINK_CHAR_H_ */
