`timescale 1ns / 1ps
//==============================================================================
// Test: test_concurrent_access
// Description: Verify concurrent I2C and SPI operations work correctly
//              Tests that both buses can operate simultaneously without
//              data corruption or bus conflicts
//==============================================================================

import tb_pkg::*;

module test_concurrent_access;

    localparam string TEST_NAME = "Concurrent I2C/SPI Access";
    
    // Test control
    logic i2c_test_done;
    logic spi_test_done;
    int   i2c_errors;
    int   spi_errors;
    
    //==========================================================================
    // I2C Test Thread
    //==========================================================================
    task automatic i2c_thread(
        ref logic       clk,
        ref logic       i2c_start,
        ref logic       i2c_done,
        ref logic [7:0] i2c_reg_addr,
        ref logic [7:0] i2c_wdata,
        ref logic [7:0] i2c_rdata,
        ref logic       i2c_rw,
        input int       num_iterations,
        output int      errors
    );
        logic [7:0] test_data;
        logic [7:0] readback;
        
        errors = 0;
        
        for (int i = 0; i < num_iterations; i++) begin
            test_data = $urandom_range(0, 255);
            
            // Write to SCRATCH_0
            @(posedge clk);
            i2c_rw       = 1'b0;
            i2c_reg_addr = ADDR_SCRATCH_0;
            i2c_wdata    = test_data;
            @(posedge clk);
            i2c_start = 1'b1;
            @(posedge clk);
            i2c_start = 1'b0;
            wait(i2c_done);
            
            // Small gap
            repeat(5) @(posedge clk);
            
            // Read back
            i2c_rw = 1'b1;
            @(posedge clk);
            i2c_start = 1'b1;
            @(posedge clk);
            i2c_start = 1'b0;
            wait(i2c_done);
            readback = i2c_rdata;
            
            if (readback !== test_data) begin
                $display("[%0t] I2C ERROR: wrote 0x%02h, read 0x%02h", 
                         $time, test_data, readback);
                errors++;
            end
            
            // Inter-transaction gap
            repeat(10) @(posedge clk);
        end
        
        i2c_test_done = 1'b1;
    endtask
    
    //==========================================================================
    // SPI Test Thread
    //==========================================================================
    task automatic spi_thread(
        ref logic       clk,
        ref logic       spi_start,
        ref logic       spi_done,
        ref logic [7:0] spi_tx_data,
        ref logic [7:0] spi_rx_data,
        input int       num_iterations,
        output int      errors
    );
        logic [7:0] tx_pattern;
        logic [7:0] expected_rx;
        logic [7:0] actual_rx;
        
        errors = 0;
        expected_rx = 8'h00;  // Initial state
        
        for (int i = 0; i < num_iterations; i++) begin
            tx_pattern = (i * 17 + 0x11) & 8'hFF;
            
            @(posedge clk);
            spi_tx_data = tx_pattern;
            @(posedge clk);
            spi_start = 1'b1;
            @(posedge clk);
            spi_start = 1'b0;
            wait(spi_done);
            actual_rx = spi_rx_data;
            
            if (actual_rx !== expected_rx) begin
                $display("[%0t] SPI ERROR: expected 0x%02h, got 0x%02h", 
                         $time, expected_rx, actual_rx);
                errors++;
            end
            
            expected_rx = tx_pattern;  // Next expected is current TX
            
            // Small gap between transfers
            repeat(5) @(posedge clk);
        end
        
        spi_test_done = 1'b1;
    endtask
    
    //==========================================================================
    // Main Test Runner
    //==========================================================================
    task automatic run_test(
        ref logic       clk,
        ref logic       rst_n,
        // I2C interface
        ref logic       i2c_start,
        ref logic       i2c_done,
        ref logic [7:0] i2c_reg_addr,
        ref logic [7:0] i2c_wdata,
        ref logic [7:0] i2c_rdata,
        ref logic       i2c_rw,
        // SPI interface
        ref logic       spi_start,
        ref logic       spi_done,
        ref logic [7:0] spi_tx_data,
        ref logic [7:0] spi_rx_data,
        // Results
        output int      pass_count,
        output int      fail_count
    );
        int i2c_err, spi_err;
        int num_i2c_iterations = 50;
        int num_spi_iterations = 100;
        
        pass_count = 0;
        fail_count = 0;
        i2c_test_done = 1'b0;
        spi_test_done = 1'b0;
        
        $display("\n========================================");
        $display("  TEST: %s", TEST_NAME);
        $display("========================================\n");
        
        $display("[%0t] Starting concurrent I2C (%0d) and SPI (%0d) operations", 
                 $time, num_i2c_iterations, num_spi_iterations);
        
        // Run both threads simultaneously
        fork
            i2c_thread(clk, i2c_start, i2c_done, i2c_reg_addr, 
                       i2c_wdata, i2c_rdata, i2c_rw, 
                       num_i2c_iterations, i2c_err);
            
            spi_thread(clk, spi_start, spi_done, 
                       spi_tx_data, spi_rx_data, 
                       num_spi_iterations, spi_err);
        join
        
        // Collect results
        $display("\n[%0t] Both threads completed", $time);
        $display("  I2C: %0d iterations, %0d errors", num_i2c_iterations, i2c_err);
        $display("  SPI: %0d iterations, %0d errors", num_spi_iterations, spi_err);
        
        // Determine pass/fail
        if (i2c_err == 0) begin
            $display("  [PASS] I2C operations");
            pass_count++;
        end else begin
            $display("  [FAIL] I2C operations (%0d errors)", i2c_err);
            fail_count++;
        end
        
        if (spi_err == 0) begin
            $display("  [PASS] SPI operations");
            pass_count++;
        end else begin
            $display("  [FAIL] SPI operations (%0d errors)", spi_err);
            fail_count++;
        end
        
        $display("\n----------------------------------------");
        $display("  Total: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");
        
    endtask
    
    //==========================================================================
    // Stress Test Variant - Maximum Concurrent Load
    //==========================================================================
    task automatic run_stress_test(
        ref logic       clk,
        ref logic       rst_n,
        ref logic       i2c_start,
        ref logic       i2c_done,
        ref logic [7:0] i2c_reg_addr,
        ref logic [7:0] i2c_wdata,
        ref logic [7:0] i2c_rdata,
        ref logic       i2c_rw,
        ref logic       spi_start,
        ref logic       spi_done,
        ref logic [7:0] spi_tx_data,
        ref logic [7:0] spi_rx_data,
        output int      pass_count,
        output int      fail_count
    );
        int i2c_err, spi_err;
        int num_iterations = 200;  // Increased for stress
        
        pass_count = 0;
        fail_count = 0;
        i2c_test_done = 1'b0;
        spi_test_done = 1'b0;
        
        $display("\n========================================");
        $display("  TEST: Concurrent Stress Test");
        $display("========================================\n");
        
        // Run with no gaps (maximum stress)
        fork
            i2c_thread(clk, i2c_start, i2c_done, i2c_reg_addr, 
                       i2c_wdata, i2c_rdata, i2c_rw, 
                       num_iterations, i2c_err);
            
            spi_thread(clk, spi_start, spi_done, 
                       spi_tx_data, spi_rx_data, 
                       num_iterations * 2, spi_err);  // SPI runs 2x as fast
        join
        
        fail_count = i2c_err + spi_err;
        pass_count = (num_iterations * 3) - fail_count;
        
        if (fail_count == 0) begin
            $display("  [PASS] Stress test completed with no errors");
        end else begin
            $display("  [FAIL] Stress test had %0d errors", fail_count);
        end
        
        $display("\n========================================\n");
        
    endtask

endmodule
