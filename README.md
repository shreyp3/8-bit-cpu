# 8-Bit CPU — Custom ISA on Intel DE10-Lite FPGA
 
A fully functional 8-bit CPU designed from scratch in VHDL and deployed on an Intel DE10-Lite FPGA. The processor implements a custom instruction set architecture (ISA) with a multi-stage controller, hardware ALU, dedicated register file, program counter, and ROM-based instruction memory — executing stored programs automatically through a fetch-decode-execute pipeline.
 
---
 
## Architecture Overview
 
The CPU is organized as a two-register, accumulator-style architecture with the following top-level components:
 
```
┌─────────────────────────────────────────────────────────────┐
│                        CPU Top Level                        │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌────────────────────────┐ │
│  │   ROM    │    │    PC    │    │      Controller        │ │
│  │ 256 x 8  │    │  8-bit   │    │   (FSM — VHDL)        │ │
│  │          │───▶│ counter  │    │                        │ │
│  └──────────┘    └────┬─────┘    │ Outputs:               │ │
│       ▲               │ addr     │   MSA1:0  (MUX A sel)  │ │
│       │               ▼          │   MSB1:0  (MUX B sel)  │ │
│       │          ┌────────┐      │   MSC3:0  (ALU op sel) │ │
│       │          │  IR    │      │   IR.LD               │ │
│       │          │ 6-bit  │─────▶│   PC_INC              │ │
│       │          └────────┘      │   PC_LD               │ │
│       │                          └────────────────────────┘ │
│       │                                    │                 │
│  ┌────┴──────────────────────────────────────────────────┐  │
│  │                     ALU Datapath                      │  │
│  │                                                       │  │
│  │  INPUT bus ──▶ [MUX A] ──▶ REGA ──▶ [Combinatorial] │  │
│  │  REGA bus  ──▶ [MUX B] ──▶ REGB ──▶ [Logic Block  ] │  │
│  │  REGB bus  ──▶                       [            ] │  │
│  │  OUTPUT bus──▶               ──────▶ [MUX C (16:1)] ──▶ OUTPUT │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```
 
---
 
## Components
 
### ALU
The arithmetic-logic unit is built around two 4-bit-wide 4:1 input multiplexers (MUX A and MUX B) feeding two 8-bit registers (REGA, REGB), whose outputs pass through a combinatorial logic block. A 16:1 output multiplexer (MUX C) selects from 16 possible operations:
 
| MSC3:0 | Operation |
|---|---|
| 0000 | Pass REGA to output |
| 0001 | Pass REGB to output |
| 0010 | Bitwise complement of REGA |
| 0011 | Bitwise AND of REGA & REGB |
| 0100 | Bitwise OR of REGA & REGB |
| 0101 | Unsigned addition REGA + REGB |
| 0110 | Logical right shift REGA by 1 |
| 0111 | Arithmetic right shift REGA by 1 |
| 1101 | Two's complement addition REGA + REGB |
| 1110 | Left rotate with carry |
| 1111 | Arithmetic left shift REGA |
 
### Instruction Register (IR)
A 6-bit register with a load-enable signal (`IR.LD`). When `IR.LD` is asserted, the IR captures the current byte from ROM at the next clock edge. When deasserted, the IR holds its value. Implemented using a 2:1 MUX on each D flip-flop input.
 
### Program Counter (PC)
An 8-bit synchronous up-counter with two control signals:
- `PC_INC` — increment PC by 1 at next clock edge (instruction fetch advance)
- `PC_LD` — synchronously load PC from the INPUT bus (used by jump instructions)
Supports a full 256-byte address space, wrapping from `0xFF` to `0x00`.
 
### ROM (Instruction Memory)
A 256 × 8 ROM storing the program as hand-assembled machine code in a `.mif` (Memory Initialization File). The ROM output feeds directly into the INPUT bus, replacing manual switch input with automatic instruction fetch.
 
### Controller (FSM)
A finite state machine implemented in VHDL that decodes the 6-bit opcode in IR and drives all datapath control signals. Each instruction follows a fetch-decode-execute sequence where:
1. The controller asserts `IR.LD` and increments PC to fetch the next opcode
2. On the following clock, the IR holds the opcode and the FSM transitions to the appropriate execution state
3. Execution states drive MSA, MSB, MSC, PC_INC, and PC_LD as required by the instruction
---
 
## Instruction Set Architecture
 
The CPU supports an 19-instruction ISA encoded in 6 bits (`IR5:0`):
 
| Opcode | Mnemonic | Operation |
|---|---|---|
| 00000 | `TAB` | Copy REGA → REGB |
| 00001 | `LDAA #data` | Load REGA with immediate data byte |
| 00010 | `COMA` | Bitwise complement REGA |
| 00011 | `ABAC` | REGA = REGA + REGB + Carry |
| 00100 | `ABA` | REGA = REGA + REGB (unsigned) |
| 00101 | `SLRA #n` | Logical shift REGA right by n bits |
| 00110 | `SLLA #n` | Logical shift REGA left by n bits |
| 00111 | `JMP addr` | Unconditional jump — load PC with address byte |
| 01000 | `JMPZ addr` | Jump if REGA = 0 |
| 01001 | `JMPNEGA addr` | Jump if REGA is negative (MSB = 1) |
| 01010 | `MULT` | REGA = REGA × REGB |
| 01011 | `BRAZR offset` | Branch relative if REGA = 0 (2's complement offset) |
| 01100 | `INCA` | REGA = REGA + 1 |
| 01101 | `SABA` | REGA = REGA + REGB (two's complement) |
| 01110 | `SARA` | Arithmetic right shift REGA by 1 |
| 01111 | `SABAC` | REGA = REGA + REGB + Carry (two's complement) |
| 10000 | `ROTL #n` | Left rotate REGA with carry by n bits |
| 10001 | `SABAV` | Two's complement add; update overflow flag V |
| 10010 | `SABACV` | Two's complement add with carry; update overflow flag V |
| 10011–11111 | `NOP` | Reserved / no operation |
 
Multi-byte instructions (`LDAA`, `JMP`, `JMPZ`, `JMPNEGA`, `BRAZR`) require additional fetch cycles — the controller automatically increments PC to read the operand byte from ROM before executing.
 
---
 
## Design Implementation
 
- **Language:** VHDL for all major components (ALU, controller FSM, IR, PC)
- **Top-level integration:** Schematic (BDF) in Intel Quartus Prime connecting subsystems
- **Target device:** Intel DE10-Lite FPGA (Altera MAX 10)
- **Simulation:** Functional and timing simulation validated in ModelSim before synthesis
- **Reset:** Active-low asynchronous reset (`RESET`) initializes all registers and the FSM to a known zero state
- **Clock:** Debounced clock input for manual single-step testing during hardware verification
- **Program storage:** Hand-assembled machine code loaded via `.mif` file into on-chip ROM
---
 
## Example Program
 
The following program demonstrates branching and accumulation — the loop runs until REGA reaches zero, exercising the conditional branch, unsigned addition, shift, and jump instructions:
 
```
$00  LDAA #2     ; A = 2
$02  TAB         ; B = 2
$03  SARA        ; A = 1 (arithmetic right shift)
$04  ABA         ; A = A + B
$05  ABA         ; A = A + B (loop body)
$07  SLLA #1     ; A = A << 1
$08  JMP $04     ; unconditional jump back to loop
```
 
---
 
## What This Project Demonstrates
 
- **Digital logic design** — ALU construction from multiplexers, combinatorial logic, and registers
- **Finite state machine design** — multi-state controller driving all datapath signals across fetch, decode, and execute phases
- **Custom ISA design** — instruction encoding, multi-byte instruction handling, conditional branching with relative and absolute addressing
- **VHDL hardware description** — synthesizable RTL code for all major CPU components
- **FPGA toolchain proficiency** — synthesis, place-and-route, and hardware verification in Intel Quartus Prime
- **Computer architecture fundamentals** — program counter sequencing, instruction memory, register file, and control signal generation implemented in real hardware
