`timescale 1ns / 1ps
//==============================================================================
// Top-Level Testbench for I2C/SPI Co-Processor Verification
//==============================================================================
// Integrates:
//   - DUT (I2C slave, SPI slave, register file)
//   - I2C Master BFM
//   - SPI Master BFM
//   - Scoreboard with golden model
//   - Test execution framework
//==============================================================================

module tb_top;
    import tb_pkg::*;

    //--------------------------------------------------------------------------
    // Parameters
    //--------------------------------------------------------------------------
    localparam CLK_PERIOD = 10;  // 100MHz
    
    //--------------------------------------------------------------------------
    // DUT Signals
    //--------------------------------------------------------------------------
    logic        clk;
    logic        rst_btn;           // Button input (active high on Basys3)
    
    // I2C Bus (directly connected - testbench handles open-drain)
    logic        i2c_scl;
    logic        i2c_sda;
    wire         i2c_sda_wire;
    
    // SPI Bus
    logic        spi_cs;
    logic        spi_mosi;
    logic        spi_miso;
    logic        spi_sclk;
    
    // UI
    logic [7:0]  led;
    logic [7:0]  sw;
    logic [6:0]  seg;
    logic [3:0]  an;
    
    //--------------------------------------------------------------------------
    // BFM Control Signals
    //--------------------------------------------------------------------------
    // I2C Master BFM
    logic        i2c_start;
    logic        i2c_is_read;
    logic [7:0]  i2c_reg_addr;
    logic [7:0]  i2c_write_data;
    logic [7:0]  i2c_read_data;
    logic        i2c_done;
    logic        i2c_ack_error;
    logic        i2c_busy;
    logic        i2c_scl_o;
    logic        i2c_sda_o;
    logic        i2c_sda_oe;
    logic        i2c_sda_i;
    
    // SPI Master BFM
    logic        spi_start;
    logic [7:0]  spi_tx_data;
    logic [7:0]  spi_rx_data;
    logic        spi_done;
    logic        spi_busy;
    
    //--------------------------------------------------------------------------
    // Scoreboard Signals
    //--------------------------------------------------------------------------
    logic        sb_i2c_valid;
    logic        sb_i2c_is_read;
    logic [7:0]  sb_i2c_addr;
    logic [7:0]  sb_i2c_wdata;
    logic [7:0]  sb_i2c_rdata;
    logic        sb_spi_valid;
    logic [7:0]  sb_spi_tx;
    logic [7:0]  sb_spi_rx;
    logic [31:0] sb_error_count;
    logic [31:0] sb_i2c_txn_count;
    logic [31:0] sb_spi_txn_count;
    
    // Internal reset (active low, synchronized)
    logic        rst_n_sync;
    logic [1:0]  rst_sync_reg;
    
    //--------------------------------------------------------------------------
    // Clock Generation
    //--------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    //--------------------------------------------------------------------------
    // Reset Synchronization (matching RTL)
    //--------------------------------------------------------------------------
    wire rst_n_inverted = ~rst_btn;
    
    always_ff @(posedge clk) begin
        rst_sync_reg <= {rst_sync_reg[0], rst_n_inverted};
        rst_n_sync   <= rst_sync_reg[1];
    end
    
    //--------------------------------------------------------------------------
    // I2C Bus Modeling (Open-Drain with Pull-ups)
    //--------------------------------------------------------------------------
    // SCL is driven by master (simplified - no clock stretching)
    assign i2c_scl = i2c_scl_o;
    
    // SDA is bidirectional with pull-up
    // Master drives low when sda_oe=1, otherwise pulled high
    // Slave (DUT) also drives via IOBUF-like logic
    logic sda_slave_drive;
    logic sda_slave_out;
    
    // Model open-drain: either side can pull low
    assign i2c_sda_wire = (i2c_sda_oe && !i2c_sda_o) ? 1'b0 :
                          (sda_slave_drive && !sda_slave_out) ? 1'b0 : 1'b1;
    
    assign i2c_sda_i = i2c_sda_wire;
    
    //--------------------------------------------------------------------------
    // DUT Instantiation (Individual Modules - No IOBUF)
    //--------------------------------------------------------------------------
    // I2C Signals from slave
    logic [7:0] dut_reg_addr;
    logic [7:0] dut_reg_wdata;
    logic       dut_reg_wr;
    logic [7:0] dut_reg_rdata;
    logic       dut_reg_rd;
    
    // SPI signals
    logic       dut_spi_active;
    logic [7:0] dut_spi_rx_byte;
    
    // I2C Slave
    i2c_slave #(.SLAVE_ADDR(7'h55)) i2c_inst (
        .clk        (clk),
        .rst_n      (rst_n_sync),
        .scl_i      (i2c_scl),       
        .sda_i      (i2c_sda_wire),   
        .sda_o      (sda_slave_out),
        .sda_oe     (sda_slave_drive),
        .reg_addr   (dut_reg_addr),
        .reg_wdata  (dut_reg_wdata),
        .reg_wr     (dut_reg_wr),
        .reg_rdata  (dut_reg_rdata),
        .reg_rd     (dut_reg_rd)
    );
    
    // SPI Slave
    spi_slave spi_inst (
        .clk            (clk),
        .sclk           (spi_sclk),
        .cs             (spi_cs),
        .mosi           (spi_mosi),
        .miso           (spi_miso),
        .data_received  (dut_spi_rx_byte)
    );
    
    assign dut_spi_active = ~spi_cs;
    
    
    // I2C Master BFM -----------------------------------------------------------
    i2c_master_bfm #(
        .TARGET_ADDR(7'h55),
        .CLK_DIV(250)
    ) i2c_master (
        .clk        (clk),
        .rst_n      (rst_n_sync),
        .scl_o      (i2c_scl_o),
        .sda_o      (i2c_sda_o),
        .sda_oe     (i2c_sda_oe),
        .sda_i      (i2c_sda_i),
        .start      (i2c_start),
        .is_read    (i2c_is_read),
        .reg_addr   (i2c_reg_addr),
        .write_data (i2c_write_data),
        .read_data  (i2c_read_data),
        .done       (i2c_done),
        .ack_error  (i2c_ack_error),
        .busy       (i2c_busy)
    );
    
    //--------------------------------------------------------------------------
    // SPI Master BFM
    //--------------------------------------------------------------------------
    spi_master_bfm #(
        .CLK_DIV(10)
    ) spi_master (
        .clk     (clk),
        .rst_n   (rst_n_sync),
        .sclk    (spi_sclk),
        .cs_n    (spi_cs),
        .mosi    (spi_mosi),
        .miso    (spi_miso),
        .start   (spi_start),
        .tx_data (spi_tx_data),
        .rx_data (spi_rx_data),
        .done    (spi_done),
        .busy    (spi_busy)
    );
    
    // Scoreboard ---------------------------------------------------------------
    scoreboard scoreboard_inst (
        .clk           (clk),
        .rst_n         (rst_n_sync),
        .i2c_valid     (sb_i2c_valid),
        .i2c_is_read   (sb_i2c_is_read),
        .i2c_addr      (sb_i2c_addr),
        .i2c_wdata     (sb_i2c_wdata),
        .i2c_rdata     (sb_i2c_rdata),
        .spi_valid     (sb_spi_valid),
        .spi_tx        (sb_spi_tx),
        .spi_rx        (sb_spi_rx),
        .error_count   (sb_error_count),
        .i2c_txn_count (sb_i2c_txn_count),
        .spi_txn_count (sb_spi_txn_count)
    );
    
    // Test Statistics ---------------------------------------------------------
    test_stats stats;
    string test_name;
    int test_passed;
    
    // High-Level Test Tasks ----------------------------------------------------
    // I2C Write Register
    task automatic i2c_write(input logic [7:0] addr, input logic [7:0] data);
        @(posedge clk);
        i2c_reg_addr   <= addr;
        i2c_write_data <= data;
        i2c_is_read    <= 1'b0;
        i2c_start      <= 1'b1;
        @(posedge clk);
        i2c_start <= 1'b0;
        
        // Wait for completion
        wait(i2c_done);
        @(posedge clk);
        
        // Report to scoreboard
        sb_i2c_valid   <= 1'b1;
        sb_i2c_is_read <= 1'b0;
        sb_i2c_addr    <= addr;
        sb_i2c_wdata   <= data;
        @(posedge clk);
        sb_i2c_valid <= 1'b0;
        
        if (i2c_ack_error) begin
            $display("[TB] I2C WRITE addr=0x%02h data=0x%02h - ACK ERROR", addr, data);
        end else begin
            $display("[TB] I2C WRITE addr=0x%02h data=0x%02h - OK", addr, data);
        end
        
        stats.i2c_writes++;
    endtask
    
    // I2C Read Register
    task automatic i2c_read(input logic [7:0] addr, output logic [7:0] data);
        @(posedge clk);
        i2c_reg_addr <= addr;
        i2c_is_read  <= 1'b1;
        i2c_start    <= 1'b1;
        @(posedge clk);
        i2c_start <= 1'b0;
        
        // Wait for completion
        wait(i2c_done);
        @(posedge clk);
        
        data = i2c_read_data;
        
        // Report to scoreboard
        sb_i2c_valid   <= 1'b1;
        sb_i2c_is_read <= 1'b1;
        sb_i2c_addr    <= addr;
        sb_i2c_rdata   <= i2c_read_data;
        @(posedge clk);
        sb_i2c_valid <= 1'b0;
        
        if (i2c_ack_error) begin
            $display("[TB] I2C READ  addr=0x%02h - ACK ERROR", addr);
        end else begin
            $display("[TB] I2C READ  addr=0x%02h data=0x%02h - OK", addr, data);
        end
        
        stats.i2c_reads++;
    endtask
    
    // SPI Transfer
    task automatic spi_transfer(input logic [7:0] tx, output logic [7:0] rx);
        @(posedge clk);
        spi_tx_data <= tx;
        spi_start   <= 1'b1;
        @(posedge clk);
        spi_start <= 1'b0;
        
        // Wait for completion
        wait(spi_done);
        @(posedge clk);
        
        rx = spi_rx_data;
        
        // Report to scoreboard
        sb_spi_valid <= 1'b1;
        sb_spi_tx    <= tx;
        sb_spi_rx    <= spi_rx_data;
        @(posedge clk);
        sb_spi_valid <= 1'b0;
        
        $display("[TB] SPI XFER  tx=0x%02h rx=0x%02h", tx, rx);
        
        stats.spi_xfers++;
    endtask
    
    
    // Test Cases ---------------------------------------------------------------
    // Test: Basic I2C Write/Read
    task automatic run_i2c_basic_write();
        logic [7:0] rd_data;
        
        $display("\n========== TEST: I2C Basic Write/Read ==========\n");
        
        // Write to scratch registers
        i2c_write(ADDR_SCRATCH_0, 8'hAB);
        i2c_write(ADDR_SCRATCH_1, 8'hCD);
        
        // Read back
        i2c_read(ADDR_SCRATCH_0, rd_data);
        if (rd_data == 8'hAB) stats.record_pass();
        else stats.record_fail();
        
        i2c_read(ADDR_SCRATCH_1, rd_data);
        if (rd_data == 8'hCD) stats.record_pass();
        else stats.record_fail();
        
        // Write to LED register
        i2c_write(ADDR_LED_OUT, 8'h55);
        i2c_read(ADDR_LED_OUT, rd_data);
        if (rd_data == 8'h55) stats.record_pass();
        else stats.record_fail();
    endtask
    
    // Test: Read-Only Registers
    task automatic run_i2c_basic_read();
        logic [7:0] rd_data;
        
        $display("\n========== TEST: I2C Read-Only Registers ==========\n");
        
        // Read fixed values
        i2c_read(ADDR_DEVICE_ID, rd_data);
        if (rd_data == EXP_DEVICE_ID) stats.record_pass();
        else stats.record_fail();
        
        i2c_read(ADDR_VERSION_MAJ, rd_data);
        if (rd_data == EXP_VERSION_MAJ) stats.record_pass();
        else stats.record_fail();
        
        i2c_read(ADDR_VERSION_MIN, rd_data);
        if (rd_data == EXP_VERSION_MIN) stats.record_pass();
        else stats.record_fail();
        
        i2c_read(ADDR_LINK_CAPS, rd_data);
        if (rd_data == EXP_LINK_CAPS) stats.record_pass();
        else stats.record_fail();
    endtask
    
    // Test: SPI Loopback
    task automatic run_spi_loopback();
        logic [7:0] rx;
        logic [7:0] patterns[$] = '{8'h00, 8'hAA, 8'h55, 8'hFF, 8'h12, 8'h34, 8'h56, 8'h78};
        logic [7:0] last_tx;
        
        $display("\n========== TEST: SPI Loopback ==========\n");
        
        last_tx = 8'h00;  // Initial value
        
        foreach (patterns[i]) begin
            spi_transfer(patterns[i], rx);
            
            // RX should be previous TX (loopback behavior)
            if (rx == last_tx) stats.record_pass();
            else stats.record_fail();
            
            last_tx = patterns[i];
        end
    endtask
    
    // Test: Concurrent I2C and SPI
    task automatic run_concurrent_test();
        logic [7:0] rd_data;
        logic [7:0] spi_rx;
        int i2c_errors, spi_errors;
        
        $display("\n========== TEST: Concurrent I2C + SPI ==========\n");
        
        i2c_errors = 0;
        spi_errors = 0;
        
        fork
            // I2C Thread
            begin
                for (int i = 0; i < 10; i++) begin
                    i2c_write(ADDR_SCRATCH_0, i[7:0]);
                    i2c_read(ADDR_SCRATCH_0, rd_data);
                    if (rd_data != i[7:0]) i2c_errors++;
                end
            end
            
            // SPI Thread
            begin
                logic [7:0] last = 8'h00;
                for (int i = 0; i < 20; i++) begin
                    spi_transfer(i[7:0], spi_rx);
                    if (spi_rx != last) spi_errors++;
                    last = i[7:0];
                end
            end
        join
        
        if (i2c_errors == 0) stats.record_pass();
        else stats.record_fail();
        
        if (spi_errors == 0) stats.record_pass();
        else stats.record_fail();
        
        $display("[TB] Concurrent test: I2C errors=%0d, SPI errors=%0d", i2c_errors, spi_errors);
    endtask
    
    // Test: Stress Test
    task automatic run_stress_test();
        logic [7:0] rd_data;
        int errors;
        
        $display("\n========== TEST: Stress Test ==========\n");
        
        errors = 0;
        
        // Rapid writes and reads
        for (int i = 0; i < 50; i++) begin
            i2c_write(ADDR_SCRATCH_0, i[7:0]);
            i2c_read(ADDR_SCRATCH_0, rd_data);
            if (rd_data != i[7:0]) errors++;
        end
        
        if (errors == 0) stats.record_pass();
        else stats.record_fail();
        
        $display("[TB] Stress test: %0d errors out of 50 transactions", errors);
    endtask
    
    
    // Main Test Sequence -------------------------------------------------------
    initial begin
        // Initialize
        rst_btn        = 1'b1;  
        sw             = 8'h00;
        i2c_start      = 1'b0;
        spi_start      = 1'b0;
        sb_i2c_valid   = 1'b0;
        sb_spi_valid   = 1'b0;
        test_passed    = 1;
        
        // Get test name from plusarg
        if (!$value$plusargs("TEST=%s", test_name)) begin
            test_name = "all";
        end
        
        stats = new(test_name);
        
        // Reset sequence
        $display("\n[TB] Starting test: %s", test_name);
        $display("[TB] Applying reset...");
        
        repeat(10) @(posedge clk);
        rst_btn = 1'b0;   // Release reset
        repeat(20) @(posedge clk);
        
        $display("[TB] Reset complete, starting tests...\n");
        
        // Run selected test
        case (test_name)
            "basic_write":  run_i2c_basic_write();
            "basic_read":   run_i2c_basic_read();
            "loopback":     run_spi_loopback();
            "concurrent":   run_concurrent_test();
            "stress":       run_stress_test();
            "all": begin
                run_i2c_basic_write();
                run_i2c_basic_read();
                run_spi_loopback();
                run_concurrent_test();
                run_stress_test();
            end
            default: begin
                $display("[TB] Unknown test: %s", test_name);
                $display("[TB] Available tests: basic_write, basic_read, loopback, concurrent, stress, all");
            end
        endcase
        
        // Report results
        stats.report();
        stats.write_results("test_results.txt");
        
        // Check for errors
        if (stats.failed_tests > 0 || sb_error_count > 0) begin
            $display("\n[TB] *** TEST FAILED ***");
            test_passed = 0;
        end else begin
            $display("\n[TB] *** TEST PASSED ***");
        end
        
        #1000;
        $finish;
    end
    
    
    // Timeout Watchdog --------------------------------------------------------
    initial begin
        #10_000_000;  // 10ms timeout
        $display("\n[TB] *** TIMEOUT ***");
        $finish;
    end
    
    
    // Waveform Dump -----------------------------------------------------------
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
    end

endmodule