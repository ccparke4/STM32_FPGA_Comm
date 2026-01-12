module top(
    input  logic        clk,
    input  logic        JA1, //CS
    input  logic        JA2, // MOSI
    input  logic        JA4, // SCLK
    output logic        JA3, // MISO
    output logic [6:0]  seg,
    output logic [3:0]  an
    );
    
    logic [7:0] rx_byte;
    
    // Instantiate SPI Slave
    spi_slave spi_inst (
        .clk            (clk),
        .sclk           (JA4),
        .cs             (JA1),
        .mosi           (JA2),
        .miso           (JA3),
        .data_received  (rx_byte)
    );
    
    // Instantiate display
    // Pad top 8 bits with 0, and show the received byte in the lower 2 digits
    seven_seg disp_inst (
        .clk    (clk),
        .number ({8'h00, rx_byte}),
        .seg    (seg),
        .an    (an)
    );
    
    
endmodule