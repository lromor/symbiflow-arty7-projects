# Point this where symbiflow-arch-defs is checked out
SYMBIFLOW_ARCH_DEFS?=/opt/fpga/symbiflow-arch-defs/

CONDA_DIR=$(SYMBIFLOW_ARCH_DEFS)/build/env/conda
YOSYS_BIN?=$(CONDA_DIR)/bin/yosys
VPR_BIN?=$(CONDA_DIR)/bin/vpr
GENFASM_BIN?=$(CONDA_DIR)/bin/genfasm

OPENOCD_BIN?=openocd

IOPLACE=PYTHONPATH=$(SYMBIFLOW_ARCH_DEFS)/utils \
	python3 $(SYMBIFLOW_ARCH_DEFS)/xc7/utils/prjxray_create_ioplace.py

# XC patch
XC7PATCH=$(SYMBIFLOW_ARCH_DEFS)/build/third_party/prjxray/tools/xc7patch

################ Symbiflow files dependencies ################

BASE_DIR=build/xc7/archs/artix7/devices

TARGET?=xc7a50t-arty-swbut

DEVICE=$(TARGET)-test

# Is this target outputting boths?
ARCH_TARGET?=file_xc7_archs_artix7_devices_$(TARGET)-roi-virt_synth_tiles_pinmap.csv
ARCH_TIMING=$(SYMBIFLOW_ARCH_DEFS)/$(BASE_DIR)/$(TARGET)-roi-virt/arch.timing.xml
ARCH_PINMAP=$(SYMBIFLOW_ARCH_DEFS)/$(BASE_DIR)/$(TARGET)-roi-virt/synth_tiles_pinmap.csv

# RRGRAPH
RR_GRAPH_TARGET?=artix7_$(TARGET)_test_rrxml_real
RR_GRAPH?=$(SYMBIFLOW_ARCH_DEFS)/$(BASE_DIR)/rr_graph_xc7a50t-arty-swbut_test.rr_graph.real.xml

# Convert FASM to frames
FASM2FRAMES=PYTHONPATH=$(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray:$(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray/third_party/fasm python3 $(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray/utils/fasm2frames.py

# Place and route parameters, some are just added to speedup the computation
VPR_PARAMS=--min_route_chan_width_hint 100 --max_criticality 0.0 --max_router_iterations 500 --routing_failure_predictor off --router_high_fanout_threshold -1 --constant_net_method route --route_chan_width 500 --clock_modeling route --place_algorithm bounding_box --enable_timing_computations off --allow_unrelated_clustering on --clustering_pin_feasibility_filter off --disable_check_route on --strict_checks off --allow_dangling_combinational_nodes on --disable_errors check_unbuffered_edges:check_route

GENFASM_PARAMS=--route_chan_width 500

################ Current project files and target ################

# Maps the FPGA IOs to the top module verilog symbols.
PCF=arty7.pcf

# Flashing. Just use good 'ol openocd. Everyone should've installed that on their machine.
DIGILENT_CONFIG=openocd-digilent-arty7.cfg

PROJECT=blink

all: top.bit

%.eblif : %.v synth.tcl
	symbiflow_arch_defs_SOURCE_DIR=$(SYMBIFLOW_ARCH_DEFS) OUT_EBLIF=$@ \
		$(YOSYS_BIN) -q -p "tcl synth.tcl" -l $@.log $<

%_io.place : %.eblif %.net
	$(IOPLACE) --pcf $(PCF) --map $(ARCH_PINMAP) --blif $< --net $*.net  --out $@

%.net: %.eblif
	$(VPR_BIN) $(ARCH_TIMING) $< --device $(DEVICE) --read_rr_graph $(RR_GRAPH) $(VPR_PARAMS) --pack > $*-pack.log

%.place: %.eblif %_io.place %.net
	$(VPR_BIN) $(ARCH_TIMING) $*.eblif\
		--device $(DEVICE) \
		--read_rr_graph $(RR_GRAPH) \
		--fix_pins $*_io.place --place \
		$(VPR_PARAMS) > $*-place.log

%.route: %.eblif %.place
	$(VPR_BIN) $(ARCH_TIMING) $*.eblif \
		--device $(DEVICE) \
		--read_rr_graph $(RR_GRAPH) \
		$(VPR_PARAMS) --route > $*-route.log

top.fasm: $(PROJECT).eblif $(PROJECT).place $(PROJECT).route $(PROJECT).net
	$(GENFASM_BIN) $(ARCH_TIMING) $(PROJECT).eblif \
		--device $(DEVICE) \
		$(VPR_PARAMS) \
		--read_rr_graph $(RR_GRAPH)> fasm.log

top.frames: top.fasm
	$(FASM2FRAMES) \
		--db-root $(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray-db/artix7 \
		--sparse --roi $(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray-db/artix7/harness/arty-a7/swbut/design.json $< $@

%.bit: %.frames
	$(XC7PATCH) --frm_file $^ \
		--output_file $@ \
		--bitstream_file $(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray-db/artix7/harness/arty-a7/swbut/design.bit \
		--part_name xc7a35tcpg236-1 --part_file $(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray-db/artix7/xc7a35tcpg236-1.yaml

prog: top.bit
	$(OPENOCD_BIN) -f $(DIGILENT_CONFIG) -c "init ; pld load 0 $^ ; exit"

clean:
	rm -f *.log *.eblif *.place *.rpt *.net *.route *.fasm *.frames
