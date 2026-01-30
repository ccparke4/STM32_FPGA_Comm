`timescale 1ns / 1ps
//==============================================================================
// Testbench Package - Common definitions for I2C/SPI verification
//==============================================================================
// Provides:
//   - Transaction classes for I2C and SPI
//   - Register map constants (mirroring RTL)
//   - Test statistics tracking
//   - Common utility functions
//==============================================================================

package tb_pkg;

    //--------------------------------------------------------------------------
    // Timing Parameters
    //--------------------------------------------------------------------------
    parameter CLK_PERIOD_NS     = 10;       // 100MHz system clock
    parameter I2C_PERIOD_NS     = 2500;     // 400kHz I2C (Fast Mode)
    parameter SPI_PERIOD_NS     = 100;      // 10MHz SPI clock
    
    //--------------------------------------------------------------------------
    // I2C Configuration
    //--------------------------------------------------------------------------
    parameter logic [6:0] I2C_SLAVE_ADDR = 7'h55;
    
    //--------------------------------------------------------------------------
    // Register Map (must match register_file.sv)
    //--------------------------------------------------------------------------
    // System Registers (0x00-0x0F)
    parameter logic [7:0] ADDR_DEVICE_ID   = 8'h00;  // RO - Device ID
    parameter logic [7:0] ADDR_VERSION_MAJ = 8'h01;  // RO - Major version
    parameter logic [7:0] ADDR_VERSION_MIN = 8'h02;  // RO - Minor version
    parameter logic [7:0] ADDR_SYS_STATUS  = 8'h03;  // RO/W1C - Status
    parameter logic [7:0] ADDR_SYS_CTRL    = 8'h04;  // RW - Control
    parameter logic [7:0] ADDR_SCRATCH_0   = 8'h05;  // RW - Scratch pad 0
    parameter logic [7:0] ADDR_SCRATCH_1   = 8'h06;  // RW - Scratch pad 1
    
    // Link Control Registers (0x10-0x1F)
    parameter logic [7:0] ADDR_LINK_CAPS   = 8'h10;  // RO - Capabilities
    parameter logic [7:0] ADDR_DATA_MODE   = 8'h11;  // RW - Data mode config
    parameter logic [7:0] ADDR_DATA_CLK    = 8'h12;  // RW - Clock divider
    parameter logic [7:0] ADDR_DATA_STATUS = 8'h13;  // RO - Data plane status
    parameter logic [7:0] ADDR_DATA_ERR    = 8'h14;  // RO - Error count
    parameter logic [7:0] ADDR_DATA_TEST   = 8'h15;  // RW - Test register
    
    // GPIO Registers (0x20-0x2F)
    parameter logic [7:0] ADDR_LED_OUT     = 8'h20;  // RW - LED output
    parameter logic [7:0] ADDR_LED_OUT_H   = 8'h21;  // RW - LED output high
    parameter logic [7:0] ADDR_SW_IN       = 8'h22;  // RO - Switch input
    parameter logic [7:0] ADDR_SW_IN_H     = 8'h23;  // RO - Switch input high
    parameter logic [7:0] ADDR_SEG_DATA    = 8'h24;  // RW - 7-seg data
    parameter logic [7:0] ADDR_SEG_CTRL    = 8'h25;  // RW - 7-seg control
    
    //--------------------------------------------------------------------------
    // Expected Fixed Values (from RTL)
    //--------------------------------------------------------------------------
    parameter logic [7:0] EXP_DEVICE_ID   = 8'hA7;
    parameter logic [7:0] EXP_VERSION_MAJ = 8'h01;
    parameter logic [7:0] EXP_VERSION_MIN = 8'h00;
    parameter logic [7:0] EXP_LINK_CAPS   = 8'b00_01_0_1_0_1;  // 0x15
    parameter logic [7:0] EXP_DATA_CLK    = 8'h04;  // Default divider

    //--------------------------------------------------------------------------
    // Transaction Types
    //--------------------------------------------------------------------------
    typedef enum {
        I2C_WRITE,
        I2C_READ,
        SPI_XFER
    } txn_type_t;
    
    //--------------------------------------------------------------------------
    // I2C Transaction Class
    //--------------------------------------------------------------------------
    class i2c_transaction;
        rand bit        is_read;
        rand bit [7:0]  reg_addr;
        rand bit [7:0]  data;
        bit [7:0]       read_data;      // Captured during read
        bit             ack_received;
        time            timestamp;
        
        // Constrain register addresses to valid range
        constraint valid_addr {
            reg_addr inside {[8'h00:8'h06], [8'h10:8'h15], [8'h20:8'h25]};
        }
        
        function new();
            timestamp = $time;
        endfunction
        
        function string to_string();
            if (is_read)
                return $sformatf("I2C_RD  addr=0x%02h data=0x%02h ack=%b @%0t", 
                                 reg_addr, read_data, ack_received, timestamp);
            else
                return $sformatf("I2C_WR  addr=0x%02h data=0x%02h ack=%b @%0t", 
                                 reg_addr, data, ack_received, timestamp);
        endfunction
    endclass
    
    //--------------------------------------------------------------------------
    // SPI Transaction Class
    //--------------------------------------------------------------------------
    class spi_transaction;
        rand bit [7:0]  tx_data;
        bit [7:0]       rx_data;
        time            timestamp;
        
        function new();
            timestamp = $time;
        endfunction
        
        function string to_string();
            return $sformatf("SPI_XFER tx=0x%02h rx=0x%02h @%0t", 
                             tx_data, rx_data, timestamp);
        endfunction
    endclass
    
    //--------------------------------------------------------------------------
    // Test Statistics Class
    //--------------------------------------------------------------------------
    class test_stats;
        int unsigned total_tests;
        int unsigned passed_tests;
        int unsigned failed_tests;
        int unsigned i2c_writes;
        int unsigned i2c_reads;
        int unsigned spi_xfers;
        string       test_name;
        time         start_time;
        time         end_time;
        
        function new(string name = "unnamed");
            test_name    = name;
            total_tests  = 0;
            passed_tests = 0;
            failed_tests = 0;
            i2c_writes   = 0;
            i2c_reads    = 0;
            spi_xfers    = 0;
            start_time   = $time;
        endfunction
        
        function void record_pass();
            total_tests++;
            passed_tests++;
        endfunction
        
        function void record_fail();
            total_tests++;
            failed_tests++;
        endfunction
        
        function void report();
            end_time = $time;
            $display("");
            $display("╔════════════════════════════════════════════════════════╗");
            $display("║              TEST RESULTS: %-26s ║", test_name);
            $display("╠════════════════════════════════════════════════════════╣");
            $display("║  Total Tests:    %6d                                 ║", total_tests);
            $display("║  Passed:         %6d                                 ║", passed_tests);
            $display("║  Failed:         %6d                                 ║", failed_tests);
            $display("╠════════════════════════════════════════════════════════╣");
            $display("║  I2C Writes:     %6d                                 ║", i2c_writes);
            $display("║  I2C Reads:      %6d                                 ║", i2c_reads);
            $display("║  SPI Transfers:  %6d                                 ║", spi_xfers);
            $display("╠════════════════════════════════════════════════════════╣");
            $display("║  Duration:       %6d ns                              ║", end_time - start_time);
            if (failed_tests == 0)
                $display("║  Status:         *** PASS ***                          ║");
            else
                $display("║  Status:         *** FAIL ***                          ║");
            $display("╚════════════════════════════════════════════════════════╝");
        endfunction
        
        function void write_results(string filename);
            int fd;
            fd = $fopen(filename, "w");
            if (fd) begin
                $fwrite(fd, "test_name=%s\n", test_name);
                $fwrite(fd, "total=%0d\n", total_tests);
                $fwrite(fd, "passed=%0d\n", passed_tests);
                $fwrite(fd, "failed=%0d\n", failed_tests);
                $fwrite(fd, "i2c_writes=%0d\n", i2c_writes);
                $fwrite(fd, "i2c_reads=%0d\n", i2c_reads);
                $fwrite(fd, "spi_xfers=%0d\n", spi_xfers);
                $fwrite(fd, "duration_ns=%0d\n", end_time - start_time);
                $fclose(fd);
            end
        endfunction
    endclass
    
    //--------------------------------------------------------------------------
    // Utility Functions
    //--------------------------------------------------------------------------
    function automatic bit is_writable_reg(input logic [7:0] addr);
        case (addr)
            ADDR_SYS_CTRL,
            ADDR_SCRATCH_0,
            ADDR_SCRATCH_1,
            ADDR_DATA_MODE,
            ADDR_DATA_CLK,
            ADDR_LED_OUT,
            ADDR_LED_OUT_H,
            ADDR_SEG_DATA,
            ADDR_SEG_CTRL:   return 1'b1;
            default:         return 1'b0;
        endcase
    endfunction
    
    function automatic bit is_readonly_reg(input logic [7:0] addr);
        case (addr)
            ADDR_DEVICE_ID,
            ADDR_VERSION_MAJ,
            ADDR_VERSION_MIN,
            ADDR_LINK_CAPS,
            ADDR_DATA_STATUS,
            ADDR_DATA_ERR,
            ADDR_SW_IN,
            ADDR_SW_IN_H:    return 1'b1;
            default:         return 1'b0;
        endcase
    endfunction

endpackage