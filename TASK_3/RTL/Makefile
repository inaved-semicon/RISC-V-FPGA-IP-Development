# Task 2 FPGA build flow for the VSDSquadron Mini board
TOP=SOC
PCF_FILE=VSDSquadronFM
BOARD_FREQ=10
CPU_FREQ=12
FPGA_VARIANT=up5k
FPGA_PACKAGE=sg48
VERILOG_FILE=riscv.v
PICO_DEVICE=/dev/ttyUSB0
BAUDS=9600

build:
	yosys -q -p "synth_ice40 -abc9 -device u -dsp -top $(TOP) -json $(TOP).json" $(VERILOG_FILE)
	nextpnr-ice40 --force --json $(TOP).json --pcf $(PCF_FILE).pcf --asc $(TOP).asc --freq $(BOARD_FREQ) --$(FPGA_VARIANT) --package $(FPGA_PACKAGE) --opt-timing
	icetime -p $(PCF_FILE).pcf -P $(FPGA_PACKAGE) -r $(TOP).timings -d $(FPGA_VARIANT) -t $(TOP).asc
	icepack -s $(TOP).asc $(TOP).bin

flash:
	iceprog $(TOP).bin

terminal:
	sudo picocom -b $(BAUDS) $(PICO_DEVICE) --imap lfcrlf,crcrlf --omap delbs,crlf --send-cmd "ascii-xfr -s -l 30 -n"

clean:
	rm -rf $(TOP).blif $(TOP).asc $(TOP).bin $(TOP).json $(TOP).timings
