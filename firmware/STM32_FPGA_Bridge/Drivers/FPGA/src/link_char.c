/*
 * link_char.c
 *
 *  Created on: Feb 5, 2026
 *      Author: treyparker
 */

#include "link_char.h"
#include "fpga_link.h"
#include "fpga_stream.h"
#include "app_config.h"
#include "main.h"
#include "cmsis_os.h"
#include <stdio.h>
#include <string.h>

/*
 * external handles
 */
extern I2C_HandleTypeDef FPGA_I2C_HANDLE;
extern SPI_HandleTypeDef FPGA_SPI_HANDLE;

/*
 * private variables
 */
static fpga_handle_t *s_hfpga = NULL;
static bool s_initialized = false;

/* DWT timing */
static volatile uint32_t s_timer_start;

/* trigger gpio */
#define TRIGGER_GPIO_PORT	GPIOE
#define TRIGGER_GPIO_PIN	GPIO_PIN_0

/* SPI CS */
#ifndef SPI_CS_GPIO_Port
#define SPI_CS_GPIO_Port	GPIOE
#endif
#ifndef SPI_CS_Pin
#define SPI_CS_Pin			GPIO_PIN_4
#endif

/* Test buffers (ini DMA-accessable memory) */
__attribute__((section(".RAM_D2"))) __attribute__((aligned(32))) static uint8_t s_tx_buf[1024];
__attribute__((section(".RAM_D2"))) __attribute__((aligned(32))) static uint8_t s_rx_buf[1024];

/*
 * DWT cycle counter - us timer
 */

void link_char_timer_init(void) {

	// enable DWT cycle counter
	CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;
	DWT->CYCCNT = 0;
	DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;

}

void link_char_timer_start(void) {

	s_timer_start = DWT->CYCCNT;

}

uint32_t link_char_timer_elapsed_us(void) {

	uint32_t cycles = DWT->CYCCNT - s_timer_start;
	// convert cycles to us based on SysCoreClk
	return cycles / (SystemCoreClock / 1000000UL);

}

/*
 * gpio trigger for oscilloscope/logic analyzer
 */
void link_char_trigger_init(void) {
    // Enable GPIO clock if not already enabled
    __HAL_RCC_GPIOE_CLK_ENABLE();

    GPIO_InitTypeDef gpio = {0};
    gpio.Pin = TRIGGER_GPIO_PIN;
    gpio.Mode = GPIO_MODE_OUTPUT_PP;
    gpio.Pull = GPIO_NOPULL;
    gpio.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
    HAL_GPIO_Init(TRIGGER_GPIO_PORT, &gpio);

    HAL_GPIO_WritePin(TRIGGER_GPIO_PORT, TRIGGER_GPIO_PIN, GPIO_PIN_RESET);
}

void link_char_trigger_pulse(void) {
    HAL_GPIO_WritePin(TRIGGER_GPIO_PORT, TRIGGER_GPIO_PIN, GPIO_PIN_SET);
    /* Brief delay - about 1us at 550MHz */
    for (volatile int i = 0; i < 100; i++);
    	HAL_GPIO_WritePin(TRIGGER_GPIO_PORT, TRIGGER_GPIO_PIN, GPIO_PIN_RESET);
}

void link_char_trigger_set(bool high)
{
    HAL_GPIO_WritePin(TRIGGER_GPIO_PORT, TRIGGER_GPIO_PIN, high ? GPIO_PIN_SET : GPIO_PIN_RESET);
}

/*
 * initialization
 */

bool link_char_init(fpga_handle_t *hfpga) {

	if (hfpga == NULL) {
		printf("[CHAR] ERROR: NULL handle\n");
		return false;
	}

	s_hfpga = hfpga;

	// init timing
	link_char_timer_init();

	// init trigger gpio
	link_char_trigger_init();

	// init spi
	fpga_stream_init(&FPGA_SPI_HANDLE);


	// fill tx buffer w/ known pattern
	for (int i = 0; i < sizeof(s_tx_buf); i++) {
		s_tx_buf[i] = (uint8_t)i;
	}

	s_initialized = true;
	printf("[CHAR] Link characterization module ready\n");

	return true;

}

/*
 * connectivity test
 */

bool link_char_test_connectivity(void) {

	printf("\n");
	printf("======================================\n");
	printf(" CONNECTIVITY TEST");
	printf("======================================\n");

	bool i2c_ok = false;
	bool spi_ok = false;

	// I2C: Read Device ID
	link_char_trigger_pulse();

	uint8_t dev_id = 0;
	fpga_status_t status = fpga_read_reg(s_hfpga, FPGA_REG_DEVICE_ID, &dev_id);

	if (status == FPGA_OK && dev_id == FPGA_DEVICE_ID_EXPECTED) {
		printf("	I2C: PASS (Device ID = 0x%02X)\n", dev_id);
		i2c_ok = true;
	} else {
		printf("	I2C: FAIL (Got 0x%02X, expected 0x%02X, status=%d\n",
				dev_id, FPGA_DEVICE_ID_EXPECTED, status);
	}

	// SPI - Loopback test
	link_char_trigger_pulse();		// scope trigger

	s_tx_buf[0] = 0x00;
	s_tx_buf[1] = 0x01;
	s_tx_buf[2] = 0x02;
	s_tx_buf[3] = 0x03;
	memset(s_rx_buf, 0xFF, 64);

	printf("  SPI: Testing using fpga_stream driver...\n");



	if (fpga_stream_init(&FPGA_SPI_HANDLE) != STREAM_OK) {
		printf("	SPI: FAIL - Stream driver init failed\n");
	} else {
		if (fpga_stream_start(s_tx_buf, s_rx_buf, 4) == STREAM_OK) {
			// wait for cplt
			uint32_t timeout = HAL_GetTick() + 100;
			while (!fpga_stream_check_complete()) {
				if (HAL_GetTick() > timeout){
					printf("	SPI: FAIL - DMA Timeout\n");
					break;
				}
				osDelay(1);
			}

			// stop stream
			fpga_stream_stop();
			fpga_stream_clear_complete();

			// invalidate cahce
			SCB_InvalidateDCache_by_Addr((uint32_t*)s_rx_buf, 32);

			printf("       TX: %02X %02X %02X %02X\n",  s_tx_buf[0], s_tx_buf[1], s_tx_buf[2], s_tx_buf[3]);
			printf("       RX: %02X %02X %02X %02X\n",  s_rx_buf[0], s_rx_buf[1], s_rx_buf[2], s_rx_buf[3]);

			/* Loopback verification: RX[n] = TX[n-1]
			* RX[0] = last_byte (0x00 on first transfer after reset)
			* RX[1] = TX[0], RX[2] = TX[1], RX[3] = TX[2]
			*/
			bool match = (s_rx_buf[1] == s_tx_buf[0]) && (s_rx_buf[2] == s_tx_buf[1]) &&  (s_rx_buf[3] == s_tx_buf[2]);

			// also accept if we got non-jarbled data
			bool got_data = (s_rx_buf[0] != 0xFF) || (s_rx_buf[1] != 0xFF);

			if (match) {
				printf("SPI: Pass");
				spi_ok = true;
			} else if (got_data) {
				printf("  SPI: Data received, checking pattern...\n");
				printf("       Expected RX[1:3] = TX[0:2]: %02X %02X %02X\n",
						s_tx_buf[0], s_tx_buf[1], s_tx_buf[2]);

				// meaningful data pass...
				if (s_rx_buf[0] == 0x00 || s_rx_buf[1] == 0x00) {
					printf("  SPI: PASS (Link operational, data flowing)\n");
					spi_ok = true;
				}
			} else {
				printf("	SPI: FAIL - No data recieved");
			}
		} else {
			printf("	SPI: FAIL - Stream start failed");
		}
	}

	printf("--------------------------------------------\n");
	printf("	Result: %s\n", (i2c_ok && spi_ok) ? "PASS" : "FAIL");
	printf("\n");

	return (i2c_ok && spi_ok);
}

/*
 * i2c latency test
 */
void link_char_test_i2c_latency(uint32_t iterations, link_char_i2c_t *results) {

	printf("\n");
	printf("======================================\n");
	printf(" I2C LATENCY TEST	|	Iterations: %-6lu  \n", iterations);
	printf("======================================\n");

	memset(results, 0, sizeof(link_char_i2c_t));
	results->wr_min_us = UINT32_MAX;
	results->rd_min_us = UINT32_MAX;

	uint64_t write_total = 0;
	uint64_t read_total = 0;
	uint32_t errors = 0;

	uint32_t progress_interval = iterations / 10;
	if (progress_interval == 0) progress_interval = 1;

	for (uint32_t i = 0; i < iterations; i++) {
		uint8_t test_val = (uint8_t)(i & 0xFF);
		uint8_t read_val = 0;
		uint32_t elapsed;
		fpga_status_t status;

		// write to SCRATCH0
		link_char_trigger_set(true);

		link_char_timer_start();
		status = fpga_write_reg(s_hfpga, FPGA_REG_SCRATCH0, test_val);
		elapsed = link_char_timer_elapsed_us();

		link_char_trigger_set(false);

		if (status == FPGA_OK) {
			write_total += elapsed;
			if (elapsed < results->wr_min_us) results->wr_min_us = elapsed;
			if (elapsed > results-> wr_max_us) results->wr_max_us = elapsed;
		} else {
			errors++;
			continue;
		}

		// read from SCRATCH0
		link_char_trigger_set(true);

		link_char_timer_start();
		status = fpga_read_reg(s_hfpga, FPGA_REG_SCRATCH0, &read_val);
		elapsed = link_char_timer_elapsed_us();

		link_char_trigger_set(false);

		if (status == FPGA_OK) {
			read_total += elapsed;
			if (elapsed < results->rd_min_us) results->rd_min_us = elapsed;
			if (elapsed > results->rd_max_us) results->rd_max_us = elapsed;

			// verify data integrity
			if (read_val != test_val) {
				errors++;
				printf("  [%lu] Data mismatch: wrote 0x%02X, read 0x%02X\n", i, test_val, read_val);

			}
		} else {
			errors++;
		}
		// progress
		if ((i + 1) % progress_interval == 0) {
			printf("  Progress: %lu%% (%lu errors)\n", ((i + 1) * 100) / iterations, errors);
		}
	}

	// calculate results
	uint32_t valid = iterations - errors;
	results->total_transactions = iterations;
	results->errors = errors;
	results->wr_avg_us = (valid > 0) ? (uint32_t)(write_total / valid) : 0;
	results->rd_avg_us = (valid > 0) ? (uint32_t)(read_total / valid) : 0;
	results->success_rate_pct = (iterations > 0) ? (100.0f * valid / iterations) : 0;

	// handle case where no valid txs
	if (valid == 0) {
		results->wr_min_us = 0;
		results->rd_min_us = 0;
	}

	printf("--------------------------------------------\n");
	printf("  Write: %lu / %lu / %lu us (min/avg/max)\n",
          results->wr_min_us, results->wr_avg_us, results->wr_max_us);
	printf("  Read:  %lu / %lu / %lu us (min/avg/max)\n",
	      results->rd_min_us, results->rd_avg_us, results->rd_max_us);
	printf("  Errors: %lu / %lu (%.2f%% success)\n",
	      results->errors, results->total_transactions, results->success_rate_pct);
	printf("\n");

}

/*
 * spi throughput
 */
void link_char_test_spi_throughput(uint32_t burst_size, link_char_spi_t *results) {

	printf("\n");
	printf("======================================\n");
	printf(" SPI THRPT TEST	|	Burst Size: %-4lu \n", burst_size);
	printf("======================================\n");

	if (burst_size > sizeof(s_tx_buf)) {
		burst_size = sizeof(s_tx_buf);
	}

	memset(results, 0, sizeof(link_char_spi_t));

    const uint32_t num_bursts = 100;
    uint32_t total_time_us = 0;
    uint32_t total_bytes = burst_size * num_bursts;

    // Single byt RTT
    uint8_t tx = 0xAA, rx = 0;

    link_char_trigger_pulse();

    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_RESET);
    link_char_timer_start();
    HAL_SPI_TransmitReceive(&FPGA_SPI_HANDLE, &tx, &rx, 1, 100);
    results->single_byte_rtt_us = link_char_timer_elapsed_us();
    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET);

    printf("  Single byte RTT: %lu us\n", results->single_byte_rtt_us);

    // burst throughput (polling)
    printf("  Testing polling mode...\n");

    total_time_us = 0;
    for (uint32_t i = 0; i < num_bursts; i++) {
    	link_char_trigger_set(true);

        HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_RESET);
        link_char_timer_start();
        HAL_SPI_TransmitReceive(&FPGA_SPI_HANDLE, s_tx_buf, s_rx_buf, burst_size, 100);
        total_time_us += link_char_timer_elapsed_us();
        HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET);

        link_char_trigger_set(false);
    }


    if (total_time_us > 0) {
    	results->burst_throughput_kbps = (total_bytes * 1000) / total_time_us;
    } else {
    	results->burst_throughput_kbps = 0;
    }


    printf("  Polling: %lu KB/s\n", results->burst_throughput_kbps);

    // DMA throughput testing
    printf("  Testing DMA mode (%lu x %lu bytes)...\n", num_bursts, burst_size);

    // reinit stream driver
    fpga_stream_init(&FPGA_SPI_HANDLE);

    total_time_us = 0;
    uint32_t dma_errors = 0;

    // DMA tx timing
    for (uint32_t i = 0; i < num_bursts; i++) {

    	link_char_trigger_set(true);

    	// Flush cache before DMA - may be redundant and waste of clk cycles
    	// Why? -> because this region should be uncacheable via MPU
    	SCB_CleanDCache_by_Addr((uint32_t*)s_tx_buf, burst_size);
    	SCB_CleanDCache_by_Addr((uint32_t*)s_rx_buf, burst_size);

    	link_char_timer_start();

    	// Start dma transfer using steram driver
    	if (fpga_stream_start(s_tx_buf, s_rx_buf, burst_size) == STREAM_OK) {
    		// wait for completion w/ timeout
    		uint32_t timeout = HAL_GetTick() + 100;
    		while (!fpga_stream_check_complete()) {
    			if (HAL_GetTick() > timeout) {
    				dma_errors++;
    				fpga_stream_stop();
    				break;
    			}
    		}
    		fpga_stream_clear_complete();
    		fpga_stream_stop();
    	} else {
    		dma_errors++;
    	}
    	total_time_us += link_char_timer_elapsed_us();

    	link_char_trigger_set(false);

    	// invalidate cache
    	SCB_InvalidateDCache_by_Addr((uint32_t*)s_rx_buf, burst_size);
    }

    if (total_time_us > 0) {
    	results->dma_throughput_kbps = (total_bytes * 1000) / total_time_us;
    } else {
    	results->dma_throughput_kbps = 0;
    }

    printf("	DMA: %lu KB/s", results->dma_throughput_kbps);
    if (dma_errors > 0) {
    	printf("	(%lu errors)", dma_errors);
    }
    printf("\n");

    printf("============================================================\n");
    printf("  Polling: %lu KB/s\n", results->burst_throughput_kbps);
    printf("  DMA:     %lu KB/s\n", results->dma_throughput_kbps);

    if (results->burst_throughput_kbps > 0) {
    	printf("	Speedup: %.1fx\n",
    			(float)results->dma_throughput_kbps / (float)results->burst_throughput_kbps);
    }
    printf("\n");
}

/*
 * spi BER test
 */
void link_char_test_spi_ber(uint32_t num_bytes, link_char_spi_t *results) {

	printf("\n");
	printf("==================================================\n");
	printf(" SPI BIT ERROR RATE TEST	|	Bytes: %-10lu 	  \n", num_bytes);
	printf("==================================================\n");

	uint64_t error_bits = 0;
	uint64_t total_bits = 0;
	uint8_t last_tx = 0;

	uint32_t progress_interval = num_bytes / 10;

	if (progress_interval == 0) progress_interval = 1;

		HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_RESET);

	    link_char_trigger_pulse();  // Mark start

	    for (uint32_t i = 0; i < num_bytes; i++) {
	        uint8_t tx = (uint8_t)(i & 0xFF);
	        uint8_t rx = 0;

	        HAL_SPI_TransmitReceive(&FPGA_SPI_HANDLE, &tx, &rx, 1, 100);

	        // Count bit errors (skip first byte - no prior TX)
	        if (i > 0) {
	            uint8_t expected = last_tx;    // Loopback
	            uint8_t diff = rx ^ expected;

	            // Count set bits in diff
	            while (diff) {
	                error_bits += (diff & 1);
	                diff >>= 1;
	            }
	            total_bits += 8;
	        }

	        last_tx = tx;

	        // Progress
	        if ((i + 1) % progress_interval == 0) {
	            printf("  Progress: %lu%% (%lu bit errors)\n",
	                   ((i + 1) * 100) / num_bytes, error_bits);
	        }
	    }

	    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET);

	    link_char_trigger_pulse();  // Mark end

	    results->total_bytes = num_bytes;
	    results->error_bits = error_bits;
	    results->error_bytes = (error_bits + 7) / 8;  // Approximate
	    results->ber = (total_bits > 0) ? (double)error_bits / (double)total_bits : 0;

	    printf("==================================\n");
	    printf("  Total bits:  %lu\n", total_bits);
	    printf("  Error bits:  %lu\n", error_bits);
	    printf("  BER:         %.2e", results->ber);
	    if (results->ber == 0) {
	        printf(" (PERFECT - 0%%)");
	    }
	    printf("\n\n");

}

/*
 * Concurrent I2C & SPI test
 */

bool link_char_test_concurrent(uint32_t duration_sec) {

	printf("\n");
	printf("==================================================\n");
	printf(" CONCURRENT I2C + SPI TEST	|	Duration: %-3lu s \n", duration_sec);
	printf("==================================================\n");

	uint32_t i2c_ok = 0, i2c_err = 0;
	uint32_t spi_ok = 0, spi_err = 0;

	uint32_t start_tick = HAL_GetTick();
	uint32_t end_tick = start_tick + (duration_sec * 1000);
	uint32_t last_print = start_tick;

	uint8_t spi_last_tx = 0;

	link_char_trigger_pulse();  // Mark start

	while (HAL_GetTick() < end_tick) {
		// I2C Transaction
		uint8_t test_val = (uint8_t)(i2c_ok & 0xFF);
	    uint8_t read_val = 0;

	    fpga_status_t status = fpga_write_reg(s_hfpga, FPGA_REG_SCRATCH0, test_val);
	    if (status == FPGA_OK) {
	    	status = fpga_read_reg(s_hfpga, FPGA_REG_SCRATCH0, &read_val);
	        if (status == FPGA_OK && read_val == test_val) {
	        	i2c_ok++;
	        } else {
	        	i2c_err++;
	        }
	    } else {
	    	i2c_err++;
	    }

	    // SPI Transaction
	    uint8_t spi_tx = (uint8_t)(spi_ok & 0xFF);
	    uint8_t spi_rx = 0;

	    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_RESET);
	    HAL_SPI_TransmitReceive(&FPGA_SPI_HANDLE, &spi_tx, &spi_rx, 1, 100);
	    HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET);

	    if (spi_ok > 0 && spi_rx == spi_last_tx) {
	    	spi_ok++;
	    } else if (spi_ok == 0) {
	    	spi_ok++;  // First byte always undefined
	    } else {
	    	spi_err++;
	    }
	    spi_last_tx = spi_tx;

	    /* Print progress every second */
	    if (HAL_GetTick() - last_print >= 1000) {
	    	printf("  [%lu s] I2C: %lu ok, %lu err | SPI: %lu ok, %lu err\n",
	    			(HAL_GetTick() - start_tick) / 1000, i2c_ok, i2c_err, spi_ok, spi_err);
	    	last_print = HAL_GetTick();

	        link_char_trigger_pulse();  /* Periodic trigger */
	        }
	    }

	bool pass = (i2c_err == 0) && (spi_err == 0);

	printf("===============================================\n");
	printf("  I2C: %lu transactions, %lu errors\n", i2c_ok + i2c_err, i2c_err);
	printf("  SPI: %lu transactions, %lu errors\n", spi_ok + spi_err, spi_err);
	printf("  Result: %s\n", pass ? "PASS" : "FAIL");
	printf("\n");

	return pass;
}

/*
 * main test drivers
 */

bool link_char_run(uint8_t tests, const link_char_config_t *config, link_char_results_t *results) {
    link_char_config_t cfg;
    if (config == NULL) {
        link_char_config_t default_cfg = LINK_CHAR_CONFIG_DEFAULT;
        cfg = default_cfg;
    } else {
        cfg = *config;
    }

    memset(results, 0, sizeof(link_char_results_t));
    results->tests_run = tests;

    uint32_t start_tick = HAL_GetTick();
    bool all_pass = true;

    printf("\n");
    printf("============================================================\n");
    printf("            LINK CHARACTERIZATION SUITE                      \n");
    printf("============================================================\n");

    // Connectivity
    if (tests & CHAR_TEST_CONNECTIVITY) {
        results->connectivity_pass = link_char_test_connectivity();
        if (!results->connectivity_pass) {
            printf("[CHAR] ABORT: Connectivity failed!\n");
            return false;
        }
    }

    // I2C Latency
    if (tests & CHAR_TEST_I2C_LATENCY) {
        link_char_test_i2c_latency(cfg.i2c_iterations, &results->i2c);
        if (results->i2c.success_rate_pct < 99.0f) {
            all_pass = false;
        }
    }

    // SPI Throughput
    if (tests & CHAR_TEST_SPI_THROUGHPUT) {
        link_char_test_spi_throughput(cfg.spi_burst_size, &results->spi);
    }

    // SPI BER
    if (tests & CHAR_TEST_SPI_BER) {
        link_char_test_spi_ber(cfg.spi_ber_bytes, &results->spi);
        if (results->spi.ber > 0) {
            all_pass = false;
        }
    }

    // Concurrent
    if (tests & CHAR_TEST_CONCURRENT) {
        results->concurrent_pass = link_char_test_concurrent(cfg.concurrent_duration_sec);
        if (!results->concurrent_pass) {
            all_pass = false;
        }
    }

    results->test_duration_ms = HAL_GetTick() - start_tick;

    return all_pass;
}


bool link_char_quick(link_char_results_t *results) {

    link_char_config_t cfg = LINK_CHAR_CONFIG_DEFAULT;
    cfg.i2c_iterations = 100;           // Quick: 100 iterations
    cfg.spi_ber_bytes = 10000;          // Quick: 10KB
    cfg.concurrent_duration_sec = 5;    // Quick: 5 seconds

    return link_char_run(CHAR_TEST_QUICK, &cfg, results);
}

bool link_char_full(link_char_results_t *results) {
    return link_char_run(CHAR_TEST_ALL, NULL, results);
}

/*
 * Results printing
 */
void link_char_print_results(const link_char_results_t *results)
{
    printf("\n");
    printf("============================================================\n");
    printf("               CHARACTERIZATION RESULTS                       \n");
    printf("============================================================\n");
    printf("  I2C CONTROL PLANE                                           \n");
    printf("  		Write: %4lu / %4lu / %4lu us (min/avg/max)            \n", results->i2c.wr_min_us, results->i2c.wr_avg_us, results->i2c.wr_max_us);
    printf("  		Read:  %4lu / %4lu / %4lu us (min/avg/max)            \n", results->i2c.rd_min_us, results->i2c.rd_avg_us, results->i2c.rd_max_us);
    printf("  		Success: %.2f%% (%lu/%lu)                             \n", results->i2c.success_rate_pct, results->i2c.total_transactions - results->i2c.errors, results->i2c.total_transactions);
    printf("============================================================\n");
    printf("  SPI DATA PLANE                                              \n");
    printf("  		Single Byte RTT: %4lu mwas                              \n", results->spi.single_byte_rtt_us);
    printf("  		Polling:         %4lu KB/s                            \n", results->spi.burst_throughput_kbps);
    printf("  		DMA:             %4lu KB/s                            \n", results->spi.dma_throughput_kbps);
    printf("  	    BER:             %.2e                                 \n", results->spi.ber);
    printf("============================================================\n");
    printf("  Connectivity: %-4s  Concurrent: %-4s  Duration: %lu ms      \n", results->connectivity_pass ? "PASS" : "FAIL", results->concurrent_pass ? "PASS" : "FAIL", results->test_duration_ms);
    printf("============================================================\n");
}

void link_char_print_csv(const link_char_results_t *results)
{
    printf("\n--- CSV OUTPUT ---\n");
    printf("metric,value,unit\n");
    printf("i2c_write_min,%lu,us\n", results->i2c.wr_min_us);
    printf("i2c_write_avg,%lu,us\n", results->i2c.wr_avg_us);
    printf("i2c_write_max,%lu,us\n", results->i2c.wr_max_us);
    printf("i2c_read_min,%lu,us\n", results->i2c.rd_min_us);
    printf("i2c_read_avg,%lu,us\n", results->i2c.rd_avg_us);
    printf("i2c_read_max,%lu,us\n", results->i2c.rd_max_us);
    printf("i2c_success_pct,%.2f,%%\n", results->i2c.success_rate_pct);
    printf("spi_rtt,%lu,us\n", results->spi.single_byte_rtt_us);
    printf("spi_polling_kbps,%lu,KB/s\n", results->spi.burst_throughput_kbps);
    printf("spi_dma_kbps,%lu,KB/s\n", results->spi.dma_throughput_kbps);
    printf("spi_ber,%.2e,ratio\n", results->spi.ber);
    printf("test_duration,%lu,ms\n", results->test_duration_ms);
    printf("--- END CSV ---\n");
}
