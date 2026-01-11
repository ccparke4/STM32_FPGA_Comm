`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/10/2026 05:57:43 AM
// Design Name: 
// Module Name: led_blink
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
`timescale 1ns / 1ps       // Tell simulatator 1 time unit = 1 ns, precision = 1 ps

module led_blink(
    input logic clk,            // 100 MHz clock from Basys 3 oscillator
    output logic [15:0] led     // 16 LEDs on the board
 );
 
    // 27'b counter
    logic [26:0] counter;
    
    // On every rising edge of clk, increment counter
    always_ff @(posedge clk) begin
        counter <= counter + 1;
    end
    
    // connect counter bits to LEDs
    assign led[0]       = counter[26];      // slower bit -> LED0 blinks (~0.7s)
    assign led [15:1]   = counter[26:12];   // faster bits -> scrolling pattern
endmodule
