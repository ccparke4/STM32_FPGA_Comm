#!/usr/bin/env python3
"""
Vivado Report Parser & Documentation Generator with Matplotlib Visualizations
File: parse_vivado_reports.py

Parses Vivado synthesis/implementation reports and generates:
- Formatted markdown documentation
- Per-module resource breakdown
- Timing analysis summary
- Matplotlib charts (utilization bars, pie charts, timing graphs)

Usage:
    python parse_vivado_reports.py --report-dir ../reports --output ../docs/Synthesis_Report.md
    python parse_vivado_reports.py --no-charts  # Skip chart generation
    python parse_vivado_reports.py --help

Requirements:
    pip install matplotlib

Author: Schvrey
Date: February 2026
"""

import argparse
import json
import csv
import re
import math
from pathlib import Path
from datetime import datetime
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

# Try to import matplotlib
try:
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
    from matplotlib.ticker import MaxNLocator
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    MATPLOTLIB_AVAILABLE = False
    print("WARNING: matplotlib not installed. Charts will be skipped.")
    print("Install with: pip install matplotlib")


@dataclass
class ModuleStats:
    """Resource statistics for a single module."""
    name: str
    luts: int = 0
    ffs: int = 0
    bram: float = 0.0
    dsp: int = 0
    parent: str = ""
    
    @property
    def total_resources(self) -> int:
        return self.luts + self.ffs


@dataclass
class TimingInfo:
    """Timing analysis results."""
    clock_period_ns: float = 10.0
    wns_ns: float = 0.0
    tns_ns: float = 0.0
    whs_ns: float = 0.0
    ths_ns: float = 0.0
    
    @property
    def max_freq_mhz(self) -> float:
        if self.wns_ns >= self.clock_period_ns:
            return 0.0
        return 1000.0 / (self.clock_period_ns - self.wns_ns)
    
    @property
    def timing_met(self) -> bool:
        return self.wns_ns >= 0 and self.whs_ns >= 0


@dataclass
class SynthesisReport:
    """Complete synthesis/implementation results."""
    project: str = ""
    part: str = ""
    top_module: str = ""
    timestamp: str = ""
    
    lut_used: int = 0
    lut_available: int = 20800
    ff_used: int = 0
    ff_available: int = 41600
    bram_used: float = 0.0
    bram_available: int = 50
    dsp_used: int = 0
    dsp_available: int = 90
    
    timing: TimingInfo = field(default_factory=TimingInfo)
    synth_time_sec: int = 0
    impl_time_sec: int = 0
    modules: List[ModuleStats] = field(default_factory=list)
    
    @property
    def lut_percent(self) -> float:
        return 100.0 * self.lut_used / self.lut_available if self.lut_available else 0
    
    @property
    def ff_percent(self) -> float:
        return 100.0 * self.ff_used / self.ff_available if self.ff_available else 0
    
    @property
    def bram_percent(self) -> float:
        return 100.0 * self.bram_used / self.bram_available if self.bram_available else 0
    
    @property
    def dsp_percent(self) -> float:
        return 100.0 * self.dsp_used / self.dsp_available if self.dsp_available else 0


class VivadoParser:
    """Parses various Vivado report formats."""
    
    def __init__(self, report_dir: Path):
        self.report_dir = report_dir
        self.report = SynthesisReport()
    
    def parse_all(self) -> SynthesisReport:
        """Parse all available reports."""
        self._parse_json_summary()
        self._parse_csv_summary()
        self._parse_utilization_report()
        self._parse_hierarchical_utilization()
        self._parse_timing_summary()
        self._parse_module_report()
        return self.report
    
    def _parse_json_summary(self):
        json_path = self.report_dir / "synthesis_summary.json"
        if not json_path.exists():
            return
        
        with open(json_path, 'r') as f:
            data = json.load(f)
        
        self.report.project = data.get('project', '')
        self.report.part = data.get('part', '')
        self.report.top_module = data.get('top_module', '')
        self.report.timestamp = data.get('generated', '')
        
        util = data.get('utilization', {})
        self.report.lut_used = util.get('lut', {}).get('used', 0)
        self.report.lut_available = util.get('lut', {}).get('available', 20800)
        self.report.ff_used = util.get('ff', {}).get('used', 0)
        self.report.ff_available = util.get('ff', {}).get('available', 41600)
        
        timing = data.get('timing', {})
        self.report.timing.clock_period_ns = timing.get('clock_period_ns', 10.0)
        self.report.timing.wns_ns = timing.get('wns_ns', 0.0)
        
        build = data.get('build_time', {})
        self.report.synth_time_sec = build.get('synthesis_sec', 0)
        self.report.impl_time_sec = build.get('implementation_sec', 0)
    
    def _parse_csv_summary(self):
        csv_path = self.report_dir / "synthesis_summary.csv"
        if not csv_path.exists():
            return
        
        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                metric = row.get('metric', '')
                value = row.get('value', '0')
                
                if metric == 'lut_used':
                    self.report.lut_used = int(value)
                elif metric == 'ff_used':
                    self.report.ff_used = int(value)
                elif metric == 'wns':
                    self.report.timing.wns_ns = float(value)
    
    def _parse_utilization_report(self):
        for filename in ['utilization_impl.rpt', 'utilization_synth.rpt']:
            rpt_path = self.report_dir / filename
            if rpt_path.exists():
                break
        else:
            return
        
        with open(rpt_path, 'r') as f:
            content = f.read()
        
        match = re.search(r'Slice LUTs\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)', content)
        if match:
            self.report.lut_used = int(match.group(1))
            self.report.lut_available = int(match.group(2))
        
        match = re.search(r'Slice Registers\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)', content)
        if match:
            self.report.ff_used = int(match.group(1))
            self.report.ff_available = int(match.group(2))
        
        match = re.search(r'Block RAM Tile\s*\|\s*([\d.]+)\s*\|\s*\d+\s*\|\s*(\d+)', content)
        if match:
            self.report.bram_used = float(match.group(1))
            self.report.bram_available = int(match.group(2))
        
        match = re.search(r'DSPs\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)', content)
        if match:
            self.report.dsp_used = int(match.group(1))
            self.report.dsp_available = int(match.group(2))
    
    def _parse_hierarchical_utilization(self):
        rpt_path = self.report_dir / "utilization_hierarchical.rpt"
        if not rpt_path.exists():
            return
        
        with open(rpt_path, 'r') as f:
            content = f.read()
        
        patterns = [
            r'\|\s*([^\|]+)\s*\|\s*([^\|]+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*([\d.]+)\s*\|\s*(\d+)\s*\|',
            r'^\s*(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+([\d.]+)\s+(\d+)',
        ]
        
        for pattern in patterns:
            matches = re.finditer(pattern, content, re.MULTILINE)
            for match in matches:
                instance = match.group(1).strip()
                module = match.group(2).strip()
                
                if instance in ['Instance', '---', '(top)', ''] or instance.startswith('-'):
                    continue
                
                mod = ModuleStats(
                    name=instance,
                    luts=int(match.group(3)),
                    ffs=int(match.group(4)),
                    bram=float(match.group(5)),
                    dsp=int(match.group(6)),
                    parent=module
                )
                self.report.modules.append(mod)
            
            if self.report.modules:
                break
    
    def _parse_timing_summary(self):
        for subdir in ['timing', '']:
            for filename in ['timing_impl_summary.rpt', 'timing_synth_summary.rpt', 'timing_summary.rpt']:
                rpt_path = self.report_dir / subdir / filename if subdir else self.report_dir / filename
                if rpt_path.exists():
                    break
            else:
                continue
            break
        else:
            return
        
        with open(rpt_path, 'r') as f:
            content = f.read()
        
        match = re.search(r'WNS\(ns\)\s+TNS\(ns\).*?\n\s*(-?[\d.]+)\s+(-?[\d.]+)', content, re.DOTALL)
        if match:
            self.report.timing.wns_ns = float(match.group(1))
            self.report.timing.tns_ns = float(match.group(2))
        
        match = re.search(r'WHS\(ns\)\s+THS\(ns\).*?\n\s*(-?[\d.]+)\s+(-?[\d.]+)', content, re.DOTALL)
        if match:
            self.report.timing.whs_ns = float(match.group(1))
            self.report.timing.ths_ns = float(match.group(2))
    
    def _parse_module_report(self):
        rpt_path = self.report_dir / "modules" / "module_utilization.rpt"
        if not rpt_path.exists():
            return
        
        with open(rpt_path, 'r') as f:
            lines = f.readlines()
        
        for line in lines:
            if line.startswith('=') or line.startswith('-') or 'Module' in line:
                continue
            
            parts = line.split()
            if len(parts) >= 5:
                mod = ModuleStats(
                    name=parts[0],
                    luts=int(parts[1]),
                    ffs=int(parts[2]),
                    bram=float(parts[3]) if '.' in parts[3] else int(parts[3]),
                    dsp=int(parts[4])
                )
                if not any(m.name == mod.name for m in self.report.modules):
                    self.report.modules.append(mod)


class ChartGenerator:
    """Generates matplotlib charts for synthesis reports."""
    
    def __init__(self, report: SynthesisReport, output_dir: Path):
        self.report = report
        self.output_dir = output_dir
        self.charts_dir = output_dir / "charts"
        self.charts_dir.mkdir(parents=True, exist_ok=True)
        
        # Professional color scheme
        self.colors = {
            'primary': '#2563eb',
            'secondary': '#7c3aed',
            'success': '#10b981',
            'warning': '#f59e0b',
            'danger': '#ef4444',
            'gray': '#6b7280',
            'light_gray': '#e5e7eb',
            'dark': '#1f2937',
        }
        
        # Set style
        plt.rcParams['font.family'] = 'sans-serif'
        plt.rcParams['font.size'] = 10
        plt.rcParams['axes.titlesize'] = 12
        plt.rcParams['axes.titleweight'] = 'bold'
        plt.rcParams['axes.grid'] = True
        plt.rcParams['grid.alpha'] = 0.3
    
    def generate_all(self) -> List[str]:
        """Generate all charts and return list of file paths."""
        charts = []
        
        if not MATPLOTLIB_AVAILABLE:
            return charts
        
        path = self._generate_utilization_bars()
        if path:
            charts.append(path)
        
        path = self._generate_module_pie()
        if path:
            charts.append(path)
        
        path = self._generate_module_bars()
        if path:
            charts.append(path)
        
        path = self._generate_timing_chart()
        if path:
            charts.append(path)
        
        path = self._generate_dashboard()
        if path:
            charts.append(path)
        
        return charts
    
    def _generate_utilization_bars(self) -> Optional[str]:
        """Generate resource utilization bar chart."""
        fig, ax = plt.subplots(figsize=(10, 6))
        
        resources = ['LUTs', 'Flip-Flops', 'BRAM', 'DSP']
        used = [self.report.lut_used, self.report.ff_used, 
                self.report.bram_used, self.report.dsp_used]
        available = [self.report.lut_available, self.report.ff_available,
                     self.report.bram_available, self.report.dsp_available]
        percentages = [self.report.lut_percent, self.report.ff_percent,
                       self.report.bram_percent, self.report.dsp_percent]
        
        x = range(len(resources))
        bar_width = 0.35
        
        # Available (background)
        ax.bar([i - bar_width/2 for i in x], available, bar_width, 
               label='Available', color=self.colors['light_gray'], 
               edgecolor=self.colors['gray'], linewidth=1)
        
        # Used (foreground)
        bar_colors = [self.colors['success'] if p < 70 else 
                      self.colors['warning'] if p < 90 else 
                      self.colors['danger'] for p in percentages]
        bars_used = ax.bar([i + bar_width/2 for i in x], used, bar_width,
                          label='Used', color=bar_colors,
                          edgecolor=self.colors['dark'], linewidth=1)
        
        # Add percentage labels
        for i, (bar, pct) in enumerate(zip(bars_used, percentages)):
            height = bar.get_height()
            ax.annotate(f'{pct:.1f}%',
                       xy=(bar.get_x() + bar.get_width()/2, height),
                       xytext=(0, 5), textcoords='offset points',
                       ha='center', va='bottom', fontweight='bold', fontsize=11)
        
        ax.set_xlabel('Resource Type', fontweight='bold')
        ax.set_ylabel('Count', fontweight='bold')
        ax.set_title('FPGA Resource Utilization\n(Artix-7 xc7a35t)', fontsize=14)
        ax.set_xticks(x)
        ax.set_xticklabels(resources)
        ax.legend(loc='upper right')
        ax.set_ylim(0, max(available) * 1.15)
        
        plt.tight_layout()
        
        filepath = self.charts_dir / 'utilization_bars.png'
        fig.savefig(filepath, dpi=150, bbox_inches='tight', facecolor='white')
        plt.close(fig)
        
        return str(filepath)
    
    def _generate_module_pie(self) -> Optional[str]:
        """Generate module LUT breakdown pie chart."""
        if not self.report.modules:
            return None
        
        sorted_modules = sorted(self.report.modules, key=lambda m: m.luts, reverse=True)
        top_modules = sorted_modules[:6]
        
        if not top_modules or sum(m.luts for m in top_modules) == 0:
            return None
        
        fig, ax = plt.subplots(figsize=(10, 8))
        
        labels = [self._clean_module_name(m.name) for m in top_modules]
        sizes = [m.luts for m in top_modules]
        
        colors = ['#2563eb', '#7c3aed', '#10b981', '#f59e0b', '#ef4444', '#6b7280']
        
        wedges, texts, autotexts = ax.pie(
            sizes, labels=labels, autopct='%1.1f%%',
            colors=colors[:len(sizes)],
            explode=[0.02] * len(sizes),
            shadow=False, startangle=90,
            pctdistance=0.75, labeldistance=1.1
        )
        
        for text in texts:
            text.set_fontsize(10)
            text.set_fontweight('bold')
        for autotext in autotexts:
            autotext.set_fontsize(9)
            autotext.set_color('white')
            autotext.set_fontweight('bold')
        
        ax.set_title('LUT Distribution by Module', fontsize=14, fontweight='bold', pad=20)
        
        legend_labels = [f'{l} ({s} LUTs)' for l, s in zip(labels, sizes)]
        ax.legend(wedges, legend_labels, title="Modules", loc="center left",
                 bbox_to_anchor=(1, 0, 0.5, 1))
        
        plt.tight_layout()
        
        filepath = self.charts_dir / 'module_pie.png'
        fig.savefig(filepath, dpi=150, bbox_inches='tight', facecolor='white')
        plt.close(fig)
        
        return str(filepath)
    
    def _generate_module_bars(self) -> Optional[str]:
        """Generate horizontal bar chart of module resources."""
        if not self.report.modules:
            return None
        
        sorted_modules = sorted(self.report.modules, key=lambda m: m.luts, reverse=True)[:8]
        
        if not sorted_modules:
            return None
        
        fig, ax = plt.subplots(figsize=(10, 6))
        
        names = [self._clean_module_name(m.name) for m in sorted_modules]
        luts = [m.luts for m in sorted_modules]
        ffs = [m.ffs for m in sorted_modules]
        
        y = range(len(names))
        height = 0.35
        
        bars1 = ax.barh([i - height/2 for i in y], luts, height, 
                       label='LUTs', color=self.colors['primary'])
        bars2 = ax.barh([i + height/2 for i in y], ffs, height,
                       label='Flip-Flops', color=self.colors['secondary'])
        
        for bar in bars1:
            width = bar.get_width()
            if width > 0:
                ax.annotate(f'{int(width)}',
                           xy=(width, bar.get_y() + bar.get_height()/2),
                           xytext=(3, 0), textcoords='offset points',
                           ha='left', va='center', fontsize=9)
        
        for bar in bars2:
            width = bar.get_width()
            if width > 0:
                ax.annotate(f'{int(width)}',
                           xy=(width, bar.get_y() + bar.get_height()/2),
                           xytext=(3, 0), textcoords='offset points',
                           ha='left', va='center', fontsize=9)
        
        ax.set_xlabel('Resource Count', fontweight='bold')
        ax.set_ylabel('Module', fontweight='bold')
        ax.set_title('Per-Module Resource Utilization', fontsize=14, fontweight='bold')
        ax.set_yticks(y)
        ax.set_yticklabels(names)
        ax.legend(loc='lower right')
        
        plt.tight_layout()
        
        filepath = self.charts_dir / 'module_bars.png'
        fig.savefig(filepath, dpi=150, bbox_inches='tight', facecolor='white')
        plt.close(fig)
        
        return str(filepath)
    
    def _generate_timing_chart(self) -> Optional[str]:
        """Generate timing margin visualization."""
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
        
        self._draw_timing_gauge(ax1, self.report.timing.wns_ns, 
                               self.report.timing.clock_period_ns, "Setup Timing (WNS)")
        self._draw_timing_gauge(ax2, self.report.timing.whs_ns,
                               self.report.timing.clock_period_ns, "Hold Timing (WHS)")
        
        fig.suptitle('Timing Analysis Summary', fontsize=14, fontweight='bold', y=1.02)
        plt.tight_layout()
        
        filepath = self.charts_dir / 'timing_chart.png'
        fig.savefig(filepath, dpi=150, bbox_inches='tight', facecolor='white')
        plt.close(fig)
        
        return str(filepath)
    
    def _draw_timing_gauge(self, ax, slack: float, period: float, title: str):
        """Draw a timing margin gauge."""
        ax.set_xlim(-1.5, 1.5)
        ax.set_ylim(-0.2, 1.5)
        ax.set_aspect('equal')
        ax.axis('off')
        
        if slack >= period * 0.2:
            color = self.colors['success']
            status = "EXCELLENT"
        elif slack >= 0:
            color = self.colors['warning']
            status = "MET"
        else:
            color = self.colors['danger']
            status = "VIOLATED"
        
        # Draw arc background
        theta = [i * math.pi / 180 for i in range(0, 181, 1)]
        x_arc = [1.0 * math.cos(t) for t in theta]
        y_arc = [1.0 * math.sin(t) for t in theta]
        ax.plot(x_arc, y_arc, color=self.colors['light_gray'], linewidth=20, solid_capstyle='round')
        
        # Calculate fill angle
        max_slack = period * 0.5
        fill_ratio = min(1.0, max(0, (slack + max_slack) / (2 * max_slack)))
        fill_angle = int(fill_ratio * 180)
        
        # Draw arc fill
        theta_fill = [i * math.pi / 180 for i in range(0, fill_angle + 1, 1)]
        x_fill = [1.0 * math.cos(t) for t in theta_fill]
        y_fill = [1.0 * math.sin(t) for t in theta_fill]
        if len(x_fill) > 1:
            ax.plot(x_fill, y_fill, color=color, linewidth=18, solid_capstyle='round')
        
        ax.text(0, 0.5, f"{slack:.3f} ns", ha='center', va='center', 
               fontsize=24, fontweight='bold', color=self.colors['dark'])
        ax.text(0, 0.15, status, ha='center', va='center',
               fontsize=14, fontweight='bold', color=color)
        ax.text(0, -0.1, title, ha='center', va='center',
               fontsize=11, color=self.colors['gray'])
    
    def _generate_dashboard(self) -> Optional[str]:
        """Generate a combined dashboard with all key metrics."""
        fig = plt.figure(figsize=(14, 10))
        
        gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)
        
        fig.suptitle(f'Synthesis Dashboard: {self.report.project or "STM32-FPGA Bridge"}',
                    fontsize=16, fontweight='bold', y=0.98)
        
        ax1 = fig.add_subplot(gs[0, :2])
        self._draw_utilization_summary(ax1)
        
        ax2 = fig.add_subplot(gs[0, 2])
        self._draw_timing_status(ax2)
        
        ax3 = fig.add_subplot(gs[1, :])
        self._draw_module_breakdown(ax3)
        
        ax4 = fig.add_subplot(gs[2, 0])
        self._draw_key_metrics(ax4)
        
        ax5 = fig.add_subplot(gs[2, 1])
        self._draw_resource_availability(ax5)
        
        ax6 = fig.add_subplot(gs[2, 2])
        self._draw_build_info(ax6)
        
        filepath = self.charts_dir / 'dashboard.png'
        fig.savefig(filepath, dpi=150, bbox_inches='tight', facecolor='white')
        plt.close(fig)
        
        return str(filepath)
    
    def _draw_utilization_summary(self, ax):
        resources = ['LUTs', 'FFs', 'BRAM', 'DSP']
        percentages = [self.report.lut_percent, self.report.ff_percent,
                      self.report.bram_percent, self.report.dsp_percent]
        
        colors = [self.colors['success'] if p < 70 else 
                  self.colors['warning'] if p < 90 else 
                  self.colors['danger'] for p in percentages]
        
        bars = ax.barh(resources, percentages, color=colors, edgecolor=self.colors['dark'])
        
        for bar, pct in zip(bars, percentages):
            ax.annotate(f'{pct:.1f}%',
                       xy=(bar.get_width() + 1, bar.get_y() + bar.get_height()/2),
                       va='center', fontsize=10, fontweight='bold')
        
        ax.set_xlim(0, 100)
        ax.set_xlabel('Utilization %')
        ax.set_title('Resource Utilization', fontweight='bold')
        ax.axvline(x=70, color=self.colors['warning'], linestyle='--', alpha=0.5)
        ax.axvline(x=90, color=self.colors['danger'], linestyle='--', alpha=0.5)
    
    def _draw_timing_status(self, ax):
        ax.axis('off')
        
        met = self.report.timing.timing_met
        color = self.colors['success'] if met else self.colors['danger']
        status = "✓ TIMING MET" if met else "✗ VIOLATION"
        
        circle = plt.Circle((0.5, 0.6), 0.3, color=color, alpha=0.2)
        ax.add_patch(circle)
        ax.text(0.5, 0.6, status, ha='center', va='center',
               fontsize=12, fontweight='bold', color=color)
        ax.text(0.5, 0.2, f"WNS: {self.report.timing.wns_ns:.3f} ns",
               ha='center', fontsize=10)
        ax.set_xlim(0, 1)
        ax.set_ylim(0, 1)
        ax.set_title('Timing Status', fontweight='bold')
    
    def _draw_module_breakdown(self, ax):
        if not self.report.modules:
            ax.text(0.5, 0.5, 'No module data available', ha='center', va='center')
            ax.axis('off')
            return
        
        sorted_modules = sorted(self.report.modules, key=lambda m: m.luts, reverse=True)[:6]
        names = [self._clean_module_name(m.name) for m in sorted_modules]
        luts = [m.luts for m in sorted_modules]
        
        bars = ax.bar(names, luts, color=self.colors['primary'], edgecolor=self.colors['dark'])
        
        for bar in bars:
            ax.annotate(f'{int(bar.get_height())}',
                       xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                       xytext=(0, 3), textcoords='offset points',
                       ha='center', fontsize=9)
        
        ax.set_ylabel('LUTs')
        ax.set_title('Per-Module LUT Usage', fontweight='bold')
        ax.tick_params(axis='x', rotation=30)
    
    def _draw_key_metrics(self, ax):
        ax.axis('off')
        
        metrics = [
            f"Max Freq: {self.report.timing.max_freq_mhz:.1f} MHz",
            f"Total LUTs: {self.report.lut_used:,}",
            f"Total FFs: {self.report.ff_used:,}",
            f"Part: {self.report.part or 'xc7a35t'}"
        ]
        
        for i, metric in enumerate(metrics):
            ax.text(0.1, 0.85 - i*0.22, metric, fontsize=10, 
                   transform=ax.transAxes, fontweight='bold')
        
        ax.set_title('Key Metrics', fontweight='bold')
    
    def _draw_resource_availability(self, ax):
        used = self.report.lut_used
        available = self.report.lut_available - used
        
        ax.pie([used, available], labels=['Used', 'Available'],
              colors=[self.colors['primary'], self.colors['light_gray']],
              autopct='%1.1f%%', startangle=90)
        ax.set_title('LUT Availability', fontweight='bold')
    
    def _draw_build_info(self, ax):
        ax.axis('off')
        
        info = [
            f"Synth Time: {self.report.synth_time_sec}s",
            f"Impl Time: {self.report.impl_time_sec}s",
            f"Generated: {datetime.now().strftime('%Y-%m-%d')}",
            f"Vivado 2025.2"
        ]
        
        for i, line in enumerate(info):
            ax.text(0.1, 0.85 - i*0.22, line, fontsize=10, transform=ax.transAxes)
        
        ax.set_title('Build Info', fontweight='bold')
    
    def _clean_module_name(self, name: str) -> str:
        name = name.replace('_inst', '').replace('_i', '')
        if len(name) > 15:
            name = name[:12] + '...'
        return name


class MarkdownGenerator:
    """Generates professional markdown from synthesis results."""
    
    def __init__(self, report: SynthesisReport, charts_dir: Optional[Path] = None):
        self.report = report
        self.charts_dir = charts_dir
    
    def generate(self) -> str:
        sections = [
            self._title_section(),
            self._dashboard_section(),
            self._summary_section(),
            self._utilization_section(),
            self._module_breakdown_section(),
            self._timing_section(),
            self._recommendations_section(),
            self._footer_section()
        ]
        return '\n'.join(sections)
    
    def _progress_bar(self, percent: float, width: int = 20) -> str:
        filled = int(percent / 100 * width)
        return '█' * filled + '░' * (width - filled)
    
    def _title_section(self) -> str:
        return f"""# Synthesis & Implementation Report

**Project:** {self.report.project or 'STM32-FPGA Bridge'}  
**Target Device:** {self.report.part or 'xc7a35tcpg236-1 (Basys 3)'}  
**Top Module:** {self.report.top_module or 'top'}  
**Generated:** {self.report.timestamp or datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

---
"""
    
    def _dashboard_section(self) -> str:
        if not self.charts_dir or not (self.charts_dir / 'dashboard.png').exists():
            return ""
        return """## Dashboard

![Synthesis Dashboard](charts/dashboard.png)

---
"""
    
    def _summary_section(self) -> str:
        timing_status = "✅ Met" if self.report.timing.timing_met else "❌ Violated"
        lut_status = "✅" if self.report.lut_percent < 70 else "⚠️" if self.report.lut_percent < 90 else "❌"
        
        return f"""## Quick Summary

| Metric | Value | Status |
|--------|-------|--------|
| **LUT Utilization** | {self.report.lut_used:,} / {self.report.lut_available:,} ({self.report.lut_percent:.1f}%) | {lut_status} |
| **FF Utilization** | {self.report.ff_used:,} / {self.report.ff_available:,} ({self.report.ff_percent:.1f}%) | ✅ |
| **BRAM** | {self.report.bram_used} / {self.report.bram_available} | ✅ |
| **DSP** | {self.report.dsp_used} / {self.report.dsp_available} | ✅ |
| **Timing (Setup)** | WNS = {self.report.timing.wns_ns:.3f} ns | {timing_status} |
| **Max Frequency** | {self.report.timing.max_freq_mhz:.1f} MHz | {'✅' if self.report.timing.timing_met else '⚠️'} |

"""
    
    def _utilization_section(self) -> str:
        chart_embed = ""
        if self.charts_dir and (self.charts_dir / 'utilization_bars.png').exists():
            chart_embed = "\n![Resource Utilization](charts/utilization_bars.png)\n"
        
        return f"""## Resource Utilization
{chart_embed}
### Detailed Breakdown

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| Slice LUTs | {self.report.lut_used:,} | {self.report.lut_available:,} | `{self._progress_bar(self.report.lut_percent)}` {self.report.lut_percent:.1f}% |
| Slice FFs | {self.report.ff_used:,} | {self.report.ff_available:,} | `{self._progress_bar(self.report.ff_percent)}` {self.report.ff_percent:.1f}% |
| Block RAM | {self.report.bram_used} | {self.report.bram_available} | `{self._progress_bar(self.report.bram_percent)}` {self.report.bram_percent:.1f}% |
| DSP48 | {self.report.dsp_used} | {self.report.dsp_available} | `{self._progress_bar(self.report.dsp_percent)}` {self.report.dsp_percent:.1f}% |

"""
    
    def _module_breakdown_section(self) -> str:
        if not self.report.modules:
            return "## Per-Module Breakdown\n\n*No module data available.*\n\n"
        
        chart_embeds = ""
        if self.charts_dir:
            if (self.charts_dir / 'module_bars.png').exists():
                chart_embeds += "\n![Module Breakdown](charts/module_bars.png)\n"
            if (self.charts_dir / 'module_pie.png').exists():
                chart_embeds += "\n![Module Distribution](charts/module_pie.png)\n"
        
        sorted_modules = sorted(self.report.modules, key=lambda m: m.luts, reverse=True)
        
        lines = [f"## Per-Module Breakdown{chart_embeds}", "### Resource Table", "",
                 "| Module | LUTs | FFs | BRAM | DSP |",
                 "|--------|------|-----|------|-----|"]
        
        for mod in sorted_modules[:10]:
            lines.append(f"| `{mod.name}` | {mod.luts} | {mod.ffs} | {mod.bram} | {mod.dsp} |")
        
        lines.append("")
        return '\n'.join(lines)
    
    def _timing_section(self) -> str:
        chart_embed = ""
        if self.charts_dir and (self.charts_dir / 'timing_chart.png').exists():
            chart_embed = "\n![Timing Analysis](charts/timing_chart.png)\n"
        
        status = "✅ All timing constraints met" if self.report.timing.timing_met else "❌ Timing violations present"
        
        return f"""## Timing Analysis
{chart_embed}
### Summary

| Metric | Value |
|--------|-------|
| **WNS (Setup)** | {self.report.timing.wns_ns:.3f} ns |
| **TNS** | {self.report.timing.tns_ns:.3f} ns |
| **WHS (Hold)** | {self.report.timing.whs_ns:.3f} ns |
| **Max Frequency** | {self.report.timing.max_freq_mhz:.1f} MHz |

**Status:** {status}

"""
    
    def _recommendations_section(self) -> str:
        recs = []
        if self.report.lut_percent < 10:
            recs.append("- ✅ **Excellent efficiency** - ~90% resources available for Core IP")
        elif self.report.lut_percent < 30:
            recs.append("- ✅ **Good utilization** - Plenty of room for expansion")
        
        if self.report.timing.wns_ns > 2.0:
            recs.append(f"- ✅ **Strong timing margin** - {self.report.timing.wns_ns:.1f} ns slack")
        
        if self.report.bram_used == 0:
            recs.append("- 💡 **BRAM available** - Consider for FIFOs/buffering")
        
        return f"""## Recommendations

{chr(10).join(recs) if recs else "- Analysis pending actual synthesis data"}

"""
    
    def _footer_section(self) -> str:
        return f"""---

**Charts Generated:**
- `charts/dashboard.png` - Combined metrics
- `charts/utilization_bars.png` - Resource utilization
- `charts/module_bars.png` - Per-module breakdown
- `charts/module_pie.png` - LUT distribution
- `charts/timing_chart.png` - Timing gauges

*Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*
"""


def main():
    parser = argparse.ArgumentParser(description='Parse Vivado reports and generate markdown with charts')
    parser.add_argument('--report-dir', '-r', type=Path, default=Path('reports'),
                        help='Directory containing Vivado reports')
    parser.add_argument('--output', '-o', type=Path, default=Path('docs/Synthesis_Report.md'),
                        help='Output markdown file')
    parser.add_argument('--no-charts', action='store_true', help='Skip chart generation')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    args = parser.parse_args()
    
    args.output.parent.mkdir(parents=True, exist_ok=True)
    
    print(f"📂 Parsing reports from: {args.report_dir}")
    parser_obj = VivadoParser(args.report_dir)
    report = parser_obj.parse_all()
    
    if args.verbose:
        print(f"   LUTs: {report.lut_used}/{report.lut_available} ({report.lut_percent:.1f}%)")
        print(f"   FFs:  {report.ff_used}/{report.ff_available} ({report.ff_percent:.1f}%)")
        print(f"   WNS:  {report.timing.wns_ns:.3f} ns")
        print(f"   Modules: {len(report.modules)}")
    
    charts_dir = None
    if not args.no_charts and MATPLOTLIB_AVAILABLE:
        print(f"📊 Generating charts...")
        chart_gen = ChartGenerator(report, args.output.parent)
        charts = chart_gen.generate_all()
        charts_dir = chart_gen.charts_dir
        print(f"   Generated {len(charts)} charts in {charts_dir}")
    
    print(f"📝 Generating markdown...")
    generator = MarkdownGenerator(report, charts_dir)
    markdown = generator.generate()
    
    with open(args.output, 'w', encoding='utf-8') as f:
        f.write(markdown)
    
    print(f"✅ Report written to: {args.output}")
    if charts_dir:
        print(f"📈 Charts saved to: {charts_dir}/")


if __name__ == '__main__':
    main()