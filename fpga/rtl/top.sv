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
    output logic       miso
);

    // --- I2C Internal Signals ---
    logic sda_i;
    logic sda_o;
    logic sda_oe;

    // --- I2C IO BUFFER (The "Physical" Connection) ---
    // 1. We read from the pin into 'sda_i'
    assign sda_i = sda; 
    
    // 2. If Output Enable (oe) is high, we drive sda_o (usually Low). 
    //    If oe is low, we let the resistor pull it High (Z).
    //    (Standard Open-Drain Logic)
    assign sda = (sda_oe) ? 1'b0 : 1'bz; 

    // --- Internal Register File (Glue Logic) ---
    logic [7:0] reg_addr;
    logic [7:0] reg_wdata;
    logic       reg_wr;
    logic [7:0] reg_rdata;
    logic       reg_rd;
    
    // Simple RAM to store data so we can read it back
    logic [7:0] memory [0:255];

    always_ff @(posedge clk) begin
        if (reg_wr) begin
            memory[reg_addr] <= reg_wdata;
        end
        // Always present data for reading
        reg_rdata <= memory[reg_addr];
    end

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

endmodule