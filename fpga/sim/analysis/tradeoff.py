import matplotlib.pyplot as plt
import numpy as np

def analyze_offload():
    # --- System Constants ---
    SPI_CLK_HZ = 25_000_000  # 25 MHz SPI Data Plane
    MCU_CLK_HZ = 550_000_000 # STM32 H7 Clock
    OVERHEAD_US = 5.0        # Interrupt/DMA setup latency (estimated)

    # --- Workload Constants (Example: AES Encryption) ---
    # Software: Takes ~20 cycles per byte on MCU
    CYCLES_PER_BYTE_SW = 20  
    # Hardware: Takes ~1 cycle per byte (pipelined) on FPGA
    CYCLES_PER_BYTE_HW = 1   

    # --- Sweep Data Sizes (Bytes) ---
    data_size = np.linspace(1, 4096, 100) # 1 byte to 4KB

    # --- Calculate Times (microseconds) ---
    
    # 1. STM32 Pure Software Time
    # Time = (Bytes * Cycles/Byte) / Frequency
    t_stm32 = (data_size * CYCLES_PER_BYTE_SW) / MCU_CLK_HZ * 1e6

    # 2. FPGA Offload Time
    # Time = Overhead + (Tx Time) + (FPGA Compute) + (Rx Time)
    # Tx/Rx Time = (Bytes * 8 bits) / SPI Frequency
    t_link_tx = (data_size * 8) / SPI_CLK_HZ * 1e6
    t_fpga_compute = (data_size * CYCLES_PER_BYTE_HW) / 100_000_000 * 1e6 # 100MHz FPGA
    t_link_rx = t_link_tx # Assume full round trip
    
    t_total_offload = OVERHEAD_US + t_link_tx + t_fpga_compute + t_link_rx

    # --- Plotting ---
    plt.figure(figsize=(10, 6))
    plt.plot(data_size, t_stm32, label='STM32 H7 (SW Only)', color='red')
    plt.plot(data_size, t_total_offload, label='FPGA Offload (SPI 25MHz)', color='blue')
    
    # Find intersection
    idx = np.argwhere(np.diff(np.sign(t_stm32 - t_total_offload))).flatten()
    if len(idx) > 0:
        breakeven = data_size[idx[0]]
        plt.plot(data_size[idx[0]], t_stm32[idx[0]], 'ko')
        plt.annotate(f'Breakeven: {int(breakeven)} Bytes', 
                     (breakeven, t_stm32[idx[0]]), xytext=(breakeven+100, t_stm32[idx[0]]-5))

    plt.title('Offload Feasibility: STM32 vs Artix-7 (SPI Link)')
    plt.xlabel('Data Batch Size (Bytes)')
    plt.ylabel('Total Execution Time (microseconds)')
    plt.legend()
    plt.grid(True)
    plt.show()

if __name__ == "__main__":
    analyze_offload()