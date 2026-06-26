<div align="center">

# 🚀 Mini MIPS Processor & Hardware Accelerators
**A 32-bit Multi-Cycle Soft-Core CPU & Custom AXI4 Accelerators built for the Xilinx PYNQ-Z2 FPGA.**

[![Verilog](https://img.shields.io/badge/Language-Verilog-blue.svg)](#)
[![C](https://img.shields.io/badge/Language-C-00599C.svg)](#)
[![Vivado](https://img.shields.io/badge/Tool-Xilinx_Vivado-red.svg)](#)
[![Vitis](https://img.shields.io/badge/Tool-Xilinx_Vitis-orange.svg)](#)
[![Platform](https://img.shields.io/badge/Hardware-PYNQ--Z2-blueviolet.svg)](#)

</div>

## 📌 Project Overview
This repository contains the RTL source code, testbenches, and C-firmware for a custom **32-bit System-on-Chip (SoC)**. Designed completely from scratch, it features a 3-cycle multi-cycle MIPS processor alongside three high-performance hardware accelerators. 

Unlike standard academic implementations, this architecture strictly enforces **Structural Datapath Arithmetic** (zero behavioral `+`/`-` operations in the core datapath) to guarantee predictable FPGA synthesis, mitigate timing violations, and eliminate multi-driver conflicts.

## 📁 Architecture Layout

The repository employs a professional Hardware/Software co-design directory structure:

```text
├── src/
│   ├── hdl/                       # Hardware Description (Verilog)
│   │   ├── Processor.v            # 3-Cycle MIPS CPU FSM & Datapath
│   │   ├── Computer.v             # Memory Arbitration & Top-Level Wrapper
│   │   ├── Adder.v                # Strict Structural Ripple-Carry Logic
│   │   └── accelerators/          # AXI-Lite Hardware Accelerators
│   │       ├── VectorAccelerator.v  
│   │       ├── MatrixAccelerator.v  
│   │       └── GraphAccelerator.v   
│   ├── sw/                        # Firmware (Vitis C Applications)
│   │   ├── helloworld.c           # Unified MIPS Test Suite
│   │   └── accelerators/          
│   │       ├── vector_app.c       
│   │       ├── matrix_app.c       
│   │       └── graph_app.c        
│   └── tb/                        # Behavioral Testbenches
│       ├── tb_computer.v          
│       └── accelerators/          
├── IP_PACKAGING_GUIDE.md          # Guide for AXI-Lite Memory-Mapped IP Packaging
└── README.md
```

---

## 🧠 1. The 32-bit MIPS Soft-Core
A robust 3-cycle MIPS architecture (Fetch/Decode → Execute → Writeback) with execution-priority memory arbitration.

### Key Features:
- **Strict `$0` Hardwire:** Ensures register `$0` remains mathematically zero across all asynchronous reads, preventing ALU glitches.
- **Big-Endian Subword Extraction:** Dynamic hardware extraction and sign-extension (`lb`, `lh`, `lbu`, `lhu`), alongside read-modify-write protocols (`sb`, `sh`) for isolated byte storage.
- **I/O Handshaking:** `SYS_read` and `SYS_write` syscalls trigger pipeline stalls, communicating cleanly with the ARM PS environment over the AXI bus.
- **Safe Hardware Reset FSM:** The Vitis C firmware issues a complete soft reset before executing each machine code program.
- **Integer-Only Telemetry:** CPI calculation utilizes pure integer math to avoid ARM floating-point crashes over the UART terminal.

### Supported Instruction Set
| Category | Instructions |
| :--- | :--- |
| **Arithmetic & Logic** | `add`, `sub`, `and`, `or`, `addi`, `lui`, `ori` |
| **Control Flow** | `j`, `jal`, `jr`, `jalr`, `beq`, `bne`, `bltz`, `bgez`, `blez`, `bgtz` |
| **Comparisons** | `slt`, `sltu`, `slti`, `sltiu` |
| **Memory** | `lw`, `lh`, `lb`, `lbu`, `lhu`, `sw`, `sh`, `sb` |

---

## ⚡ 2. FPGA Hardware Accelerators
Three parallel accelerators were synthesized to exploit FPGA fabric density. These accelerators are packaged as AXI4 Peripherals and controlled by the ARM Cortex-A9 Processing System (PS) via Vitis IDE.

| Accelerator | Hardware Approach | Speedup over ARM |
| :--- | :--- | :--- |
| **Vector Addition** | `generate for` loops for 512 parallel structural adds + 9-cycle tree reduction. | **~150–200×** |
| **Matrix-Vector Mul** | Row inner products via 4-level structural tree reduction (7 cycles per row). | **~16×** |
| **Graph Pathfinding** | Boolean matrix multiplication (`A^k`) using packed 32-bit bitwise-ANDs. | **~1000×** |

## 🛠 Getting Started

1. Create a new Vivado RTL project targeting the **PYNQ-Z2**.
2. Add the source files from `src/hdl/`.
3. Follow the instructions in `IP_PACKAGING_GUIDE.md` to properly map the custom 32-register AXI4 address decoder.
4. Export the bitstream (`.xsa`) to Xilinx Vitis IDE.
5. Compile and run the applications in `src/sw/` on the ARM processor.
