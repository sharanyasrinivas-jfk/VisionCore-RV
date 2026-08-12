# ============================================================
# VisionCore-RV Makefile
# ============================================================
ASM        ?= asm/test_program.asm
MEMFILE    := sim/instructions.mem

RTL_COMMON := rtl/cla_adder.v rtl/alu.v rtl/register_file.v rtl/decoder.v \
              rtl/control_unit.v rtl/ai_accelerator.v rtl/instruction_memory.v \
              rtl/data_memory.v rtl/branch_unit.v

RTL_PIPE   := rtl/pipeline_regs.v rtl/hazard_unit.v rtl/forwarding_unit.v \
              rtl/visioncore_pipeline.v

.PHONY: all asm single pipeline clean wave-single wave-pipeline

all: single pipeline

asm:
	python3 asm/assembler.py $(ASM) $(MEMFILE)

single: asm
	iverilog -o sim/single.out $(RTL_COMMON) rtl/visioncore_single.v sim/tb_single.v
	vvp sim/single.out

pipeline: asm
	iverilog -o sim/pipeline.out $(RTL_COMMON) $(RTL_PIPE) sim/tb_pipeline.v
	vvp sim/pipeline.out

wave-single: single
	gtkwave sim/single.vcd &

wave-pipeline: pipeline
	gtkwave sim/pipeline.vcd &

clean:
	rm -f sim/*.out sim/*.vcd sim/instructions.mem
