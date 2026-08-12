# VisionCore-RV — AI-Enhanced 32-bit RISC-V Processor

A from-scratch RV32I processor in Verilog, built in two forms — a
single-cycle reference core and a 5-stage pipelined core with hazard
detection and full operand forwarding — plus a custom AI accelerator
reachable through the `custom-0` opcode space. Both cores are
verified against each other with Icarus Verilog.

## What's implemented

**ISA (RV32I subset):**
- R-type: `add sub and or xor sll srl sra slt sltu`
- I-type: `addi andi ori xori slti sltiu slli srli srai lw jalr`
- S-type: `sw`
- B-type: `beq bne blt bge bltu bgeu`
- U-type: `lui auipc`
- J-type: `jal`
- Custom-0: `ai.load ai.mac ai.read` (AI accelerator)

**Single-cycle core** (`rtl/visioncore_single.v`) — every instruction
completes in one clock. This is the reference model the pipeline is
checked against.

**Pipelined core** (`rtl/visioncore_pipeline.v`) — classic 5-stage
IF → ID → EX → MEM → WB:
- Full forwarding (EX/MEM and MEM/WB feed back into EX) for ALU
  operands, branch comparisons, store data, and AI accelerator
  operands.
- Load-use hazard detection stalls IF/ID for one cycle when an
  instruction needs a value the previous `lw` hasn't fetched yet.
- Branches and jumps resolve in EX (no prediction), flushing IF/ID
  and ID/EX on a taken branch — a 2-cycle penalty.
- A WB-to-ID bypass mux (in the top-level pipeline file, not inside
  `register_file.v`) covers the case where a register's WB write and
  a dependent instruction's ID read land on the same clock edge. It's
  kept out of the register file itself because building it in there
  creates a real combinational loop for same-cycle single-cycle
  instructions like `addi x9, x9, 1` (source and destination the same
  register) — see the comment in `register_file.v`.

**AI accelerator** (`rtl/ai_accelerator.v`) — a small MAC unit
reachable via three custom instructions, replacing a multiply-add
software loop with one instruction per term:
```
ai.load rs1        # (reserved for streaming operand loads)
ai.mac  rs1, rs2    # acc += rs1 * rs2
ai.read rd          # rd = acc; acc clears
```
`asm/test_program.asm` computes a 2-element dot product
`[3,4]·[5,6] = 39` this way and both cores confirm the result.

**Arithmetic:** the ALU's adder is a genuine 32-bit carry look-ahead
adder (`rtl/cla_adder.v`), built from cascaded 4-bit CLA blocks with
generate/propagate logic, not a ripple-carry chain.

**Toolchain:** `asm/assembler.py` turns the assembly subset above
(labels, comments, standard and ABI register names) into a
`$readmemh`-compatible hex file consumed by `rtl/instruction_memory.v`.

**UART** (`rtl/uart_tx.v`) — a standalone 8N1 transmitter, not yet
wired into either core's datapath. It's there as the starting point
for streaming results (e.g. an AI accelerator read) out to a host PC.

## Structure
```
VisionCore-RV/
│
├── asm/
│   ├── assembler.py
│   └── test_program.asm
│
├── docs/
│   ├── AI Accelerator Datapath Diagram.png
│   ├── CPU Pipeline Branch Flush Diagram.png
│   ├── CPU Pipeline Forwarding Unit Diagram.png
│   ├── FIVE STAGE PIPELINE DATAPATH.png
│   ├── Load–Use Hazard Stall Diagram.png
│   ├── Processor Core Verification Flowchart.png
│   ├── Single-Cycle RISC-V Datapath Diagram.png
│   └── VisionCore-RV Architecture Overview.png
│
├── rtl/
│   ├── cla_adder.v
│   ├── alu.v
│   ├── register_file.v
│   ├── decoder.v
│   ├── control_unit.v
│   ├── branch_unit.v
│   ├── ai_accelerator.v
│   ├── instruction_memory.v
│   ├── data_memory.v
│   ├── uart_tx.v
│   ├── visioncore_single.v
│   ├── pipeline_regs.v
│   ├── hazard_unit.v
│   ├── forwarding_unit.v
│   └── visioncore_pipeline.v
│
├── sim/
│   ├── tb_single.v
│   └── tb_pipeline.v
│
├── Makefile
├── README.md
└── .gitignore
```

## Running it

Requires Icarus Verilog (`iverilog`/`vvp`) and Python 3.

```bash
make single      # assemble test_program.asm, run the single-cycle core
make pipeline    # assemble test_program.asm, run the pipelined core
make all         # both

make wave-single    # same, then open the waveform in GTKWave
make wave-pipeline
```

Both testbenches check the same five results — `add`, `sub`, a
load-after-store, a software loop (branch + jump), and the AI
accelerator dot product — and both currently `PASS`.

## Known gaps (next steps)

- No `jalr`-based function-call convention exercised yet (return
  addresses work, but there's no test program using them).
- `ai.load` is decoded but unused — the accelerator currently takes
  both operands directly from `rs1`/`rs2` on `ai.mac` rather than
  streaming from a queue; extending it to matrix-sized operations
  would use `ai.load` to stage a row/column first.
- UART is not yet wired to the CPU (no memory-mapped I/O or dedicated
  instruction hooks it up to `ai.read` output, etc.).
- No FPGA constraints/board files — this has only been simulated.
