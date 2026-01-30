`timescale 1ns / 1ps

module i2c_debounce #(
        parameter CLK_FREQ_MHZ  = 100,
        parameter DEBOUNCE_US   = 0.1   // 100ns filter
    )(
        input   logic clk,
        input   logic rst_n,
        input   logic in_raw,
        output  logic out_filtered
    
    );
    
    localparam CNT_MAX = int'(CLK_FREQ_MHZ * DEBOUNCE_US);
    logic [$clog2(CNT_MAX):0] cnt;          // counter sizing "ceiling log base 2" determining min # of bits req to represent CNT_MAX
    logic sync_0, sync_1;
    
    // 1. Sync
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin 
            sync_0 <= 1;
            sync_1 <= 1;
        end else begin
            sync_0 <= in_raw;
            sync_1 <= sync_0;
        end
    end
    
    // 2. filter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt          <= 0;
            out_filtered <= 1;
        end else begin
            if (sync_1 != out_filtered) begin
                cnt <= cnt + 1;
                if (cnt >= CNT_MAX) begin
                    out_filtered <= sync_1;
                    cnt <= 0;
                end
            end else cnt <= 0;
        end
        
        
    end
endmodule