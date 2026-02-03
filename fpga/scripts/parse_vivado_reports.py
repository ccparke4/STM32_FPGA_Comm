import os
import argparse
import numpy as np
import matplotlib.pyplot as plt

# Basys 3 Limits (XC7A35T)
BOARD_LIMITS = { 'LUT': 20800, 'FF': 41600, 'BRAM': 50, 'DSP': 90 }

def parse_csv(csv_path):
    data = {}
    if not os.path.exists(csv_path): return data
    with open(csv_path, 'r') as f:
        for line in f:
            parts = line.strip().split(',')
            if len(parts) < 2 or parts[0] == 'metric': continue
            try: data[parts[0]] = float(parts[1])
            except: continue
    return data

def safe_get(data, key): return data.get(key, 0)

def generate_dashboard(data, output_dir):
    if not os.path.exists(output_dir): os.makedirs(output_dir)

    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle(f"FPGA Analysis (Basys 3)", fontsize=16)

    # --- PLOT 1: Main Resources ---
    metrics = ['LUTs', 'Registers', 'BRAM', 'DSP']
    synth_vals = [safe_get(data, 'synth_lut'), safe_get(data, 'synth_ff'), safe_get(data, 'synth_bram'), safe_get(data, 'synth_dsp')]
    impl_vals  = [safe_get(data, 'impl_lut'), safe_get(data, 'impl_ff'), safe_get(data, 'impl_bram'), safe_get(data, 'impl_dsp')]
    
    x = np.arange(len(metrics))
    width = 0.35
    ax1.bar(x - width/2, synth_vals, width, label='Synthesis', color='#3498db')
    ax1.bar(x + width/2, impl_vals, width, label='Implementation', color='#2ecc71')
    ax1.set_title('Primary Resource Usage')
    ax1.set_xticks(x); ax1.set_xticklabels(metrics)
    ax1.legend()
    ax1.grid(axis='y', linestyle='--', alpha=0.5)

    # --- PLOT 2: Timing ---
    timings = ['Setup (WNS)', 'Hold (WHS)']
    vals = [safe_get(data, 'impl_wns'), safe_get(data, 'impl_whs')]
    colors = ['#27ae60' if v >= 0 else '#c0392b' for v in vals]
    ax2.bar(timings, vals, color=colors, width=0.5)
    ax2.axhline(0, color='k')
    ax2.set_title('Timing Slack (Post-Route)')
    ax2.set_ylabel('ns')
    for i, v in enumerate(vals):
        ax2.text(i, v + (0.1 if v>=0 else -0.5), f"{v:.2f}", ha='center', fontweight='bold')

    # --- PLOT 3: Logic Primitives (NEW) ---
    # Compare LUT vs MUXF7 vs CARRY4
    prims = ['LUTs', 'MUXF7', 'MUXF8', 'CARRY4']
    prim_vals = [
        safe_get(data, 'impl_lut'), 
        safe_get(data, 'impl_muxf7'), 
        safe_get(data, 'impl_muxf8'), 
        safe_get(data, 'impl_carry')
    ]
    # Log scale often helps here because LUTs >> Muxes
    ax3.bar(prims, prim_vals, color='#9b59b6')
    ax3.set_title('Logic Primitives Breakdown (Log Scale)')
    ax3.set_yscale('log')
    ax3.set_ylabel('Count (Log)')
    for i, v in enumerate(prim_vals):
        ax3.text(i, v, f"{int(v)}", ha='center', va='bottom', fontsize=9)

    # --- PLOT 4: Performance Gauge ---
    freq = safe_get(data, 'max_freq')
    power = safe_get(data, 'total_power')
    ax4.text(0.5, 0.7, f"{freq:.1f} MHz", ha='center', fontsize=26, color='#8e44ad', fontweight='bold')
    ax4.text(0.5, 0.55, "Max Frequency", ha='center', fontsize=12)
    ax4.text(0.5, 0.3, f"{power:.3f} W", ha='center', fontsize=26, color='#e67e22', fontweight='bold')
    ax4.text(0.5, 0.15, "Total Power", ha='center', fontsize=12)
    ax4.axis('off')

    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    plt.savefig(os.path.join(output_dir, 'design_dashboard.png'), dpi=100)
    plt.close()

def generate_markdown(data, output_file):
    def status(val): return "[PASS]" if val >= 0 else "[FAIL]"
    
    md = f"""
# FPGA Design Report
**Device:** XC7A35T (Basys 3)

## 1. High-Level Metrics
| Metric | Value | Status |
| :--- | :--- | :--- |
| **Max Frequency** | **{safe_get(data, 'max_freq'):.1f} MHz** | - |
| **Setup Slack** | {safe_get(data, 'impl_wns')} ns | {status(safe_get(data, 'impl_wns'))} |
| **Hold Slack** | {safe_get(data, 'impl_whs')} ns | {status(safe_get(data, 'impl_whs'))} |
| **Power** | {safe_get(data, 'total_power'):.3f} W | - |

## 2. Resource Utilization
| Resource | Synth | Impl | Limit | Utilization |
| :--- | :--- | :--- | :--- | :--- |
| **LUT** | {int(safe_get(data, 'synth_lut'))} | {int(safe_get(data, 'impl_lut'))} | {BOARD_LIMITS['LUT']} | {safe_get(data, 'impl_lut')/BOARD_LIMITS['LUT']*100:.1f}% |
| **FF** | {int(safe_get(data, 'synth_ff'))} | {int(safe_get(data, 'impl_ff'))} | {BOARD_LIMITS['FF']} | {safe_get(data, 'impl_ff')/BOARD_LIMITS['FF']*100:.1f}% |
| **BRAM** | {safe_get(data, 'synth_bram'):.1f} | {safe_get(data, 'impl_bram'):.1f} | {BOARD_LIMITS['BRAM']} | {safe_get(data, 'impl_bram')/BOARD_LIMITS['BRAM']*100:.1f}% |
| **DSP** | {int(safe_get(data, 'synth_dsp'))} | {int(safe_get(data, 'impl_dsp'))} | {BOARD_LIMITS['DSP']} | {safe_get(data, 'impl_dsp')/BOARD_LIMITS['DSP']*100:.1f}% |

## 3. Logic Primitives Breakdown
This section details specific hardware primitives used (Hardware-level analysis).

| Primitive | Count | Purpose |
| :--- | :--- | :--- |
| **MUXF7** | {int(safe_get(data, 'impl_muxf7'))} | Used to combine 2 LUTs (for 5-8 input functions). |
| **MUXF8** | {int(safe_get(data, 'impl_muxf8'))} | Used to combine 2 MUXF7s (for larger muxes). |
| **CARRY4** | {int(safe_get(data, 'impl_carry'))} | Dedicated Fast Carry Logic for adders/counters. |

![Dashboard](charts/design_dashboard.png)
    """
    with open(output_file, 'w', encoding='utf-8') as f: f.write(md)
    print(f"Report saved to {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-r", "--report_dir", default="reports")
    parser.add_argument("-o", "--output", default="docs/Design_Report.md")
    args = parser.parse_args()
    
    csv_path = os.path.join(args.report_dir, "synthesis_summary.csv")
    data = parse_csv(csv_path)
    chart_dir = os.path.dirname(args.output) + "/charts"
    generate_dashboard(data, chart_dir)
    generate_markdown(data, args.output)