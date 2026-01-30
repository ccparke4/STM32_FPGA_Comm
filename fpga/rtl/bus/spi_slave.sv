`timescale 1ns / 1ps

module spi_slave(
    input   logic       clk,            // 100MHz sys clk
    input   logic       rst_n,          // <--- ESSENTIAL: Reset Input
    input   logic       sclk,           // SPI clk
    input   logic       cs,             // Chip select
    input   logic       mosi,           // Master Out Slave In
    output  logic       miso,           // Master In Slave Out
    output  logic [7:0] data_received   // Data to display
    );
    
    // --- Synchronization ----
    logic [2:0] sclk_sync, cs_sync;
    logic [1:0] mosi_sync;
    
    // FIX 1: Reset the synchronizers
    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            cs_sync   <= 3'b111; // Default CS inactive (High)
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            cs_sync   <= {cs_sync[1:0], cs};
            mosi_sync <= {mosi_sync[0], mosi};
        end
    end
    
    // Edge detection
    wire sclk_rising     = (sclk_sync[2:1] == 2'b01);
    wire sclk_falling    = (sclk_sync[2:1] == 2'b10);
    wire cs_active       = ~cs_sync[2];                 
    wire cs_falling      = (cs_sync[2:1] == 2'b10);     
    
    // --- SPI Logic ---
    logic [7:0] shift_in;           
    logic [7:0] shift_out;          
    logic [7:0] last_byte;          
    logic [2:0] bit_cnt;
    
    // FIX 2: Reset the Shift Registers (The cause of your 'X' error)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_in      <= 8'h00;
            shift_out     <= 8'h00; // <--- THIS FIXES THE BUG
            last_byte     <= 8'h00;
            bit_cnt       <= 3'd0;
            data_received <= 8'h00;
        end else if (cs_falling) begin
            // CS just went active - Load the data to send
            shift_out <= last_byte;
            bit_cnt   <= 3'd0;
        end else if (!cs_active) begin
            // CS inactive - Reset bit counter
            bit_cnt  <= 3'd0;
        end else begin
            // --- SPI Mode 1 Implementation ---
            // CPHA=1: Data changes on Leading Edge (Rising), Sampled on Trailing (Falling)
            
            if (sclk_rising) begin
                // Don't shift on very first bit (CPHA=1 requirement)
                // The first bit (MSB) must be valid before the first clock edge
                if (bit_cnt != 3'd0) begin
                    shift_out <= {shift_out[6:0], 1'b0};
                end
            end
            
            // Sample MOSI on FALLING edge
            if (sclk_falling) begin
                shift_in <= {shift_in[6:0], mosi_sync[1]};
                bit_cnt  <= bit_cnt + 1;
                
                // Byte Complete
                if (bit_cnt == 3'd7) begin
                    last_byte     <= {shift_in[6:0], mosi_sync[1]};
                    data_received <= {shift_in[6:0], mosi_sync[1]};
                    // Burst mode: Load next byte immediately
                    shift_out     <= {shift_in[6:0], mosi_sync[1]};
                end
            end
        end
    end

    // MISO output - Drive MSB when Active, High-Z otherwise
    // Note: shift_out[7] will now be 0 instead of X on the first cycle
    assign miso = cs_active ? shift_out[7] : 1'bz;

endmodule