`timescale 1ns / 1ps

module top(
    input  logic        clk,        
    input  logic        rst_n,      // Physical Button (Active High on Basys 3)
    
    // I2C - control plane
    input  logic        i2c_scl,    
    inout  wire         i2c_sda,    
    
    // SPI - data plane
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
    // OPTIMAL RESET SYNC & POLARITY FIX
    // =========================================================================
    // ILA: Debug the raw button and the synced result to verify Reset timing
    (* mark_debug = "true" *) logic rst_n_raw_debug; 
    (* mark_debug = "true" *) logic rst_n_sync;
    
    logic [1:0] rst_sync_reg;
    
    // 1. Invert the button: Basys3 buttons are 1 when pressed.
    //    We want: Button (1) -> Internal Reset (0).
    wire rst_n_inverted = ~rst_n; 

    // Assign raw input to debug wire just for ILA visualization
    assign rst_n_raw_debug = rst_n;

    always_ff @(posedge clk) begin
        // 2. Synchronize the INVERTED signal
        rst_sync_reg <= {rst_sync_reg[0], rst_n_inverted};
        rst_n_sync   <= rst_sync_reg[1];
    end
    
    // =========================================================================
    // I2C PHYSICAL LAYER (IOBUF) 
    // =========================================================================
    (* mark_debug = "true" *) logic sda_in;  
    logic sda_out; 
    (* mark_debug = "true" *) logic sda_oe;  
    
    IOBUF i2c_iobuf (
        .O (sda_in),       
        .IO(i2c_sda),      
        .I (1'b0),         // Always drive 0 (I2C is open drain)
        .T (~sda_oe)       // T=0 drives, T=1 floats
    );

    // RF signals 
    logic [7:0] reg_addr;
    logic [7:0] reg_wdata;
    logic       reg_wr;
    logic [7:0] reg_rdata;
    logic       reg_rd;
    
    // Hardware interfaces
    logic [7:0] led_from_regs;
    
    // I2C init 
    i2c_slave #(
        .SLAVE_ADDR(7'h50)
    ) i2c_inst (
        .clk        (clk),
        .rst_n      (rst_n_sync), // Clean, Synchronized, Active Low
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
    
    // RF init. 
    logic       spi_active;
    logic [7:0] spi_rx_byte;
    
    // WARNING: Ensure register_file treats spi_rx_byte as an INPUT
    // If it tries to drive it, you will have a multi-driver conflict with spi_slave.
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
    
    // SPI init.
    spi_slave spi_inst (
        .clk            (clk),
        .sclk           (spi_sclk),
        .cs             (spi_cs),
        .mosi           (spi_mosi),
        .miso           (spi_miso),
        .data_received  (spi_rx_byte)
    );
    
    assign spi_active = ~spi_cs;
    
    // 7-seg init. 
    seven_seg disp_inst (
        .clk    (clk),
        .number ({8'h00, spi_rx_byte}),  
        .seg    (seg),
        .an     (an)
    );
    
    assign led = led_from_regs;
    
endmodule