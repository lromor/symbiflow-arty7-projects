# Point this where symbiflow-arch-defs is checked out
SYMBIFLOW_ARCH_DEFS?=/opt/fpga/symbiflow-arch-defs/

################ Black magic starts ##############
#-- io place
IOPLACE=PYTHONPATH=$(SYMBIFLOW_ARCH_DEFS)/utils python3 $(SYMBIFLOW_ARCH_DEFS)/xc7/utils/prjxray_create_ioplace.py
MAP=$(SYMBIFLOW_ARCH_DEFS)/build/xc7/archs/artix7/devices/xc7a50t-arty-swbut-roi-virt/synth_tiles_pinmap.csv

#-- VPR
VPR_BIN?=vpr

DEVICE=xc7a50t-arty-swbut-test
ARCH_TIMING_XML=$(SYMBIFLOW_ARCH_DEFS)/build/xc7/archs/artix7/devices/xc7a50t-arty-swbut-roi-virt/arch.timing.xml
RR_GRAPH=$(SYMBIFLOW_ARCH_DEFS)/build/xc7/archs/artix7/devices/rr_graph_xc7a50t-arty-swbut_test.rr_graph.real.xml

# FASM
GENFASM_BIN?=genfasm

# XC patch
XC7PATCH=$(SYMBIFLOW_ARCH_DEFS)/build/third_party/prjxray/tools/xc7patch

# Convert FASM to frames
FASM2FRAMES=PYTHONPATH=$(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray:$(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray/third_party/fasm python3 $(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray/utils/fasm2frames.py

# yosys
YOSYS_BIN=yosys

# vpr params
#VPR_PARAMS=--route_chan_width 500 --disable_errors check_unbuffered_edges:check_route
VPR_PARAMS=--min_route_chan_width_hint 100 \
	--max_criticality 0.0 --max_router_iterations 500 \
	--routing_failure_predictor off --router_high_fanout_threshold -1 \
	--constant_net_method route --route_chan_width 500 \
	--clock_modeling route --place_algorithm bounding_box \
	--enable_timing_computations off --allow_unrelated_clustering on \
	--clustering_pin_feasibility_filter off --disable_check_route on \
	--strict_checks off --allow_dangling_combinational_nodes on \
	--disable_errors check_unbuffered_edges:check_route


################ Black magic ends ##############

# Io board files
PCF=arty7.pcf

# Flashing. Just use good 'ol openocd. Everyone should've installed that on their machine.
OPENOCD_BIN?=openocd

PROJECT=blink

all: top.bit

%.eblif : %.v synth.tcl
	symbiflow_arch_defs_SOURCE_DIR=$(SYMBIFLOW_ARCH_DEFS) \
        OUT_EBLIF=$@ \
        $(YOSYS_BIN) -q -p "tcl synth.tcl" -l $@.log $<

%_io.place : %.eblif
	$(IOPLACE) --pcf $(PCF) --map $(MAP) --blif $^ --out $@

%.net: %.eblif
	$(VPR_BIN) $(ARCH_TIMING_XML) $< --device $(DEVICE) --read_rr_graph $(RR_GRAPH) $(VPR_PARAMS) --pack > $*-pack.log

%.place: %.eblif %_io.place %.net
	$(VPR_BIN) $(ARCH_TIMING_XML) $*.eblif --device $(DEVICE) --read_rr_graph $(RR_GRAPH) $(VPR_PARAMS) --fix_pins $*_io.place --place > $*-place.log

%.route: %.eblif %.place
	$(VPR_BIN) $(ARCH_TIMING_XML) $*.eblif --device $(DEVICE) --read_rr_graph $(RR_GRAPH) $(VPR_PARAMS) --route > $*-route.log

top.fasm: $(PROJECT).eblif $(PROJECT).place $(PROJECT).route $(PROJECT).net
	$(GENFASM_BIN) $(ARCH_TIMING_XML) $(PROJECT).eblif --device $(DEVICE) --read_rr_graph $(RR_GRAPH) $(VPR_PARAMS) > fasm.log

top.frames: top.fasm
	$(FASM2FRAMES) --db-root $(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray-db/artix7 --sparse --roi $(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray-db/artix7/harness/arty-a7/swbut/design.json $< $@

%.bit: %.frames
	$(XC7PATCH) --frm_file $^ --output_file $@ --bitstream_file $(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray-db/artix7/harness/arty-a7/swbut/design.bit --part_name xc7a35tcpg236-1 --part_file $(SYMBIFLOW_ARCH_DEFS)/third_party/prjxray-db/artix7/xc7a35tcpg236-1.yaml

prog: top.bit
	$(OPENOCD_BIN) -f $(DIGILENT_CONFIG) -c "init ; pld load 0 $^ ; exit"

clean:
	rm -f *.log *.eblif *.place *.rpt *.net *.route
