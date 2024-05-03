# Custom Include for UVM
include ../Makefile.uvm

# Define ANSI Color Escape Codes
BOLD='\033[1m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m' # Reset text attributes to default

export CLOCK_PERIOD_PS = $(shell python3 ../synth/get_clock.py)

SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

PKG_SRCS  := $(PWD)/../pkg/types.sv
HDL_SRCS  := $(shell find $(PWD)/../hdl -not -path '*/modules/*' -name '*.sv')
HVL_SRCS  := $(shell find $(PWD)/../hvl -not -path '*/modules/*' -name '*.sv' -o -name '*.v')
SRAM_SRCS := $(shell find $(PWD)/../sram/output -name '*.v')
HDRS      := $(shell find $(PWD)/../hvl -not -path '*/modules/*' -name '*.svh')
DW_IP     := $(shell python3 get_dw_ip.py)
SRCS      := $(PKG_SRCS) $(HDL_SRCS) $(HVL_SRCS) $(SRAM_SRCS) $(DW_IP)

export VCS_ARCH_OVERRIDE=linux
VCS_FLAGS= -full64 -lca -sverilog -timescale=1ns/1ns -debug_acc+all -kdb -fsdb -suppress=LCA_FEATURES_ENABLED +incdir+$(DW)/sim_ver +define+DW_SUPPRESS_WARN
VCS_FLAGS_UVM= -full64 -lca -sverilog +lint=no -timescale=1ns/1ns -debug_acc+all -kdb -fsdb -suppress=LCA_FEATURES_ENABLED

# Custom test suite variables
TEST_SUITE_SRCS:=$(PKG_SRCS) $(HDL_SRCS) $(HVL_SRCS)
TEST_SUITE_SRCS+=$(shell find $(PWD)/../hvl/modules/$(DIR) -name '*.sv' -o -name '*.v')
TEST_SUITE_INC:=+incdir+$(PWD)/../hvl/modules/$(DIR)
TOP:=$(basename $(notdir $(shell find $(PWD)/../hvl/modules/$(DIR) -name 'top_tb**.sv')))

sim/top_tb: $(SRCS) $(HDRS)
	mkdir -p sim
	python3 ../bin/rvfi_reference.py
	python3 set_dw_ip.py
	cd sim && vcs $(SRCS) $(VCS_FLAGS) -msg_config=../vcs_warn.config -l compile.log -top top_tb -o top_tb
	bash check_compile_error.sh

.PHONY: run_top_tb
run_top_tb: sim/top_tb $(PROG)
	../bin/generate_memory_file.sh $(PROG)
	rm -f sim/dump.fsdb
	python3 ../synth/get_clock.py
	python3 get_bmem_x.py
	export ECE411_CLOCK_PERIOD_PS=$(shell python3 ../synth/get_clock.py) ;\
	export ECE411_BRAM_0_ON_X=$(shell python3 get_bmem_x.py) ;\
	export ECE411_MEMLST=$(PWD)/sim/memory ;\
	cd sim && ./top_tb -l simulation.log
	bash check_sim_error.sh

.PHONY: compile
compile: $(PROG)
	../bin/generate_memory_file.sh $(PROG)

.PHONY: compare
compare:
	@diff -s sim/commit.log sim/spike.log

.PHONY: test_suite
test_suite: $(TEST_SUITE_SRCS)
	@echo -e ${GREEN}Running Testbench: $(TOP) @ modules/$(DIR)${RESET}
	@echo -e ${GREEN}Running UVM TEST: $(TEST)${RESET}
	mkdir -p sim
	mkdir -p hdl
	cp ../hdl/toggle.sv hdl
	cd sim && vcs $(VCS) $(TEST_SUITE_SRCS) $(VCS_FLAGS_UVM) $(IP_INC) $(TEST_SUITE_INC) -msg_config=../vcs_warn.config -l top_test_suite_compile.log -top $(TOP) -o top_test_suite
	# bash check_compile_error_test_suite.sh
	rm -f sim/dump.fsdb
	cd sim && ./top_test_suite $(SIMV) -l top_test_suite_sim.log
	bash check_sim_error_test_suite.sh

.PHONY: covrep_test_suite
covrep_test_suite: sim/top_test_suite.vdb
	cd sim && urg -dir top_test_suite.vdb

.PHONY: info
info:
	@echo -e ${GREEN}WELCOME TO THE CUSTOM TEST SUITE!${RESET}
	@echo -e 
	@echo -e ${GREEN}make test_suite DIR=... TEST=...${RESET}
	@echo -e 
	@echo -e ${GREEN}DIR is the name of your directory in 'hvl/modules/...'${RESET}
	@echo -e ${GREEN}TEST is the name of your UVM test, UVM testbench specific${RESET}
	@echo -e 
	@echo -e ${GREEN}Example: make test_suite DIR=fifo TEST=fifo_test${RESET}
	@echo -e 

.PHONY: covrep
covrep: sim/top_tb.vdb
	cd sim && urg -dir top_tb.vdb

.PHONY: verdi
verdi:
	mkdir -p verdi
	cd verdi && $(VERDI_HOME)/bin/verdi -ssf $(PWD)/sim/dump.fsdb

.PHONY: spike
spike: $(ELF)
	mkdir -p sim
	spike --isa=rv32imc -m0x60000000:0x20000000 --log-commits $(ELF) |& tail -n +6 > sim/spike.log

.PHONY: interactive_spike
interactive_spike: $(ELF)
	mkdir -p sim
	spike --isa=rv32imc -m0x60000000:0x20000000 --log-commits -d $(ELF)

.PHONY: clean
clean:
	rm -rf bin sim verdi
