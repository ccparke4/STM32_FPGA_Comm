#!/usr/bin/env python3
"""
FPGA Report Generator with Hierarchical Module Analysis
Parses Vivado outputs and generates professional markdown + charts

Usage:
    python generate_report.py -r reports -o docs/Design_Report.md
"""

import os
import argparse
import csv
import matplotlib.pyplot as plt
import numpy as np

# Basys 3 Limits (XC7A35T)
LIMITS = {'LUT': 20800, 'FF': 41600, 'BRAM': 50, 'DSP': 90, 'IO': 106, 'BUFG': 32}

def parse_summary_csv(csv_path):
    """Parse synthesis_summary.csv into a dictionary."""
    data = {}
    if not os.path.exists(csv_path):
        print(f"WARNING: {csv_path} not found")
        return data
    with open(csv_path, 'r') as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) >= 2 and row[0] != 'metric':
                try:
                    data[row[0]] = float(row[1]) if '.' in row[1] else int(row[1])
                except ValueError:
                    data[row[0]] = row[1]
    return data

def parse_hierarchical_csv(csv_path):
    """Parse hierarchical_utilization.csv into list of module dicts."""
    modules = []
    if not os.path.exists(csv_path):
        print(f"WARNING: {csv_path} not found")
        return modules
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                modules.append({
                    'instance': row.get('instance', ''),
                    'module': row.get('module', ''),
                    'luts': int(row.get('luts', 0)),
                    'ffs': int(row.get('ffs', 0)),
                    'bram': float(row.get('bram', 0)),
                    'dsp': int(row.get('dsp', 0))
                })
            except (ValueError, KeyError):
                continue
    return modules

def parse_critical_path(txt_path):
    """Parse critical_path_summary.txt."""
    info = {}
    if not os.path.exists(txt_path):
        return info
    with open(txt_path, 'r') as f:
        for line in f:
            if ':' in line:
                parts = line.strip().split(':', 1)
                if len(parts) == 2:
                    key = parts[0].strip().lower().replace(' ', '_')
                    info[key] = parts[1].strip()
    return info

def safe_get(data, key, default=0):
    return data.get(key, default)

def pct(used, limit):
    return f"{used/limit*100:.2f}%" if limit > 0 else "0%"

def generate_charts(data, modules, output_dir):
    """Generate all matplotlib charts."""
    os.makedirs(output_dir, exist_ok=True)
    
    # --- Chart 1: Resource Usage Comparison ---
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('FPGA Build Analysis - STM32-FPGA Bridge', fontsize=14, fontweight='bold')
    
    # Top-left: Synth vs Impl
    ax1 = axes[0, 0]
    metrics = ['LUTs', 'FFs', 'BRAM', 'DSP']
    synth = [safe_get(data, 'synth_lut'), safe_get(data, 'synth_ff'),
             safe_get(data, 'synth_bram'), safe_get(data, 'synth_dsp')]
    impl = [safe_get(data, 'impl_lut'), safe_get(data, 'impl_ff'),
            safe_get(data, 'impl_bram'), safe_get(data, 'impl_dsp')]
    
    x = np.arange(len(metrics))
    w = 0.35
    ax1.bar(x - w/2, synth, w, label='Synthesis', color='#3498db')
    ax1.bar(x + w/2, impl, w, label='Implementation', color='#2ecc71')
    ax1.set_xticks(x)
    ax1.set_xticklabels(metrics)
    ax1.set_title('Resource Usage: Synthesis vs Implementation')
    ax1.legend()
    ax1.set_ylabel('Count')
    for i, (s, im) in enumerate(zip(synth, impl)):
        if im > 0:
            ax1.text(i + w/2, im, str(int(im)), ha='center', va='bottom', fontsize=9)
    
    # Top-right: Timing
    ax2 = axes[0, 1]
    wns = safe_get(data, 'impl_wns')
    whs = safe_get(data, 'impl_whs')
    timing_names = ['Setup (WNS)', 'Hold (WHS)']
    timing_vals = [wns, whs]
    colors = ['#27ae60' if v >= 0 else '#e74c3c' for v in timing_vals]
    bars = ax2.bar(timing_names, timing_vals, color=colors, width=0.5)
    ax2.axhline(0, color='k', linewidth=0.5)
    ax2.set_title('Timing Slack (ns)')
    ax2.set_ylabel('Slack (ns)')
    for bar, v in zip(bars, timing_vals):
        ax2.text(bar.get_x() + bar.get_width()/2, v + 0.1, f'{v:.2f}', 
                ha='center', fontweight='bold')
    
    # Bottom-left: Utilization %
    ax3 = axes[1, 0]
    resources = ['LUT', 'FF', 'BRAM', 'DSP', 'IO', 'BUFG']
    percentages = [
        safe_get(data, 'impl_lut') / LIMITS['LUT'] * 100,
        safe_get(data, 'impl_ff') / LIMITS['FF'] * 100,
        safe_get(data, 'impl_bram') / LIMITS['BRAM'] * 100,
        safe_get(data, 'impl_dsp') / LIMITS['DSP'] * 100,
        safe_get(data, 'impl_io') / LIMITS['IO'] * 100,
        safe_get(data, 'impl_bufg') / LIMITS['BUFG'] * 100,
    ]
    colors = ['#27ae60' if p < 50 else '#f39c12' if p < 80 else '#e74c3c' for p in percentages]
    bars = ax3.barh(resources, percentages, color=colors)
    ax3.set_xlim(0, 100)
    ax3.set_xlabel('Utilization %')
    ax3.set_title('Resource Utilization')
    ax3.axvline(50, color='#f39c12', linestyle='--', alpha=0.5)
    ax3.axvline(80, color='#e74c3c', linestyle='--', alpha=0.5)
    for bar, p in zip(bars, percentages):
        ax3.text(min(p + 2, 95), bar.get_y() + bar.get_height()/2, 
                f'{p:.1f}%', va='center', fontsize=9)
    
    # Bottom-right: Per-Module Breakdown
    ax4 = axes[1, 1]
    if modules:
        # Sort by LUTs, take top 6
        sorted_mods = sorted(modules, key=lambda m: m['luts'], reverse=True)[:6]
        names = [m['instance'][:12] for m in sorted_mods]
        luts = [m['luts'] for m in sorted_mods]
        ffs = [m['ffs'] for m in sorted_mods]
        
        x = np.arange(len(names))
        w = 0.35
        ax4.bar(x - w/2, luts, w, label='LUTs', color='#3498db')
        ax4.bar(x + w/2, ffs, w, label='FFs', color='#e74c3c')
        ax4.set_xticks(x)
        ax4.set_xticklabels(names, rotation=30, ha='right')
        ax4.set_title('Per-Module Resource Usage')
        ax4.legend()
        ax4.set_ylabel('Count')
    else:
        ax4.text(0.5, 0.5, 'No hierarchical data', ha='center', va='center', 
                transform=ax4.transAxes)
        ax4.set_title('Per-Module Resource Usage')
    
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    plt.savefig(os.path.join(output_dir, 'design_dashboard.png'), dpi=150)
    plt.close()
    
    # --- Chart 2: Module Pie Chart ---
    if modules:
        fig, ax = plt.subplots(figsize=(10, 8))
        sorted_mods = sorted(modules, key=lambda m: m['luts'], reverse=True)[:8]
        labels = [m['instance'] for m in sorted_mods]
        sizes = [m['luts'] for m in sorted_mods]
        
        if sum(sizes) > 0:
            colors = plt.cm.Set3(np.linspace(0, 1, len(sizes)))
            wedges, texts, autotexts = ax.pie(sizes, labels=labels, autopct='%1.1f%%',
                                               colors=colors, startangle=90)
            ax.set_title('LUT Distribution by Module', fontsize=14, fontweight='bold')
            plt.tight_layout()
            plt.savefig(os.path.join(output_dir, 'module_distribution.png'), dpi=150)
        plt.close()

def generate_markdown(data, modules, crit_path, output_file):
    """Generate professional markdown report."""
    
    wns = safe_get(data, 'impl_wns')
    whs = safe_get(data, 'impl_whs')
    freq = safe_get(data, 'max_freq')
    power = safe_get(data, 'total_power')
    
    # Module table
    module_rows = ""
    if modules:
        sorted_mods = sorted(modules, key=lambda m: m['luts'], reverse=True)
        total_luts = sum(m['luts'] for m in sorted_mods) or 1
        for m in sorted_mods[:10]:
            pct_total = m['luts'] / total_luts * 100
            module_rows += f"| `{m['instance']}` | {m['module']} | {m['luts']} | {m['ffs']} | {pct_total:.1f}% |\n"
    else:
        module_rows = "| *No data* | - | - | - | - |\n"
    
    # Critical path info
    crit_slack = crit_path.get('slack', 'N/A')
    crit_levels = crit_path.get('logic_levels', 'N/A')
    crit_start = crit_path.get('start_point', 'N/A')
    crit_end = crit_path.get('end_point', 'N/A')
    
    md = f"""# FPGA Synthesis & Implementation Report

**Project:** {safe_get(data, 'project', 'STM32-FPGA Bridge')}  
**Device:** {safe_get(data, 'part', 'xc7a35tcpg236-1')} (Basys 3)  
**Top Module:** {safe_get(data, 'top_module', 'top')}  
**Clock:** {safe_get(data, 'clock_period', 10.0)} ns (100 MHz)

---

## Executive Summary

| Metric | Value | Status |
|--------|-------|--------|
| **Max Frequency** | **{freq:.1f} MHz** | {'Large Headroom' if freq > 150 else 'Good Headroom' if freq > 100 else 'Marginal Headroom'} |
| **Setup Slack (WNS)** | {wns:.3f} ns | {'PASS' if wns >= 0 else 'FAIL'} |
| **Hold Slack (WHS)** | {whs:.3f} ns | {'PASS' if whs >= 0 else 'FAIL'} |
| **LUT Usage** | {pct(safe_get(data, 'impl_lut'), LIMITS['LUT'])} | Good |
| **Total Power** | {power:.3f} W | estimated |

---

## 1. Resource Utilization

### 1.1 Summary

| Resource | Synthesis | Implementation | Available | Utilization |
|----------|-----------|----------------|-----------|-------------|
| **Slice LUTs** | {int(safe_get(data, 'synth_lut'))} | {int(safe_get(data, 'impl_lut'))} | {LIMITS['LUT']:,} | {pct(safe_get(data, 'impl_lut'), LIMITS['LUT'])} |
| **Slice Registers** | {int(safe_get(data, 'synth_ff'))} | {int(safe_get(data, 'impl_ff'))} | {LIMITS['FF']:,} | {pct(safe_get(data, 'impl_ff'), LIMITS['FF'])} |
| **Block RAM** | {safe_get(data, 'synth_bram'):.1f} | {safe_get(data, 'impl_bram'):.1f} | {LIMITS['BRAM']} | {pct(safe_get(data, 'impl_bram'), LIMITS['BRAM'])} |
| **DSP48E1** | {int(safe_get(data, 'synth_dsp'))} | {int(safe_get(data, 'impl_dsp'))} | {LIMITS['DSP']} | {pct(safe_get(data, 'impl_dsp'), LIMITS['DSP'])} |
| **Bonded IOB** | {int(safe_get(data, 'synth_io'))} | {int(safe_get(data, 'impl_io'))} | {LIMITS['IO']} | {pct(safe_get(data, 'impl_io'), LIMITS['IO'])} |
| **BUFG** | {int(safe_get(data, 'synth_bufg'))} | {int(safe_get(data, 'impl_bufg'))} | {LIMITS['BUFG']} | {pct(safe_get(data, 'impl_bufg'), LIMITS['BUFG'])} |

### 1.2 Logic Primitives

| Primitive | Synthesis | Implementation | Purpose |
|-----------|-----------|----------------|---------|
| **LUT as Logic** | {int(safe_get(data, 'synth_lut'))} | {int(safe_get(data, 'impl_lut'))} | Combinational logic |
| **LUT as Memory** | {int(safe_get(data, 'synth_lutram'))} | {int(safe_get(data, 'impl_lutram'))} | Distributed RAM |
| **MUXF7** | {int(safe_get(data, 'synth_muxf7'))} | {int(safe_get(data, 'impl_muxf7'))} | Wide muxes (7-8 inputs) |
| **MUXF8** | {int(safe_get(data, 'synth_muxf8'))} | {int(safe_get(data, 'impl_muxf8'))} | Wider muxes |
| **CARRY4** | {int(safe_get(data, 'synth_carry'))} | {int(safe_get(data, 'impl_carry'))} | Fast carry chains |

---

## 2. Per-Module Breakdown

| Instance | Module | LUTs | FFs | % of Total |
|----------|--------|------|-----|------------|
{module_rows}

![Module Distribution](charts/module_distribution.png)

---

## 3. Timing Analysis

### 3.1 Summary

| Metric | Value |
|--------|-------|
| **Clock Period** | {safe_get(data, 'clock_period', 10.0)} ns |
| **Setup Slack (WNS)** | {wns:.3f} ns |
| **Hold Slack (WHS)** | {whs:.3f} ns |
| **Max Achievable Freq** | {freq:.1f} MHz |
| **Timing Margin** | {(freq/100 - 1)*100:.0f}% over 100 MHz |

### 3.2 Critical Path

| Property | Value |
|----------|-------|
| **Slack** | {crit_slack} |
| **Logic Levels** | {crit_levels} |
| **Start Point** | `{crit_start[:60]}...` |
| **End Point** | `{crit_end[:60]}...` |

---

## 4. Power Analysis

| Category | Power (W) |
|----------|-----------|
| **Dynamic** | {safe_get(data, 'dynamic_power', 0):.3f} |
| **Static** | {safe_get(data, 'static_power', 0):.3f} |
| **Total** | **{power:.3f}** |

---

## 5. Build Information

| Metric | Value |
|--------|-------|
| **Synthesis Time** | {int(safe_get(data, 'synth_time'))} sec |
| **Implementation Time** | {int(safe_get(data, 'impl_time'))} sec |
| **Total Build Time** | {int(safe_get(data, 'synth_time')) + int(safe_get(data, 'impl_time'))} sec |

---

## 6. Design Quality

### Strengths
- **{(wns/10)*100:.0f}% timing margin** on critical path
- **{100 - safe_get(data, 'impl_lut')/LIMITS['LUT']*100:.0f}% LUTs available** for Core IP expansion
- **Low power** ({power*1000:.0f} mW) - suitable for embedded applications

### Resource Headroom

| Future Feature | Est. LUTs | After Addition |
|----------------|-----------|----------------|
| DMA Engine | ~500 | {pct(safe_get(data, 'impl_lut') + 500, LIMITS['LUT'])} |
| Packet Processor | ~300 | {pct(safe_get(data, 'impl_lut') + 800, LIMITS['LUT'])} |
| Hardware CRC | ~100 | {pct(safe_get(data, 'impl_lut') + 900, LIMITS['LUT'])} |

---

![Design Dashboard](charts/design_dashboard.png)

---
*Generated automatically from Vivado reports*
"""
    
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(md)
    print(f"Report saved to: {output_file}")


def main():
    parser = argparse.ArgumentParser(description='Generate FPGA design report')
    parser.add_argument('-r', '--report-dir', default='reports', help='Vivado reports directory')
    parser.add_argument('-o', '--output', default='docs/Design_Report.md', help='Output markdown file')
    args = parser.parse_args()
    
    # Parse all data sources
    summary = parse_summary_csv(os.path.join(args.report_dir, 'synthesis_summary.csv'))
    modules = parse_hierarchical_csv(os.path.join(args.report_dir, 'hierarchical_utilization.csv'))
    crit_path = parse_critical_path(os.path.join(args.report_dir, 'critical_path_summary.txt'))
    
    print(f"Parsed {len(summary)} metrics from summary")
    print(f"Parsed {len(modules)} modules from hierarchical report")
    
    # Generate charts
    chart_dir = os.path.join(os.path.dirname(args.output), 'charts')
    generate_charts(summary, modules, chart_dir)
    print(f"Charts saved to: {chart_dir}/")
    
    # Generate markdown
    generate_markdown(summary, modules, crit_path, args.output)


if __name__ == '__main__':
    main()