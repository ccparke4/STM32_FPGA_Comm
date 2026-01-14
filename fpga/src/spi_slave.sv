module spi_slave(
    input   logic       clk,            // 100MHz sys clk
    input   logic       sclk,           // SPI clk
    input   logic       cs,             // Chip select
    input   logic       mosi,           // Master Out Slave In
    output  logic       miso,           // Master In Slave Out
    output  logic [7:0] data_received   // Data to display
    );
    
    // --- Syncronization ----
    logic [2:0] sclk_sync, cs_sync;
    logic [1:0] mosi_sync;
    
    always_ff @(posedge clk) begin 
        sclk_sync <= {sclk_sync[1:0], sclk};
        cs_sync   <= {cs_sync[1:0], cs};
        mosi_sync <= {mosi_sync[0], mosi};
    end
    
    // Edge detection
    wire sclk_rising    = (sclk_sync[2:1] == 2'b01);
    wire sclk_falling   = (sclk_sync[2:1] == 2'b10);
    wire cs_active      = ~cs_sync[2];                  // fully sync'd signal
    wire cs_falling     = (cs_sync[2:1] == 2'b10);      // CS just went active
    
    // --- SPI Logic ---
    logic [7:0] shift_in;           // Rx shift reg
    logic [7:0] shift_out;          // Tx shift reg
    logic [7:0] last_byte;          // persist - 0x00 state issues last version       
    logic [2:0] bit_cnt;
    
    // Init. last_byte to 0 on powerup
    initial begin
        last_byte = 8'h00;
    end
    
    always_ff @(posedge clk) begin
        if (cs_falling) begin
            // CS just went active - ld prev. byte to Tx
            shift_out <= last_byte;
            bit_cnt   <= 3'd0;
        end else if (!cs_active) begin
            // CS inactive - just reset bit counter
            bit_cnt  <= 3'd0;
        end else begin
            // --- SPI Mode 1 Implementation ---
            // Logic: Shift MISO on Rising, Sample MOSI on Falling
            if (sclk_rising) begin
                // FIX - Don't shift on very first bit
                // CPHA, 1st bit must be valid before 1st clock
                // we load 'shift_out' at CS_falling (burst reload)
                // bit 7 already on wire. Shifting now loses MSB
                if (bit_cnt != 3'd0) begin
                    shift_out   <= {shift_out[6:0], 1'b0};
                end
            end
            
            // Sample MOSI on FALLING edge (stable data)
            if (sclk_falling) begin
                shift_in <= {shift_in[6:0], mosi_sync[1]};
                bit_cnt  <= bit_cnt + 1;
                
                // byte cplt?
                if (bit_cnt == 3'd7) begin
                    // save Rx 
                    last_byte     <= {shift_in[6:0], mosi_sync[1]};
                    data_received <= {shift_in[6:0], mosi_sync[1]};
                    
                    // FIX - burst mode issue, reload immediately w/ new byte?
                    // ensures new MSB is ready on the wire
                    // Next rising edge of next byte
                    shift_out     <= {shift_in[6:0], mosi_sync[1]};
                end
            end
        end
    end

    // MISO output - directly from shift reg. MSB
    // drive when CS active, high-Z when inactive
    assign miso = cs_active ? shift_out[7] : 1'bz;
endmodule