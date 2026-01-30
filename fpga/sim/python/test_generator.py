#!/usr/bin/env python3
"""
test_generator.py - Generate test stimulus files for I2C/SPI verification

Generates stimulus.txt files that can be read by the testbench to drive
transactions. Similar to the FIFO test generation approach.
"""

import random
import csv
from pathlib import Path
from typing import List, Tuple, Dict
from dataclasses import dataclass
from enum import Enum


class TransactionType(Enum):
    I2C_WRITE = "I2C_WR"
    I2C_READ = "I2C_RD"
    SPI_XFER = "SPI"


@dataclass
class I2CTransaction:
    """I2C transaction descriptor"""
    rw: int           # 0=write, 1=read
    slave_addr: int   # 7-bit address
    reg_addr: int     # Register address
    data: List[int]   # Data bytes
    
    def to_stimulus(self) -> str:
        """Convert to stimulus file format"""
        data_str = ','.join(f'{d:02X}' for d in self.data)
        return f"I2C {self.rw} {self.slave_addr:02X} {self.reg_addr:02X} {len(self.data)} {data_str}"


@dataclass 
class SPITransaction:
    """SPI transaction descriptor"""
    tx_data: List[int]  # Data to transmit
    
    def to_stimulus(self) -> str:
        """Convert to stimulus file format"""
        data_str = ','.join(f'{d:02X}' for d in self.tx_data)
        return f"SPI {len(self.tx_data)} {data_str}"


class RegisterMap:
    """Register map definitions loaded from CSV"""
    
    def __init__(self, csv_path: str = None):
        self.registers: Dict[int, dict] = {}
        self.writable_addrs: List[int] = []
        self.readonly_addrs: List[int] = []
        
        if csv_path:
            self.load_from_csv(csv_path)
        else:
            self._init_defaults()
    
    def _init_defaults(self):
        """Initialize with hardcoded defaults"""
        self.registers = {
            0x00: {'name': 'DEVICE_ID', 'access': 'RO', 'reset': 0xA7},
            0x01: {'name': 'VERSION_MAJ', 'access': 'RO', 'reset': 0x01},
            0x02: {'name': 'VERSION_MIN', 'access': 'RO', 'reset': 0x00},
            0x04: {'name': 'SYS_CTRL', 'access': 'RW', 'reset': 0x00},
            0x05: {'name': 'SCRATCH_0', 'access': 'RW', 'reset': 0x00},
            0x06: {'name': 'SCRATCH_1', 'access': 'RW', 'reset': 0x00},
            0x10: {'name': 'LINK_CAPS', 'access': 'RO', 'reset': 0x15},
            0x11: {'name': 'DATA_MODE', 'access': 'RW', 'reset': 0x00},
            0x12: {'name': 'DATA_CLK', 'access': 'RW', 'reset': 0x04},
            0x20: {'name': 'LED_OUT', 'access': 'RW', 'reset': 0x00},
            0x21: {'name': 'LED_OUT_H', 'access': 'RW', 'reset': 0x00},
            0x22: {'name': 'SW_IN', 'access': 'RO', 'reset': 0x00},
            0x24: {'name': 'SEG_DATA', 'access': 'RW', 'reset': 0x00},
            0x25: {'name': 'SEG_CTRL', 'access': 'RW', 'reset': 0x00},
        }
        self._categorize_registers()
    
    def load_from_csv(self, csv_path: str):
        """Load register map from CSV file"""
        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                addr = int(row['Address'], 16)
                self.registers[addr] = {
                    'name': row['Name'],
                    'access': row['Access'],
                    'reset': int(row['Reset'], 16),
                    'description': row.get('Description', '')
                }
        self._categorize_registers()
    
    def _categorize_registers(self):
        """Categorize registers by access type"""
        self.writable_addrs = []
        self.readonly_addrs = []
        
        for addr, reg in self.registers.items():
            if 'RW' in reg['access']:
                self.writable_addrs.append(addr)
            elif 'RO' in reg['access']:
                self.readonly_addrs.append(addr)


class TestGenerator:
    """Generate test stimulus patterns"""
    
    def __init__(self, slave_addr: int = 0x55, seed: int = None):
        self.slave_addr = slave_addr
        self.regmap = RegisterMap()
        if seed is not None:
            random.seed(seed)
    
    def gen_i2c_write(self, reg_addr: int, data: List[int]) -> I2CTransaction:
        """Generate single I2C write transaction"""
        return I2CTransaction(
            rw=0,
            slave_addr=self.slave_addr,
            reg_addr=reg_addr,
            data=data
        )
    
    def gen_i2c_read(self, reg_addr: int, num_bytes: int = 1) -> I2CTransaction:
        """Generate single I2C read transaction"""
        return I2CTransaction(
            rw=1,
            slave_addr=self.slave_addr,
            reg_addr=reg_addr,
            data=[0] * num_bytes  # Placeholder
        )
    
    def gen_spi_transfer(self, data: List[int]) -> SPITransaction:
        """Generate SPI transfer transaction"""
        return SPITransaction(tx_data=data)
    
    def gen_random_write_read(self) -> Tuple[I2CTransaction, I2CTransaction]:
        """Generate random write followed by read-back"""
        addr = random.choice(self.regmap.writable_addrs)
        data = [random.randint(0, 255)]
        
        write_txn = self.gen_i2c_write(addr, data)
        read_txn = self.gen_i2c_read(addr, 1)
        
        return write_txn, read_txn
    
    def gen_stress_sequence(self, num_iterations: int = 100) -> List:
        """Generate stress test sequence"""
        transactions = []
        
        for _ in range(num_iterations):
            write_txn, read_txn = self.gen_random_write_read()
            transactions.append(write_txn)
            transactions.append(read_txn)
        
        return transactions
    
    def gen_concurrent_sequence(self, num_pairs: int = 10) -> List:
        """Generate interleaved I2C and SPI transactions"""
        transactions = []
        
        for i in range(num_pairs):
            # I2C write
            addr = random.choice(self.regmap.writable_addrs)
            data = [random.randint(0, 255)]
            transactions.append(self.gen_i2c_write(addr, data))
            
            # SPI transfer (marked to run concurrently)
            spi_data = [random.randint(0, 255) for _ in range(random.randint(1, 4))]
            transactions.append(self.gen_spi_transfer(spi_data))
            
            # I2C read-back
            transactions.append(self.gen_i2c_read(addr, 1))
        
        return transactions
    
    def gen_spi_loopback_sequence(self, num_bytes: int = 16) -> List[SPITransaction]:
        """Generate SPI loopback test sequence"""
        # First transfer: send pattern, receive 0x00
        # Subsequent: receive previous pattern
        transactions = []
        
        for i in range(num_bytes):
            pattern = (i * 17 + 0x11) & 0xFF  # Walking pattern
            transactions.append(self.gen_spi_transfer([pattern]))
        
        return transactions
    
    def gen_read_only_test(self) -> List:
        """Generate tests for read-only register protection"""
        transactions = []
        
        for addr in self.regmap.readonly_addrs[:5]:  # Test first 5 RO regs
            # Read original value
            transactions.append(self.gen_i2c_read(addr, 1))
            # Attempt write
            transactions.append(self.gen_i2c_write(addr, [0x00]))
            # Read again (should be unchanged)
            transactions.append(self.gen_i2c_read(addr, 1))
        
        return transactions
    
    def write_stimulus_file(self, filepath: str, transactions: List):
        """Write transactions to stimulus file"""
        with open(filepath, 'w') as f:
            f.write("# I2C/SPI Stimulus File\n")
            f.write("# Format: TYPE [PARAMS...]\n")
            f.write(f"# Generated with seed for reproducibility\n\n")
            
            for txn in transactions:
                f.write(txn.to_stimulus() + "\n")
        
        print(f"Generated {len(transactions)} transactions to {filepath}")


def gen_basic_write_test(outfile: str):
    """Generate basic write/read test stimulus"""
    gen = TestGenerator(seed=42)
    
    transactions = [
        # Write to scratch register
        gen.gen_i2c_write(0x05, [0xA5]),
        # Read back
        gen.gen_i2c_read(0x05, 1),
        # Write different value
        gen.gen_i2c_write(0x05, [0x5A]),
        # Read back
        gen.gen_i2c_read(0x05, 1),
    ]
    
    gen.write_stimulus_file(outfile, transactions)


def gen_stress_test(outfile: str, iterations: int = 100):
    """Generate stress test stimulus"""
    gen = TestGenerator(seed=12345)
    transactions = gen.gen_stress_sequence(iterations)
    gen.write_stimulus_file(outfile, transactions)


def gen_concurrent_test(outfile: str, pairs: int = 10):
    """Generate concurrent I2C+SPI test"""
    gen = TestGenerator(seed=67890)
    transactions = gen.gen_concurrent_sequence(pairs)
    gen.write_stimulus_file(outfile, transactions)


# CLI entry point
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Generate test stimulus files")
    parser.add_argument('--type', '-t', choices=['basic', 'stress', 'concurrent', 'loopback'],
                        default='basic', help='Test type to generate')
    parser.add_argument('--output', '-o', default='stimulus.txt',
                        help='Output file path')
    parser.add_argument('--iterations', '-n', type=int, default=100,
                        help='Number of iterations for stress test')
    parser.add_argument('--seed', '-s', type=int, default=None,
                        help='Random seed for reproducibility')
    
    args = parser.parse_args()
    
    if args.type == 'basic':
        gen_basic_write_test(args.output)
    elif args.type == 'stress':
        gen_stress_test(args.output, args.iterations)
    elif args.type == 'concurrent':
        gen_concurrent_test(args.output)
    elif args.type == 'loopback':
        gen = TestGenerator(seed=args.seed)
        transactions = gen.gen_spi_loopback_sequence(16)
        gen.write_stimulus_file(args.output, transactions)