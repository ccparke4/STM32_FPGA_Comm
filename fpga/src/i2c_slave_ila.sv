`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/20/2026 03:29:32 PM
// Design Name: 
// Module Name: i2c_slave_ila
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module i2c_slave #(
    parameter logic [6:0] SLAVE_ADDR = 7'h50
)(
    input   logic           clk,
    input   logic           rst_n,
    
    // I2C interface
    input   logic           scl_i,
    input   logic           sda_i,
    output  logic           sda_o,
    output  logic           sda_oe,
    
    // Register file interface
    output  logic [7:0]     reg_addr,
    output  logic [7:0]     reg_wdata,
    output  logic           reg_wr,
    input   logic [7:0]     reg_rdata,
    output  logic           reg_rd
);
    
    // =========================================================================
    // CDC SYNCHRONIZERS - Mark for debug
    // =========================================================================
    (* mark_debug = "true" *) logic [2:0] scl_sync;
    (* mark_debug = "true" *) logic [2:0] sda_sync;
    (* mark_debug = "true" *) logic scl_d, sda_d;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 3'b111;
            sda_sync <= 3'b111;
            scl_d    <= 1'b1;
            sda_d    <= 1'b1;
        end else begin
            scl_sync <= {scl_sync[1:0], scl_i};
            sda_sync <= {sda_sync[1:0], sda_i};
            scl_d    <= scl_sync[2];
            sda_d    <= sda_sync[2];
        end
    end
    
    // Synchronized signals
    (* mark_debug = "true" *) wire scl = scl_sync[2];
    (* mark_debug = "true" *) wire sda = sda_sync[2];
    
    // Edge detection
    (* mark_debug = "true" *) wire scl_rising  = scl && !scl_d;
    (* mark_debug = "true" *) wire scl_falling = !scl && scl_d;
    
    // SDA driving flag for gating START/STOP
    (* mark_debug = "true" *) logic sda_driving;
    
    // START/STOP detection
    (* mark_debug = "true" *) wire start_detect = !sda && sda_d && scl && !sda_driving;
    (* mark_debug = "true" *) wire stop_detect  = sda && !sda_d && scl && !sda_driving;
    
    // =========================================================================
    // STATE MACHINE
    // =========================================================================
    typedef enum logic [3:0] {
        IDLE        = 4'd0,
        GET_ADDR    = 4'd1,
        ACK_ADDR    = 4'd2,
        GET_REG     = 4'd3,
        ACK_REG     = 4'd4,
        WRITE_DATA  = 4'd5,
        ACK_WRITE   = 4'd6,
        READ_DATA   = 4'd7,
        WAIT_ACK    = 4'd8
    } state_t;
    
    (* mark_debug = "true" *) state_t state, next_state;
    
    // =========================================================================
    // INTERNAL REGISTERS - All marked for debug
    // =========================================================================
    (* mark_debug = "true" *) logic [7:0] shift_reg;
    (* mark_debug = "true" *) logic [2:0] bit_cnt;
    (* mark_debug = "true" *) logic       rw_bit;
    (* mark_debug = "true" *) logic       addr_match;
    (* mark_debug = "true" *) logic [7:0] reg_addr_r;
    (* mark_debug = "true" *) logic [7:0] tx_data;
    (* mark_debug = "true" *) logic       ack_scl_rose;
    (* mark_debug = "true" *) logic       reg_wr_pending;
    
    // Debug: Computed address comparison result
    (* mark_debug = "true" *) wire [6:0] received_addr = shift_reg[6:0];
    (* mark_debug = "true" *) wire addr_cmp_result = (received_addr == SLAVE_ADDR);
    
    // =========================================================================
    // SDA OUTPUT CONTROL
    // =========================================================================
    (* mark_debug = "true" *) logic sda_o_reg;
    (* mark_debug = "true" *) logic sda_oe_reg;
    
    always_comb begin
        sda_o_reg   = 1'b1;
        sda_oe_reg  = 1'b0;
        sda_driving = 1'b0;
        
        case (state)
            ACK_ADDR, ACK_REG, ACK_WRITE: begin
                sda_o_reg   = 1'b0;     // ACK = drive low
                sda_oe_reg  = 1'b1;
                sda_driving = 1'b1;
            end
            
            READ_DATA: begin
                sda_o_reg   = tx_data[7];
                sda_oe_reg  = 1'b1;
                sda_driving = 1'b1;
            end
            
            default: begin
                sda_o_reg   = 1'b1;
                sda_oe_reg  = 1'b0;
                sda_driving = 1'b0;
            end
        endcase
    end
    
    assign sda_o  = sda_o_reg;
    assign sda_oe = sda_oe_reg;
    
    // =========================================================================
    // FSM - NEXT STATE LOGIC
    // =========================================================================
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
                        // Compare the 7 address bits we've received
                        if (shift_reg[6:0] == SLAVE_ADDR) begin
                            next_state = ACK_ADDR;
                        end else begin
                            next_state = IDLE;
                        end
                    end
                end
                
                ACK_ADDR: begin
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
                            next_state = IDLE;
                        end else begin
                            next_state = READ_DATA;
                        end
                    end
                end
                
                default: next_state = IDLE;
            endcase
        end
    end
    
    // =========================================================================
    // FSM - SEQUENTIAL LOGIC
    // =========================================================================
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
            reg_wr_pending <= 1'b0;
            
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
                        bit_cnt      <= 3'd0;
                        ack_scl_rose <= 1'b0;
                    end
                    
                    GET_ADDR: begin
                        ack_scl_rose <= 1'b0;
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
                        if (scl_rising) begin
                            ack_scl_rose <= 1'b1;
                        end
                        if (scl_falling && ack_scl_rose) begin
                            bit_cnt      <= 3'd0;
                            ack_scl_rose <= 1'b0;
                            if (rw_bit) begin
                                tx_data <= reg_rdata;
                            end
                        end
                    end
                    
                    GET_REG: begin
                        ack_scl_rose <= 1'b0;
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1'b1;
                            
                            if (bit_cnt == 3'd7) begin
                                reg_addr_r <= {shift_reg[6:0], sda};
                            end
                        end
                    end
                    
                    ACK_REG: begin
                        if (scl_rising) begin
                            ack_scl_rose <= 1'b1;
                        end
                        if (scl_falling && ack_scl_rose) begin
                            bit_cnt      <= 3'd0;
                            ack_scl_rose <= 1'b0;
                        end
                    end
                    
                    WRITE_DATA: begin
                        ack_scl_rose <= 1'b0;
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1'b1;
                        end
                    end
                    
                    ACK_WRITE: begin
                        if (scl_rising) begin
                            ack_scl_rose   <= 1'b1;
                            reg_wr_pending <= 1'b1;
                        end
                        if (scl_falling && ack_scl_rose) begin
                            bit_cnt      <= 3'd0;
                            reg_addr_r   <= reg_addr_r + 1'b1;
                            ack_scl_rose <= 1'b0;
                        end
                    end
                    
                    READ_DATA: begin
                        if (scl_falling) begin
                            tx_data <= {tx_data[6:0], 1'b0};
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                    end
                    
                    WAIT_ACK: begin
                        if (scl_rising) begin
                            if (!sda) begin
                                reg_addr_r <= reg_addr_r + 1'b1;
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
    
    // =========================================================================
    // REGISTER FILE INTERFACE
    // =========================================================================
    assign reg_addr  = reg_addr_r;
    assign reg_wdata = shift_reg;
    assign reg_wr    = reg_wr_pending;
    assign reg_rd    = (state == ACK_ADDR && rw_bit && scl_falling && ack_scl_rose) ||
                       (state == WAIT_ACK && !sda && scl_rising);                

endmodule
