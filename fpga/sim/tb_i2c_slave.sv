`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/16/2026 10:56:19 PM
// Design Name: 
// Module Name: tb_i2c_slave
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_i2c_slave();

    // parameters ----------------------------------------------------------
    parameter   CLK_PERIOD = 10;        // 100 MHz sys clk
    parameter   I2C_PERIOD = 2500;      // 400kHz i2c clock (2.5us period)
    parameter   SLAVE_ADDR = 7'h50;
    // signals -------------------------------------------------------------
    logic       clk;
    logic       rst_n;
    logic       scl_master;             // Master drive SCL
    logic       sda_master;             // Master drives SDA
    logic       sda_slave;              // Slave drives SDA
    logic       sda_slave_oe;           // Slave output enable
    wire        sda_bus;                // Combined SDA bus         

    // HW Interfaces
    logic [7:0] led_out;
    logic [7:0] sw_in;

    // Test results
    logic [7:0] read_data;
    int         test_pass;
    int         test_fail;

    // I2C Bus model -------------------------------------------------------
    // open drain w/ PU
    assign sda_bus  = (sda_master === 1'b0) ? 1'b0 :
                      (sda_slave_oe && !sda_slave) ? 1'b0 : 1'b1;

    // DUI Inst. -----------------------------------------------------------
    logic [7:0]     reg_addr;
    logic [7:0]     reg_wdata;
    logic           reg_wr;
    logic [7:0]     reg_rdata;
    logic           reg_rd;

    i2c_slave #(
        .SLAVE_ADDR(SLAVE_ADDR)
    ) dut_i2c (
        .clk        (clk),
        .rst_n      (rst_n),
        .scl_i      (scl_master),
        .sda_i      (sda_bus),
        .sda_o      (sda_slave),
        .sda_oe     (sda_slave_oe),
        .reg_addr   (reg_addr),
        .reg_wdata  (reg_wdata),
        .reg_wr     (reg_wr),
        .reg_rdata  (reg_rdata),
        .reg_rd     (reg_rd)
    );

    register_file dut_regs (
        .clk        (clk),
        .rst_n      (rst_n),
        .reg_addr   (reg_addr),
        .reg_wdata  (reg_wdata),
        .reg_wr     (reg_wr),
        .reg_rdata  (reg_rdata),
        .reg_rd     (reg_rd),
        .led_out    (led_out),
        .sw_in      (sw_in),
        .spi_active (1'b0),
        .spi_rx_byte(8'h00)
    );

    // Clock gen ---------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // I2C Master Tasks --------------------------------------------------
    // Gen I2C START 
    task i2c_start();
        // SDA falls while SCL is high
        sda_master  <= 1'b1;
        scl_master  <= 1'b1;
        #(I2C_PERIOD/2);
        sda_master  <= 1'b0;        // SDA falls
        #(I2C_PERIOD/2);
        scl_master  <= 1'b0;        // SCL falls
        #(I2C_PERIOD/4);
    endtask //i2c_start()

    // generate I2C STOP
    task i2c_stop();
        sda_master  <= 1'b0;
        #(I2C_PERIOD/4);
        scl_master  <= 1'b1;        // SCL rises
        #(I2C_PERIOD/2);
        sda_master  <= 1'b1;        // SDA rises - STOP
        #(I2C_PERIOD);
    endtask

    // Write 1'B, return ACK status
    task i2c_write_byte(input [7:0] data, output logic ack);
        integer i;
        // send 8'b, MSB 1st
        for (i = 7; i >= 0; i = i - 1) begin
            sda_master  <= data[i];
            #(I2C_PERIOD/4);
            scl_master  <= 1'b1;
            #(I2C_PERIOD/4);
            scl_master  <= 1'b0;
            #(I2C_PERIOD/4);
        end
        // Release SDA for ACK
        sda_master  <=  1'bz;
        #(I2C_PERIOD/4);
        scl_master  <= 1'b1;
        #(I2C_PERIOD/4);
        ack         = ~sda_bus;
        #(I2C_PERIOD/4);
        scl_master  <= 1'b0;
        #(I2C_PERIOD/4);
    endtask

    // Read one byte, send ACK or NACK
    task i2c_read_byte(output [7:0] data, input logic send_ack);
        integer i;
        data        =   8'h00;
        sda_master  <= 1'bz;    // Release SDA for slave to drive
        // Receive 8'b
        for (i = 7; i >= 0; i = i - 1) begin
            #(I2C_PERIOD/4);
            scl_master  <= 1'b1;
            #(I2C_PERIOD/4);
            data[i]     = sda_bus;
            #(I2C_PERIOD/4);
            scl_master  <= 1'b0;
            #(I2C_PERIOD/4);
        end
        // send ACK or NACK
        sda_master  <= send_ack ? 1'b0 : 1'b1;
        #(I2C_PERIOD/4);
        scl_master  <= 1'b1;
        #(I2C_PERIOD/2);
        scl_master  <= 1'b0;
        #(I2C_PERIOD/4);
        sda_master  <= 1'bz;
    endtask

    // High-level i2c comm tasks -----------------------------------------------
    // write single reg
    task i2c_reg_write(input [7:0] reg_address, input [7:0] data);
        logic ack;

        i2c_start();
        i2c_write_byte({SLAVE_ADDR, 1'b0}, ack);        // addr + wr
        if (!ack) $display("   ERROR: No ACK on address");

        i2c_write_byte(reg_address, ack);               // register address
        if (!ack) $display("    ERROR: No ACK on reg address");

        i2c_write_byte(data, ack);                      // data
        if (!ack) $display("    ERROR: No ACK on data");

        i2c_stop();
    endtask

    // Read single reg
    task i2c_reg_read(input [7:0] reg_address, output [7:0] data);
        logic ack;

        i2c_start();
        i2c_write_byte({SLAVE_ADDR, 1'b0}, ack);        // address + write
        if (!ack) $display("    ERROR: No ACK on address");

        i2c_write_byte(reg_address, ack);               // reg address
        if (!ack) $display("    ERROR: No ACK on reg address");

        i2c_start();                                    // repeated start
        i2c_write_byte({SLAVE_ADDR, 1'b1}, ack);        // addr + read
        if (!ack) $display("    ERROR: No ACK on read address");

        i2c_read_byte(data, 1'b0);
        i2c_stop();

        $display("[%0t] I2C Read:   Reg[0x%02X] = 0x%02X", $time, reg_address, data);
    endtask

    // Helpers ------------------------------------------------------------------------
    task check_value(input [7:0] expected, input [7:0] actual, input string name);
        if (actual === expected) begin
            $display("  PASS: %s = 0x%02X", name, actual);
            test_pass++;
        end else begin
            $display("  FAIL: %s = 0x%02X (expected 0x%02X)", name, actual, expected);
            test_fail++;
        end 
    endtask

    // TEST SEQ ========================================================================
    initial begin
        $display("=====================================");
        $display("  I2C Slave Testbench");
        $display("=====================================");

        // init.
        rst_n       = 0;
        scl_master  = 1;
        sda_master  = 1'bz;
        sw_in       = 8'hA5;
        test_pass   = 0;
        test_fail   = 0;

        // reset
        #100;
        rst_n       = 1;
        #100;

        // TEST 1: Rd DEVICE_ID (expect 0xA7)
        $display("\n--- Test 1: Read DEVICE_ID ---");
        i2c_reg_read(8'h00, read_data);
        check_value(8'hA7, read_data, "DEVICE_ID");

        // TEST 2: Rd VERSION regs
        $display("\n--- Test 2: Read VERSION ---");
        i2c_reg_read(8'h01, read_data);
        check_value(8'h01, read_data, "VERSION_MAJ");
        i2c_reg_read(8'h02, read_data);
        check_value(8'h00, read_data, "VERSION_MIN");

        // TEST 3: wr/rd SCRATCH0
        $display("\n--- Test 3: SCRATCH0 Write/Read ---");
        i2c_reg_write(8'h05, 8'h55);
        i2c_reg_read(8'h05, read_data);
        check_value(8'h55, read_data, "SCRATCH0");
        
        i2c_reg_write(8'h05, 8'hAA);
        i2c_reg_read(8'h05, read_data);
        check_value(8'hAA, read_data, "SCRATCH0");

        // TEST 4: Wr/rd SCRATCH1
        $display("\n--- Test 4: SCRATCH1 Write/Read ---");
        i2c_reg_write(8'h06, 8'h12);
        i2c_reg_read(8'h06, read_data);
        check_value(8'h12, read_data, "SCRATCH1");

        // TEST 5: Rd LINK_CAPS
        $display("\n--- Test 5: Read LINK_CAPS ---");
        i2c_reg_read(8'h10, read_data);
        check_value(8'b10_01_0_1_0_1, read_data, "LINK_CAPS");

        // TEST 6: LED control
        $display("\n--- Test 6: LED Control ---");
        i2c_reg_write(8'h20, 8'hF0);
        #100;
        check_value(8'hF0, led_out, "LED_OUT hardware");
        i2c_reg_read(8'h20, read_data);
        check_value(8'hF0, read_data, "LED_OUT register");

        // TEST 7: Rd switches
        $display("\n--- Test 7: Read Switches ---");
        sw_in = 8'h3C;
        #100;
        i2c_reg_read(8'h22, read_data);
        check_value(8'h3C, read_data, "SW_IN");

        // TEST 8: Wrong addr (NACK test)
        $display("\n--- Test 8: Wrong Slave Address ---");
        begin
            logic ack;
            i2c_start();
            i2c_write_byte({7'h51, 1'b0}, ack);  // Wrong address
            if (!ack) begin
                $display("  PASS: No ACK for wrong address");
                test_pass++;
            end else begin
                $display("  FAIL: Got ACK for wrong address");
                test_fail++;
            end
            i2c_stop();
        end

        // Results ----------------------------------------------------
        $display("\n========================================");
        $display("  Test Results: %0d PASS, %0d FAIL", test_pass, test_fail);
        $display("========================================");
        
        if (test_fail == 0)
            $display("  ALL TESTS PASSED!");
        else
            $display("  SOME TESTS FAILED!");
        
        $display("\n");
        #1000;
        $finish;
    end

    // wave dump
    initial begin
        $dumpfile("tb_i2c_slave.vcd");
        $dumpvars(0, tb_i2c_slave);
    end

endmodule