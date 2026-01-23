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
// Description: I2C Slave with ILA Debug
// 
// Dependencies: 
// 
// Revision:
// Revision 1.2 - Added comprehensive ILA debugging
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module i2c_slave #(
    parameter   logic [6:0]     SLAVE_ADDR = 7'h50  
    )(
        input   logic           clk,        // 100MHz sys clock
        input   logic           rst_n,      
        
        // i2c interface
        input   logic           scl_i,      
        input   logic           sda_i,      
        output  logic           sda_o,      
        output  logic           sda_oe,     
        // Register file intrface
        output  logic [7:0]     reg_addr,   
        output  logic [7:0]     reg_wdata,  
        output  logic           reg_wr,     
        input   logic [7:0]     reg_rdata,  
        output  logic           reg_rd      
    );
    
    logic scl_clean, sda_clean;
    logic scl_d, sda_d;  // Re-declared here

    // Filter SCL
    i2c_debounce #(.CLK_FREQ_MHZ(100), .DEBOUNCE_US(0.1)) db_scl (
        .clk(clk), .rst_n(rst_n), 
        .in_raw(scl_i), .out_filtered(scl_clean)
    );

    // Filter SDA
    i2c_debounce #(.CLK_FREQ_MHZ(100), .DEBOUNCE_US(0.1)) db_sda (
        .clk(clk), .rst_n(rst_n), 
        .in_raw(sda_i), .out_filtered(sda_clean)
    );

    // Create Delayed versions for Edge Detection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_d <= 1'b1;
            sda_d <= 1'b1;
        end else begin
            scl_d <= scl_clean;
            sda_d <= sda_clean;
        end
    end
    
    // ILA: Mark synchronized signals to see what the logic actually "sees"
    (* mark_debug = "true" *) wire scl = scl_clean; // Updated alias
    (* mark_debug = "true" *) wire sda = sda_clean; // Updated alias
    
    // Edge detection
    (* mark_debug = "true" *) wire scl_rising  = scl_clean && !scl_d;
    (* mark_debug = "true" *) wire scl_falling = !scl_clean && scl_d;
    
    logic sda_driving;
    
    // START/STOP detection
    (* mark_debug = "true" *) wire start_detect = !sda && sda_d && scl && !sda_driving;
    (* mark_debug = "true" *) wire stop_detect  = sda && !sda_d && scl && !sda_driving;
    
    // IDC State Machine 
    typedef enum logic [3:0] {
        IDLE,
        GET_ADDR,       
        ACK_ADDR,       
        GET_REG,        
        ACK_REG,        
        WRITE_DATA,     
        ACK_WRITE,      
        READ_DATA,      
        WAIT_ACK        
    } state_t;
    
    // ILA: Mark the State variable so we can see the FSM transitions
    (* mark_debug = "true" *) state_t state;
    state_t next_state;
    
    // Internal regs 
    (* mark_debug = "true" *) logic [7:0] shift_reg;      
    (* mark_debug = "true" *) logic [3:0] bit_cnt;        
    (* mark_debug = "true" *) logic       rw_bit;         
    (* mark_debug = "true" *) logic       addr_match;     
    (* mark_debug = "true" *) logic [7:0] reg_addr_r;     
    (* mark_debug = "true" *) logic [7:0] tx_data;        
    
    // ILA: DEBUG the ACK timing
    (* mark_debug = "true" *) logic       ack_scl_rose;
    logic       reg_wr_pending;
    (* mark_debug = "true" *) logic       nack_received;
    
    // SDA output control 
    always_comb begin
        sda_o       = 1'b1;
        sda_oe      = 1'b0;
        sda_driving = 1'b0;
        
        case (state)
            ACK_ADDR, ACK_REG, ACK_WRITE: begin
                sda_o       = 1'b0;     
                sda_oe      = 1'b1;
                sda_driving = 1'b1;
            end
            
            READ_DATA: begin
                sda_o       = tx_data[7];  
                sda_oe      = 1'b1;
                sda_driving = 1'b1;
            end
            
            // explicit
            WAIT_ACK: begin
                sda_o       = 1'b1;
                sda_oe      = 1'b0;
                sda_driving = 1'b0;
            end
            
            default: begin
                sda_o       = 1'b1;
                sda_oe      = 1'b0;
                sda_driving = 1'b0;
            end
        endcase
    end
    
    // FSM - Next state logic 
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
                end
                
                GET_ADDR: begin
                    // Transition on Falling Edge to prep. ACK
                    if (scl_falling && bit_cnt == 4'd8) begin       // wraparound results in state loop, try 8bit so we count the R/W bit
                        if (addr_match) begin    
                            next_state = ACK_ADDR;
                        end else begin
                            next_state = IDLE;
                        end
                    end
                end
                
                ACK_ADDR: begin
                    // stay in ACK state until SCL falls (end of 9th SCK)
                    if (scl_falling && ack_scl_rose) begin
                        if (rw_bit) begin
                            next_state = READ_DATA;
                        end else begin
                            next_state = GET_REG;
                        end
                    end
                end
                
                GET_REG: begin
                    // Wait for 8th bit to finish before we go to ACK state
                    if (scl_falling && bit_cnt == 4'd8) begin
                        next_state = ACK_REG;
                    end
                end
                
                ACK_REG: begin
                    if (scl_falling && ack_scl_rose) begin
                        next_state = WRITE_DATA;
                    end
                end
                
                WRITE_DATA: begin
                    if (scl_falling && bit_cnt == 4'd8) begin
                        next_state = ACK_WRITE;
                    end
                end
                
                ACK_WRITE: begin
                    if (scl_falling && ack_scl_rose) begin
                        next_state = WRITE_DATA;
                    end
                end
                
                READ_DATA: begin
                    // Slaved Tx'd 8 bits, now release bus for master ACK
                    if (scl_falling && bit_cnt == 4'd8) begin
                        next_state = WAIT_ACK;
                    end
                end
                
                WAIT_ACK: begin
                    // captued ACK/NACK on rising edge (see seq. logic)
                    // Now on Falling we act on it
                    if (scl_falling) begin
                        if (nack_received) begin
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
    
    // FSM - seq. logic 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            shift_reg       <= 8'h00;
            bit_cnt         <= 4'd0;
            rw_bit          <= 1'b0;
            reg_addr_r      <= 8'h00;
            addr_match      <= 1'b0;
            tx_data         <= 8'h00;
            ack_scl_rose    <= 1'b0;   
            reg_wr_pending  <= 1'b0;    
            nack_received   <= 1'b0;
        end
        else begin
            // Default signal updated
            reg_wr_pending  <= 1'b0;
            
            if (start_detect) begin
                state           <= GET_ADDR;
                bit_cnt         <= 4'd0;
                shift_reg       <= 8'h00;
                addr_match      <= 1'b0;
                ack_scl_rose    <= 1'b0; 
                nack_received   <= 1'b0;
            end
            else if (stop_detect) begin
                state           <= IDLE;
                addr_match      <= 1'b0;
                ack_scl_rose    <= 1'b0;
            end
            else begin
                // Normal state updated
                state <= next_state;
                    
                case (state)
                    IDLE: begin
                        bit_cnt         <= 4'd0;
                        ack_scl_rose    <= 1'b0;
                    end
                    
                    GET_ADDR: begin
                        ack_scl_rose    <= 1'b0;    
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1'b1;
                            // check on 7th bit
                            if (bit_cnt == 4'd7) begin
                                rw_bit <= sda;
                                // use concat to check full byte, even if shift reg not updated
                                if ({shift_reg[6:0], sda} >> 1 == SLAVE_ADDR) begin         // changed from 7:1 to 6:0
                                    addr_match <= 1'b1;
                                end
                            end
                        end
                    end
                    
                    ACK_ADDR: begin
                        if (scl_rising) begin
                            ack_scl_rose    <= 1'b1;
                        end
                        if (scl_falling && ack_scl_rose) begin
                            bit_cnt         <= 4'd0;
                            ack_scl_rose    <= 1'b0;
                            if (rw_bit) begin
                                tx_data <= reg_rdata;       // load data for tx
                            end
                        end
                    end
                    
                    GET_REG: begin
                        ack_scl_rose    <= 1'b0;    
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1'b1;
                            
                            if (bit_cnt == 4'd7) begin
                                reg_addr_r <= {shift_reg[6:0], sda};
                            end
                        end
                    end
                    
                    ACK_REG: begin
                        if (scl_rising) begin
                            ack_scl_rose    <= 1'b1;
                        end
                        if (scl_falling && ack_scl_rose) begin
                            bit_cnt         <= 4'd0;
                            ack_scl_rose    <= 1'b0;
                        end
                    end
                    
                    WRITE_DATA: begin
                         ack_scl_rose    <= 1'b0;       
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1'b1;
                        end
                    end
                    
                    ACK_WRITE: begin
                        if (scl_rising) begin
                            ack_scl_rose    <= 1'b1;
                            reg_wr_pending  <= 1'b1;        
                        end
                        if (scl_falling && ack_scl_rose) begin
                            bit_cnt         <= 4'd0;
                            reg_addr_r      <= reg_addr_r + 1'b1;
                            ack_scl_rose    <= 1'b0;
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
                            // capture masters ACK/NACK bit 
                            nack_received <= sda;
                            if (!sda) begin
                                reg_addr_r <= reg_addr_r + 1'b1;        
                            end     
                        end
                        if (scl_falling) begin
                            bit_cnt <= 4'd0;
                            tx_data <= reg_rdata;
                        end
                    end
                    
                    default: ;
                endcase
            end
        end
    end
    
    // Reg File interface 
    assign reg_addr  = reg_addr_r;
    assign reg_wdata = shift_reg;
    assign reg_wr = reg_wr_pending;
    
    assign reg_rd = (state == ACK_ADDR && rw_bit && scl_falling && ack_scl_rose) ||
                    (state == WAIT_ACK && !sda && scl_rising);                

endmodule