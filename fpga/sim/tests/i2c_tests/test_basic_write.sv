`timescale 1ns / 1ps
//==============================================================================
// Test: test_i2c_basic_write
// Description: Verify basic I2C write operations to writable registers
//==============================================================================

import tb_pkg::*;

module test_i2c_basic_write;

    // Test configuration
    localparam string TEST_NAME = "I2C Basic Write";
    
    // Test sequence definition (can be driven from file or hardcoded)
    typedef struct {
        logic [7:0] addr;
        logic [7:0] data;
        logic [7:0] expected;
    } write_test_t;
    
    write_test_t test_sequence[] = '{
        '{addr: ADDR_SCRATCH_0, data: 8'hA5, expected: 8'hA5},
        '{addr: ADDR_SCRATCH_0, data: 8'h5A, expected: 8'h5A},
        '{addr: ADDR_SCRATCH_1, data: 8'hFF, expected: 8'hFF},
        '{addr: ADDR_SCRATCH_1, data: 8'h00, expected: 8'h00},
        '{addr: ADDR_LED_OUT,   data: 8'h55, expected: 8'h55},
        '{addr: ADDR_LED_OUT,   data: 8'hAA, expected: 8'hAA},
        '{addr: ADDR_SYS_CTRL,  data: 8'h01, expected: 8'h01},
        '{addr: ADDR_DATA_MODE, data: 8'h80, expected: 8'h80}
    };
    
    // Test execution task (called from tb_top)
    task automatic run_test(
        // BFM interface signals passed from tb_top
        ref logic       clk,
        ref logic       rst_n,
        ref logic       i2c_start,
        ref logic       i2c_done,
        ref logic [7:0] i2c_reg_addr,
        ref logic [7:0] i2c_wdata,
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
            // Write phase
            $display("[%0t] Writing 0x%02h to addr 0x%02h", 
                     $time, test_sequence[i].data, test_sequence[i].addr);
            
            @(posedge clk);
            i2c_rw       = 1'b0;  // Write
            i2c_reg_addr = test_sequence[i].addr;
            i2c_wdata    = test_sequence[i].data;
            
            @(posedge clk);
            i2c_start = 1'b1;
            @(posedge clk);
            i2c_start = 1'b0;
            
            wait(i2c_done);
            @(posedge clk);
            
            // Read-back phase
            i2c_rw = 1'b1;  // Read
            @(posedge clk);
            i2c_start = 1'b1;
            @(posedge clk);
            i2c_start = 1'b0;
            
            wait(i2c_done);
            readback = i2c_rdata;
            @(posedge clk);
            
            // Verify
            if (readback === test_sequence[i].expected) begin
                $display("  [PASS] Read back 0x%02h (expected 0x%02h)", 
                         readback, test_sequence[i].expected);
                pass_count++;
            end else begin
                $display("  [FAIL] Read back 0x%02h (expected 0x%02h)", 
                         readback, test_sequence[i].expected);
                fail_count++;
            end
        end
        
        $display("\n----------------------------------------");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");
        
    endtask

endmodule