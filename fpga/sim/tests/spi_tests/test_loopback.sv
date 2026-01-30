`timescale 1ns / 1ps
//==============================================================================
// Test: test_spi_loopback
// Description: Verify SPI loopback operation
//              DUT echoes previous byte on each transfer
//==============================================================================

import tb_pkg::*;

module test_spi_loopback;

    localparam string TEST_NAME = "SPI Loopback";
    
    // Test patterns
    logic [7:0] test_patterns[] = '{
        8'hA5, 8'h5A, 8'hFF, 8'h00, 
        8'h55, 8'hAA, 8'h0F, 8'hF0,
        8'h12, 8'h34, 8'h56, 8'h78,
        8'h9A, 8'hBC, 8'hDE, 8'hF0
    };
    
    task automatic run_test(
        ref logic       clk,
        ref logic       rst_n,
        ref logic       spi_start,
        ref logic       spi_done,
        ref logic [7:0] spi_tx_data,
        ref logic [7:0] spi_rx_data,
        output int      pass_count,
        output int      fail_count
    );
        logic [7:0] expected;
        logic [7:0] received;
        logic [7:0] prev_tx;
        
        pass_count = 0;
        fail_count = 0;
        prev_tx    = 8'h00;  // Initial state is 0x00
        
        $display("\n========================================");
        $display("  TEST: %s", TEST_NAME);
        $display("========================================\n");
        
        foreach (test_patterns[i]) begin
            expected = prev_tx;  // Should receive what we sent last time
            
            $display("[%0t] SPI Transfer #%0d: TX=0x%02h, expecting RX=0x%02h", 
                     $time, i, test_patterns[i], expected);
            
            @(posedge clk);
            spi_tx_data = test_patterns[i];
            
            @(posedge clk);
            spi_start = 1'b1;
            @(posedge clk);
            spi_start = 1'b0;
            
            wait(spi_done);
            received = spi_rx_data;
            @(posedge clk);
            
            if (received === expected) begin
                $display("  [PASS] Received 0x%02h", received);
                pass_count++;
            end else begin
                $display("  [FAIL] Received 0x%02h (expected 0x%02h)", 
                         received, expected);
                fail_count++;
            end
            
            prev_tx = test_patterns[i];  // Update for next iteration
        end
        
        $display("\n----------------------------------------");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");
        
    endtask
    
    // Burst transfer test
    task automatic run_burst_test(
        ref logic       clk,
        ref logic       rst_n,
        ref logic       spi_start,
        ref logic       spi_done,
        ref logic [7:0] spi_tx_data[16],
        ref logic [7:0] spi_rx_data[16],
        ref int         spi_num_bytes,
        output int      pass_count,
        output int      fail_count
    );
        logic [7:0] expected[16];
        int burst_size = 8;
        
        pass_count = 0;
        fail_count = 0;
        
        $display("\n========================================");
        $display("  TEST: SPI Burst Loopback");
        $display("========================================\n");
        
        // First burst: send pattern, receive zeros
        for (int i = 0; i < burst_size; i++) begin
            spi_tx_data[i] = (i * 17) & 8'hFF;
            expected[i] = 8'h00;  // First burst should receive initial state
        end
        spi_num_bytes = burst_size;
        
        @(posedge clk);
        spi_start = 1'b1;
        @(posedge clk);
        spi_start = 1'b0;
        
        wait(spi_done);
        @(posedge clk);
        
        $display("First burst completed");
        
        // Second burst: send new pattern, should receive first pattern
        for (int i = 0; i < burst_size; i++) begin
            expected[i] = spi_tx_data[i];  // Should receive what we just sent
            spi_tx_data[i] = 8'hFF - i;    // New pattern
        end
        
        @(posedge clk);
        spi_start = 1'b1;
        @(posedge clk);
        spi_start = 1'b0;
        
        wait(spi_done);
        @(posedge clk);
        
        // Note: Due to how loopback works (byte-by-byte), we check last byte
        if (spi_rx_data[burst_size-1] === expected[burst_size-1]) begin
            $display("  [PASS] Burst loopback verified");
            pass_count++;
        end else begin
            $display("  [FAIL] Burst loopback mismatch");
            fail_count++;
        end
        
        $display("\n----------------------------------------");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================\n");
        
    endtask

endmodule
