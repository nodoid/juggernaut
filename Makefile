# Juggernaut for the Oric Atmos.  Needs cc65 (cl65/ca65/ld65) and python3.
CL65    = cl65
BUILD   = build
TAP     = $(BUILD)/juggernaut.tap

CSRC    = src/main.c
ASRC    = src/game.s src/header.s src/hw.s src/screen.s src/dash.s \
          src/town.s src/truck.s src/ui.s src/sound.s \
          data/font.s data/tables.s data/town.s data/gfx.s
INC     = src/hw.inc src/zp.inc

all: $(TAP)

$(TAP): $(CSRC) $(ASRC) $(INC)
	@mkdir -p $(BUILD)
	$(CL65) -t atmos -O -I src -C src/juggernaut.cfg --obj-path $(BUILD) \
	        -m $(BUILD)/juggernaut.map -Ln $(BUILD)/juggernaut.lbl \
	        -o $@ $(CSRC) $(ASRC)

assets:
	python3 tools/gen_assets.py

run: $(TAP)
	tools/run.sh

clean:
	rm -rf $(BUILD)

.PHONY: all assets run clean
