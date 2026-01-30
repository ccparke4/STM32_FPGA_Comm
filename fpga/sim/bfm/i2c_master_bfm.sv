`timescale 1ns / 1ps
//==============================================================================
// I2C Master Bus Functional Model (BFM)
//==============================================================================
// Implements a cycle-accurate I2C master for verification.
// Features:
//   - Full I2C protocol: START, STOP, repeated START
//   - 7-bit addressing with R/W bit
//   - ACK/NACK detection
//   - Configurable timing (default: 400kHz Fast Mode)
//   - High-level API: write_reg(), read_reg()
//==============================================================================

module i2c_master_bfm #(
    parameter logic [6:0] TARGET_ADDR  = 7'h55,
    parameter int         CLK_DIV      = 250      // For 400kHz @ 100MHz
)(
    input  logic        clk,
    input  logic        rst_n,
    
    // I2C Bus (directly connected - testbench handles open-drain)
    output logic        scl_o,
    output logic        sda_o,
    output logic        sda_oe,
    input  logic        sda_i,
    
    // Control Interface
    input  logic        start,
    input  logic        is_read,
    input  logic [7:0]  reg_addr,
    input  logic [7:0]  write_data,
    output logic [7:0]  read_data,
    output logic        done,
    output logic        ack_error,
    output logic        busy
);

    //--------------------------------------------------------------------------
    // Timing Parameters (400kHz Fast Mode)
    //--------------------------------------------------------------------------
    localparam int T_SU_STA  = CLK_DIV / 4;    // Setup time for START
    localparam int T_HD_STA  = CLK_DIV / 4;    // Hold time for START
    localparam int T_SU_DAT  = CLK_DIV / 10;   // Data setup time
    localparam int T_HD_DAT  = CLK_DIV / 20;   // Data hold time
    localparam int T_HIGH    = CLK_DIV / 2;    // SCL high time
    localparam int T_LOW     = CLK_DIV / 2;    // SCL low time
    localparam int T_SU_STO  = CLK_DIV / 4;    // Setup time for STOP
    localparam int T_BUF     = CLK_DIV / 2;    // Bus free time
    
    //--------------------------------------------------------------------------
    // State Machine
    //--------------------------------------------------------------------------
    typedef enum logic [4:0] {
        ST_IDLE,
        ST_START,
        ST_ADDR_BIT,
        ST_ADDR_ACK,
        ST_REG_BIT,
        ST_REG_ACK,
        ST_WRITE_BIT,
        ST_WRITE_ACK,
        ST_RESTART,
        ST_RADDR_BIT,
        ST_RADDR_ACK,
        ST_READ_BIT,
        ST_READ_ACK,
        ST_STOP,
        ST_DONE
    } state_t;
    
    state_t state, next_state;
    
    //--------------------------------------------------------------------------
    // Internal Registers
    //--------------------------------------------------------------------------
    logic [15:0] clk_cnt;
    logic [3:0]  bit_cnt;
    logic [7:0]  shift_reg;
    logic        captured_ack;
    logic        is_read_op;
    logic [7:0]  reg_addr_r;
    logic [7:0]  write_data_r;
    logic        first_read_bit;        // FIX - flag the 1st read bit 
    
    // Output registers
    logic        scl_out;
    logic        sda_out;
    logic        sda_drive;
    
    assign scl_o  = scl_out;
    assign sda_o  = sda_out;
    assign sda_oe = sda_drive;
    assign busy   = (state != ST_IDLE);
    
    //--------------------------------------------------------------------------
    // Main State Machine
    //--------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= ST_IDLE;
            clk_cnt         <= '0;
            bit_cnt         <= '0;
            shift_reg       <= '0;
            scl_out         <= 1'b1;
            sda_out         <= 1'b1;
            sda_drive       <= 1'b0;
            done            <= 1'b0;
            ack_error       <= 1'b0;
            read_data       <= '0;
            captured_ack    <= 1'b0;
            is_read_op      <= 1'b0;
            reg_addr_r      <= '0;
            write_data_r    <= '0;
            first_read_bit  <= 1'b0;
        end else begin
            done <= 1'b0;
            
            case (state)
                //--------------------------------------------------------------
                ST_IDLE: begin
                    scl_out   <= 1'b1;
                    sda_out   <= 1'b1;
                    sda_drive <= 1'b0;
                    ack_error <= 1'b0;
                    
                    if (start) begin
                        is_read_op   <= is_read;
                        reg_addr_r   <= reg_addr;
                        write_data_r <= write_data;
                        state        <= ST_START;
                        clk_cnt      <= '0;
                    end
                end
                
                //--------------------------------------------------------------
                // Generate START condition: SDA falls while SCL high
                ST_START: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_SU_STA) begin
                        // Setup: Both high
                        scl_out   <= 1'b1;
                        sda_out   <= 1'b1;
                        sda_drive <= 1'b1;
                    end else if (clk_cnt < T_SU_STA + T_HD_STA) begin
                        // START: Pull SDA low while SCL high
                        sda_out <= 1'b0;
                    end else begin
                        // Pull SCL low to start first bit
                        scl_out <= 1'b0;
                        clk_cnt <= '0;
                        bit_cnt <= '0;
                        // Load address byte: {7-bit addr, R/W=0 for write phase}
                        shift_reg <= {TARGET_ADDR, 1'b0};
                        state <= ST_ADDR_BIT;
                    end
                end
                
                //--------------------------------------------------------------
                // Send address byte (7-bit addr + W)
                ST_ADDR_BIT: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_HD_DAT) begin
                        // Hold after SCL fall
                        scl_out <= 1'b0;
                    end else if (clk_cnt < T_LOW) begin
                        // Set data during SCL low
                        sda_out   <= shift_reg[7];
                        sda_drive <= 1'b1;
                    end else if (clk_cnt < T_LOW + T_HIGH) begin
                        // SCL high - slave samples
                        scl_out <= 1'b1;
                    end else begin
                        // End of bit
                        scl_out   <= 1'b0;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt   <= bit_cnt + 1;
                        clk_cnt   <= '0;
                        
                        if (bit_cnt == 4'd7) begin
                            state <= ST_ADDR_ACK;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // Receive ACK for address
                ST_ADDR_ACK: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_HD_DAT) begin
                        scl_out   <= 1'b0;
                        sda_drive <= 1'b0;  // Release SDA for slave ACK
                    end else if (clk_cnt < T_LOW) begin
                        // Wait in SCL low
                    end else if (clk_cnt < T_LOW + T_HIGH/2) begin
                        scl_out <= 1'b1;
                    end else if (clk_cnt == T_LOW + T_HIGH/2) begin
                        // Sample ACK
                        captured_ack <= sda_i;
                    end else if (clk_cnt < T_LOW + T_HIGH) begin
                        // Continue SCL high
                    end else begin
                        scl_out <= 1'b0;
                        clk_cnt <= '0;
                        bit_cnt <= '0;
                        
                        if (captured_ack) begin
                            // NACK - go to STOP
                            ack_error <= 1'b1;
                            state <= ST_STOP;
                        end else begin
                            // ACK received - send register address
                            shift_reg <= reg_addr_r;
                            state <= ST_REG_BIT;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // Send register address byte
                ST_REG_BIT: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_HD_DAT) begin
                        scl_out <= 1'b0;
                    end else if (clk_cnt < T_LOW) begin
                        sda_out   <= shift_reg[7];
                        sda_drive <= 1'b1;
                    end else if (clk_cnt < T_LOW + T_HIGH) begin
                        scl_out <= 1'b1;
                    end else begin
                        scl_out   <= 1'b0;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt   <= bit_cnt + 1;
                        clk_cnt   <= '0;
                        
                        if (bit_cnt == 4'd7) begin
                            state <= ST_REG_ACK;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // Receive ACK for register address
                ST_REG_ACK: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_HD_DAT) begin
                        scl_out   <= 1'b0;
                        sda_drive <= 1'b0;
                    end else if (clk_cnt < T_LOW) begin
                        // Wait
                    end else if (clk_cnt < T_LOW + T_HIGH/2) begin
                        scl_out <= 1'b1;
                    end else if (clk_cnt == T_LOW + T_HIGH/2) begin
                        captured_ack <= sda_i;
                    end else if (clk_cnt < T_LOW + T_HIGH) begin
                        // Continue
                    end else begin
                        scl_out <= 1'b0;
                        clk_cnt <= '0;
                        bit_cnt <= '0;
                        
                        if (captured_ack) begin
                            ack_error <= 1'b1;
                            state <= ST_STOP;
                        end else if (is_read_op) begin
                            // For read: generate repeated START
                            state <= ST_RESTART;
                        end else begin
                            // For write: send data
                            shift_reg <= write_data_r;
                            state <= ST_WRITE_BIT;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // Send write data byte
                ST_WRITE_BIT: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_HD_DAT) begin
                        scl_out <= 1'b0;
                    end else if (clk_cnt < T_LOW) begin
                        sda_out   <= shift_reg[7];
                        sda_drive <= 1'b1;
                    end else if (clk_cnt < T_LOW + T_HIGH) begin
                        scl_out <= 1'b1;
                    end else begin
                        scl_out   <= 1'b0;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt   <= bit_cnt + 1;
                        clk_cnt   <= '0;
                        
                        if (bit_cnt == 4'd7) begin
                            state <= ST_WRITE_ACK;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // Receive ACK for write data
                ST_WRITE_ACK: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_HD_DAT) begin
                        scl_out   <= 1'b0;
                        sda_drive <= 1'b0;
                    end else if (clk_cnt < T_LOW) begin
                        // Wait
                    end else if (clk_cnt < T_LOW + T_HIGH/2) begin
                        scl_out <= 1'b1;
                    end else if (clk_cnt == T_LOW + T_HIGH/2) begin
                        captured_ack <= sda_i;
                    end else if (clk_cnt < T_LOW + T_HIGH) begin
                        // Continue
                    end else begin
                        scl_out <= 1'b0;
                        clk_cnt <= '0;
                        
                        if (captured_ack) begin
                            ack_error <= 1'b1;
                        end
                        state <= ST_STOP;
                    end
                end
                
                //--------------------------------------------------------------
                // Generate repeated START for read operation
                ST_RESTART: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_LOW/2) begin
                        // SDA high while SCL low
                        scl_out   <= 1'b0;
                        sda_out   <= 1'b1;
                        sda_drive <= 1'b1;
                    end else if (clk_cnt < T_LOW/2 + T_SU_STA) begin
                        // SCL high, SDA high
                        scl_out <= 1'b1;
                    end else if (clk_cnt < T_LOW/2 + T_SU_STA + T_HD_STA) begin
                        // START: Pull SDA low while SCL high
                        sda_out <= 1'b0;
                    end else begin
                        // Pull SCL low
                        scl_out <= 1'b0;
                        clk_cnt <= '0;
                        bit_cnt <= '0;
                        // Address byte with READ bit
                        shift_reg <= {TARGET_ADDR, 1'b1};
                        state <= ST_RADDR_BIT;
                    end
                end
                
                //--------------------------------------------------------------
                // Send address byte for read (with R bit)
                ST_RADDR_BIT: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_HD_DAT) begin
                        scl_out <= 1'b0;
                    end else if (clk_cnt < T_LOW) begin
                        sda_out   <= shift_reg[7];
                        sda_drive <= 1'b1;
                    end else if (clk_cnt < T_LOW + T_HIGH) begin
                        scl_out <= 1'b1;
                    end else begin
                        scl_out   <= 1'b0;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt   <= bit_cnt + 1;
                        clk_cnt   <= '0;
                        
                        if (bit_cnt == 4'd7) begin
                            state <= ST_RADDR_ACK;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // Receive ACK for read address
                ST_RADDR_ACK: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_HD_DAT) begin
                        scl_out   <= 1'b0;
                        sda_drive <= 1'b0;
                    end else if (clk_cnt < T_LOW) begin
                        // Wait
                    end else if (clk_cnt < T_LOW + T_HIGH/2) begin
                        scl_out <= 1'b1;
                    end else if (clk_cnt == T_LOW + T_HIGH/2) begin
                        captured_ack <= sda_i;
                    end else if (clk_cnt < T_LOW + T_HIGH) begin
                        // Continue
                    end else begin
                        scl_out <= 1'b0;
                        clk_cnt <= '0;
                        bit_cnt <= '0;
                        shift_reg <= '0;
                        
                        if (captured_ack) begin
                            ack_error <= 1'b1;
                            state <= ST_STOP;
                        end else begin
                            // slave loads tx_data on the ACK falling and immediatly drives the 1st bit (maybe incorrect)
                            first_read_bit <= 1'b1;
                            state <= ST_READ_BIT;
                        end
                    end
                end
                
                //--------------------------------------------------------------
                // Read data byte from slave
                ST_READ_BIT: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (first_read_bit) begin
                        // 1st bit -> slave already has data on SDA from ACK

                        // Short low time before raising SCL
                        if (clk_cnt < T_HD_DAT) begin
                            scl_out     <= 1'b0;
                            sda_drive   <= 1'b0;
                        end else if (clk_cnt < T_HD_DAT + T_SU_DAT) begin
                            // short setup - data should be stable
                            scl_out     <= 1'b0;
                        end else if (clk_cnt < T_HD_DAT + T_SU_DAT + T_HIGH/2) begin
                            scl_out     <= 1'b1;
                        end else if (clk_cnt == T_HD_DAT + T_SU_DAT + T_HIGH/2) begin
                            // sample 1st data bit
                            shift_reg   <= {shift_reg[6:0], sda_i};
                        end else if (clk_cnt < T_HD_DAT + T_SU_DAT + T_HIGH) begin
                            // scl stays high
                        end else begin
                            scl_out         <= 1'b0;
                            bit_cnt         <= bit_cnt + 1;
                            clk_cnt         <= '0;
                            first_read_bit  <= 1'b0;        // clear flag for subsequesnt bits

                            if (bit_cnt == 4'd7) begin
                                read_data <= {shift_reg[6:0], sda_i};
                                state     <= ST_READ_ACK;
                            end
                        end
                    end else begin
                        // typical bit 1-7 timing
                        if (clk_cnt < T_HD_DAT) begin
                            scl_out     <= 1'b0;
                            sda_drive   <= 1'b0;
                        end else if (clk_cnt < T_LOW) begin
                            // wait in SCL lo - slave shifts on falling edge
                        end else if (clk_cnt < T_LOW + T_HIGH/2) begin
                            scl_out     <= 1'b1;
                        end else if (clk_cnt == T_LOW + T_HIGH/2) begin
                            // bit of data
                            shift_reg   <= {shift_reg[6:0], sda_i};
                        end else if (clk_cnt < T_LOW + T_HIGH) begin
                            // continue SCL high
                        end else begin
                            scl_out     <= 1'b0;
                            bit_cnt     <= bit_cnt + 1;
                            clk_cnt     <= '0;

                            if (bit_cnt == 4'd7) begin
                                read_data   <= {shift_reg[6:0], sda_i};
                                state       <= ST_READ_ACK;
                            end
                        end
                    end 
                end
                
                //--------------------------------------------------------------
                // Send NACK after read (single byte read)
                ST_READ_ACK: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_HD_DAT) begin
                        scl_out   <= 1'b0;
                        sda_out   <= 1'b1;  // NACK (high)
                        sda_drive <= 1'b1;
                    end else if (clk_cnt < T_LOW) begin
                        // Hold
                    end else if (clk_cnt < T_LOW + T_HIGH) begin
                        scl_out <= 1'b1;
                    end else begin
                        scl_out <= 1'b0;
                        clk_cnt <= '0;
                        state <= ST_STOP;
                    end
                end
                
                //--------------------------------------------------------------
                // Generate STOP condition
                ST_STOP: begin
                    clk_cnt <= clk_cnt + 1;
                    
                    if (clk_cnt < T_LOW/2) begin
                        // SDA low while SCL low
                        scl_out   <= 1'b0;
                        sda_out   <= 1'b0;
                        sda_drive <= 1'b1;
                    end else if (clk_cnt < T_LOW/2 + T_SU_STO) begin
                        // SCL high, SDA still low
                        scl_out <= 1'b1;
                    end else if (clk_cnt < T_LOW/2 + T_SU_STO + T_BUF) begin
                        // STOP: Release SDA while SCL high
                        sda_out   <= 1'b1;
                        sda_drive <= 1'b0;
                    end else begin
                        state <= ST_DONE;
                        clk_cnt <= '0;
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
