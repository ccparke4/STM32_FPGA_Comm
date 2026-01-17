module top(
    input  logic        clk,        // 100 MHz system clock
    input  logic        rst_n,      // active low reset
    // I2C - control plane
    input  logic        i2c_scl,    // JB1 - i2c clock
    inout  wire         i2c_sda,    // JB2 - i2c data (bi-dir)
    // SPI - data plane
    input  logic        spi_cs,     // JA1 - Chip sel
    input  logic        spi_mosi,   // JA2 - Master Out Slave In
    input  logic        spi_miso,   // JA3 - Master In Slave Out
    output logic        spi_sclk,   // JA4 - SPI clk
    // UI - gpio, leds, ...
    
    output logic [7:0]  led,
    input  logic [7:0]  sw,             // 8 switches
    output logic [6:0]  seg,
    output logic [3:0]  an
    );
    
    // Reset Sync ---------------------------------------
    logic rst_n_sync;
    logic [1:0] rst_sync_reg;
    
    always_ff @(posedge clk) begin
        rst_sync_reg <= {rst_sync_reg[0], rst_n};
        rst_n_sync   <= rst_sync_reg[1];
    end
    
    // I2C TRI-STATE handling -----------------------------
    logic sda_out;
    logic sda_oe;
    assign i2c_sda = sda_oe ? sda_out : 1'bz;
    wire sda_in = i2c_sda;

    // RF signals ------------------------------------------
    logic [7:0] reg_addr;
    logic [7:0] reg_wdata;
    logic       reg_wr;
    logic [7:0] reg_rdata;
    logic       reg_rd;
    
    // Hardware interfaces from register file
    logic [7:0] led_from_regs;
    
    // I2C init --------------------------------------------
    i2c_slave #(
        .SLAVE_ADDR(7'h50)
    ) i2c_inst (
        .clk        (clk),
        .rst_n      (rst_n_sync),
        .scl_i      (i2c_scl),
        .sda_i      (sda_in),
        .sda_o      (sda_out),
        .sda_oe     (sda_oe),
        .reg_addr   (reg_addr),
        .reg_wdata  (reg_wdata),
        .reg_wr     (reg_wr),
        .reg_rdata  (reg_rdata),
        .reg_rd     (reg_rd)
    );
    
    // RF init. ------------------------------------------------------
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
    
    // SPI init. (existing data plane) ------------------------------------------
    spi_slave spi_inst (
        .clk            (clk),
        .sclk           (spi_sclk),
        .cs             (spi_cs),
        .mosi           (spi_mosi),
        .miso           (spi_miso),
        .data_received  (spi_rx_byte)
    );
    
    // SPI active when CS is low
    assign spi_active = ~spi_cs;
    
    // 7-seg init. ---------------------------------------------------------------------
    seven_seg disp_inst (
        .clk    (clk),
        .number ({8'h00, spi_rx_byte}),  // Show SPI data on display
        .seg    (seg),
        .an     (an)
    );
    
    // LED init ----------------------------------------------------------------------
    assign led = led_from_regs;
    
endmodule