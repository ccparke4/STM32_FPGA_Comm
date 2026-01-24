`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/20/2026 03:32:01 PM
// Design Name: 
// Module Name: top_ila
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


module top(
    input  logic        clk,
    input  logic        rst_n,
    // I2C
    input  logic        i2c_scl,
    inout  wire         i2c_sda,
    // SPI
    input  logic        spi_cs,
    input  logic        spi_mosi,
    output logic        spi_miso,
    input  logic        spi_sclk,
    // UI
    output logic [7:0]  led,
    input  logic [7:0]  sw,
    output logic [6:0]  seg,
    output logic [3:0]  an
);
    
    // =========================================================================
    // RESET SYNCHRONIZER
    // =========================================================================
    logic rst_n_sync;
    logic [2:0] rst_sync_reg;
    
    always_ff @(posedge clk) begin
        rst_sync_reg <= {rst_sync_reg[1:0], rst_n};
        rst_n_sync   <= rst_sync_reg[2];
    end
    
    // =========================================================================
    // I2C ACTIVE-LOW DIRECTLY DIRECTLY FOR DEBUGGING
    // =========================================================================
    (* mark_debug = "true" *) wire i2c_scl_raw = i2c_scl;
    (* mark_debug = "true" *) wire i2c_sda_raw;
    
    // I2C tristate
    (* mark_debug = "true" *) logic sda_out;
    (* mark_debug = "true" *) logic sda_oe;
    
    assign i2c_sda = sda_oe ? sda_out : 1'bz;
    assign i2c_sda_raw = i2c_sda;

    // =========================================================================
    // REGISTER FILE SIGNALS
    // =========================================================================
    logic [7:0] reg_addr;
    logic [7:0] reg_wdata;
    logic       reg_wr;
    logic [7:0] reg_rdata;
    logic       reg_rd;
    logic [7:0] led_from_regs;
    
    // =========================================================================
    // I2C SLAVE INSTANCE
    // =========================================================================
    i2c_slave #(
        .SLAVE_ADDR(7'h50)
    ) i2c_inst (
        .clk        (clk),
        .rst_n      (rst_n_sync),
        .scl_i      (i2c_scl),
        .sda_i      (i2c_sda),
        .sda_o      (sda_out),
        .sda_oe     (sda_oe),
        .reg_addr   (reg_addr),
        .reg_wdata  (reg_wdata),
        .reg_wr     (reg_wr),
        .reg_rdata  (reg_rdata),
        .reg_rd     (reg_rd)
    );
    
    // =========================================================================
    // REGISTER FILE
    // =========================================================================
    logic       spi_active;
    logic [7:0] spi_rx_byte;
    
    register_file reg_file_inst (
        .clk         (clk),
        .rst_n       (rst_n_sync),
        .reg_addr    (reg_addr),
        .reg_wdata   (reg_wdata),
        .reg_wr      (reg_wr),
        .reg_rdata   (reg_rdata),
        .reg_rd      (reg_rd),
        .led_out     (led_from_regs),
        .sw_in       (sw),
        .spi_active  (spi_active),
        .spi_rx_byte (spi_rx_byte)
    );
    
    // =========================================================================
    // SPI SLAVE
    // =========================================================================
    spi_slave spi_inst (
        .clk            (clk),
        .sclk           (spi_sclk),
        .cs             (spi_cs),
        .mosi           (spi_mosi),
        .miso           (spi_miso),
        .data_received  (spi_rx_byte)
    );
    
    assign spi_active = ~spi_cs;
    
    // =========================================================================
    // 7-SEGMENT DISPLAY
    // =========================================================================
    seven_seg disp_inst (
        .clk    (clk),
        .number ({8'h00, spi_rx_byte}),
        .seg    (seg),
        .an     (an)
    );
    
    // =========================================================================
    // LED OUTPUT
    // =========================================================================
    assign led = led_from_regs;
    
endmodule