`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/15/2026 05:36:14 PM
// Design Name: 
// Module Name: i2c_slave
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

// 'dynamic' module, def'ing params before ports
module i2c_slave #(
    parameter   logic [6:0]     SLAVE_ADDR = 7'h0;  // 7'b addr
    )(
        input   logic           clk,        // 100MHz sys clock
        input   logic           rst_n,      // Active low reset
        
        // i2c interface
        input   logic           scl_i,      // SCL in
        input   logic           sda_i,      // SDA in
        output  logic           sda_o,      // SDA out
        output  logic           sda_oe,     // SDA out enable
        // Register file intrface
        output  logic [7:0]     reg_addr,   // reg addr
        output  logic [7:0]     reg_wdata,  // wrtie data
        output  logic           reg_wr,     // write strobe
        input   logic [7:0]     reg_rdata,  // read data
        output  logic           reg_rd      // read strobe
    );
    
    // CDC SYNC ==================================================
    logic [2:0]     scl_sync;
    logic [2:0]     sda_sync;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync    <= 3'b111;
            sda_sync    <= 3'b111;
        end else begin
            scl_sync    <= {scl_sync[1:0], scl_i};
            sda_sync    <= {sda_sync[1:0], sda_i};
        end
    end
    
    // sync'd signals
    wire scl = scl_sync[2];
    wire sda = sda_sync[2];
    
    // Edge detection
    wire scl_rising  = (scl_sync[2:1] == 2'b01);
    wire scl_falling = (scl_sync[2:1] == 2'b10);
    
    // START: SDA falls while SCL is high
    wire start_detect = (sda_sync[2:1] == 2'b10) && scl;
    
    // STOP: SDA rises while SCL is high
    wire stop_detect = (sda_sync[2:1] == 2'b01) && scl;
    
    
    
endmodule
