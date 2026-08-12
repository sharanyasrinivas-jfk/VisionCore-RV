# test_program.asm
# Exercises R-type, I-type, load/store, branch, and the AI
# accelerator's dot-product path (2-element dot product).

addi x1, x0, 10        # x1 = 10
addi x2, x0, 20        # x2 = 20
add  x3, x1, x2        # x3 = 30
sub  x4, x2, x1        # x4 = 10
and  x5, x1, x2        # x5 = 10 & 20
or   x6, x1, x2        # x6 = 10 | 20
xor  x7, x1, x2        # x7 = 10 ^ 20

sw   x3, 0(x0)         # mem[0] = 30
lw   x8, 0(x0)         # x8 = 30

addi x9, x0, 0         # loop counter
addi x10, x0, 5        # loop bound
addi x11, x0, 0        # accumulator

loop:
beq  x9, x10, done
add  x11, x11, x9
addi x9, x9, 1
jal  x0, loop

done:
# AI accelerator: dot product of [3,4] . [5,6] = 15+24 = 39
addi x20, x0, 3
addi x21, x0, 4
addi x22, x0, 5
addi x23, x0, 6
ai.mac x20, x22        # acc += 3*5 = 15
ai.mac x21, x23        # acc += 4*6 = 24  -> acc = 39
ai.read x24            # x24 = 39
