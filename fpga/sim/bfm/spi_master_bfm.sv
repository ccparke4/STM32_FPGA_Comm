`timescale 1ns / 1ps
//==============================================================================
// SPI Master Bus Functional Model (BFM) - Verification IP
//==============================================================================
// Features:
//   - SPI Mode 1 (CPOL=0, CPHA=1): Data changes on Rising, Sampled on Falling.
//   - X-State Detection: Alerts if MISO is uninitialized (common sim bug).
//   - Robust Timing: Configurable divider with safety assertions.
//==============================================================================

module spi_master_bfm #(
    parameter int CLK_DIV = 10    // SPI clock = sys_clk / (2 * CLK_DIV)
)(
    input  logic        clk,
    input  logic        rst_n,
    
    // SPI Bus
    output logic        sclk,
    output logic        cs_n,
    output logic        mosi,
    input  logic        miso,
    
    // Control Interface
    input  logic        start,
    input  logic [7:0]  tx_data,
    output logic [7:0]  rx_data,
    output logic        done,
    output logic        busy
);

    //--------------------------------------------------------------------------
    // State Machine
    //--------------------------------------------------------------------------
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_CS_SETUP,
        ST_TRANSFER,
        ST_CS_HOLD,
        ST_DONE
    } state_t;
    
    state_t state;
    
    //--------------------------------------------------------------------------
    // Internal Registers
    //--------------------------------------------------------------------------
    logic [15:0] clk_cnt;
    logic [3:0]  bit_cnt;
    logic [7:0]  tx_shift;
    logic [7:0]  rx_shift;
    logic        sclk_r;
    logic        first_bit;
    
    assign busy = (state != ST_IDLE);
    assign sclk = sclk_r;
    
    //--------------------------------------------------------------------------
    // Timing Parameters
    //--------------------------------------------------------------------------
    localparam int T_CS_SETUP = CLK_DIV * 2;   // CS to first SCLK edge
    localparam int T_CS_HOLD  = CLK_DIV * 2;   // Last SCLK edge to CS release
    localparam int T_HALF_CLK = CLK_DIV;       // Half SCLK period
    
    // Safety check for parameter
    initial begin
        if (CLK_DIV < 4) 
            $warning("SPI BFM: CLK_DIV=%0d is very low. Ensure it exceeds Slave sync latency!", CLK_DIV);
    end

    //--------------------------------------------------------------------------
    // Main State Machine
    //--------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            clk_cnt   <= '0;
            bit_cnt   <= '0;
            tx_shift  <= '0;
            rx_shift  <= '0;
            sclk_r    <= 1'b0;  // Mode 1: Idle Low
            cs_n      <= 1'b1;
            mosi      <= 1'b0;
            rx_data   <= '0;
            done      <= 1'b0;
            first_bit <= 1'b1;
        end else begin
            done <= 1'b0;
            
            case (state)
                //--------------------------------------------------------------
                ST_IDLE: begin
                    sclk_r    <= 1'b0; 
                    cs_n      <= 1'b1;
                    first_bit <= 1'b1;
                    
                    if (start) begin
                        tx_shift <= tx_data;
                        rx_shift <= '0;
                        bit_cnt  <= '0;
                        clk_cnt  <= '0;
                        state    <= ST_CS_SETUP;
                    end
                end
                
                //--------------------------------------------------------------
                // Assert CS and set up first bit (CPHA=1: first bit valid before clock)
                ST_CS_SETUP: begin
                    cs_n <= 1'b0;
                    mosi <= tx_shift[7]; 
                    
                    clk_cnt <= clk_cnt + 1;
                    if (clk_cnt >= T_CS_SETUP) begin
                        clk_cnt   <= '0;
                        state     <= ST_TRANSFER;
                        first_bit <= 1'b1;
                    end
                end
                
                //--------------------------------------------------------------
                // Transfer 8 bits - Mode 1
                ST_TRANSFER: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_HALF_CLK) begin
                        // First half: SCLK low
                        sclk_r <= 1'b0;
                    end else if (clk_cnt == T_HALF_CLK) begin
                        // Rising edge: Shift out next bit (except for first bit)
                        sclk_r <= 1'b1;
                        if (!first_bit) begin
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            mosi     <= tx_shift[6];
                        end
                        first_bit <= 1'b0;
                    end else if (clk_cnt < T_HALF_CLK * 2) begin
                        // Second half: SCLK high
                        sclk_r <= 1'b1;
                    end else begin
                        // Falling edge: Sample MISO
                        sclk_r <= 1'b0;
                        
                        // DEBUG: Check for X-propagation
                        if (miso === 1'bx) begin
                            $display("[SPI BFM Error] Time %t: Sampled 'X' on MISO! Check Slave Reset/Initialization.", $time);
                        end

                        rx_shift <= {rx_shift[6:0], miso};
                        bit_cnt  <= bit_cnt + 1;
                        clk_cnt  <= '0;
                        
                        if (bit_cnt == 4'd7) begin
                            // Byte complete
                            rx_data <= {rx_shift[6:0], miso};
                            state   <= ST_CS_HOLD;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                ST_CS_HOLD: begin
                    sclk_r <= 1'b0;
                    
                    clk_cnt <= clk_cnt + 1;
                    if (clk_cnt >= T_CS_HOLD) begin
                        cs_n    <= 1'b1;
                        clk_cnt <= '0;
                        state   <= ST_DONE;
                    end
                end
                
                //--------------------------------------------------------------
                ST_DONE: begin
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule