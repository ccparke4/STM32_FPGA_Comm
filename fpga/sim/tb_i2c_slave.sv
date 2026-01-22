`timescale 1ns / 1ps

module tb_i2c_slave();

    // -------------------------------------------------------------------------
    // Parameters & Signals
    // -------------------------------------------------------------------------
    parameter   CLK_PERIOD = 10;    // 100 MHz
    parameter   I2C_PERIOD = 2500;  // 400kHz
    parameter   SLAVE_ADDR = 7'h50;
    
    logic       clk;
    logic       rst_n;
    logic       scl_master;
    logic       sda_master;
    logic       sda_slave;
    logic       sda_slave_oe;
    logic       sda_bus;        

    logic [7:0] led_out;
    logic [7:0] sw_in;
    logic [7:0] read_data;
    
    integer     log_file;

    // -------------------------------------------------------------------------
    // I2C Open-Drain Model
    // -------------------------------------------------------------------------
    always_comb begin
        if (sda_master == 1'b0) sda_bus = 1'b0;
        else if (sda_slave_oe && (sda_slave == 1'b0)) sda_bus = 1'b0;
        else sda_bus = 1'b1;
    end

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    logic [7:0] reg_addr, reg_wdata, reg_rdata;
    logic reg_wr, reg_rd;

    i2c_slave #(.SLAVE_ADDR(SLAVE_ADDR)) dut_i2c (
        .clk(clk), .rst_n(rst_n),
        .scl_i(scl_master), .sda_i(sda_bus), .sda_o(sda_slave), .sda_oe(sda_slave_oe),
        .reg_addr(reg_addr), .reg_wdata(reg_wdata), .reg_wr(reg_wr), .reg_rdata(reg_rdata), .reg_rd(reg_rd)
    );

    register_file dut_regs (
        .clk(clk), .rst_n(rst_n),
        .reg_addr(reg_addr), .reg_wdata(reg_wdata), .reg_wr(reg_wr), .reg_rdata(reg_rdata), .reg_rd(reg_rd),
        .led_out(led_out), .sw_in(sw_in), .spi_active(1'b0), .spi_rx_byte(8'h00)
    );

    // Clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Logging & assertion Tasks
    // -------------------------------------------------------------------------
    task log(input string msg);
        $display("[%0t] %s", $time, msg);
        $fwrite(log_file, "[%0t] %s\n", $time, msg);
    endtask

    // STOP ON FAIL LOGIC
    task assert_val(input [7:0] expected, input [7:0] actual, input string name);
        if (actual !== expected) begin
            log($sformatf("FATAL ERROR: %s mismatch!", name));
            log($sformatf("  Expected: 0x%02X", expected));
            log($sformatf("  Actual:   0x%02X", actual));
            $fatal(1, "Test Failed. Stopping simulation.");
        end else begin
            log($sformatf("PASS: %s = 0x%02X", name, actual));
        end
    endtask

    // -------------------------------------------------------------------------
    // I2C Tasks (Master Simulation)
    // -------------------------------------------------------------------------
    task i2c_start();
        sda_master <= 1'b1; scl_master <= 1'b1;
        #(I2C_PERIOD/2);
        sda_master <= 1'b0; // START
        #(I2C_PERIOD/4);
        scl_master <= 1'b0;
        #(I2C_PERIOD/4);
    endtask

    task i2c_stop();
        sda_master <= 1'b0;
        #(I2C_PERIOD/4);
        scl_master <= 1'b1;
        #(I2C_PERIOD/2);
        sda_master <= 1'b1; // STOP
        #(I2C_PERIOD);
    endtask

    task i2c_write_byte(input [7:0] data, output logic ack);
        integer i;
        for (i = 7; i >= 0; i = i - 1) begin
            sda_master <= data[i];
            #(I2C_PERIOD/4);
            scl_master <= 1'b1;
            #(I2C_PERIOD/2);
            scl_master <= 1'b0;
            #(I2C_PERIOD/4);
        end
        // ACK Phase
        sda_master <= 1'b1; // Release
        #(I2C_PERIOD/4);
        scl_master <= 1'b1;
        #(I2C_PERIOD/4);
        ack = (sda_bus == 1'b0); // Sample
        #(I2C_PERIOD/4);
        scl_master <= 1'b0;
        #(I2C_PERIOD/4);
    endtask

    task i2c_read_byte(output [7:0] data, input logic send_ack);
        integer i;
        data = 8'h00;
        sda_master <= 1'b1; // Release
        for (i = 7; i >= 0; i = i - 1) begin
            #(I2C_PERIOD/4);
            scl_master <= 1'b1;
            #(I2C_PERIOD/4);
            data[i] = sda_bus; // Sample
            #(I2C_PERIOD/4);
            scl_master <= 1'b0;
            #(I2C_PERIOD/4);
        end
        // ACK Phase
        sda_master <= send_ack ? 1'b0 : 1'b1;
        #(I2C_PERIOD/4);
        scl_master <= 1'b1;
        #(I2C_PERIOD/2);
        scl_master <= 1'b0;
        #(I2C_PERIOD/4);
        sda_master <= 1'b1;
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        log_file = $fopen("robust_test.log", "w");
        log("-----------------------------------------");
        log(" Starting Robust I2C Slave Testbench");
        log("-----------------------------------------");

        rst_n = 0; scl_master = 1; sda_master = 1; sw_in = 8'hA5;
        #200;
        rst_n = 1;
        #200;

        // 1. DEVICE ID Check
        log("TEST 1: Read Device ID (Expect 0xA7)");
        begin
            logic ack;
            logic [7:0] rdata;
            i2c_start();
            i2c_write_byte({SLAVE_ADDR, 1'b0}, ack); // Write Addr
            if(!ack) begin log("No ACK on Addr"); $fatal(1); end
            
            i2c_write_byte(8'h00, ack); // Reg 0x00
            if(!ack) begin log("No ACK on Reg"); $fatal(1); end
            
            i2c_start(); // Repeated Start
            i2c_write_byte({SLAVE_ADDR, 1'b1}, ack); // Read Addr
            if(!ack) begin log("No ACK on Read Addr"); $fatal(1); end
            
            i2c_read_byte(rdata, 1'b0); // NACK (Done)
            i2c_stop();
            
            assert_val(8'hA7, rdata, "DEVICE_ID");
        end

        // 2. SCRATCHPAD Write/Read
        log("TEST 2: Write/Read Scratchpad (0x05)");
        begin
            logic ack;
            logic [7:0] rdata;
            // Write 0x55 to Reg 0x05
            i2c_start();
            i2c_write_byte({SLAVE_ADDR, 1'b0}, ack);
            if(!ack) $fatal(1, "ACK fail");
            i2c_write_byte(8'h05, ack);
            if(!ack) $fatal(1, "ACK fail");
            i2c_write_byte(8'h55, ack);
            if(!ack) $fatal(1, "ACK fail");
            i2c_stop();
            
            #1000; // Gap
            
            // Read Back
            i2c_start();
            i2c_write_byte({SLAVE_ADDR, 1'b0}, ack);
            i2c_write_byte(8'h05, ack);
            i2c_start();
            i2c_write_byte({SLAVE_ADDR, 1'b1}, ack);
            i2c_read_byte(rdata, 1'b0);
            i2c_stop();
            
            assert_val(8'h55, rdata, "SCRATCH0");
        end

        // 3. LED Control
        log("TEST 3: LED Control (0x20)");
        begin
            logic ack;
            i2c_start();
            i2c_write_byte({SLAVE_ADDR, 1'b0}, ack);
            i2c_write_byte(8'h20, ack);
            i2c_write_byte(8'hF0, ack); // LEDs ON
            i2c_stop();
            
            #500; // Wait for internal propagation
            assert_val(8'hF0, led_out, "LED Output HW");
        end
        
        // 4. Test Wrong Address (Should NACK)
        log("TEST 4: Wrong Address Check");
        begin
            logic ack;
            i2c_start();
            i2c_write_byte({7'h51, 1'b0}, ack); // Wrong Addr
            i2c_stop();
            
            if(ack) begin
                log("FATAL: Slave ACKed wrong address!");
                $fatal(1);
            end else begin
                log("PASS: Slave NACKed wrong address.");
            end
        end

        log("-----------------------------------------");
        log(" ALL TESTS PASSED SUCCESSFULLY");
        log("-----------------------------------------");
        $fclose(log_file);
        $finish;
    end

endmodule