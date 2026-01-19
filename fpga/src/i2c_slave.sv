`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/15/2026 05:36:14 PM
// Design Name: 
// Module Name: i2c_slave
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 1.1 - Issue with shift_reg on write
// Additional Comments:

// 
//////////////////////////////////////////////////////////////////////////////////

// 'dynamic' module, def'ing params before ports
module i2c_slave #(
    parameter   logic [6:0]     SLAVE_ADDR = 7'h50  // 7'b addr
    )(
        input   logic           clk,        // 100MHz sys clock
        input   logic           rst_n,      // Active low reset
        
        // i2c interface
        input   logic           scl_i,      // SCL in
        input   logic           sda_i,      // SDA in
        output  logic           sda_o,      // SDA out
        output  logic           sda_oe,     // SDA out enable
        // Register file intrface
        output  logic [7:0]     reg_addr,   // reg addr
        output  logic [7:0]     reg_wdata,  // wrtie data
        output  logic           reg_wr,     // write strobe
        input   logic [7:0]     reg_rdata,  // read data
        output  logic           reg_rd      // read strobe
    );
    
    // CDC SYNC ==================================================
    // 2-stage
    logic [1:0] scl_sync, sda_sync;
    logic       scl_d, sda_d;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 2'b11;
            sda_sync <= 2'b11;
            scl_d    <= 1'b1;
            sda_d    <= 1'b1;
        end else begin
            scl_sync <= {scl_sync[0], scl_i};
            sda_sync <= {sda_sync[0], sda_i};
            scl_d    <= scl_sync[1];
            sda_d    <= sda_sync[1];
        end
    end
    
    // sync'd signals
    wire scl = scl_sync[1];
    wire sda = sda_sync[1];
    
    // Edge detection
    wire scl_rising  = scl && !scl_d;
    wire scl_falling = !scl && scl_d;
    
    // Internal sda_oe for gating (directly from state)
    logic sda_driving;
    
    // START/STOP detection - GATED by sda_driving to prevent false triggers
    wire start_detect = !sda && sda_d && scl && !sda_driving;
    wire stop_detect  = sda && !sda_d && scl && !sda_driving;
    
    // IDC State Machine =============================================
    
    typedef enum logic [3:0] {
        IDLE,
        GET_ADDR,               // Rx 7'b addr + R/W
        ACK_ADDR,               // send ACK for addr
        GET_REG,                // Rx reg addr
        ACK_REG,                // send ACK for reg addr
        WRITE_DATA,             // rx data byte
        ACK_WRITE,              // send ACK for write data
        READ_DATA,              // TRansmit data byte
        WAIT_ACK                // wait for master ACK/NACK on read
    } state_t;
    
    state_t state, next_state;
    
    // Internal regs ==================================================
    logic [7:0] shift_reg;      // Shift reg for Rx/Tx
    logic [2:0] bit_cnt;        // bit counter 0-7
    logic       rw_bit;         // 0=W, 1=R
    logic       addr_match;     // Address matched flag
    logic [7:0] reg_addr_r;     // Internal reg addr
    logic [7:0] tx_data;        // Seperate Tx regs for reads
    
    // Flag to track if we see the ACK on clks RISING edge, only exit ACK states after rise & fall
    logic       ack_scl_rose;
    
    // Write strobe - delay reg write by a cycle
    logic       reg_wr_pending;
    
    // SDA output control ============================================
    always_comb begin
        sda_o       = 1'b1;
        sda_oe      = 1'b0;
        sda_driving = 1'b0;
        
        case (state)
            ACK_ADDR, ACK_REG, ACK_WRITE: begin
                sda_o       = 1'b0;     // ACK = drive low
                sda_oe      = 1'b1;
                sda_driving = 1'b1;
            end
            
            READ_DATA: begin
                sda_o       = tx_data[7];  // MSB first
                sda_oe      = 1'b1;
                sda_driving = 1'b1;
            end
            
            default: begin
                sda_o       = 1'b1;
                sda_oe      = 1'b0;
                sda_driving = 1'b0;
            end
        endcase
    end
    
    // FSM - Next state logic =================================================
    always_comb begin
        next_state = state;
        
        if (start_detect) begin
            next_state = GET_ADDR;
        end
        else if (stop_detect) begin
            next_state = IDLE;
        end
        else begin
            case (state)
                IDLE: begin
                    // Wait for START
                end
                
                GET_ADDR: begin
                    if (scl_rising && bit_cnt == 3'd7) begin
                        if (shift_reg[6:0] == SLAVE_ADDR) begin
                            next_state = ACK_ADDR;
                        end else begin
                            next_state = IDLE;
                        end
                    end
                end
                
                ACK_ADDR: begin
                // FIX:  only exit after we see ACK clk rise  fal
                    if (scl_falling && ack_scl_rose) begin
                        if (rw_bit) begin
                            next_state = READ_DATA;
                        end else begin
                            next_state = GET_REG;
                        end
                    end
                end
                
                GET_REG: begin
                    if (scl_rising && bit_cnt == 3'd7) begin
                        next_state = ACK_REG;
                    end
                end
                
                ACK_REG: begin
                // FIX: Wait for full ACK clk cycke
                    if (scl_falling && ack_scl_rose) begin
                        next_state = WRITE_DATA;
                    end
                end
                
                WRITE_DATA: begin
                    if (scl_rising && bit_cnt == 3'd7) begin
                        next_state = ACK_WRITE;
                    end
                end
                
                ACK_WRITE: begin
                // FIX: Wait for Full ACK
                    if (scl_falling && ack_scl_rose) begin
                        next_state = WRITE_DATA;
                    end
                end
                
                READ_DATA: begin
                    if (scl_falling && bit_cnt == 3'd7) begin
                        next_state = WAIT_ACK;
                    end
                end
                
                WAIT_ACK: begin
                    if (scl_rising) begin
                        if (sda) begin
                            next_state = IDLE;      // NACK
                        end else begin
                            next_state = READ_DATA; // ACK - continue
                        end
                    end
                end
                
                default: next_state = IDLE;
            endcase
        end
    end
    
    // FSM - seq. logic =================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            shift_reg       <= 8'h00;
            bit_cnt         <= 3'd0;
            rw_bit          <= 1'b0;
            reg_addr_r      <= 8'h00;
            addr_match      <= 1'b0;
            tx_data         <= 8'h00;
            ack_scl_rose    <= 1'b0;   
            reg_wr_pending  <= 1'b0;    
        end
        else begin
            state <= next_state;
            
            // Clear write pending after one cycle
            reg_wr_pending  <= 1'b0;
            
            if (start_detect) begin
                bit_cnt         <= 3'd0;
                shift_reg       <= 8'h00;
                addr_match      <= 1'b0;
                ack_scl_rose    <= 1'b0; 
            end
            else if (stop_detect) begin
                addr_match      <= 1'b0;
                ack_scl_rose    <= 1'b0;
            end
            else begin
                case (state)
                    IDLE: begin
                        bit_cnt         <= 3'd0;
                        ack_scl_rose    <= 1'b0;
                    end
                    
                    GET_ADDR: begin
                        ack_scl_rose    <= 1'b0;    // Ready for upcoming ACK
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1'b1;
                            
                            if (bit_cnt == 3'd7) begin
                                rw_bit <= sda;
                                if (shift_reg[6:0] == SLAVE_ADDR) begin
                                    addr_match <= 1'b1;
                                end
                            end
                        end
                    end
                    
                    ACK_ADDR: begin
                        // Track the ACK clock (9th clock) rising edge
                        if (scl_rising) begin
                            ack_scl_rose    <= 1'b1;
                            $display("[%0t] ACK_ADDR: Saw 9th clock (ACK) rising edge", $time);
                        end
                        if (scl_falling && ack_scl_rose) begin
                            bit_cnt         <= 3'd0;
                            ack_scl_rose    <= 1'b0;
                            // Pre-load tx_data for reads BEFORE entering READ_DATA
                            if (rw_bit) begin
                                tx_data <= reg_rdata;
                                $display("[%0t] ACK_ADDR: Loading tx_data=0x%02X for read", $time, reg_rdata);
                            end
                        end
                    end
                    
                    GET_REG: begin
                    ack_scl_rose    <= 1'b0;    // Reset for upcoming ACK
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1'b1;
                            
                            if (bit_cnt == 3'd7) begin
                                reg_addr_r <= {shift_reg[6:0], sda};
                                $display("[%0t] GET_REG: Captured reg_addr=0x%02X", $time, {shift_reg[6:0], sda});
                            end
                        end
                    end
                    
                    ACK_REG: begin
                        if (scl_rising) begin
                            ack_scl_rose    <= 1'b1;
                            $display("[%0t] ACK_REG: Saw ACK clock rising edge", $time);
                        end
                        if (scl_falling && ack_scl_rose) begin
                            bit_cnt         <= 3'd0;
                            ack_scl_rose    <= 1'b0;
                        end
                    end
                    
                    WRITE_DATA: begin
                         ack_scl_rose    <= 1'b0;       // reset for coming ACK
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1'b1;
                            $display("[%0t] WRITE_DATA: bit[%0d]=%b, shift_reg=0x%02X", 
                                     $time, 7-bit_cnt, sda, {shift_reg[6:0], sda});
                        end
                    end
                    
                    ACK_WRITE: begin
                        if (scl_rising) begin
                            ack_scl_rose    <= 1'b1;
                            reg_wr_pending  <= 1'b1;        // FIX: isse wr strobe, one cycle AFTER shift_reg updated. now shift_reg should be stable
                            $display("[%0t] ACK_WRITE: Issuing write strobe, shift_reg=0x%02X to reg_addr=0x%02X", 
                                     $time, shift_reg, reg_addr_r);
                        end
                        if (scl_falling && ack_scl_rose) begin
                            bit_cnt         <= 3'd0;
                            reg_addr_r      <= reg_addr_r + 1'b1;
                            ack_scl_rose    <= 1'b0;
                            $display("[%0t] ACK_WRITE: Write complete, reg_addr incremented to 0x%02X", 
                                     $time, reg_addr_r + 1'b1);
                        end
                    end
                    
                    READ_DATA: begin
                        if (scl_falling) begin
                            tx_data <= {tx_data[6:0], 1'b0};
                            bit_cnt <= bit_cnt + 1'b1;
                            $display("[%0t] READ_DATA: Shifted out bit, tx_data now=0x%02X, bit_cnt=%0d", 
                                     $time, {tx_data[6:0], 1'b0}, bit_cnt+1);
                        end
                    end
                    
                    WAIT_ACK: begin
                        if (scl_rising) begin
                            if (!sda) begin
                                reg_addr_r <= reg_addr_r + 1'b1;        // ACK = continue
                                $display("[%0t] WAIT_ACK: Master ACK, incrementing reg_addr", $time);
                            end else begin
                                $display("[%0t] WAIT_ACK: Master NACK, ending read", $time);        
                            end                    
                        end
                        if (scl_falling) begin
                            bit_cnt <= 3'd0;
                            tx_data <= reg_rdata;
                        end
                    end
                    
                    default: ;
                endcase
            end
        end
    end
    
    // Reg File interface =============================================
    assign reg_addr  = reg_addr_r;
    assign reg_wdata = shift_reg;
    
    // Write strobe - delayed by 1 cycle
    
    //assign reg_wr = (state == WRITE_DATA) && (next_state == ACK_WRITE);
    assign reg_wr = reg_wr_pending;
    //assign reg_rd = (state == ACK_ADDR && rw_bit && scl_falling) ||
                    //(state == WAIT_ACK && !sda && scl_rising);
    assign reg_rd = (state == ACK_ADDR && rw_bit && scl_falling && ack_scl_rose) ||
                    (state == WAIT_ACK && !sda && scl_rising);                

// DEBUG ==========================================================================
    always @(state) begin
        $display("[%0t] === STATE: %s (bit_cnt=%0d, ack_scl_rose=%b, reg_addr=0x%02X, tx_data=0x%02X) ===", 
                 $time, state.name, bit_cnt, ack_scl_rose, reg_addr_r, tx_data);
    end
    
    // Monitor SDA outputs during ACK states
    always @(posedge clk) begin
        if (state == ACK_ADDR || state == ACK_REG || state == ACK_WRITE) begin
            if (scl_rising || scl_falling) begin
                $display("[%0t] ACK_OUTPUT: state=%s scl_edge=%s sda_o=%b sda_oe=%b ack_scl_rose=%b", 
                         $time, state.name, scl_rising ? "RISE" : "FALL", sda_o, sda_oe, ack_scl_rose);
            end
        end
    end
endmodule