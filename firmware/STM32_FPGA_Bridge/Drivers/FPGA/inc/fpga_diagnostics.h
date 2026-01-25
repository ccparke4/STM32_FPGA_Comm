/*
 * fpga_diagnostics.h
 *
 *  Created on: Jan 25, 2026
 *      Author: treyparker
 */

#ifndef FPGA_INC_FPGA_DIAGNOSTICS_H_
#define FPGA_INC_FPGA_DIAGNOSTICS_H_

#include "fpga_link.h"

/**
 * @brief Reads all system registers and prints a formatted report to stdout.
 * @param hfpga Pointer to the initialized FPGA handle
 */
void fpga_diagnostics_print_system_info(fpga_handle_t *hfpga);

#endif /* FPGA_INC_FPGA_DIAGNOSTICS_H_ */
