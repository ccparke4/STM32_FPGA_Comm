/*
 * fpga_diagnostics.c
 *
 *  Created on: Jan 25, 2026
 *      Author: treyparker
 */

#include "fpga_diagnostics.h"
#include <stdio.h>

static const char* get_phy_type_str(uint8_t caps) {
	uint8_t width = (caps >> 6) & 0x03;
	switch (width) {
	case 0:
		return "Standard SPI (1-bit)";
	case 1:
		return "Dual SPI (2-bit)";
	case 2:
		return "Quad SPI (4-bit)";
	case 3:
		return "FMC (8-bit)";
	default:
		return "Unknown";
	}
}

static const char* get_clk_str(uint8_t caps) {
	uint8_t clk = (caps >> 4) & 0x03;
	switch (clk) {
	case 0:
		return "10 MHz";
	case 1:
		return "25 MHz";
	case 2:
		return "50 MHz";
	case 3:
		return "100 MHz";
	default:
		return "Unknown";
	}
}

void fpga_diagnostics_print_system_info(fpga_handle_t *hfpga) {
    uint8_t val, caps, status;
    fpga_status_t res;

    printf("\n[DIAG] === FPGA SYSTEM REPORT ===\n");
    printf("--------------------------------\n");

    // --- IDENTITY ---
    res = fpga_read_reg(hfpga, FPGA_REG_DEVICE_ID, &val);
    if (res != FPGA_OK) {
        printf("[FAIL] I2C Bus Error (No ACK)\n");
        return;
    }

    printf("Device Hardware:  ");
    if (val == 0xA7) printf("Artix-7 (Basys 3)\n");
    else             printf("Unknown Device (ID: 0x%02X)\n", val);

    fpga_read_reg(hfpga, FPGA_REG_VERSION_MAJ, &val);
    uint8_t v_maj = val;
    fpga_read_reg(hfpga, FPGA_REG_VERSION_MIN, &val);
    printf("Gateware Version: v%d.%d\n", v_maj, val);

    // --- STATUS ---
    fpga_read_reg(hfpga, FPGA_REG_SYS_STATUS, &status);
    // Verilog bit 6 is 'spi_active' input
    bool data_plane_active = (status & 0x40);
    bool i2c_ready = (status & 0x80);
    bool err_flag  = (status & 0x20);

    printf("System Status:    [0x%02X]\n", status);
    printf("  > Control Plane:%s\n", i2c_ready ? " READY" : " BUSY");
    printf("  > Data Plane:   %s\n", data_plane_active ? " ACTIVE (Signal Detected)" : " DISCONNECTED");
    printf("  > Health:       %s\n", err_flag ? " FAULT DETECTED" : " NOMINAL");

    // --- CAPABILITIES ---
    fpga_read_reg(hfpga, FPGA_REG_LINK_CAPS, &caps);
    printf("Link Config:      [0x%02X]\n", caps);
    printf("  > Interface:    %s\n", get_phy_type_str(caps));
    printf("  > Max Clock:    %s\n", get_clk_str(caps));
    printf("  > DMA Engine:   %s\n", (caps & 0x04) ? "Enabled" : "Disabled");

    printf("--------------------------------\n");
    printf("[DIAG] Report Complete.\n\n");
}
