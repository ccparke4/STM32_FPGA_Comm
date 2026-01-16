`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/15/2026 03:55:51 PM
// Design Name: 
// Module Name: register_file
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


module register_file(
    input logic         clk,
    input logic         rst_n,
    
    // I2C slave interface
    input  logic [7:0]  reg_addr,
    input  logic [7:0]  reg_wdata,
    input  logic        reg_wr,
    output logic[7:0]   reg_rdata,
    input  logic        reg_rd,
    
    // HW interfaces
    output logic [7:0]  led_out,
    input  logic [7:0]  sw_in,
    
    // SPI Dataplane status
    input  logic        spi_active,
    input  logic [7:0]  spi_rx_byte
    );
    
    // Register Addresses =========================================================
    // system registers - 0x00-0x0F ---------------------------------------
    localparam ADDR_DEVICE_ID   = 8'h00;
    localparam ADDR_VERSION_MAJ = 8'h01;
    localparam ADDR_VERSION_MIN = 8'h02;
    localparam ADDR_SYS_STATUS  = 8'h03; // 7'b -> i2c ready
                                         // 6'b -> data plane ready
                                         // 5'b -> error flag, sticky
                                         // 4'b -> IRQ pending
                                         // [3:0] -> RESERVED
    localparam ADDR_SYS_CTRL    = 8'h04;
    localparam ADDR_SCRATCH_0   = 8'h05;
    localparam ADDR_SCRATCH_1   = 8'h06;
    
    // link control registers - 0x10-0x1F --------------------------------
    localparam ADDR_LINK_CAPS   = 8'h10; // [7:6] -> data bus width
                                            // 00 = 1'b -> SPI
                                            // 01 = 2'b -> DUAL_SPI (maybe)
                                            // 10 = 4'b -> QUAD_SPI
                                            // 11 = 8'b -> FMC
                                        // [5:4] -> max clock timer
                                            // 00 = 10MHz
                                            // 01 = 25MHz
                                            // 10 = 50MHz
                                            // 11 = 100MHz
                                        // 3'b -> FMI interface avail
                                        // 2'b -> DMA strm supportd
                                        // 1'b -> CRC avail
                                        // 0'b -> IRQ output avail
                                        
    localparam ADDR_DATA_MODE   = 8'h11; // 7'b   -> enable data plane
                                         // 6'b   -> loopback mode (testing)
                                         // [5:4] -> RESERVED
                                         // [3:2] -> Bus width   (00=1,01=2,10=4,11=8)
                                         // [1:0] -> mode select (00=SPI,01=SPI-HI,10=QSPI, 11=FMC
    localparam ADDR_DATA_CLK    = 8'h12;
    localparam ADDR_DATA_STATUS = 8'h13;
    localparam ADDR_DATA_ERR    = 8'h14;
    localparam ADDR_DATA_TEST   = 8'h15;
    
    // gpio registers - 0x20-0x2F -------------------------------------
    localparam ADDR_LED_OUT     = 8'h20;
    localparam ADDR_LED_OUT_H   = 8'h21;
    localparam ADDR_SW_IN       = 8'h22;
    localparam ADDR_SW_IN_H     = 8'h23;
    localparam ADDR_SEG_DATA    = 8'h24;
    localparam ADDR_SEG_CTRL    = 8'h25;
    
    // Fixed Values ===========================================================
    localparam DEVICE_ID    = 8'hA7;   // artix-7 ID
    localparam VERSION_MAJ  = 8'h01;   // v1.0
    localparam VERSION_MIN  = 8'h00;
    
    // device capabilities
    // [7:6] = 00 = 1'b -> SPI
    // [5:4] = 01 = 25MHz clk
    // 3'b   = 0  = FMI not avail... in dev.
    // 2'b   = 1  = DMA support
    // 1'b   = 0  = No CRC support...yet...maybe...probabably?
    // 0'b   = 1  = IRQ support
    // 00_01_0_1_0_1
    localparam LINK_CAPS    = 8'b00_01_0_1_0_1;
    
    // R/W Registers ===========================================================
    logic [7:0] sys_ctrl;
    logic [7:0] scratch0;
    logic [7:0] scratch1;
    logic [7:0] data_mode;
    logic [7:0] data_clk_div;
    logic [7:0] data_test;
    logic [7:0] led_reg;
    logic [7:0] led_reg_h;
    logic [7:0] seg_data;
    logic [7:0] seg_ctrl;
    logic       error_flag;
    logic [7:0] error_count;
    
    // LOGIC ===================================================================
    
    // write logic attempt #1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sys_ctrl        <= 8'h00;
            scratch0        <= 8'h00;
            scratch1        <= 8'h00;
            data_mode       <= 8'h00;
            data_clk_div    <= 8'h04;   // default div.
            led_reg         <= 8'h00;
            led_reg_h       <= 8'h00;
            seg_data        <= 8'h00;
            seg_ctrl        <= 8'h00;
            error_flag      <= 1'b0;
            error_count     <= 8'h00;
        end else if (reg_wr) begin
            case (reg_addr) 
                ADDR_SYS_CTRL:   sys_ctrl     <= reg_wdata;
                ADDR_SCRATCH_0:  scratch0     <= reg_wdata;
                ADDR_SCRATCH_1:  scratch1     <= reg_wdata;
                ADDR_DATA_MODE:  data_mode    <= reg_wdata;
                ADDR_DATA_CLK:   data_clk_div <= reg_wdata;
                ADDR_LED_OUT:    led_reg      <= reg_wdata;
                ADDR_LED_OUT_H:  led_reg_h    <= reg_wdata;
                ADDR_SEG_DATA:   seg_data     <= reg_wdata;
                ADDR_SEG_CTRL:   seg_ctrl     <= reg_wdata;
                // WR 1 to error flag clears it
                ADDR_SYS_STATUS: if (reg_wdata[5]) error_flag <= 1'b0;
                default: ;      // register DNE
            endcase
        end
    end
    
    // read logic attempt #1
    always_comb begin
        case(reg_addr) 
            // system regs 0x00-0x0F
            ADDR_DEVICE_ID:     reg_rdata = DEVICE_ID;
            ADDR_VERSION_MAJ:   reg_rdata = VERSION_MAJ;
            ADDR_VERSION_MIN:   reg_rdata = VERSION_MIN;
            ADDR_SYS_STATUS:    reg_rdata = {
                1'b1,       // I2C ready
                spi_active, // data plane ready
                error_flag,
                1'b0,       // IRQ pending
                4'b0000     // RESERVED
            };
            ADDR_SYS_CTRL:      reg_rdata = sys_ctrl;
            ADDR_SCRATCH_0:     reg_rdata = scratch0;
            ADDR_SCRATCH_1:     reg_rdata = scratch1;
            
            // link control regs 0x10-0x1F
            ADDR_LINK_CAPS:     reg_rdata = LINK_CAPS;
            ADDR_DATA_MODE:     reg_rdata = data_mode;
            ADDR_DATA_CLK:      reg_rdata = data_clk_div;
            ADDR_DATA_STATUS:   reg_rdata = {spi_active, 7'b0000000};
            ADDR_DATA_ERR:      reg_rdata = error_count;
            ADDR_DATA_TEST:     reg_rdata = data_test;
            
            // gpio regs 0x20-0x2F
            ADDR_LED_OUT:     reg_rdata = led_reg;
            ADDR_LED_OUT_H:   reg_rdata = led_reg_h;
            ADDR_SW_IN:       reg_rdata = sw_in;
            ADDR_SW_IN_H:     reg_rdata = 8'h00;  
            ADDR_SEG_DATA:    reg_rdata = seg_data;
            ADDR_SEG_CTRL:    reg_rdata = seg_ctrl;
            
            default:          reg_rdata = 8'h00;
            
        endcase
    end
    
    // HW Output(s) ===================================================
    assign led_out = led_reg;

endmodule
