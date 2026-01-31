`timescale 1ns / 1ps
// FSM for IEEE 1149.1 for IDCODE extraction
module jtag_master (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start_scan,
    output logic        tck, tms, tdi,
    input  logic        tdo,
    output logic [31:0] idcode,
    output logic        valid 
);



endmodule