`timescale 1ns / 1ps
//==============================================================================
// Scoreboard - Golden Model Verification
//==============================================================================
// Maintains a shadow copy of the register file and verifies all transactions.
// Features:
//   - Golden register model
//   - I2C write/read verification
//   - SPI loopback verification
//   - Transaction logging
//   - Error counting and reporting
//==============================================================================

module scoreboard
    import tb_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    
    // I2C Transaction Interface
    input  logic        i2c_valid,
    input  logic        i2c_is_read,
    input  logic [7:0]  i2c_addr,
    input  logic [7:0]  i2c_wdata,
    input  logic [7:0]  i2c_rdata,
    
    // SPI Transaction Interface
    input  logic        spi_valid,
    input  logic [7:0]  spi_tx,
    input  logic [7:0]  spi_rx,
    
    // Status
    output logic [31:0] error_count,
    output logic [31:0] i2c_txn_count,
    output logic [31:0] spi_txn_count
);

    //--------------------------------------------------------------------------
    // Golden Register File
    //--------------------------------------------------------------------------
    logic [7:0] golden_regs [0:255];
    logic [7:0] spi_last_byte;
    
    // Log file handle
    integer log_fd;
    
    //--------------------------------------------------------------------------
    // Initialize Log File (simulation only)
    //--------------------------------------------------------------------------
    initial begin
        log_fd = $fopen("scoreboard_log.txt", "w");
        if (log_fd) begin
            $fwrite(log_fd, "=== Scoreboard Transaction Log ===\n");
            $fwrite(log_fd, "Time,Type,Addr,Expected,Actual,Status\n");
        end
    end
    
    //--------------------------------------------------------------------------
    // Initialize Golden Model
    //--------------------------------------------------------------------------
    task automatic init_golden_model();
        // Initialize all to 0
        for (int i = 0; i < 256; i++) begin
            golden_regs[i] = 8'h00;
        end
        
        // Set read-only fixed values
        golden_regs[ADDR_DEVICE_ID]   = EXP_DEVICE_ID;    // 0xA7
        golden_regs[ADDR_VERSION_MAJ] = EXP_VERSION_MAJ;  // 0x01
        golden_regs[ADDR_VERSION_MIN] = EXP_VERSION_MIN;  // 0x00
        golden_regs[ADDR_LINK_CAPS]   = EXP_LINK_CAPS;    // 0x15
        golden_regs[ADDR_DATA_CLK]    = EXP_DATA_CLK;     // 0x04
    endtask
    
    //--------------------------------------------------------------------------
    // Single Clocked Block - All State Updates
    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset counters
            error_count   <= '0;
            i2c_txn_count <= '0;
            spi_txn_count <= '0;
            spi_last_byte <= 8'h00;
            
            // Initialize golden model
            init_golden_model();
            
        end else begin
            //------------------------------------------------------------------
            // I2C Transaction Processing
            //------------------------------------------------------------------
            if (i2c_valid) begin
                i2c_txn_count <= i2c_txn_count + 1;
                
                if (i2c_is_read) begin
                    // Verify read data matches golden model
                    if (i2c_rdata !== golden_regs[i2c_addr]) begin
                        error_count <= error_count + 1;
                        $display("[SCOREBOARD] I2C READ:  addr=0x%02h exp=0x%02h got=0x%02h - *** MISMATCH ***", 
                                 i2c_addr, golden_regs[i2c_addr], i2c_rdata);
                        if (log_fd) begin
                            $fwrite(log_fd, "%0t,I2C_RD,0x%02h,0x%02h,0x%02h,MISMATCH\n", 
                                    $time, i2c_addr, golden_regs[i2c_addr], i2c_rdata);
                        end
                    end else begin
                        $display("[SCOREBOARD] I2C READ:  addr=0x%02h exp=0x%02h got=0x%02h - MATCH", 
                                 i2c_addr, golden_regs[i2c_addr], i2c_rdata);
                        if (log_fd) begin
                            $fwrite(log_fd, "%0t,I2C_RD,0x%02h,0x%02h,0x%02h,MATCH\n", 
                                    $time, i2c_addr, golden_regs[i2c_addr], i2c_rdata);
                        end
                    end
                end else begin
                    // I2C Write - Update golden model if writable
                    if (is_writable_reg(i2c_addr)) begin
                        golden_regs[i2c_addr] <= i2c_wdata;
                        $display("[SCOREBOARD] I2C WRITE: addr=0x%02h data=0x%02h - OK", i2c_addr, i2c_wdata);
                        if (log_fd) begin
                            $fwrite(log_fd, "%0t,I2C_WR,0x%02h,N/A,0x%02h,WRITE_OK\n", $time, i2c_addr, i2c_wdata);
                        end
                    end else if (is_readonly_reg(i2c_addr)) begin
                        $display("[SCOREBOARD] I2C WRITE: addr=0x%02h data=0x%02h - RO (ignored)", i2c_addr, i2c_wdata);
                        if (log_fd) begin
                            $fwrite(log_fd, "%0t,I2C_WR,0x%02h,N/A,0x%02h,RO_IGNORE\n", $time, i2c_addr, i2c_wdata);
                        end
                    end else begin
                        $display("[SCOREBOARD] I2C WRITE: addr=0x%02h data=0x%02h - UNKNOWN REG", i2c_addr, i2c_wdata);
                        if (log_fd) begin
                            $fwrite(log_fd, "%0t,I2C_WR,0x%02h,N/A,0x%02h,UNKNOWN\n", $time, i2c_addr, i2c_wdata);
                        end
                    end
                end
            end
            
            //------------------------------------------------------------------
            // SPI Transaction Processing
            //------------------------------------------------------------------
            if (spi_valid) begin
                spi_txn_count <= spi_txn_count + 1;
                
                // Loopback check: RX should equal previous TX
                if (spi_rx !== spi_last_byte) begin
                    error_count <= error_count + 1;
                    $display("[SCOREBOARD] SPI XFER:  tx=0x%02h rx=0x%02h exp=0x%02h - *** MISMATCH ***", 
                             spi_tx, spi_rx, spi_last_byte);
                    if (log_fd) begin
                        $fwrite(log_fd, "%0t,SPI,0x%02h,0x%02h,0x%02h,MISMATCH\n", 
                                $time, spi_tx, spi_last_byte, spi_rx);
                    end
                end else begin
                    $display("[SCOREBOARD] SPI XFER:  tx=0x%02h rx=0x%02h exp=0x%02h - MATCH", 
                             spi_tx, spi_rx, spi_last_byte);
                    if (log_fd) begin
                        $fwrite(log_fd, "%0t,SPI,0x%02h,0x%02h,0x%02h,MATCH\n", 
                                $time, spi_tx, spi_last_byte, spi_rx);
                    end
                end
                
                // Update last byte for next transfer
                spi_last_byte <= spi_tx;
            end
        end
    end
    
    //--------------------------------------------------------------------------
    // Manual Check Functions (called from testbench)
    //--------------------------------------------------------------------------
    function automatic logic [7:0] get_expected(input logic [7:0] addr);
        return golden_regs[addr];
    endfunction
    
    //--------------------------------------------------------------------------
    // Final Report
    //--------------------------------------------------------------------------
    final begin
        if (log_fd) begin
            $fwrite(log_fd, "\n=== Summary ===\n");
            $fwrite(log_fd, "I2C Transactions: %0d\n", i2c_txn_count);
            $fwrite(log_fd, "SPI Transactions: %0d\n", spi_txn_count);
            $fwrite(log_fd, "Errors: %0d\n", error_count);
            $fclose(log_fd);
        end
        
        $display("");
        $display("[SCOREBOARD] ============ Final Summary ============");
        $display("[SCOREBOARD] I2C Transactions: %0d", i2c_txn_count);
        $display("[SCOREBOARD] SPI Transactions: %0d", spi_txn_count);
        $display("[SCOREBOARD] Total Errors:     %0d", error_count);
        $display("[SCOREBOARD] =========================================");
    end

endmodule