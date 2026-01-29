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
            $display("[%0t] [I2C] Initializing Bus to Idle...", $time);
            vif.scl_out = 1;    // release SCL, goes high
            vif.sda_out = 1;
            vif.sda_oe  = 0;
            #5000;
        endtask

        // Gen Start condition (SDA goes Low while SCL is high)
        task start_cond();
            $display("[%0t] [I2C] Generating START Condition", $time);
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
            $display("[%0t] [I2C] Generating STOP Condition", $time);
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
                //$display("[%0t] [I2C] Sending Byte: 0x%h", $time, data);
                // 1. setup data
                vif.sda_out = data[i];
                vif.sda_oe  = 0;

                // 2. Puls SCL hgh
                #(quarter_period);
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

            // Sample SDA - Did the slave pull sda low??
            ack = vif.sda;
            if (ack == 1'b0)
                $display("[%0t] [I2C] Wrote: 0x%h | ACK Received", $time, data);
            else
                $error("[%0t] [I2C] Wrote: 0x%h | NACK Received (ERROR)", $time, data);
            
            #(quarter_period);

            vif.scl_out = 0;    // end of ack
            #(quarter_period);
        endtask

        // read single byte
        task read_byte(output logic [7:0] data, input logic send_ack);
            vif.sda_oe = 0; // float sda line
            for (int i=7; i>=0; i--) begin
                #(quarter_period);
                vif.scl_out = 1;
                #(quarter_period);
                data[i] = vif.sda;  // sample
                #(quarter_period);
                vif.scl_out = 0;
                #(quarter_period);
            end
            
            $display("[%0t] [I2C] Read Byte: 0x%h", $time, data);

            // Send ACK/NACK
            vif.sda_out = !send_ack;    // 1=ACK (low), 0=NACK(high)
            vif.sda_oe  = 1;
            #(quarter_period);
            vif.scl_out = 1;
            #(quarter_period * 2);
            vif.scl_out = 0;
            #(quarter_period);
            vif.sda_oe  = 0;
        endtask

        // High Level Task: Write register
        task write_register(input logic [6:0] slave_addr, input logic [7:0] reg_addr, input logic [7:0] val);
            logic ack;
            $display("----------------------------------------");
            $display("[%0t] [I2C TX] Write Reg 0x%h = 0x%h", $time, reg_addr, val);

            start_cond();

            // send slave ADDR
            write_byte({slave_addr, 1'b0}, ack);
            if (ack) begin
                $error("[STM32] Slave Addr. NACKed! Aborting.");
                stop_cond();
                return;
            end

            // send reg addr
            write_byte(reg_addr, ack);

            // send data
            write_byte(val, ack);

            stop_cond();
            $display("----------------------------------------");
        endtask

        // High level task: read register
        task read_register(input logic [6:0] slave_addr, input logic [7:0] reg_addr, output logic [7:0] val);
            logic ack;
            $display("----------------------------------------");
            $display("[%0t] [I2C TX] Read Reg 0x%h", $time, reg_addr);

            // write ptr
            start_cond();
            write_byte({slave_addr, 1'b0}, ack);
            write_byte(reg_addr, ack);

            // restart and read
            start_cond();
            write_byte({slave_addr, 1'b1}, ack);        // raed addr

            // Read bye and send NACK(0) to indicate end tx
            stop_cond();
            $display("----------------------------------------");
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
            $display("[%0t] [SPI] Initializing SPI Bus...", $time);
            vif.cs   = 1;
            vif.sclk = 0;
            vif.mosi = 0;
        endtask

        task send_byte(input logic [7:0] data);
            $display("[%0t] [SPI] Initializing SPI Bus...", $time);
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