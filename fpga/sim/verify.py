#!/usr/bin/env python3
"""
FPGA Verification Automation Script
====================================
Automates Vivado xsim-based verification for I2C/SPI co-processor.

Usage:
    python verify.py                    # Run all tests
    python verify.py --test basic_write # Run specific test
    python verify.py --list             # List available tests
    python verify.py --clean            # Clean build artifacts
    python verify.py --report results.json  # Specify output report

Author: Auto-generated for STM32H723ZG + Artix-7 FPGA Co-processor Project
"""

import argparse
import subprocess
import sys
import os
import json
import re
import shutil
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple

#==============================================================================
# Configuration
#==============================================================================

# Update this path to match your Vivado installation
VIVADO_PATHS = [
    "/tools/Xilinx/Vivado/2025.2/bin",
    "/opt/Xilinx/Vivado/2025.2/bin",
    "/tools/Xilinx/Vivado/2025.2/bin",
    "/opt/Xilinx/Vivado/2025.2/bin",
    "C:/Xilinx/Vivado/2025.2/bin",
    "C:/Xilinx/Vivado/2025.2/bin",
]

# Test registry - maps test names to descriptions
TESTS = {
    "basic_write":  "I2C write to writable registers with readback verification",
    "basic_read":   "I2C read from read-only registers (DEVICE_ID, VERSION)",
    "loopback":     "SPI loopback test - verify TX appears on next RX",
    "concurrent":   "Concurrent I2C and SPI operations",
    "stress":       "High-volume stress test with concurrent operations",
    "read_only":    "Verify write protection on read-only registers",
    "all":          "Run all tests in sequence",
}

# File organization
SIM_DIR = Path(__file__).parent.resolve()
RTL_DIR = SIM_DIR.parent / "rtl"
PKG_DIR = SIM_DIR / "pkg"
BFM_DIR = SIM_DIR / "bfm"
COMMON_DIR = SIM_DIR / "common"
WORK_DIR = SIM_DIR / "work"
SNAPSHOT_NAME = "sim_snapshot"

#==============================================================================
# Vivado Runner Class
#==============================================================================

class VivadoRunner:
    """Handles Vivado xsim tool execution."""
    
    def __init__(self, vivado_path: Optional[str] = None):
        self.vivado_bin = self._find_vivado(vivado_path)
        if not self.vivado_bin:
            raise RuntimeError("Vivado not found. Please set VIVADO_PATH or add to PATH.")
        print(f"[INFO] Using Vivado: {self.vivado_bin}")
    
    def _find_vivado(self, explicit_path: Optional[str]) -> Optional[Path]:
        """Find Vivado installation."""
        # Check explicit path first
        if explicit_path:
            p = Path(explicit_path)
            if p.exists():
                return p
        
        # Check environment variable
        env_path = os.environ.get("VIVADO_PATH")
        if env_path:
            p = Path(env_path)
            if p.exists():
                return p
        
        # Check common paths
        for path in VIVADO_PATHS:
            p = Path(path)
            if p.exists():
                return p
        
        # Check PATH
        xvlog = shutil.which("xvlog")
        if xvlog:
            return Path(xvlog).parent
        
        return None
    
    def _run_cmd(self, cmd: List[str], description: str) -> Tuple[int, str, str]:
        """Run command and capture output."""
        print(f"[CMD] {' '.join(cmd)}")
        
        env = os.environ.copy()
        env["PATH"] = str(self.vivado_bin) + os.pathsep + env.get("PATH", "")
        
        try:
            result = subprocess.run(
                cmd,
                cwd=str(SIM_DIR),
                capture_output=True,
                text=True,
                env=env,
                timeout=300  # 5 minute timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "Command timed out"
        except Exception as e:
            return -1, "", str(e)
    
    def compile(self, files: List[Path]) -> bool:
        """Compile SystemVerilog files."""
        print("\n" + "="*60)
        print("  COMPILATION")
        print("="*60)
        
        # Create work directory
        WORK_DIR.mkdir(exist_ok=True)
        
        cmd = ["xvlog", "-sv", "--work", "work=" + str(WORK_DIR)]
        cmd.extend([str(f) for f in files])
        
        rc, stdout, stderr = self._run_cmd(cmd, "Compilation")
        
        if rc != 0:
            print(f"[ERROR] Compilation failed (rc={rc})")
            print(stderr)
            return False
        
        # Check for errors in output
        if "ERROR:" in stdout or "ERROR:" in stderr:
            print("[ERROR] Compilation errors detected")
            print(stdout)
            print(stderr)
            return False
        
        print("[OK] Compilation successful")
        return True
    
    def elaborate(self, top_module: str = "tb_top") -> bool:
        """Elaborate design."""
        print("\n" + "="*60)
        print("  ELABORATION")
        print("="*60)
        
        cmd = [
            "xelab",
            "-debug", "typical",
            "-L", "work=" + str(WORK_DIR),
            f"work.{top_module}",
            "-s", SNAPSHOT_NAME
        ]
        
        rc, stdout, stderr = self._run_cmd(cmd, "Elaboration")
        
        if rc != 0:
            print(f"[ERROR] Elaboration failed (rc={rc})")
            print(stderr)
            return False
        
        if "ERROR:" in stdout or "ERROR:" in stderr:
            print("[ERROR] Elaboration errors detected")
            print(stdout)
            print(stderr)
            return False
        
        print("[OK] Elaboration successful")
        return True
    
    def simulate(self, test_name: str) -> Tuple[bool, str]:
        """Run simulation with specified test."""
        print("\n" + "="*60)
        print(f"  SIMULATION: {test_name}")
        print("="*60)
        
        cmd = [
            "xsim",
            SNAPSHOT_NAME,
            "-tclbatch", str(SIM_DIR / "xsim_cfg.tcl"),
            f"--testplusarg", f"TEST={test_name}"
        ]
        
        rc, stdout, stderr = self._run_cmd(cmd, f"Simulation ({test_name})")
        
        # Combine output
        output = stdout + "\n" + stderr
        
        if rc != 0 and "Simulation completed" not in output:
            print(f"[ERROR] Simulation failed (rc={rc})")
            return False, output
        
        return True, output

#==============================================================================
# Result Parser
#==============================================================================

class ResultParser:
    """Parses simulation output and results files."""
    
    def __init__(self):
        self.pass_count = 0
        self.fail_count = 0
        self.errors = []
        self.test_results = {}
    
    def parse_output(self, output: str, test_name: str) -> Dict:
        """Parse simulation stdout for results."""
        result = {
            "test": test_name,
            "passed": False,
            "pass_count": 0,
            "fail_count": 0,
            "errors": [],
            "duration_ns": 0
        }
        
        # Look for pass/fail counts
        pass_match = re.search(r"(\d+)\s+passed", output, re.IGNORECASE)
        fail_match = re.search(r"(\d+)\s+failed", output, re.IGNORECASE)
        
        if pass_match:
            result["pass_count"] = int(pass_match.group(1))
        if fail_match:
            result["fail_count"] = int(fail_match.group(1))
        
        # Look for errors
        error_lines = re.findall(r"\[.*ERROR.*\].*", output, re.IGNORECASE)
        result["errors"] = error_lines
        
        # Check for overall pass
        if "ALL TESTS PASSED" in output or (result["fail_count"] == 0 and result["pass_count"] > 0):
            result["passed"] = True
        elif "TEST PASSED" in output and result["fail_count"] == 0:
            result["passed"] = True
        
        # Extract simulation time
        time_match = re.search(r"Simulation completed at (\d+)\s*ns", output)
        if time_match:
            result["duration_ns"] = int(time_match.group(1))
        
        self.test_results[test_name] = result
        self.pass_count += result["pass_count"]
        self.fail_count += result["fail_count"]
        self.errors.extend(result["errors"])
        
        return result
    
    def parse_results_file(self, filepath: Path) -> Optional[Dict]:
        """Parse test_results.txt generated by testbench."""
        if not filepath.exists():
            return None
        
        try:
            with open(filepath, "r") as f:
                content = f.read()
            
            # Format: PASS_COUNT=N FAIL_COUNT=M
            result = {}
            for line in content.strip().split("\n"):
                if "=" in line:
                    key, val = line.split("=", 1)
                    result[key.strip()] = val.strip()
            
            return result
        except Exception as e:
            print(f"[WARN] Could not parse results file: {e}")
            return None

#==============================================================================
# Test Runner
#==============================================================================

class TestRunner:
    """Orchestrates test execution."""
    
    def __init__(self, vivado_runner: VivadoRunner):
        self.vivado = vivado_runner
        self.parser = ResultParser()
        self.results = {}
        self.start_time = None
        self.end_time = None
    
    def get_source_files(self) -> List[Path]:
        """Get all source files in compilation order."""
        files = []
        
        # Package first (defines types used by others)
        files.append(PKG_DIR / "tb_pkg.sv")
        
        # RTL files
        rtl_files = [
            "i2c_debounce.sv",
            "i2c_slave.sv", 
            "spi_slave.sv",
            "register_file.sv",
            "seven_seg.sv",
            "top.sv"
        ]
        for f in rtl_files:
            # Check both RTL_DIR and subdirectories
            for p in [RTL_DIR / f, RTL_DIR / "bus" / f, RTL_DIR / "core" / f, RTL_DIR / "io" / f]:
                if p.exists():
                    files.append(p)
                    break
        
        # BFMs
        files.append(BFM_DIR / "i2c_master_bfm.sv")
        files.append(BFM_DIR / "spi_master_bfm.sv")
        
        # Common verification components
        files.append(COMMON_DIR / "scoreboard.sv")
        files.append(COMMON_DIR / "test_base.sv")
        
        # Test modules (include all for compilation)
        test_dirs = [
            SIM_DIR / "tests" / "i2c_tests",
            SIM_DIR / "tests" / "spi_tests",
            SIM_DIR / "tests" / "integration_tests"
        ]
        for test_dir in test_dirs:
            if test_dir.exists():
                for f in test_dir.glob("*.sv"):
                    files.append(f)
        
        # Top testbench last
        files.append(SIM_DIR / "tb_top.sv")
        
        # Filter to existing files
        existing = [f for f in files if f.exists()]
        missing = [f for f in files if not f.exists()]
        
        if missing:
            print(f"[WARN] Missing files: {[str(f) for f in missing]}")
        
        return existing
    
    def run_test(self, test_name: str) -> bool:
        """Run a single test."""
        print(f"\n{'='*60}")
        print(f"  RUNNING TEST: {test_name}")
        print(f"{'='*60}")
        
        success, output = self.vivado.simulate(test_name)
        result = self.parser.parse_output(output, test_name)
        
        # Check results file
        results_file = SIM_DIR / "test_results.txt"
        file_results = self.parser.parse_results_file(results_file)
        if file_results:
            result["file_results"] = file_results
        
        self.results[test_name] = result
        
        status = "PASSED" if result["passed"] else "FAILED"
        print(f"\n[{status}] Test '{test_name}': {result['pass_count']} passed, {result['fail_count']} failed")
        
        return result["passed"]
    
    def run_all_tests(self, test_names: Optional[List[str]] = None) -> bool:
        """Run all specified tests (or all tests if none specified)."""
        self.start_time = datetime.now()
        
        if test_names is None or "all" in test_names:
            test_names = [t for t in TESTS.keys() if t != "all"]
        
        # Compile and elaborate once
        files = self.get_source_files()
        print(f"\n[INFO] Found {len(files)} source files")
        
        if not self.vivado.compile(files):
            return False
        
        if not self.vivado.elaborate():
            return False
        
        # Run each test
        all_passed = True
        for test_name in test_names:
            if test_name not in TESTS:
                print(f"[WARN] Unknown test: {test_name}")
                continue
            
            if not self.run_test(test_name):
                all_passed = False
        
        self.end_time = datetime.now()
        return all_passed
    
    def generate_report(self, output_file: Optional[Path] = None) -> Dict:
        """Generate JSON report."""
        report = {
            "timestamp": datetime.now().isoformat(),
            "duration_seconds": (self.end_time - self.start_time).total_seconds() if self.end_time else 0,
            "summary": {
                "total_tests": len(self.results),
                "passed": sum(1 for r in self.results.values() if r["passed"]),
                "failed": sum(1 for r in self.results.values() if not r["passed"]),
                "total_pass_count": self.parser.pass_count,
                "total_fail_count": self.parser.fail_count,
            },
            "tests": self.results,
            "errors": self.parser.errors[:50],  # Limit to 50 errors
        }
        
        report["summary"]["all_passed"] = report["summary"]["failed"] == 0
        
        if output_file:
            with open(output_file, "w") as f:
                json.dump(report, f, indent=2)
            print(f"\n[INFO] Report written to: {output_file}")
        
        return report
    
    def print_summary(self):
        """Print test summary to console."""
        print("\n" + "="*60)
        print("  VERIFICATION SUMMARY")
        print("="*60)
        
        for test_name, result in self.results.items():
            status = "✓ PASS" if result["passed"] else "✗ FAIL"
            print(f"  {status}  {test_name}: {result['pass_count']} passed, {result['fail_count']} failed")
        
        print("-"*60)
        total = len(self.results)
        passed = sum(1 for r in self.results.values() if r["passed"])
        failed = total - passed
        
        if failed == 0:
            print(f"  ALL {total} TESTS PASSED")
        else:
            print(f"  {passed}/{total} tests passed, {failed} FAILED")
        
        print("="*60)

#==============================================================================
# Utility Functions
#==============================================================================

def clean_build():
    """Remove build artifacts."""
    print("[INFO] Cleaning build artifacts...")
    
    patterns = [
        WORK_DIR,
        SIM_DIR / "xsim.dir",
        SIM_DIR / "*.log",
        SIM_DIR / "*.jou",
        SIM_DIR / "*.pb",
        SIM_DIR / "*.wdb",
        SIM_DIR / "*.vcd",
        SIM_DIR / "test_results.txt",
        SIM_DIR / "scoreboard_log.txt",
    ]
    
    for pattern in patterns:
        if isinstance(pattern, Path):
            if pattern.is_dir():
                shutil.rmtree(pattern, ignore_errors=True)
                print(f"  Removed directory: {pattern}")
            elif "*" in str(pattern):
                for f in SIM_DIR.glob(pattern.name):
                    f.unlink()
                    print(f"  Removed file: {f}")
            elif pattern.exists():
                pattern.unlink()
                print(f"  Removed file: {pattern}")
    
    print("[OK] Clean complete")

def list_tests():
    """Print available tests."""
    print("\nAvailable Tests:")
    print("-"*60)
    for name, desc in TESTS.items():
        print(f"  {name:15} - {desc}")
    print("-"*60)

#==============================================================================
# Main Entry Point
#==============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="FPGA Verification Automation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python verify.py                    # Run all tests
  python verify.py --test basic_write # Run specific test
  python verify.py --test basic_write --test loopback  # Run multiple tests
  python verify.py --list             # Show available tests
  python verify.py --clean            # Clean build artifacts
        """
    )
    
    parser.add_argument(
        "--test", "-t",
        action="append",
        dest="tests",
        help="Test(s) to run (can be specified multiple times)"
    )
    parser.add_argument(
        "--list", "-l",
        action="store_true",
        help="List available tests"
    )
    parser.add_argument(
        "--clean", "-c",
        action="store_true",
        help="Clean build artifacts"
    )
    parser.add_argument(
        "--report", "-r",
        type=Path,
        default=SIM_DIR / "verification_report.json",
        help="Output report file (default: verification_report.json)"
    )
    parser.add_argument(
        "--vivado-path",
        type=str,
        help="Path to Vivado bin directory"
    )
    
    args = parser.parse_args()
    
    # Handle simple commands
    if args.list:
        list_tests()
        return 0
    
    if args.clean:
        clean_build()
        return 0
    
    # Run tests
    try:
        vivado = VivadoRunner(args.vivado_path)
    except RuntimeError as e:
        print(f"[ERROR] {e}")
        print("\nPlease either:")
        print("  1. Set VIVADO_PATH environment variable")
        print("  2. Use --vivado-path argument")
        print("  3. Add Vivado bin directory to PATH")
        return 1
    
    runner = TestRunner(vivado)
    
    test_names = args.tests if args.tests else ["all"]
    all_passed = runner.run_all_tests(test_names)
    
    runner.print_summary()
    runner.generate_report(args.report)
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())