interface i2c_if(input logic clk);
    // SCL Wiring
    logic scl_out;  // Driven by Master (Moxk)
    wire  scl;      // Actual wire
    assign scl = (scl_out) ? 1'bz : 1'b0;   // open drain simulation
    pullup(scl);

    // SDA Wiring
    logic sda_out;
    logic sda_oe;
    wire sda;
    assign sda = (sda_oe && ~sda_out) ? 1'b0 : 1'bz;
    pullup(sda);
endinterface

interface spi_if (input logic clk);
    logic sclk;
    logic cs;
    logic mosi;
    logic miso;
endinterface