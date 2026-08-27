IVERILOG ?= iverilog
VVP ?= vvp

BUILD_DIR := build
SIM := $(BUILD_DIR)/processor_system_tb

RTL := \
	rtl/alu_opcodes_pkg.sv \
	rtl/csr_pkg.sv \
	rtl/memory_pkg.sv \
	rtl/decoder_pkg.sv \
	rtl/alu.sv \
	rtl/decoder.sv \
	rtl/register_file.sv \
	rtl/instr_mem.sv \
	rtl/data_mem.sv \
	rtl/lsu.sv \
	rtl/interrupt_controller.sv \
	rtl/csr_controller.sv \
	rtl/operand_analyzer.sv \
	rtl/pre_res.sv \
	rtl/exp_corr.sv \
	rtl/rounding_module.sv \
	rtl/real_mul.sv \
	rtl/processor_core.sv \
	rtl/processor_system.sv

TB := tb/processor_system_tb.sv

.PHONY: all test compile clean

all: test

test: compile
	$(VVP) $(SIM)

compile:
	mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s lab_11_tb_processor_system \
		-o $(SIM) $(RTL) $(TB)

clean:
	rm -rf $(BUILD_DIR)
