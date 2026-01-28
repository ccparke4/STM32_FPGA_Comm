`timescale 1ns / 1ps

package stm32_mock_pkg;

    // I2C MASTER DRIVER =================================
    class I2CDriver;
        virtual i2c_if vif;     // handle for phy interface

        // setting 400kHz I2C
        int quarter_period = 625; // 2500 for 100khz

        function new(virtual i2c_if _vif);
            this.vif = _vif;
        endfunction

        // init bus to idle
        task init();
            vif.scl_out = 1;    // release SCL, goes high
            vif.sda_out = 1;
            vif.sda_oe  = 0;
            #5000;
        endtask

        // Gen Start condition (SDA goes Low while SCL is high)
        task start_cond();
            vif.scl_out = 1;
            vif.sda_out = 1;
            vif.sda_oe  = 0;    // float high
            #(quarter_period);

            // Drive SDA low
            vif.sda_out = 0;
            vif.sda_oe  = 1;
            #(quarter_period);

            // bring SCL low
            vif.scl_out = 0;
            #(quarter_period);
        endtask

        // Gen Stop condition (SDA goes high while SCL is high)
        task stop_cond();
            vif.scl_out = 0;
            vif.sda_out = 0;
            vif.sda_oe  = 1;    // drive low
            #(quarter_period);

            vif.scl_out = 1;    // release scl
            #(quarter_period);

            // Realse SDA (pull-up takes it high)
            vif.sda_oe   = 0;
            #(quarter_period);
        endtask

        // Write single byte and return the ACK (0=ACK, 1=NACK)
        task write_byte(input logic [7:0] data, output logic ack);
            for(int i=7; i>=0; i--) begin
                // 1. setup data
                vif.scl_out = 0;
                vif.sda_out = data[i];
                vif.sda_oe  = 0;

                // 2. Puls SCL hgh
                vif.scl_out = 1;
                #(quarter_period * 2);

                // 3. SCL Low
                vif.scl_out = 0;
                #(quarter_period);
            end

            // Handle ACK/NACK ---
            vif.sda_oe  = 0;    // release SDA SO SLAVE CAN DRIVE IT
            #(quarter_period);

            vif.scl_out = 1;    // Rising edge for ACK
            #(quarter_period);

            // Sample SDA (slave pull low?)
            ack = vif.sda;

            #(quarter_period);
            vif.scl_out = 0;    // end of ack cycle
        endtask

        // High Level Task: Write register
        task write_register(input logic [6:0] slave_addr, input logic [7:0] reg_addr, input logic [7:0] val);
            logic ack;
            start_cond();

            // send slave ADDR
            writebyte({slave_addr, 1'b0}, ack);
            if (ack) $display("[STM32] NACK received on addr");

            // send reg addr
            write_byt(reg_addr, ack);

            // send data
            write_byte(val, ack);

            stop_cond();
        endtask
    endclass

    // SPI MASTER DRIVER (DATA plane) =======================================================
    class SPIDriver;
        virtual spi_if vif;
        int half_period = 50;   // 10 MHz SPI

        function new(virtual spi_if _vif);
            this.vif = _vif;
        endfunction

        task init();
            vif.cs   = 1;
            vif.sclk = 0;
            vif.mosi = 0
        endtask

        task send_byte(input logic [7:0] data)
            vif.cs = 0;
            #(half_period);

            for(int i=7;i>=0; i--) begin
               // setup MOSI 
                vif.mosi = data[i];
                #(half_period);

                // Clock high (sample)
                vif.sclk = 1;
                #(half_period);

                // cloc low
                vif.sclk = 0;
            end

            #(half_period);
            vif.cs = 1;
            #(half_period * 5);
        endtask
    endclass

endpackage