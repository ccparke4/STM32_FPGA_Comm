`timescale 1ns / 1ps
//==============================================================================
// Test: test_i2c_basic_read
// Description: Verify I2C read operations from read-only registers
//==============================================================================

import tb_pkg::*;

module test_i2c_basic_read;

    localparam string TEST_NAME = "I2C Basic Read";
    
    // Expected values for read-only registers
    typedef struct {
        logic [7:0] addr;
        logic [7:0] expected;
        string      name;
    } read_test_t;
    
    read_test_t test_sequence[] = '{
        '{addr: ADDR_DEVICE_ID,   expected: DEVICE_ID_VALUE, name: "DEVICE_ID"},
        '{addr: ADDR_VERSION_MAJ, expected: VERSION_MAJ_VAL, name: "VERSION_MAJ"},
        '{addr: ADDR_VERSION_MIN, expected: VERSION_MIN_VAL, name: "VERSION_MIN"},
        '{addr: ADDR_LINK_CAPS,   expected: LINK_CAPS_VAL,   name: "LINK_CAPS"}
    };
    
    task automatic run_test(
        ref logic       clk,
        ref logic       rst_n,
        ref logic       i2c_start,
        ref logic       i2c_done,
        ref logic [7:0] i2c_reg_addr,
        ref logic [7:0] i2c_rdata,
        ref logic       i2c_rw,
        output int      pass_count,
        output int      fail_count
    );
        logic [7:0] readback;
        
        pass_count = 0;
        fail_count = 0;
        
        $display("\n========================================");
        $display("  TEST: %s", TEST_NAME);
        $display("========================================\n");
        
        foreach (test_sequence[i]) begin
            $display("[%0t] Reading %s (addr 0x%02h)", 
                     $time, test_sequence[i].name, test_sequence[i].addr);
            
            @(posedge clk);
            i2c_rw       = 1'b1;  // Read
            i2c_reg_addr = test_sequence[i].addr;
            
            @(posedge clk);
            i2c_start = 1'b1;
            @(posedge clk);
            i2c_start = 1'b0;
            
            wait(i2c_done);
            readback = i2c_rdata;
            @(posedge clk);
            
            if (readback === test_sequence[i].expected) begin
                $display("  [PASS] %s = 0x%02h", 
                         test_sequence[i].name, readback);
                pass_count++;
            end else begin
                $display("  [FAIL] %s = 0x%02h (expected 0x%02h)", 
                         test_sequence[i].name, readback, test_sequence[i].expected);
                fail_count++;
            end
        end
        
        $display("\n----------------------------------------");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");
        
    endtask

endmodule
