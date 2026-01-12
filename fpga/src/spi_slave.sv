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
    logic       mosi_sync;
    
    always_ff @(posedge clk) begin 
        sclk_sync <= {sclk_sync[1:0], sclk};
        cs_sync   <= {cs_sync[1:0], cs};
        mosi_sync <= mosi;
    end
    
    // Edge detection
    logic sclk_rising, sclk_falling, cs_active;
    assign sclk_rising  = (sclk_sync[2:1] == 2'b01);
    assign sclk_falling = (sclk_sync[2:1] == 2'b10);
    assign cs_active    = ~cs_sync[1]; // active low
    
    // --- SPI Logic ---
    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;
    logic [7:0] byte_to_send;
    logic [1:0] byte_index;
    
    always_ff @(posedge clk) begin
        if (!cs_active) begin
            bit_cnt     <= '0;
            byte_index  <= '0;
            miso        <= 1'b0;
        end else begin
            // 1. Sample MOSI (Input) on Rising Edge
            if (sclk_rising) begin
                shift_reg <= {shift_reg[6:0], mosi_sync};
                bit_cnt   <= bit_cnt + 1;
                
                // Byte Complete?
                if (bit_cnt == 7) begin
                    // If its the first byte, save to the display register
                    if (byte_index == 0) data_received <= {shift_reg[6:0], mosi_sync};
                    byte_index <= byte_index + 1;
                end
            end
            
            // 2. Drivre MISO (Output) on falling edge
            if (sclk_falling) begin
                // Det. response packet structure
                // 0'B -> Echo captured value
                // 1'B -> 'H' 2'B -> 'i'
                case (byte_index)
                    1: byte_to_send <= data_received;   // echo loopback
                    2: byte_to_send <= 8'h48;           // ASCII 'H', 8 bits
                    3: byte_to_send <= 8'h69;           // ASCII 'i', 8 bits
                    default: byte_to_send <= 8'h00;
                endcase
                
                // shift out the bit
                if (bit_cnt == 0) miso <= byte_to_send[7];
                else              miso <= byte_to_send[7 - bit_cnt];
            end
        end
    end
endmodule