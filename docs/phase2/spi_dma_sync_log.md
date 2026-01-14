# Logging bit shift issues

## 1 phase SPI SWV, CPOL Low
Tx Buffer Addr: 0x30000000
Rx Buffer Addr: 0x30000040
Starting DMA SPI Test...
System Alive: 0 seconds | FPGA Link Active
System Alive: 1 seconds | FPGA Link Active
DMA: 100 | Match: 0 | Shifted: 63 | Rx[1]:C6 | Exp:63
System Alive: 2 seconds | FPGA Link Active
DMA: 200 | Match: 1 | Shifted: 63 | Rx[1]:8E | Exp:C7
System Alive: 3 seconds | FPGA Link Active
DMA: 300 | Match: 0 | Shifted: 63 | Rx[1]:56 | Exp:2B
System Alive: 4 seconds | FPGA Link Active
DMA: 400 | Match: 0 | Shifted: 63 | Rx[1]:1E | Exp:8F
System Alive: 5 seconds | FPGA Link Active
DMA: 500 | Match: 1 | Shifted: 63 | Rx[1]:E6 | Exp:F3
System Alive: 6 seconds | FPGA Link Active
DMA: 600 | Match: 0 | Shifted: 63 | Rx[1]:AE | Exp:57

## 2 phase SPI SWV, CPOL High
Tx Buffer Addr: 0x30000000
Rx Buffer Addr: 0x30000040
Starting DMA SPI Test...
System Alive: 0 seconds | FPGA Link Active
System Alive: 1 seconds | FPGA Link Active
DMA: 100 | Match: 4 | Shifted: 1 | Rx[1]:E7 | Exp:63
System Alive: 2 seconds | FPGA Link Active
DMA: 200 | Match: 8 | Shifted: 1 | Rx[1]:C7 | Exp:C7
System Alive: 3 seconds | FPGA Link Active
DMA: 300 | Match: 7 | Shifted: 8 | Rx[1]:2B | Exp:2B
System Alive: 4 seconds | FPGA Link Active
DMA: 400 | Match: 4 | Shifted: 0 | Rx[1]:8F | Exp:8F
System Alive: 5 seconds | FPGA Link Active
DMA: 500 | Match: 12 | Shifted: 7 | Rx[1]:F7 | Exp:F3
System Alive: 6 seconds | FPGA Link Active
DMA: 600 | Match: 3 | Shifted: 3 | Rx[1]:5F | Exp:57

## 2 phase SPI SWV, CPOL Low
Tx Buffer Addr: 0x30000000
Rx Buffer Addr: 0x30000040
Starting DMA SPI Test...
System Alive: 0 seconds | FPGA Link Active
System Alive: 1 seconds | FPGA Link Active
DMA: 100 | Match: 5 | Shifted: 2 | Rx[1]:E6 | Exp:63
System Alive: 2 seconds | FPGA Link Active
DMA: 200 | Match: 7 | Shifted: 2 | Rx[1]:CF | Exp:C7
System Alive: 3 seconds | FPGA Link Active
DMA: 300 | Match: 2 | Shifted: 4 | Rx[1]:7E | Exp:2B
System Alive: 4 seconds | FPGA Link Active
DMA: 400 | Match: 4 | Shifted: 0 | Rx[1]:8F | Exp:8F
System Alive: 5 seconds | FPGA Link Active
DMA: 500 | Match: 7 | Shifted: 10 | Rx[1]:E7 | Exp:F3
System Alive: 6 seconds | FPGA Link Active
DMA: 600 | Match: 5 | Shifted: 3 | Rx[1]:FE | Exp:57

## 2 phase SPI SWV, CPOL High
Tx Buffer Addr: 0x30000000
Rx Buffer Addr: 0x30000040
Starting DMA SPI Test...
System Alive: 0 seconds | FPGA Link Active
System Alive: 1 seconds | FPGA Link Active
DMA: 100 | Match: 0 | Shifted: 14 | Rx[1]:C4 | Exp:63
System Alive: 2 seconds | FPGA Link Active
DMA: 200 | Match: 1 | Shifted: 3 | Rx[1]:8D | Exp:C7
System Alive: 3 seconds | FPGA Link Active
DMA: 300 | Match: 0 | Shifted: 31 | Rx[1]:54 | Exp:2B
System Alive: 4 seconds | FPGA Link Active
DMA: 400 | Match: 0 | Shifted: 0 | Rx[1]:1D | Exp:8F
System Alive: 5 seconds | FPGA Link Active
DMA: 500 | Match: 1 | Shifted: 25 | Rx[1]:E5 | Exp:F3
System Alive: 6 seconds | FPGA Link Active
DMA: 600 | Match: 0 | Shifted: 20 | Rx[1]:AC | Exp:57

## FIX - 2 phase SPI SWV, CPOL LOW
Tx Buffer Addr: 0x30000000
Rx Buffer Addr: 0x30000040
Starting DMA SPI Test...
System Alive: 0 seconds | FPGA Link Active
System Alive: 1 seconds | FPGA Link Active
DMA: 100 | Match: 63 | Shifted: 0 | Rx[1]:63 | Exp:63
System Alive: 2 seconds | FPGA Link Active
DMA: 200 | Match: 63 | Shifted: 1 | Rx[1]:C7 | Exp:C7
System Alive: 3 seconds | FPGA Link Active
DMA: 300 | Match: 63 | Shifted: 0 | Rx[1]:2B | Exp:2B
System Alive: 4 seconds | FPGA Link Active
DMA: 400 | Match: 63 | Shifted: 0 | Rx[1]:8F | Exp:8F
System Alive: 5 seconds | FPGA Link Active
DMA: 500 | Match: 63 | Shifted: 1 | Rx[1]:F3 | Exp:F3
System Alive: 6 seconds | FPGA Link Active
DMA: 600 | Match: 63 | Shifted: 0 | Rx[1]:57 | Exp:57