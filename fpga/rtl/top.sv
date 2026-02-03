`timescale 1ns / 1ps

module top (
    input  logic       clk,      // System Clock
    input  logic       rst_n,    // Active Low Reset
    
    // --- Physical I2C Pins ---
    input  logic       scl,      // SCL is Input only for Slave (unless clock stretching)
    inout  wire        sda,      // SDA is Bidirectional (In/Out)
    
    // --- Physical SPI Pins ---
    input  logic       sclk,
    input  logic       cs,
    input  logic       mosi,
    output logic       miso,

    // --- IO ---
    input  logic [7:0] sw,      // Switches
    output logic [7:0] led,     // LEDs
    output logic [6:0] seg,     // 7-seg segments
    output logic [3:0] an       // 7-seg anodes
);

    // --- Internal Signals ---
    logic [7:0] reg_addr;
    logic [7:0] reg_wdata;
    logic       reg_wr;
    logic [7:0] reg_rdata;
    logic       reg_rd;

    // SPI data exhange 
    logic [7:0] spi_rx_data;
    logic       spi_active;

    // I2C IO Buffer Logic
    logic sda_i, sda_o, sda_oe;

    assign sda_i = i2c_sda;
    assign i2c_sda = (sda_oe) ? 1'b0 : 1'bz;

    // Activ status for register file
    assign spi_active = !cs;

    // --- Instantiate I2C Slave ---
    i2c_slave #(
        .SLAVE_ADDR(7'h55)
    ) i2c_inst (
        .clk(clk),
        .rst_n(rst_n),
        .scl_i(scl),         // Connect to Pin
        .sda_i(sda_i),       // Connect to Input Wire
        .sda_o(sda_o),       // Connect to Output Wire
        .sda_oe(sda_oe),     // Connect to Output Enable
        
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_wr(reg_wr),
        .reg_rdata(reg_rdata),
        .reg_rd(reg_rd)
    );

    // --- Instantiate SPI Slave ---
    spi_slave spi_inst (
        .clk(clk),
        .sclk(sclk),
        .cs(cs),
        .mosi(mosi),
        .miso(miso),
        .data_received()     // Connect this to memory if you want Loopback later
    );

    // --- Instantiate Register file ---
    register_file reg_file_inst (
        .clk(clk),
        .rst_n(rst_n), 
        // I2C interface
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_wr(reg_wr),
        .reg_rdata(reg_rdata),
        .reg_rd(reg_rd),
        // HW IO
        .led_out(led),
        .sw_in(sw),
        // SPI status
        .spi_active(spi_active),
        .spi_rx_byte(spi_rx_data)
    );

    // --- Instatiate 7-segment display ---
    seven_seg display_inst (
        .clk(clk),
        .number({8'b00, spi_rx_data}),  // 00 + spi data
        .seg(seg),
        .an(an)
    );

endmodule