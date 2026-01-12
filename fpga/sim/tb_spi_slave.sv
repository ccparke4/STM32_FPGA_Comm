`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/12/2026 08:25:55 AM
// Design Name: 
// Module Name: tb_spi_slave
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


module tb_spi_slave;

    // 1. Singal declerations to connect to design
    logic       sys_clk;      // 100MHz FPGA Clock
    logic       spi_cs;       // chip select (Active low)
    logic       spi_sclk;     // SPI clk (from STM32)
    logic       spi_mosi;     // Master Out Slave In
    wire        spi_miso;     // Master In Slave Out (logic driven wire)
    
    // 2. Inst. Top.sv (DUT)
    top dut (
        .clk(sys_clk),      // TB sys_clk -> FPGA clk
        .JA1(spi_cs),       // JA1 -> CS
        .JA2(spi_mosi),     // JA2 -> MOSI
        .JA3(spi_miso),     // JA3 -> MISO
        .JA4(spi_sclk)     // JA4 -> SCLK
    );
    
    // 3. Gen. 100MHz System Clock; T=10ns
    initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk;  // toggle 5ns
    end
    
    // 4. Task mimicing STM32 SPI transmission (Mode 0)
    // data: byte to send
    // start:1 = Pull CS low (Tx Start)
    // end:  1 = Pull CS high (Tx end)
    task send_byte(input logic [7:0] data, input logic start, input logic stop);
        integer i;
        begin
            // A. Start of Frame Logic
            if (start) begin
                spi_cs = 0;     // assert CS
                #100;           // setup time
            end
            
            // B. Byte Tx
            for (i = 7; i >= 0; i--) begin
                spi_mosi = data[i];
                #64 spi_sclk = 1;   // rising edge (sample)
                #64 spi_sclk = 0;   // Falling edge (shift)
            end
            
            // C. End of Frame logic
            if (stop) begin
                #100;
                spi_cs = 1;     // De-assert CS
                #200;           // Inter-frame gap
            end else begin
                // if not stopping, wait briefly
                #200;
            end
        end
    endtask
  
    // 5. Main test
    initial begin
        // init. Inputs
        sys_clk = 0; spi_cs = 1; spi_sclk = 0; spi_mosi = 0;
        
        // Wait for global reset / FPGA startup
        #100;
        
        // TEST - 2'B burst
        // Fpga: Rx 0xAA, MISO 0x00
        send_byte(8'hAA, 1, 0);
        
        // Fpga: Rx 0x55, MISO echo 0xAA
        send_byte(8'h55, 0, 1);
        
        
        // Stop sim
        #500;
        $finish;
    end
  
endmodule
