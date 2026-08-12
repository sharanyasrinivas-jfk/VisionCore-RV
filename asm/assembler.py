#!/usr/bin/env python3
"""
assembler.py -- VisionCore-RV assembler

Converts a subset of RV32I assembly (plus the custom AI accelerator
instructions ai.load / ai.mac / ai.read) into a $readmemh-compatible
hex file consumable by rtl/instruction_memory.v.

Usage:
    python3 assembler.py input.asm output.mem
"""
import sys
import re

REGS = {f"x{i}": i for i in range(32)}
# common ABI aliases
ABI = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15,
    "a6": 16, "a7": 17,
    **{f"s{i}": 18 + (i - 2) for i in range(2, 12)},
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}
REGS.update(ABI)


def reg(tok):
    tok = tok.strip().rstrip(',')
    if tok not in REGS:
        raise ValueError(f"unknown register '{tok}'")
    return REGS[tok]


def imm_bits(val, bits):
    val = int(val)
    mask = (1 << bits) - 1
    return val & mask


R_TYPE = {
    "add":  (0b0110011, 0b000, 0b0000000),
    "sub":  (0b0110011, 0b000, 0b0100000),
    "and":  (0b0110011, 0b111, 0b0000000),
    "or":   (0b0110011, 0b110, 0b0000000),
    "xor":  (0b0110011, 0b100, 0b0000000),
    "sll":  (0b0110011, 0b001, 0b0000000),
    "srl":  (0b0110011, 0b101, 0b0000000),
    "sra":  (0b0110011, 0b101, 0b0100000),
    "slt":  (0b0110011, 0b010, 0b0000000),
    "sltu": (0b0110011, 0b011, 0b0000000),
}

I_TYPE_ARITH = {
    "addi":  (0b0010011, 0b000),
    "andi":  (0b0010011, 0b111),
    "ori":   (0b0010011, 0b110),
    "xori":  (0b0010011, 0b100),
    "slti":  (0b0010011, 0b010),
    "sltiu": (0b0010011, 0b011),
}

I_TYPE_LOAD = {
    "lw": (0b0000011, 0b010),
}

S_TYPE = {
    "sw": (0b0100011, 0b010),
}

B_TYPE = {
    "beq":  (0b1100011, 0b000),
    "bne":  (0b1100011, 0b001),
    "blt":  (0b1100011, 0b100),
    "bge":  (0b1100011, 0b101),
    "bltu": (0b1100011, 0b110),
    "bgeu": (0b1100011, 0b111),
}

AI_TYPE = {
    "ai.load": (0b0001011, 0b000),
    "ai.mac":  (0b0001011, 0b001),
    "ai.read": (0b0001011, 0b010),
}


def parse_mem_operand(tok):
    """'imm(rs1)' -> (imm, rs1)"""
    m = re.match(r"(-?\d+)\((\w+)\)", tok.strip())
    if not m:
        raise ValueError(f"bad memory operand '{tok}'")
    return int(m.group(1)), reg(m.group(2))


def encode_r(mnemonic, rd, rs1, rs2):
    opcode, funct3, funct7 = R_TYPE[mnemonic]
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_i(opcode, funct3, rd, rs1, imm):
    return (imm_bits(imm, 12) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_s(opcode, funct3, rs1, rs2, imm):
    imm = imm_bits(imm, 12)
    imm_hi = (imm >> 5) & 0x7F
    imm_lo = imm & 0x1F
    return (imm_hi << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_lo << 7) | opcode


def encode_b(opcode, funct3, rs1, rs2, imm):
    imm = imm_bits(imm, 13)
    bit12   = (imm >> 12) & 1
    bit11   = (imm >> 11) & 1
    bits10_5 = (imm >> 5) & 0x3F
    bits4_1  = (imm >> 1) & 0xF
    return (bit12 << 31) | (bits10_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (bits4_1 << 8) | (bit11 << 7) | opcode


def encode_j(rd, imm):
    opcode = 0b1101111
    imm = imm_bits(imm, 21)
    bit20    = (imm >> 20) & 1
    bits10_1 = (imm >> 1) & 0x3FF
    bit11    = (imm >> 11) & 1
    bits19_12 = (imm >> 12) & 0xFF
    return (bit20 << 31) | (bits10_1 << 21) | (bit11 << 20) | (bits19_12 << 12) | (rd << 7) | opcode


def encode_u(opcode, rd, imm):
    return (imm_bits(imm, 20) << 12) | (rd << 7) | opcode


def first_pass(lines):
    """Collect label -> instruction-index (word address) map."""
    labels = {}
    idx = 0
    for raw in lines:
        line = strip_comment(raw).strip()
        if not line:
            continue
        if line.endswith(':'):
            labels[line[:-1]] = idx
            continue
        if ':' in line and not line.startswith('.'):
            label, rest = line.split(':', 1)
            labels[label.strip()] = idx
            line = rest.strip()
            if not line:
                continue
        idx += 1
    return labels


def strip_comment(line):
    for marker in ('#', '//'):
        pos = line.find(marker)
        if pos != -1:
            line = line[:pos]
    return line


def tokenize(line):
    line = line.replace(',', ' ')
    return line.split()


def assemble(lines):
    labels = first_pass(lines)
    words = []
    pc = 0

    for raw in lines:
        line = strip_comment(raw).strip()
        if not line:
            continue
        if ':' in line and not line.startswith('.'):
            label, rest = line.split(':', 1)
            line = rest.strip()
            if not line:
                continue

        toks = tokenize(line)
        mnem = toks[0].lower()
        args = toks[1:]

        if mnem in R_TYPE:
            rd_, rs1_, rs2_ = reg(args[0]), reg(args[1]), reg(args[2])
            word = encode_r(mnem, rd_, rs1_, rs2_)

        elif mnem in I_TYPE_ARITH:
            opcode, funct3 = I_TYPE_ARITH[mnem]
            rd_, rs1_, imm_ = reg(args[0]), reg(args[1]), int(args[2])
            word = encode_i(opcode, funct3, rd_, rs1_, imm_)

        elif mnem in I_TYPE_LOAD:
            opcode, funct3 = I_TYPE_LOAD[mnem]
            rd_ = reg(args[0])
            off, rs1_ = parse_mem_operand(args[1])
            word = encode_i(opcode, funct3, rd_, rs1_, off)

        elif mnem in S_TYPE:
            opcode, funct3 = S_TYPE[mnem]
            rs2_ = reg(args[0])
            off, rs1_ = parse_mem_operand(args[1])
            word = encode_s(opcode, funct3, rs1_, rs2_, off)

        elif mnem in B_TYPE:
            opcode, funct3 = B_TYPE[mnem]
            rs1_, rs2_ = reg(args[0]), reg(args[1])
            target = labels[args[2]] if args[2] in labels else int(args[2])
            byte_offset = (target - pc) * 4 if args[2] in labels else target
            word = encode_b(opcode, funct3, rs1_, rs2_, byte_offset)

        elif mnem == "jal":
            rd_ = reg(args[0])
            target = labels[args[1]] if args[1] in labels else int(args[1])
            byte_offset = (target - pc) * 4 if args[1] in labels else target
            word = encode_j(rd_, byte_offset)

        elif mnem == "jalr":
            rd_ = reg(args[0])
            off, rs1_ = parse_mem_operand(args[1])
            word = encode_i(0b1100111, 0b000, rd_, rs1_, off)

        elif mnem == "lui":
            rd_, imm_ = reg(args[0]), int(args[1])
            word = encode_u(0b0110111, rd_, imm_)

        elif mnem == "auipc":
            rd_, imm_ = reg(args[0]), int(args[1])
            word = encode_u(0b0010111, rd_, imm_)

        elif mnem in AI_TYPE:
            opcode, funct3 = AI_TYPE[mnem]
            # ai.load rs1 / ai.mac rs1 rs2 / ai.read rd
            if mnem == "ai.load":
                rs1_ = reg(args[0])
                word = encode_i(opcode, funct3, 0, rs1_, 0)
            elif mnem == "ai.mac":
                rs1_, rs2_ = reg(args[0]), reg(args[1])
                word = encode_r("add", 0, rs1_, rs2_)  # reuse R encoding
                word = (word & ~0x7F) | opcode
                word = (word & ~(0x7 << 12)) | (funct3 << 12)
            elif mnem == "ai.read":
                rd_ = reg(args[0])
                word = encode_i(opcode, funct3, rd_, 0, 0)

        elif mnem == "nop":
            word = encode_i(0b0010011, 0b000, 0, 0, 0)  # addi x0, x0, 0

        else:
            raise ValueError(f"unknown mnemonic '{mnem}' in line: {raw!r}")

        words.append(word)
        pc += 1

    return words


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    src_path, dst_path = sys.argv[1], sys.argv[2]
    with open(src_path) as f:
        lines = f.readlines()

    words = assemble(lines)

    with open(dst_path, 'w') as f:
        for w in words:
            f.write(f"{w & 0xFFFFFFFF:08x}\n")

    print(f"Assembled {len(words)} instructions -> {dst_path}")


if __name__ == "__main__":
    main()
