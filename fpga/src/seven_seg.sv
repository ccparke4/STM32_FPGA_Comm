module seven_seg(
    input   logic        clk,
    input   logic [15:0] number,   // value to display (hex)
    output  logic [6:0]  seg,      // segment cathodes
    output  logic [3:0]  an       // anodes
    );
    
    // Refresh counter for multiplexing
    logic [19:0] refresh_counter;
    always_ff @(posedge clk) begin
        refresh_counter <= refresh_counter + 1;
    end
    
    // use top 2'b to select active digit
    logic [1:0] LED_activating_counter;
    assign LED_activating_counter = refresh_counter[19:18];
    
    logic [3:0] LED_BCD;
    
    // Anode Activation (Active Low)
    always_comb begin
        case(LED_activating_counter)
            2'b00: begin an = 4'b1110; LED_BCD = number[3:0];   end    // digit 0 (Right)
            2'b01: begin an = 4'b1101; LED_BCD = number[7:4];   end    // Digit 1
            2'b10: begin an = 4'b1011; LED_BCD = number[11:8];  end    // Digit 2
            2'b11: begin an = 4'b0111; LED_BCD = number[15:12]; end    // Digit 3 (Left)
            default: begin an = 4'b1111; LED_BCD = 4'b0000; end
        endcase
    end
    
    // Cathode decoding (active low)
    always_comb begin
        case(LED_BCD)
            4'h0: seg = 7'b1000000; // 0
            4'h1: seg = 7'b1111001; // 1
            4'h2: seg = 7'b0100100; // 2
            4'h3: seg = 7'b0110000; // 3
            4'h4: seg = 7'b0011001; // 4
            4'h5: seg = 7'b0010010; // 5
            4'h6: seg = 7'b0000010; // 6
            4'h7: seg = 7'b1111000; // 7
            4'h8: seg = 7'b0000000; // 8
            4'h9: seg = 7'b0010000; // 9
            4'hA: seg = 7'b0001000; // A
            4'hB: seg = 7'b0000011; // b
            4'hC: seg = 7'b1000110; // C
            4'hD: seg = 7'b0100001; // d
            4'hE: seg = 7'b0000110; // E
            4'hF: seg = 7'b0001110; // F
            default: seg = 7'b1111111; // Off
        endcase
    end
endmodule
