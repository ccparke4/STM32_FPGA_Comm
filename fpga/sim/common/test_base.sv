`timescale 1ns / 1ps
//==============================================================================
// Module: test_base
// Description: Base test infrastructure with common utilities and patterns
//              All tests should inherit from this structure
//==============================================================================

import tb_pkg::*;

// Virtual interface for BFM access
interface test_if (
    input logic clk,
    input logic rst_n
);
    // Test control signals
    logic       test_start;
    logic       test_done;
    logic       test_pass;
    string      test_name;
    
    // I2C BFM control
    logic       i2c_start;
    logic       i2c_done;
    logic       i2c_ack;
    logic [6:0] i2c_slave_addr;
    logic       i2c_rw;
    logic [7:0] i2c_reg_addr;
    logic [7:0] i2c_wdata[8];
    logic [7:0] i2c_rdata[8];
    int         i2c_num_bytes;
    
    // SPI BFM control
    logic       spi_start;
    logic       spi_done;
    logic [7:0] spi_tx_data[16];
    logic [7:0] spi_rx_data[16];
    int         spi_num_bytes;
    
    // Scoreboard interface
    logic       sb_i2c_valid;
    logic       sb_spi_valid;
    
endinterface

//==============================================================================
// Test Sequencer Module
//==============================================================================
module test_sequencer (
    input  logic clk,
    input  logic rst_n,
    output logic tests_complete,
    output int   tests_passed,
    output int   tests_failed
);
    
    // Test list management
    typedef struct {
        string name;
        logic  enabled;
        logic  passed;
        logic  completed;
    } test_entry_t;
    
    test_entry_t test_queue[$];
    int current_test_idx;
    
    initial begin
        tests_complete = 1'b0;
        tests_passed   = 0;
        tests_failed   = 0;
        current_test_idx = 0;
    end
    
    // Register a test
    function void register_test(string name, logic enabled = 1'b1);
        test_entry_t t;
        t.name = name;
        t.enabled = enabled;
        t.passed = 1'b0;
        t.completed = 1'b0;
        test_queue.push_back(t);
    endfunction
    
    // Mark test complete
    function void test_complete(logic passed);
        if (current_test_idx < test_queue.size()) begin
            test_queue[current_test_idx].completed = 1'b1;
            test_queue[current_test_idx].passed = passed;
            if (passed) tests_passed++;
            else tests_failed++;
        end
    endfunction
    
    // Report results
    function void report_all();
        $display("\n");
        $display("╔══════════════════════════════════════════════════════════════╗");
        $display("║                    TEST SEQUENCER REPORT                     ║");
        $display("╠══════════════════════════════════════════════════════════════╣");
        foreach (test_queue[i]) begin
            string status;
            if (!test_queue[i].enabled) status = "SKIP";
            else if (!test_queue[i].completed) status = "----";
            else if (test_queue[i].passed) status = "PASS";
            else status = "FAIL";
            $display("║  %-50s [%4s] ║", test_queue[i].name, status);
        end
        $display("╠══════════════════════════════════════════════════════════════╣");
        $display("║  Total: %3d  |  Passed: %3d  |  Failed: %3d                  ║",
                 tests_passed + tests_failed, tests_passed, tests_failed);
        $display("╚══════════════════════════════════════════════════════════════╝");
    endfunction
    
endmodule

//==============================================================================
// Test Utilities Package
//==============================================================================
package test_utils;
    
    import tb_pkg::*;
    
    // Wait for reset deassertion
    task automatic wait_for_reset_done(input logic rst_n);
        wait(rst_n === 1'b1);
        #100;  // Extra settling time
    endtask
    
    // Generate random data
    function automatic logic [7:0] random_byte();
        return $urandom_range(0, 255);
    endfunction
    
    // Generate random writable address
    function automatic logic [7:0] random_writable_addr();
        logic [7:0] addrs[] = '{
            ADDR_SYS_CTRL, ADDR_SCRATCH_0, ADDR_SCRATCH_1,
            ADDR_DATA_MODE, ADDR_DATA_CLK, ADDR_LED_OUT,
            ADDR_LED_OUT_H, ADDR_SEG_DATA, ADDR_SEG_CTRL
        };
        return addrs[$urandom_range(0, addrs.size()-1)];
    endfunction
    
    // Print test banner
    task automatic print_test_banner(string test_name);
        $display("\n");
        $display("================================================================");
        $display("  TEST: %s", test_name);
        $display("  Time: %0t", $time);
        $display("================================================================");
    endtask
    
    // Print test result
    task automatic print_test_result(string test_name, logic passed, int checks, int errors);
        $display("----------------------------------------------------------------");
        if (passed)
            $display("  RESULT: PASS (%0d checks, %0d errors)", checks, errors);
        else
            $display("  RESULT: FAIL (%0d checks, %0d errors)", checks, errors);
        $display("================================================================\n");
    endtask
    
    // Compare with tolerance (for timing-dependent tests)
    function automatic logic compare_with_tolerance(
        int actual, int expected, int tolerance
    );
        return (actual >= expected - tolerance) && (actual <= expected + tolerance);
    endfunction
    
endpackage