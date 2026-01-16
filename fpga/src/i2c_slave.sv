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
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// 'dynamic' module, def'ing params before ports
module i2c_slave #(
    parameter   logic [6:0]     SLAVE_ADDR = 7'h0  // 7'b addr
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
    logic [2:0]     scl_sync;
    logic [2:0]     sda_sync;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync    <= 3'b111;
            sda_sync    <= 3'b111;
        end else begin
            scl_sync    <= {scl_sync[1:0], scl_i};
            sda_sync    <= {sda_sync[1:0], sda_i};
        end
    end
    
    // sync'd signals
    wire scl = scl_sync[2];
    wire sda = sda_sync[2];
    
    // Edge detection
    wire scl_rising  = (scl_sync[2:1] == 2'b01);
    wire scl_falling = (scl_sync[2:1] == 2'b10);
    
    // START: SDA falls while SCL is high
    wire start_detect = (sda_sync[2:1] == 2'b10) && scl;
    
    // STOP: SDA rises while SCL is high
    wire stop_detect = (sda_sync[2:1] == 2'b01) && scl;
    
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
    
    // Internal regs
    logic [7:0] shift_reg;      // Shift reg for Rx/Tx
    logic [2:0] bit_cnt;        // bit counter 0-7
    logic       rw_bit;         // 0=W, 1=R
    logic       addr_match;     // Address matched flag
    logic [7:0] reg_addr_int;   // Internal reg addr
    logic       first_byte;     // first byt after address
    
    // SDA output control
    logic       sda_out;        // need to drive
    logic       sda_drive;      // do we drive sda?
    
    
    // Seq. State Machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            shift_reg       <= 8'h00;
            bit_cnt         <= 3'h00;
            rw_bit          <= 1'b0;
            addr_match      <= 1'b0;
            reg_addr_int    <= 8'h00;
            first_byte      <= 1'b1;
            sda_out         <= 1'b1;
            sda_drive       <= 1'b0;
        end else begin
            // default: RELEASE SDA
            sda_drive       <= 1'b0;
            sda_out         <= 1'b1;
            
            // start: reset state machine
            if (start_detect) begin
                state       <= GET_ADDR;
                bit_cnt     <= 3'd0;
                shift_reg   <= 8'h00;
                addr_match  <= 1'b0;
                first_byte  <= 1'b1;
            end
            // stop: see a stop return to idle
            else if (stop_detect) begin
                state       <= IDLE;
                addr_match  <= 1'b0;
            end
            else begin 
                case(state)
                    IDLE: begin
                        bit_cnt     <= 3'd0;    // wait for start cond..
                    end
                    
                    GET_ADDR: begin
                        // sample addr + R/W bit on SCL RISING
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1;
                            
                            if (bit_cnt == 3'd7) begin  // received full data (7'b mode)
                                // check address match (7:1=address, 0=R/W sel.)
                                if (shift_reg[6:0] == SLAVE_ADDR) begin
                                    addr_match <= 1'b1;
                                    rw_bit     <= sda;          // capture SDA 
                                    state      <= ACK_ADDR;
                                end else begin
                                    // invlaid address/not for us (simplex comm...)
                                    addr_match <= 1'b0;
                                    state      <= IDLE;
                                end
                            end
                        end
                    end 
                    // ------------------------------------------------------
                    ACK_ADDR: begin
                        // Drive ACK (SDA low) on falling edge, release after next falling
                        sda_drive   <= 1'b1;
                        sda_out     <= 1'b0;    // ACK = LOW
                        
                        if (scl_falling) begin
                            bit_cnt     <= 1'b0;
                            if (rw_bit) begin
                                // READ: load data & transmit
                                state       <= READ_DATA;
                                shift_reg   <= reg_rdata;
                            end else begin
                                // WRITE: receive registre addr or data
                                if (first_byte) begin
                                    state   <= GET_REG;
                                end else begin
                                    state   <= WRITE_DATA;
                                end
                            end
                        end
                    end
                    // -------------------------------------------------------------
                    GET_REG: begin
                        // Rx register address byte
                        if (scl_rising) begin
                            shift_reg   <= {shift_reg[6:0], sda};
                            bit_cnt     <= bit_cnt + 1;
                            
                            if (bit_cnt == 8'd7) begin
                                reg_addr_int    <= {shift_reg[6:0], sda};
                                state           <= ACK_REG;
                            end
                        end
                    end
                    // ------------------------------------------------------------
                    ACK_REG: begin
                        // ACK the register address
                        sda_drive   <= 1'b1;
                        sda_out     <= 1'b0;  // ACK
                        
                        if (scl_falling) begin
                            bit_cnt     <= 3'd0;
                            first_byte  <= 1'b0;  // Next byte is data
                            state       <= WRITE_DATA;
                        end
                    end
                    // -----------------------------------------------------------
                    WRITE_DATA: begin
                        // Rx data from master
                        if (scl_rising) begin
                            shift_reg <= {shift_reg[6:0], sda};
                            bit_cnt   <= bit_cnt + 1;
                            
                            if (bit_cnt == 3'd7) begin
                                state <= ACK_WRITE;
                            end
                        end
                    end
                    // ----------------------------------------------------------
                    ACK_WRITE: begin
                        // ACK & WRITE to RF
                        sda_drive   <= 1'b1;
                        sda_out     <= 1'b0;    // ACK
                        if (scl_falling) begin
                            bit_cnt      <= 3'd0;
                            reg_addr_int <= reg_addr_int + 1;  // increment internal addr
                            state        <= WRITE_DATA;        // Ready for next byte
                        end
                    end
                    // -----------------------------------------------------------
                    READ_DATA: begin
                        // Tx byte to master
                        sda_drive   <= 1'b1;
                        sda_out     <= shift_reg[7];  // MSB first, aka 'big endianess'
                        if (scl_falling) begin
                            shift_reg   <= {shift_reg[6:0], 1'b0};
                            bit_cnt     <= bit_cnt + 1;
                            
                            if (bit_cnt == 3'd7) begin
                                state   <= WAIT_ACK;
                            end
                        end
                    end
                    // -----------------------------------------------------------
                    WAIT_ACK: begin
                        // Master sends ACK (continue) or NACK (stop)
                        if (scl_rising) begin
                            if (sda) begin
                                // NACK - master done reading
                                state    <= IDLE;
                            end else begin
                                // ACK - master wants more
                                reg_addr_int    <= reg_addr_int + 1;  // Auto-increment
                                state           <= READ_DATA;
                                shift_reg       <= reg_rdata;          // Load next byte
                            end
                        end
                    end
                    default: state  <= IDLE;    // sit in idle as default
                endcase
            end
        end
    end

// OUTPUT ASSIGNMENTS ==========================================================
assign sda_oe    = sda_drive;
assign sda_o     = sda_out;

// RF interface
assign reg_addr  = reg_addr_int;
assign reg_wdata = shift_reg;

// Write strobe: pulse when ACK_WRITE state entered on falling edge
assign reg_wr    = (state == ACK_WRITE) && scl_falling;

// Read strobe: pulse when loading data for read
assign reg_rd = ((state == ACK_ADDR) && rw_bit && scl_falling) ||
                ((state == WAIT_ACK) && !sda && scl_rising);
    
    
endmodule
